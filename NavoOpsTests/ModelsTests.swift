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

    func testStoreFeedDecodesOffsetRFC3339Date() throws {
        let json = """
        {
          "schemaVersion": 1,
          "generatedAt": "2026-09-11T16:20:31Z",
          "sourceRepository": "acciento89-bot/onemorefloor",
          "appleAvailable": true,
          "googleAvailable": false,
          "apps": [{
            "provider": "apple",
            "appName": "NavoKids – Lerninseln",
            "externalID": "6809038305",
            "bundleOrPackageID": "com.kamilunavo.navokids",
            "version": "0.4.0",
            "build": "13",
            "rawState": "IN_REVIEW",
            "state": "review",
            "updatedAt": "2026-09-10T14:36:14-07:00",
            "detail": "IN_REVIEW"
          }]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let feed = try decoder.decode(StoreStatusFeed.self, from: Data(json.utf8))
        XCTAssertNotNil(feed.apps.first?.updatedAt)
        XCTAssertEqual(feed.apps.first?.state, .review)
    }

    func testPortfolioMigrationAddsCanonicalIdentifiersWithoutOverwritingManualState() throws {
        let suiteName = "NavoOpsTests.PortfolioMigration.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var legacy = ProductApp(
            id: "navokids",
            name: "NavoKids",
            repository: "navokids",
            platforms: [.iOS],
            appleState: .attention,
            googleState: .development,
            version: "0.3.0",
            build: "7",
            notes: "keep my manual note",
            checklist: .init(icon: true),
            storeInfo: .init(appleBundleID: nil, androidPackageID: nil),
            monetization: .mixed,
            tags: ["Manual"]
        )
        legacy.storeInfo.privacyURL = nil

        let data = try JSONEncoder().encode([legacy])
        defaults.set(data, forKey: "navoops.portfolio.v1")

        let store = PortfolioStore(defaults: defaults)
        let migrated = try XCTUnwrap(store.loadMerged(with: ProductCatalog.seed).first { $0.id == "navokids" })
        XCTAssertEqual(migrated.appleState, .attention)
        XCTAssertEqual(migrated.notes, "keep my manual note")
        XCTAssertEqual(migrated.storeInfo.appleBundleID, "com.kamilunavo.navokids")
        XCTAssertEqual(migrated.storeInfo.androidPackageID, "com.kamilunavo.navokids")
        XCTAssertTrue(migrated.platforms.contains(.android))
        XCTAssertTrue(migrated.tags.contains("Manual"))
        XCTAssertTrue(migrated.tags.contains("Education"))
        XCTAssertNotNil(migrated.storeInfo.privacyURL)
    }
    func testBridgeRefreshPolicyWaitsForEverySuccessfullyDispatchedProvider() {
        let baselineApple = Date(timeIntervalSince1970: 100)
        let baselineGoogle = Date(timeIntervalSince1970: 200)

        XCTAssertFalse(BridgeRefreshPolicy.providersAdvanced(
            appleGeneratedAt: baselineApple,
            googleGeneratedAt: baselineGoogle,
            previousApple: baselineApple,
            previousGoogle: baselineGoogle,
            waitForApple: true,
            waitForGoogle: true
        ))

        XCTAssertFalse(BridgeRefreshPolicy.providersAdvanced(
            appleGeneratedAt: baselineApple.addingTimeInterval(1),
            googleGeneratedAt: baselineGoogle,
            previousApple: baselineApple,
            previousGoogle: baselineGoogle,
            waitForApple: true,
            waitForGoogle: true
        ))

        XCTAssertTrue(BridgeRefreshPolicy.providersAdvanced(
            appleGeneratedAt: baselineApple.addingTimeInterval(1),
            googleGeneratedAt: baselineGoogle.addingTimeInterval(1),
            previousApple: baselineApple,
            previousGoogle: baselineGoogle,
            waitForApple: true,
            waitForGoogle: true
        ))

        XCTAssertTrue(BridgeRefreshPolicy.providersAdvanced(
            appleGeneratedAt: baselineApple.addingTimeInterval(1),
            googleGeneratedAt: baselineGoogle,
            previousApple: baselineApple,
            previousGoogle: baselineGoogle,
            waitForApple: true,
            waitForGoogle: false
        ))
    }

}
