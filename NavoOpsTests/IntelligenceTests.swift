import XCTest
@testable import NavoOps

final class IntelligenceTests: XCTestCase {
    func testHistoryStoreRecordsOnlyMeaningfulChanges() throws {
        let suiteName = "NavoOpsTests.StoreHistory.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = StoreHistoryStore(defaults: defaults)
        let product = ProductApp(
            id: "sample",
            name: "Sample",
            repository: "sample",
            platforms: [.iOS],
            appleState: .development,
            googleState: .development,
            version: "1.0.0",
            build: "1",
            storeInfo: .init(appleBundleID: "com.kamilunavo.sample")
        )

        let initial = StoreStatusFeed(
            schemaVersion: 1,
            generatedAt: Date(timeIntervalSince1970: 100),
            sourceRepository: "test",
            appleAvailable: true,
            googleAvailable: false,
            apps: [snapshot(state: .review, version: "1.0.0", build: "1")]
        )
        var events = store.record(feed: initial, products: [product], existing: [])
        XCTAssertEqual(events.count, 1)
        XCTAssertNil(events.first?.previousState)

        let unchanged = StoreStatusFeed(
            schemaVersion: 1,
            generatedAt: Date(timeIntervalSince1970: 200),
            sourceRepository: "test",
            appleAvailable: true,
            googleAvailable: false,
            apps: [snapshot(state: .review, version: "1.0.0", build: "1")]
        )
        events = store.record(feed: unchanged, products: [product], existing: events)
        XCTAssertEqual(events.count, 1)

        let changed = StoreStatusFeed(
            schemaVersion: 1,
            generatedAt: Date(timeIntervalSince1970: 300),
            sourceRepository: "test",
            appleAvailable: true,
            googleAvailable: false,
            apps: [snapshot(state: .live, version: "1.0.0", build: "1")]
        )
        events = store.record(feed: changed, products: [product], existing: events)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.first?.previousState, .review)
        XCTAssertEqual(events.first?.state, .live)
        XCTAssertTrue(events.first?.changedState == true)
    }

    @MainActor
    func testSemanticVersionNormalizesStoreReleaseNames() {
        let model = AppModel()
        XCTAssertEqual(model.semanticVersion(from: "3 (1.0.2)"), "1.0.2")
        XCTAssertEqual(model.semanticVersion(from: "NavoKids 0.4.0 – Acht Lerninseln"), "0.4.0")
        XCTAssertEqual(model.semanticVersion(from: "1.0"), "1.0.0")
        XCTAssertNil(model.semanticVersion(from: "Draft"))
    }

    @MainActor
    func testCrossPlatformStoreDriftProducesActionInsight() {
        let model = AppModel()
        let product = ProductApp(
            id: "sample",
            name: "Sample",
            repository: "sample",
            platforms: [.iOS, .android],
            appleState: .development,
            googleState: .development,
            version: "1.0.0",
            build: "1",
            checklist: .fullyReady,
            storeInfo: .init(
                appleBundleID: "com.kamilunavo.sample",
                androidPackageID: "com.kamilunavo.sample"
            )
        )
        model.products = [product]
        model.storeFeed = StoreStatusFeed(
            schemaVersion: 1,
            generatedAt: .now,
            sourceRepository: "test",
            appleAvailable: true,
            googleAvailable: true,
            apps: [
                StoreAppSnapshot(
                    provider: .apple,
                    appName: "Sample",
                    externalID: "apple",
                    bundleOrPackageID: "com.kamilunavo.sample",
                    version: "1.0.0",
                    build: "1",
                    rawState: "READY_FOR_SALE",
                    state: .live,
                    updatedAt: .now,
                    detail: nil
                ),
                StoreAppSnapshot(
                    provider: .google,
                    appName: "Sample",
                    externalID: "google",
                    bundleOrPackageID: "com.kamilunavo.sample",
                    version: "1.0.0",
                    build: "1",
                    rawState: "production:RELEASE_LIFECYCLE_STATE_IN_REVIEW",
                    state: .review,
                    updatedAt: .now,
                    detail: nil
                )
            ]
        )

        let parity = model.insights(for: product).first { $0.kind == .parity }
        XCTAssertNotNil(parity)
        XCTAssertEqual(parity?.severity, .action)
        XCTAssertFalse(model.isCrossPlatformAligned(product))
    }

    @MainActor
    func testRejectedStoreProducesCriticalInsight() {
        let model = AppModel()
        let product = ProductApp(
            id: "sample",
            name: "Sample",
            repository: "sample",
            platforms: [.android],
            appleState: .development,
            googleState: .development,
            version: "1.0.0",
            build: "1",
            checklist: .fullyReady,
            storeInfo: .init(androidPackageID: "com.kamilunavo.sample")
        )
        model.products = [product]
        model.storeFeed = StoreStatusFeed(
            schemaVersion: 1,
            generatedAt: .now,
            sourceRepository: "test",
            appleAvailable: false,
            googleAvailable: true,
            apps: [
                StoreAppSnapshot(
                    provider: .google,
                    appName: "Sample",
                    externalID: "google",
                    bundleOrPackageID: "com.kamilunavo.sample",
                    version: "1.0.0",
                    build: "1",
                    rawState: "production:RELEASE_LIFECYCLE_STATE_NOT_APPROVED",
                    state: .rejected,
                    updatedAt: .now,
                    detail: nil
                )
            ]
        )

        let rejected = model.insights(for: product).first { $0.provider == .google && $0.severity == .critical }
        XCTAssertNotNil(rejected)
    }

    private func snapshot(state: StoreAppSnapshot.State, version: String, build: String) -> StoreAppSnapshot {
        StoreAppSnapshot(
            provider: .apple,
            appName: "Sample",
            externalID: "apple",
            bundleOrPackageID: "com.kamilunavo.sample",
            version: version,
            build: build,
            rawState: state.rawValue,
            state: state,
            updatedAt: nil,
            detail: nil
        )
    }
}
