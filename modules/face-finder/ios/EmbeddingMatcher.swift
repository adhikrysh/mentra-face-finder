import Foundation
import Accelerate

enum MatchClassification: String {
    case strong   // > 0.55
    case possible // > 0.40
    case none     // <= 0.40
}

struct MatchResult {
    let embeddingId: String
    let photoLocalId: String
    let similarity: Float
    let classification: MatchClassification
    let photoDate: Int
    let photoLocationLat: Double?
    let photoLocationLon: Double?
}

/// Shared singleton — both FaceFinderModule and FrameProcessorPlugin
/// must access the same loaded embeddings. Thread-safe via serial queue.
final class EmbeddingMatcher {

    static let shared = EmbeddingMatcher()

    // In-memory store: parallel arrays for SIMD-friendly access
    private var embeddingIds: [String] = []
    private var photoLocalIds: [String] = []
    private var embeddings: [[Float]] = []
    private var confidences: [Float] = []
    private var photoDates: [Int] = []
    private var photoLocationLats: [Double?] = []
    private var photoLocationLons: [Double?] = []
    private let queue = DispatchQueue(label: "com.mentra.facefinder.matcher")

    static let strongThreshold: Float = 0.55
    static let possibleThreshold: Float = 0.40

    // MARK: - Load

    func loadEmbeddings(_ records: [FaceEmbeddingRecord]) {
        queue.sync {
            embeddingIds = records.map(\.id)
            photoLocalIds = records.map(\.photoLocalId)
            embeddings = records.map(\.embedding)
            confidences = records.map(\.confidence)
            photoDates = records.map(\.photoDate)
            photoLocationLats = records.map(\.photoLocationLat)
            photoLocationLons = records.map(\.photoLocationLon)
        }
    }

    func clear() {
        queue.sync {
            embeddingIds.removeAll()
            photoLocalIds.removeAll()
            embeddings.removeAll()
            confidences.removeAll()
            photoDates.removeAll()
            photoLocationLats.removeAll()
            photoLocationLons.removeAll()
        }
    }

    var count: Int { embeddingIds.count }

    // MARK: - Match

    func findMatches(query: [Float], topK: Int = 10) -> [MatchResult] {
        guard !embeddings.isEmpty else { return [] }

        var scored: [(index: Int, similarity: Float)] = []
        scored.reserveCapacity(embeddings.count)

        for i in 0..<embeddings.count {
            let sim = Self.dotProduct(query, embeddings[i])

            // Down-weight low-confidence embeddings
            let adjustedSim = confidences[i] < 0.5
                ? sim * 0.8
                : sim

            if adjustedSim > Self.possibleThreshold {
                scored.append((i, adjustedSim))
            }
        }

        // Sort descending by similarity
        scored.sort { $0.similarity > $1.similarity }

        // Take top K, deduplicate by photoLocalId (keep highest per photo)
        var seen = Set<String>()
        var results: [MatchResult] = []

        for entry in scored {
            let photoId = photoLocalIds[entry.index]
            guard !seen.contains(photoId) else { continue }
            seen.insert(photoId)

            results.append(MatchResult(
                embeddingId: embeddingIds[entry.index],
                photoLocalId: photoId,
                similarity: entry.similarity,
                classification: Self.classifyMatch(similarity: entry.similarity),
                photoDate: photoDates[entry.index],
                photoLocationLat: photoLocationLats[entry.index],
                photoLocationLon: photoLocationLons[entry.index]
            ))

            if results.count >= topK { break }
        }

        return results
    }

    // MARK: - Vector Math

    /// Compute dot product of two vectors using Accelerate SIMD
    static func dotProduct(_ a: [Float], _ b: [Float]) -> Float {
        var result: Float = 0
        vDSP_dotpr(a, 1, b, 1, &result, vDSP_Length(a.count))
        return result
    }

    /// L2-normalize a vector so its magnitude is 1.0
    static func l2Normalize(_ vector: [Float]) -> [Float] {
        var magnitude: Float = 0
        vDSP_dotpr(vector, 1, vector, 1, &magnitude, vDSP_Length(vector.count))
        magnitude = sqrt(magnitude)

        guard magnitude > 0 else { return vector }

        var normalized = [Float](repeating: 0, count: vector.count)
        var mag = magnitude
        vDSP_vsdiv(vector, 1, &mag, &normalized, 1, vDSP_Length(vector.count))
        return normalized
    }

    /// Classify match quality from cosine similarity score
    static func classifyMatch(similarity: Float) -> MatchClassification {
        if similarity > strongThreshold {
            return .strong
        } else if similarity > possibleThreshold {
            return .possible
        } else {
            return .none
        }
    }
}
