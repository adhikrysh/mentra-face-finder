import Foundation
import GRDB

final class FaceClusterManager {

    private let dbQueue: DatabaseQueue
    static let mergeThreshold: Float = 0.45

    init(dbPath: String) throws {
        dbQueue = try DatabaseQueue(path: dbPath)

        try dbQueue.write { db in
            try db.create(table: "face_clusters", ifNotExists: true) { t in
                t.column("clusterId", .text).notNull()
                t.column("faceEmbeddingId", .text).notNull()
                t.column("updatedAt", .integer).notNull()
                t.primaryKey(["clusterId", "faceEmbeddingId"])
            }
        }
    }

    /// Attempt to merge two embeddings into a cluster if similarity exceeds threshold
    func tryMerge(embeddingIdA: String, embeddingIdB: String, similarity: Float) throws {
        guard similarity >= Self.mergeThreshold else { return }

        try dbQueue.write { db in
            let clusterA = try fetchClusterId(for: embeddingIdA, in: db)
            let clusterB = try fetchClusterId(for: embeddingIdB, in: db)
            let now = Int(Date().timeIntervalSince1970)

            switch (clusterA, clusterB) {
            case (nil, nil):
                // Neither is clustered — create new cluster
                let newClusterId = UUID().uuidString
                try db.execute(
                    sql: "INSERT INTO face_clusters (clusterId, faceEmbeddingId, updatedAt) VALUES (?, ?, ?)",
                    arguments: [newClusterId, embeddingIdA, now]
                )
                try db.execute(
                    sql: "INSERT INTO face_clusters (clusterId, faceEmbeddingId, updatedAt) VALUES (?, ?, ?)",
                    arguments: [newClusterId, embeddingIdB, now]
                )

            case (let existing?, nil):
                // A is clustered, B is not — add B to A's cluster
                try db.execute(
                    sql: "INSERT INTO face_clusters (clusterId, faceEmbeddingId, updatedAt) VALUES (?, ?, ?)",
                    arguments: [existing, embeddingIdB, now]
                )

            case (nil, let existing?):
                // B is clustered, A is not — add A to B's cluster
                try db.execute(
                    sql: "INSERT INTO face_clusters (clusterId, faceEmbeddingId, updatedAt) VALUES (?, ?, ?)",
                    arguments: [existing, embeddingIdA, now]
                )

            case (let clA?, let clB?):
                // Both clustered — merge clusters if different
                if clA != clB {
                    // Move all members of clB into clA
                    try db.execute(
                        sql: "UPDATE face_clusters SET clusterId = ?, updatedAt = ? WHERE clusterId = ?",
                        arguments: [clA, now, clB]
                    )
                }
                // If same cluster, nothing to do
            }
        }
    }

    func getClusterId(for embeddingId: String) throws -> String? {
        try dbQueue.read { db in
            try fetchClusterId(for: embeddingId, in: db)
        }
    }

    func getClusterMembers(clusterId: String) throws -> [String] {
        try dbQueue.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT faceEmbeddingId FROM face_clusters WHERE clusterId = ?",
                arguments: [clusterId]
            )
        }
    }

    func deleteAll() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM face_clusters")
        }
    }

    // MARK: - Private

    private func fetchClusterId(for embeddingId: String, in db: Database) throws -> String? {
        try String.fetchOne(
            db,
            sql: "SELECT clusterId FROM face_clusters WHERE faceEmbeddingId = ?",
            arguments: [embeddingId]
        )
    }
}
