import ExpoModulesCore
import Photos

public class FaceFinderModule: Module, PhotoLibraryScannerDelegate {

    private var detector: FaceDetector?
    private var embedder: FaceEmbedder?
    private var store: EmbeddingStore?
    private var clusterManager: FaceClusterManager?
    private var scanner: PhotoLibraryScanner?
    private let matcher = EmbeddingMatcher.shared

    private var isInitialized = false

    public func definition() -> ModuleDefinition {
        Name("FaceFinder")

        Events("onScanProgress", "onScanComplete")

        OnCreate {
            self.initializeIfNeeded()
        }

        AsyncFunction("startLibraryScan") { (promise: Promise) in
            guard self.isInitialized else {
                promise.reject("NOT_INITIALIZED", "Face Finder module not initialized")
                return
            }

            // Request photo library permission
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                guard status == .authorized else {
                    promise.reject("PERMISSION_DENIED", "Photo library access denied")
                    return
                }

                self.scanner?.startScan()
                promise.resolve(nil)
            }
        }

        AsyncFunction("getEmbeddingCount") { () -> Int in
            guard let store = self.store else { return 0 }
            return try store.count()
        }

        AsyncFunction("deleteAllFaceData") { (promise: Promise) in
            do {
                try self.store?.deleteAll()
                try self.clusterManager?.deleteAll()
                self.matcher.clear()
                UserDefaults.standard.removeObject(forKey: "facefinder_lastScanDate")
                promise.resolve(nil)
            } catch {
                promise.reject("DELETE_FAILED", error.localizedDescription)
            }
        }

        AsyncFunction("findMatches") { (embeddingJson: String) -> String in
            guard let data = embeddingJson.data(using: .utf8),
                  let embedding = try? JSONDecoder().decode([Float].self, from: data) else {
                throw NSError(domain: "FaceFinder", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid embedding JSON"
                ])
            }

            let results = self.matcher.findMatches(query: embedding, topK: 10)

            let matches = results.map { result -> [String: Any] in
                var match: [String: Any] = [
                    "embeddingId": result.embeddingId,
                    "photoLocalId": result.photoLocalId,
                    "similarity": result.similarity,
                    "confidenceLabel": result.classification.rawValue,
                    "photoDate": result.photoDate,
                ]
                if let lat = result.photoLocationLat, let lon = result.photoLocationLon {
                    match["photoLocation"] = ["lat": lat, "lon": lon]
                }
                return match
            }

            let jsonData = try JSONSerialization.data(withJSONObject: matches)
            return String(data: jsonData, encoding: .utf8) ?? "[]"
        }

        AsyncFunction("reloadEmbeddingsIntoMemory") { (promise: Promise) in
            do {
                guard let store = self.store else {
                    promise.reject("NOT_INITIALIZED", "Store not initialized")
                    return
                }
                let records = try store.fetchAll()
                self.matcher.loadEmbeddings(records)
                promise.resolve(records.count)
            } catch {
                promise.reject("LOAD_FAILED", error.localizedDescription)
            }
        }
    }

    // MARK: - Initialization

    private func initializeIfNeeded() {
        guard !isInitialized else { return }

        do {
            detector = FaceDetector()
            embedder = try FaceEmbedder()

            let dbDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)

            let embeddingDbPath = dbDir.appendingPathComponent("face_embeddings.sqlite").path
            store = try EmbeddingStore(path: embeddingDbPath)

            let clusterDbPath = dbDir.appendingPathComponent("face_clusters.sqlite").path
            clusterManager = try FaceClusterManager(dbPath: clusterDbPath)

            // Set file protection
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: embeddingDbPath
            )
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: clusterDbPath
            )

            // Exclude from backup
            var embeddingUrl = URL(fileURLWithPath: embeddingDbPath)
            var clusterUrl = URL(fileURLWithPath: clusterDbPath)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try embeddingUrl.setResourceValues(values)
            try clusterUrl.setResourceValues(values)

            scanner = PhotoLibraryScanner(
                detector: detector!,
                embedder: embedder!,
                store: store!,
                clusterManager: clusterManager!
            )
            scanner?.delegate = self

            // Load existing embeddings into memory
            let records = try store!.fetchAll()
            matcher.loadEmbeddings(records)

            isInitialized = true
        } catch {
            print("[FaceFinder] Initialization failed: \(error)")
        }
    }

    // MARK: - PhotoLibraryScannerDelegate

    func scannerDidUpdateProgress(total: Int, completed: Int, facesFound: Int) {
        sendEvent("onScanProgress", [
            "totalPhotos": total,
            "completedPhotos": completed,
            "facesFound": facesFound,
        ])
    }

    func scannerDidComplete(totalFaces: Int) {
        // Reload embeddings into matcher
        if let records = try? store?.fetchAll() {
            matcher.loadEmbeddings(records)
        }

        sendEvent("onScanComplete", [
            "totalFaces": totalFaces,
        ])
    }

    func scannerDidFail(error: Error) {
        sendEvent("onScanProgress", [
            "error": error.localizedDescription,
        ])
    }
}
