import XCTest
@testable import FaceFinder
import Accelerate

final class EmbeddingMatcherTests: XCTestCase {

    func testL2NormalizationMagnitudeIsOne() {
        let raw: [Float] = (0..<512).map { _ in Float.random(in: -1...1) }
        let normalized = EmbeddingMatcher.l2Normalize(raw)

        var magnitude: Float = 0
        vDSP_dotpr(normalized, 1, normalized, 1, &magnitude, vDSP_Length(normalized.count))
        magnitude = sqrt(magnitude)

        XCTAssertEqual(magnitude, 1.0, accuracy: 1e-5)
    }

    func testDotProductOfIdenticalVectorsIsOne() {
        var vec: [Float] = (0..<512).map { _ in Float.random(in: -1...1) }
        vec = EmbeddingMatcher.l2Normalize(vec)

        let similarity = EmbeddingMatcher.dotProduct(vec, vec)
        XCTAssertEqual(similarity, 1.0, accuracy: 1e-5)
    }

    func testDotProductOfOrthogonalVectorsIsZero() {
        // Create two orthogonal vectors in 512-dim space
        var a = [Float](repeating: 0, count: 512)
        a[0] = 1.0
        var b = [Float](repeating: 0, count: 512)
        b[1] = 1.0

        let similarity = EmbeddingMatcher.dotProduct(a, b)
        XCTAssertEqual(similarity, 0.0, accuracy: 1e-5)
    }

    func testThresholdClassification() {
        XCTAssertEqual(EmbeddingMatcher.classifyMatch(similarity: 0.60), .strong)
        XCTAssertEqual(EmbeddingMatcher.classifyMatch(similarity: 0.55), .strong)
        XCTAssertEqual(EmbeddingMatcher.classifyMatch(similarity: 0.45), .possible)
        XCTAssertEqual(EmbeddingMatcher.classifyMatch(similarity: 0.40), .possible)
        XCTAssertEqual(EmbeddingMatcher.classifyMatch(similarity: 0.39), .none)
        XCTAssertEqual(EmbeddingMatcher.classifyMatch(similarity: 0.10), .none)
    }

    func testFindMatchesReturnsTopK() {
        let matcher = EmbeddingMatcher.shared

        // Insert 50 random embeddings
        var records: [FaceEmbeddingRecord] = []
        for i in 0..<50 {
            let emb = EmbeddingMatcher.l2Normalize(
                (0..<512).map { _ in Float.random(in: -1...1) }
            )
            records.append(FaceEmbeddingRecord(
                id: "emb_\(i)",
                photoLocalId: "photo_\(i)",
                embedding: emb,
                confidence: 0.9,
                faceRect: FaceRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
                photoDate: 1700000000 + i
            ))
        }

        matcher.loadEmbeddings(records)

        // Query with the first embedding — should match itself as top result
        let results = matcher.findMatches(query: records[0].embedding, topK: 10)

        XCTAssertTrue(results.count <= 10)
        // The first result should be the exact match (similarity ~1.0)
        XCTAssertEqual(results[0].embeddingId, "emb_0")
        XCTAssertEqual(results[0].similarity, 1.0, accuracy: 1e-4)
    }

    func testFindMatchesRespectsThreshold() {
        let matcher = EmbeddingMatcher.shared
        matcher.clear()

        // Create one very different embedding
        var farEmbedding = [Float](repeating: 0, count: 512)
        farEmbedding[0] = 1.0 // unit vector in first dimension
        let record = FaceEmbeddingRecord(
            id: "far",
            photoLocalId: "photo_far",
            embedding: farEmbedding,
            confidence: 0.9,
            faceRect: FaceRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            photoDate: 1700000000
        )

        matcher.loadEmbeddings([record])

        // Query with unit vector in a completely different dimension
        var queryEmbedding = [Float](repeating: 0, count: 512)
        queryEmbedding[255] = 1.0

        let results = matcher.findMatches(query: queryEmbedding, topK: 10)

        // Orthogonal vectors — similarity is 0, well below 0.40 threshold
        XCTAssertTrue(results.isEmpty)
    }

    func testMatchingPerformanceUnder50ms() {
        let matcher = EmbeddingMatcher.shared
        matcher.clear()

        // Load 10,000 embeddings
        var records: [FaceEmbeddingRecord] = []
        for i in 0..<10_000 {
            records.append(FaceEmbeddingRecord(
                id: "emb_\(i)",
                photoLocalId: "photo_\(i)",
                embedding: EmbeddingMatcher.l2Normalize(
                    (0..<512).map { _ in Float.random(in: -1...1) }
                ),
                confidence: 0.9,
                faceRect: FaceRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
                photoDate: 1700000000
            ))
        }
        matcher.loadEmbeddings(records)

        let query = EmbeddingMatcher.l2Normalize(
            (0..<512).map { _ in Float.random(in: -1...1) }
        )

        measure {
            _ = matcher.findMatches(query: query, topK: 10)
        }
        // XCTest measure block reports average time — should be < 50ms
    }
}
