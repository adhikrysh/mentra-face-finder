import XCTest
@testable import FaceFinder

final class FaceClusterManagerTests: XCTestCase {
    var manager: FaceClusterManager!
    var dbPath: String!

    override func setUp() {
        super.setUp()
        dbPath = NSTemporaryDirectory() + "test_clusters_\(UUID().uuidString).sqlite"
        manager = try! FaceClusterManager(dbPath: dbPath)
    }

    override func tearDown() {
        manager = nil
        try? FileManager.default.removeItem(atPath: dbPath)
        super.tearDown()
    }

    func testMergeAboveThresholdSameCluster() throws {
        // Two embeddings with high similarity should cluster together
        try manager.tryMerge(embeddingIdA: "emb_1", embeddingIdB: "emb_2", similarity: 0.50)

        let clusterA = try manager.getClusterId(for: "emb_1")
        let clusterB = try manager.getClusterId(for: "emb_2")

        XCTAssertNotNil(clusterA)
        XCTAssertNotNil(clusterB)
        XCTAssertEqual(clusterA, clusterB)
    }

    func testBelowThresholdSeparateClusters() throws {
        try manager.tryMerge(embeddingIdA: "emb_1", embeddingIdB: "emb_2", similarity: 0.30)

        let clusterA = try manager.getClusterId(for: "emb_1")
        let clusterB = try manager.getClusterId(for: "emb_2")

        // Below threshold — should not be clustered
        XCTAssertNil(clusterA)
        XCTAssertNil(clusterB)
    }

    func testTransitiveMerge() throws {
        // A-B merge, B-C merge → all three in same cluster
        try manager.tryMerge(embeddingIdA: "emb_A", embeddingIdB: "emb_B", similarity: 0.55)
        try manager.tryMerge(embeddingIdA: "emb_B", embeddingIdB: "emb_C", similarity: 0.50)

        let clusterA = try manager.getClusterId(for: "emb_A")
        let clusterB = try manager.getClusterId(for: "emb_B")
        let clusterC = try manager.getClusterId(for: "emb_C")

        XCTAssertNotNil(clusterA)
        XCTAssertEqual(clusterA, clusterB)
        XCTAssertEqual(clusterB, clusterC)
    }

    func testGetClusterMembers() throws {
        try manager.tryMerge(embeddingIdA: "emb_1", embeddingIdB: "emb_2", similarity: 0.60)
        try manager.tryMerge(embeddingIdA: "emb_2", embeddingIdB: "emb_3", similarity: 0.55)

        let clusterId = try manager.getClusterId(for: "emb_1")!
        let members = try manager.getClusterMembers(clusterId: clusterId)

        XCTAssertEqual(Set(members), Set(["emb_1", "emb_2", "emb_3"]))
    }

    func testDeleteAll() throws {
        try manager.tryMerge(embeddingIdA: "emb_1", embeddingIdB: "emb_2", similarity: 0.55)
        try manager.deleteAll()

        XCTAssertNil(try manager.getClusterId(for: "emb_1"))
        XCTAssertNil(try manager.getClusterId(for: "emb_2"))
    }
}
