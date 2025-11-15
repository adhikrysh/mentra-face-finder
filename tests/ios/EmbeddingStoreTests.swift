import XCTest
@testable import FaceFinder
import Foundation

final class EmbeddingStoreTests: XCTestCase {
    var store: EmbeddingStore!
    var dbPath: String!

    override func setUp() {
        super.setUp()
        dbPath = NSTemporaryDirectory() + "test_embeddings_\(UUID().uuidString).sqlite"
        store = try! EmbeddingStore(path: dbPath)
    }

    override func tearDown() {
        store = nil
        try? FileManager.default.removeItem(atPath: dbPath)
        super.tearDown()
    }

    func testInsertAndRetrieveEmbedding() throws {
        let embedding = randomEmbedding(dim: 512)
        let record = FaceEmbeddingRecord(
            id: UUID().uuidString,
            photoLocalId: "photo_001",
            embedding: embedding,
            confidence: 0.95,
            faceRect: FaceRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            photoDate: 1700000000,
            photoLocationLat: nil,
            photoLocationLon: nil
        )

        try store.insert(record)
        let retrieved = try store.fetchAll()

        XCTAssertEqual(retrieved.count, 1)
        XCTAssertEqual(retrieved[0].id, record.id)
        XCTAssertEqual(retrieved[0].photoLocalId, "photo_001")
        XCTAssertEqual(retrieved[0].confidence, 0.95, accuracy: 0.001)

        // Verify embedding round-trip fidelity
        for i in 0..<512 {
            XCTAssertEqual(retrieved[0].embedding[i], embedding[i], accuracy: 1e-6)
        }
    }

    func testDeleteByPhotoId() throws {
        let record1 = makeRecord(photoLocalId: "photo_001")
        let record2 = makeRecord(photoLocalId: "photo_001") // same photo, second face
        let record3 = makeRecord(photoLocalId: "photo_002")

        try store.insert(record1)
        try store.insert(record2)
        try store.insert(record3)

        XCTAssertEqual(try store.fetchAll().count, 3)

        try store.deleteByPhotoId("photo_001")

        let remaining = try store.fetchAll()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining[0].photoLocalId, "photo_002")
    }

    func testBulkLoadIntoMemory() throws {
        for i in 0..<100 {
            try store.insert(makeRecord(photoLocalId: "photo_\(i)"))
        }

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 100)

        // Verify all embeddings are 512-dim
        for record in all {
            XCTAssertEqual(record.embedding.count, 512)
        }
    }

    func testEmbeddingCount() throws {
        XCTAssertEqual(try store.count(), 0)
        try store.insert(makeRecord(photoLocalId: "p1"))
        try store.insert(makeRecord(photoLocalId: "p2"))
        XCTAssertEqual(try store.count(), 2)
    }

    func testDeleteAll() throws {
        for i in 0..<10 {
            try store.insert(makeRecord(photoLocalId: "photo_\(i)"))
        }
        XCTAssertEqual(try store.count(), 10)

        try store.deleteAll()
        XCTAssertEqual(try store.count(), 0)
    }

    // MARK: - Helpers

    private func randomEmbedding(dim: Int) -> [Float] {
        (0..<dim).map { _ in Float.random(in: -1...1) }
    }

    private func makeRecord(photoLocalId: String) -> FaceEmbeddingRecord {
        FaceEmbeddingRecord(
            id: UUID().uuidString,
            photoLocalId: photoLocalId,
            embedding: randomEmbedding(dim: 512),
            confidence: Float.random(in: 0.5...1.0),
            faceRect: FaceRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            photoDate: Int(Date().timeIntervalSince1970),
            photoLocationLat: nil,
            photoLocationLon: nil
        )
    }
}
