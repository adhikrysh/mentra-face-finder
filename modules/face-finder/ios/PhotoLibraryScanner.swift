import Foundation
import Photos
import UIKit

protocol PhotoLibraryScannerDelegate: AnyObject {
    func scannerDidUpdateProgress(total: Int, completed: Int, facesFound: Int)
    func scannerDidComplete(totalFaces: Int)
    func scannerDidFail(error: Error)
}

final class PhotoLibraryScanner {

    weak var delegate: PhotoLibraryScannerDelegate?

    private let detector: FaceDetector
    private let aligner: FaceAligner.Type = FaceAligner.self
    private let embedder: FaceEmbedder
    private let store: EmbeddingStore
    private let clusterManager: FaceClusterManager

    private let batchSize = 50
    private let maxImageDimension: CGFloat = 1024
    private let processingQueue = DispatchQueue(label: "com.mentra.facefinder.scan", qos: .utility)

    private var isScanning = false
    private var totalPhotos = 0
    private var completedPhotos = 0
    private var facesFound = 0

    init(
        detector: FaceDetector,
        embedder: FaceEmbedder,
        store: EmbeddingStore,
        clusterManager: FaceClusterManager
    ) {
        self.detector = detector
        self.embedder = embedder
        self.store = store
        self.clusterManager = clusterManager
    }

    /// Start scanning the photo library. Call from main thread; processing happens on background queue.
    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        completedPhotos = 0
        facesFound = 0

        processingQueue.async { [weak self] in
            self?.performScan()
        }
    }

    // MARK: - Private

    private func performScan() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized else {
            delegate?.scannerDidFail(error: ScannerError.notAuthorized)
            isScanning = false
            return
        }

        // Fetch all image assets, newest first
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        // Only scan assets newer than last scan watermark
        if let lastScanDate = UserDefaults.standard.object(forKey: "facefinder_lastScanDate") as? Date {
            options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                options.predicate!,
                NSPredicate(format: "creationDate > %@", lastScanDate as NSDate)
            ])
        }

        let assets = PHAsset.fetchAssets(with: .image, options: options)
        totalPhotos = assets.count

        if totalPhotos == 0 {
            delegate?.scannerDidComplete(totalFaces: 0)
            isScanning = false
            return
        }

        delegate?.scannerDidUpdateProgress(total: totalPhotos, completed: 0, facesFound: 0)

        // Process in batches
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact
        requestOptions.isNetworkAccessAllowed = true // Allow iCloud downloads

        for startIndex in stride(from: 0, to: totalPhotos, by: batchSize) {
            guard isScanning else { break }

            let endIndex = min(startIndex + batchSize, totalPhotos)

            for i in startIndex..<endIndex {
                guard isScanning else { break }

                let asset = assets[i]
                let targetSize = CGSize(
                    width: min(CGFloat(asset.pixelWidth), maxImageDimension),
                    height: min(CGFloat(asset.pixelHeight), maxImageDimension)
                )

                imageManager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFit,
                    options: requestOptions
                ) { [weak self] image, info in
                    guard let self = self, let image = image, let cgImage = image.cgImage else {
                        return
                    }

                    self.processImage(
                        cgImage: cgImage,
                        asset: asset
                    )
                }

                completedPhotos += 1
                delegate?.scannerDidUpdateProgress(
                    total: totalPhotos,
                    completed: completedPhotos,
                    facesFound: facesFound
                )
            }

            // Yield between batches to avoid memory pressure
            autoreleasepool { }
        }

        // Update watermark
        UserDefaults.standard.set(Date(), forKey: "facefinder_lastScanDate")

        delegate?.scannerDidComplete(totalFaces: facesFound)
        isScanning = false
    }

    private func processImage(cgImage: CGImage, asset: PHAsset) {
        do {
            let faces = try detector.detectFacesWithLandmarks(in: cgImage)

            for face in faces {
                guard let landmarks = face.landmarks else { continue }

                // Extract 5-point landmarks
                guard let fivePoints = FaceAligner.extractFiveLandmarks(
                    from: landmarks,
                    boundingBox: face.boundingBox,
                    imageWidth: CGFloat(cgImage.width),
                    imageHeight: CGFloat(cgImage.height)
                ) else { continue }

                // Compute pixel bounding box with margin
                let pixelBox = FaceDetector.visionRectToScreen(
                    face.boundingBox,
                    imageWidth: CGFloat(cgImage.width),
                    imageHeight: CGFloat(cgImage.height)
                )

                // Align face to 112x112
                guard let alignedFace = FaceAligner.alignFace(
                    image: cgImage,
                    boundingBox: pixelBox,
                    landmarks: fivePoints
                ) else { continue }

                // Generate embedding
                let embedding = try embedder.generateEmbedding(from: alignedFace)

                // Store
                let record = FaceEmbeddingRecord(
                    id: UUID().uuidString,
                    photoLocalId: asset.localIdentifier,
                    embedding: embedding,
                    confidence: face.quality,
                    faceRect: FaceRect(
                        x: Float(face.boundingBox.origin.x),
                        y: Float(face.boundingBox.origin.y),
                        width: Float(face.boundingBox.width),
                        height: Float(face.boundingBox.height)
                    ),
                    photoDate: Int(asset.creationDate?.timeIntervalSince1970 ?? 0),
                    photoLocationLat: asset.location?.coordinate.latitude,
                    photoLocationLon: asset.location?.coordinate.longitude
                )

                try store.insert(record)
                facesFound += 1
            }
        } catch {
            // Log and continue — don't fail the whole scan for one bad image
            print("[FaceFinder] Failed to process asset \(asset.localIdentifier): \(error)")
        }
    }

    func stopScan() {
        isScanning = false
    }
}

enum ScannerError: Error {
    case notAuthorized
}
