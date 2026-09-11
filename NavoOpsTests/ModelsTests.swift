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

    func testStoreStatesMapToProductStates() {
        XCTAssertEqual(StoreAppSnapshot.State.live.productState, .live)
        XCTAssertEqual(StoreAppSnapshot.State.review.productState, .review)
        XCTAssertEqual(StoreAppSnapshot.State.internalTest.productState, .internalTest)
        XCTAssertEqual(StoreAppSnapshot.State.rejected.productState, .attention)
        XCTAssertEqual(StoreAppSnapshot.State.attention.productState, .attention)
        XCTAssertEqual(StoreAppSnapshot.State.processing.productState, .development)
    }

    func testAppleSnapshotMatchesByBundleID() {
        let product = ProductApp(
            id: "navopass",
            name: "Different Display Name",
            repository: "navopass",
            platforms: [.iOS],
            appleState: .development,
            googleState: .development,
            version: "1.0",
            build: "1",
            storeInfo: .init(appleBundleID: "de.kamilunavo.navopass")
        )
        let snapshot = StoreAppSnapshot(
            provider: .apple,
            appName: "NavoPass",
            externalID: "123",
            bundleOrPackageID: "de.kamilunavo.navopass",
            version: "1.0",
            build: "5",
            rawState: "WAITING_FOR_REVIEW",
            state: .review,
            updatedAt: nil,
            detail: nil
        )
        XCTAssertTrue(snapshot.matches(product))
    }

    func testSnapshotNameFallbackIgnoresCaseSpacesAndDiacritics() {
        let product = ProductApp(
            id: "waermetakt",
            name: "WärmeTakt",
            repository: "w-rmetakt",
            platforms: [.iOS],
            appleState: .development,
            googleState: .development,
            version: "1.0",
            build: "1"
        )
        let snapshot = StoreAppSnapshot(
            provider: .apple,
            appName: "waerme takt",
            externalID: nil,
            bundleOrPackageID: nil,
            version: nil,
            build: nil,
            rawState: "READY_FOR_SALE",
            state: .live,
            updatedAt: nil,
            detail: nil
        )
        XCTAssertTrue(snapshot.matches(product))
    }

    func testStoreFeedDecodesRFC3339Snapshot() throws {
        let json = """
        {
          "schemaVersion": 1,
          "generatedAt": "2026-09-11T16:20:31Z",
          "sourceRepository": "acciento89-bot/onemorefloor",
          "appleAvailable": true,
          "googleAvailable": false,
          "apps": [{
            "provider": "apple",
            "appName": "NavoOps",
            "externalID": "6811085573",
            "bundleOrPackageID": "com.kamilunavo.NavoOps",
            "version": "1.0",
            "build": "1",
            "rawState": "PREPARE_FOR_SUBMISSION",
            "state": "development",
            "updatedAt": "2026-09-11T14:48:04Z",
            "detail": "PREPARE_FOR_SUBMISSION"
          }]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let feed = try decoder.decode(StoreStatusFeed.self, from: Data(json.utf8))
        XCTAssertTrue(feed.appleAvailable)
        XCTAssertFalse(feed.googleAvailable)
        XCTAssertEqual(feed.apps.first?.appName, "NavoOps")
        XCTAssertEqual(feed.apps.first?.state, .development)
    }
}
