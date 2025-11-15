import Foundation
import VisionCamera

@objc(FaceFinderFrameProcessor)
public class FaceFinderFrameProcessor: FrameProcessorPlugin {

    private let detector = FaceDetector()
    private var embedder: FaceEmbedder?
    private let matcher = EmbeddingMatcher.shared

    private var frameCounter = 0
    private let processEveryNthFrame = 5

    // Lock state per tracked face
    private var lockedFaces: [String: Date] = [:]
    private let lockDuration: TimeInterval = 10.0

    public override init(proxy: VisionCameraProxyHolder, options: [AnyHashable: Any]! = nil) {
        super.init(proxy: proxy, options: options)

        do {
            embedder = try FaceEmbedder()
        } catch {
            print("[FaceFinder] Failed to load embedder in frame processor: \(error)")
        }
    }

    public override func callback(_ frame: Frame, withArguments arguments: [AnyHashable: Any]?) -> Any? {
        frameCounter += 1

        // Skip frames for performance
        guard frameCounter % processEveryNthFrame == 0 else {
            return nil
        }

        guard let embedder = embedder else { return nil }

        let buffer = frame.buffer

        do {
            // Detect faces with landmarks
            let faces = try detector.detectFacesWithLandmarks(in: buffer)

            guard !faces.isEmpty else {
                // Clear expired locks
                cleanExpiredLocks()
                return ["faces": []] as [String: Any]
            }

            var results: [[String: Any]] = []

            // Process up to 5 faces, largest first
            let sortedFaces = faces.sorted {
                ($0.boundingBox.width * $0.boundingBox.height) >
                ($1.boundingBox.width * $1.boundingBox.height)
            }
            .prefix(5)

            for (index, face) in sortedFaces.enumerated() {
                let faceId = "face_\(index)"

                // Check lock state
                if let lockTime = lockedFaces[faceId],
                   Date().timeIntervalSince(lockTime) < lockDuration {
                    // Face is locked — return cached state
                    results.append([
                        "faceId": faceId,
                        "boundingBox": rectToDict(face.boundingBox),
                        "matchState": "matched",
                        "topMatches": [], // Cached matches would go here in production
                    ])
                    continue
                }

                guard let landmarks = face.landmarks else {
                    results.append([
                        "faceId": faceId,
                        "boundingBox": rectToDict(face.boundingBox),
                        "matchState": "low_quality",
                        "topMatches": [],
                    ])
                    continue
                }

                // Get pixel buffer dimensions
                let width = CGFloat(CVPixelBufferGetWidth(buffer))
                let height = CGFloat(CVPixelBufferGetHeight(buffer))

                // Extract landmarks and align
                guard let fivePoints = FaceAligner.extractFiveLandmarks(
                    from: landmarks,
                    boundingBox: face.boundingBox,
                    imageWidth: width,
                    imageHeight: height
                ) else {
                    results.append([
                        "faceId": faceId,
                        "boundingBox": rectToDict(face.boundingBox),
                        "matchState": "searching",
                        "topMatches": [],
                    ])
                    continue
                }

                // Convert buffer to CGImage for alignment
                let ciImage = CIImage(cvPixelBuffer: buffer)
                let context = CIContext()
                guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                    continue
                }

                let pixelBox = FaceDetector.visionRectToScreen(
                    face.boundingBox,
                    imageWidth: width,
                    imageHeight: height
                )

                guard let alignedFace = FaceAligner.alignFace(
                    image: cgImage,
                    boundingBox: pixelBox,
                    landmarks: fivePoints
                ) else {
                    continue
                }

                // Generate embedding
                let embedding = try embedder.generateEmbedding(from: alignedFace)

                // Match
                let matches = matcher.findMatches(query: embedding, topK: 5)

                let matchState: String
                if matches.isEmpty {
                    matchState = "no_match"
                } else {
                    matchState = "matched"
                    // Lock this face
                    lockedFaces[faceId] = Date()
                }

                results.append([
                    "faceId": faceId,
                    "boundingBox": rectToDict(face.boundingBox),
                    "matchState": matchState,
                    "topMatches": matches.map { match in
                        [
                            "embeddingId": match.embeddingId,
                            "photoLocalId": match.photoLocalId,
                            "similarity": match.similarity,
                            "confidenceLabel": match.classification.rawValue,
                            "photoDate": match.photoDate,
                        ] as [String: Any]
                    },
                ])
            }

            return ["faces": results] as [String: Any]
        } catch {
            return ["error": error.localizedDescription] as [String: Any]
        }
    }

    private func rectToDict(_ rect: CGRect) -> [String: Any] {
        [
            "x": Float(rect.origin.x),
            "y": Float(1.0 - rect.origin.y - rect.height), // Flip Y for screen coords
            "width": Float(rect.width),
            "height": Float(rect.height),
        ]
    }

    private func cleanExpiredLocks() {
        let now = Date()
        lockedFaces = lockedFaces.filter { _, lockTime in
            now.timeIntervalSince(lockTime) < lockDuration
        }
    }
}
