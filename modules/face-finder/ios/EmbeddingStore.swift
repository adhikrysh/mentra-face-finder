import Foundation
import GRDB

struct FaceRect: Codable {
    let x: Float
    let y: Float
    let width: Float
    let height: Float
}

struct FaceEmbeddingRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "face_embeddings"

    let id: String
    let photoLocalId: String
    let embedding: [Float]
    let confidence: Float
    let faceRect: FaceRect
    let photoDate: Int
    let photoLocationLat: Double?
    let photoLocationLon: Double?
    let createdAt: Int

    init(
        id: String,
        photoLocalId: String,
        embedding: [Float],
        confidence: Float,
        faceRect: FaceRect,
        photoDate: Int,
        photoLocationLat: Double? = nil,
        photoLocationLon: Double? = nil
    ) {
        self.id = id
        self.photoLocalId = photoLocalId
        self.embedding = embedding
        self.confidence = confidence
        self.faceRect = faceRect
        self.photoDate = photoDate
        self.photoLocationLat = photoLocationLat
        self.photoLocationLon = photoLocationLon
        self.createdAt = Int(Date().timeIntervalSince1970)
    }

    // Custom encoding: store embedding as raw BLOB for compact storage
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["photoLocalId"] = photoLocalId
        container["embedding"] = embeddingToData(embedding)
        container["confidence"] = confidence
        container["faceRect"] = try! JSONEncoder().encode(faceRect)
        container["photoDate"] = photoDate
        container["photoLocationLat"] = photoLocationLat
        container["photoLocationLon"] = photoLocationLon
        container["createdAt"] = createdAt
    }

    // Custom decoding: read embedding from raw BLOB
    init(row: Row) {
        id = row["id"]
        photoLocalId = row["photoLocalId"]
        let embeddingData: Data = row["embedding"]
        embedding = dataToEmbedding(embeddingData)
        confidence = row["confidence"]
        let faceRectData: Data = row["faceRect"]
        faceRect = try! JSONDecoder().decode(FaceRect.self, from: faceRectData)
        photoDate = row["photoDate"]
        photoLocationLat = row["photoLocationLat"]
        photoLocationLon = row["photoLocationLon"]
        createdAt = row["createdAt"]
    }
}

// MARK: - BLOB Serialization

/// Convert [Float] to raw Data (no JSON overhead)
func embeddingToData(_ embedding: [Float]) -> Data {
    embedding.withUnsafeBufferPointer { buffer in
        Data(buffer: buffer)
    }
}

/// Convert raw Data back to [Float]
func dataToEmbedding(_ data: Data) -> [Float] {
    data.withUnsafeBytes { raw in
        let buffer = raw.bindMemory(to: Float.self)
        return Array(buffer)
    }
}

// MARK: - EmbeddingStore

final class EmbeddingStore {
    private let dbQueue: DatabaseQueue

    init(path: String) throws {
        dbQueue = try DatabaseQueue(path: path)

        try dbQueue.write { db in
            try db.create(table: "face_embeddings", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("photoLocalId", .text).notNull()
                t.column("embedding", .blob).notNull()
                t.column("confidence", .double).notNull()
                t.column("faceRect", .blob).notNull()
                t.column("photoDate", .integer).notNull()
                t.column("photoLocationLat", .double)
                t.column("photoLocationLon", .double)
                t.column("createdAt", .integer).notNull()
            }

            try db.create(
                index: "idx_photo_local_id",
                on: "face_embeddings",
                columns: ["photoLocalId"],
                ifNotExists: true
            )
        }
    }

    func insert(_ record: FaceEmbeddingRecord) throws {
        try dbQueue.write { db in
            try record.insert(db)
        }
    }

    func fetchAll() throws -> [FaceEmbeddingRecord] {
        try dbQueue.read { db in
            try FaceEmbeddingRecord.fetchAll(db)
        }
    }

    func count() throws -> Int {
        try dbQueue.read { db in
            try FaceEmbeddingRecord.fetchCount(db)
        }
    }

    func deleteByPhotoId(_ photoLocalId: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM face_embeddings WHERE photoLocalId = ?",
                arguments: [photoLocalId]
            )
        }
    }

    func deleteAll() throws {
        try dbQueue.write { db in
            try FaceEmbeddingRecord.deleteAll(db)
        }
    }
}
