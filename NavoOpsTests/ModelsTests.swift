import XCTest
@testable import NavoOps

final class ModelsTests: XCTestCase {
    func testFullyReadyChecklistHasCompleteStoreScores() {
        let checklist = ReleaseChecklist.fullyReady
        XCTAssertEqual(checklist.appleCompleted, checklist.appleTotal)
        XCTAssertEqual(checklist.googleCompleted, checklist.googleTotal)
        XCTAssertTrue(checklist.readyForApple)
        XCTAssertTrue(checklist.readyForGoogle)
    }

    func testProductCatalogUsesStableUniqueIDs() {
        let ids = ProductCatalog.seed.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
        XCTAssertFalse(ids.contains(where: \.isEmpty))
    }

    func testFullyLiveRequiresAllSupportedStores() {
        let product = ProductApp(
            id: "test",
            name: "Test",
            repository: "test",
            platforms: [.iOS, .android],
            appleState: .live,
            googleState: .review,
            version: "1.0",
            build: "1"
        )
        XCTAssertFalse(product.isFullyLive)

        var updated = product
        updated.googleState = .live
        XCTAssertTrue(updated.isFullyLive)
    }
}
