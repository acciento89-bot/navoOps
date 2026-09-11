import XCTest
@testable import NavoOps

final class AnalyticsTests: XCTestCase {
    func testAnalyticsSnapshotMatchesGooglePackageID() {
        let product = ProductApp(
            id: "navokids",
            name: "Different Name",
            repository: "navokids",
            platforms: [.android],
            appleState: .development,
            googleState: .internalTest,
            version: "1.0",
            build: "1",
            storeInfo: .init(androidPackageID: "com.kamilunavo.navokids")
        )

        let snapshot = AppAnalyticsSnapshot(
            provider: .google,
            appName: "NavoKids",
            externalID: "com.kamilunavo.navokids",
            bundleOrPackageID: "com.kamilunavo.navokids",
            periodStart: nil,
            periodEnd: nil,
            units: nil,
            downloads: nil,
            proceeds: [],
            activeSubscriptions: nil,
            subscriptionProducts: 2,
            oneTimeProducts: 1,
            productsNeedingAction: 0,
            crashRate: nil,
            userPerceivedCrashRate: nil,
            anrRate: nil,
            userPerceivedAnrRate: nil,
            detail: nil
        )

        XCTAssertTrue(snapshot.matches(product))
    }

    func testAnalyticsNameFallbackNormalizesGermanDiacritics() {
        let product = ProductApp(
            id: "waermetakt",
            name: "Wärme Takt",
            repository: "w-rmetakt",
            platforms: [.iOS],
            appleState: .development,
            googleState: .development,
            version: "1.0",
            build: "1"
        )

        let snapshot = AppAnalyticsSnapshot(
            provider: .apple,
            appName: "WaermeTakt",
            externalID: nil,
            bundleOrPackageID: nil,
            periodStart: nil,
            periodEnd: nil,
            units: 4,
            downloads: nil,
            proceeds: [],
            activeSubscriptions: nil,
            subscriptionProducts: nil,
            oneTimeProducts: nil,
            productsNeedingAction: nil,
            crashRate: nil,
            userPerceivedCrashRate: nil,
            anrRate: nil,
            userPerceivedAnrRate: nil,
            detail: nil
        )

        XCTAssertTrue(snapshot.matches(product))
    }

    func testAnalyticsHistoryKeepsOneObservationPerStoreProductAndDay() throws {
        let suiteName = "NavoOps.AnalyticsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AnalyticsHistoryStore(defaults: defaults)
        let product = ProductApp(
            id: "reklaio",
            name: "Reklaio",
            repository: "reklaio",
            platforms: [.iOS],
            appleState: .live,
            googleState: .development,
            version: "1.0",
            build: "1",
            storeInfo: .init(appleBundleID: "de.kamilunavo.reklaio")
        )

        let first = Date()
        let firstSnapshot = AppAnalyticsSnapshot(
            provider: .apple,
            appName: "Reklaio",
            externalID: "1",
            bundleOrPackageID: "de.kamilunavo.reklaio",
            periodStart: first,
            periodEnd: first,
            units: 2,
            downloads: nil,
            proceeds: [CurrencyAmount(currency: "EUR", amount: 3.5)],
            activeSubscriptions: nil,
            subscriptionProducts: 1,
            oneTimeProducts: 0,
            productsNeedingAction: 0,
            crashRate: nil,
            userPerceivedCrashRate: nil,
            anrRate: nil,
            userPerceivedAnrRate: nil,
            detail: nil
        )
        let firstFeed = AnalyticsFeed(
            schemaVersion: 1,
            generatedAt: first,
            sourceRepository: "test",
            appleAvailable: true,
            googleAvailable: false,
            commercialAvailable: true,
            reliabilityAvailable: false,
            apps: [firstSnapshot]
        )

        let firstHistory = store.record(feed: firstFeed, products: [product], existing: [])
        XCTAssertEqual(firstHistory.count, 1)
        XCTAssertEqual(firstHistory.first?.units, 2)

        let secondSnapshot = AppAnalyticsSnapshot(
            provider: .apple,
            appName: "Reklaio",
            externalID: "1",
            bundleOrPackageID: "de.kamilunavo.reklaio",
            periodStart: first,
            periodEnd: first.addingTimeInterval(60),
            units: 5,
            downloads: nil,
            proceeds: [CurrencyAmount(currency: "EUR", amount: 8.5)],
            activeSubscriptions: nil,
            subscriptionProducts: 1,
            oneTimeProducts: 0,
            productsNeedingAction: 0,
            crashRate: nil,
            userPerceivedCrashRate: nil,
            anrRate: nil,
            userPerceivedAnrRate: nil,
            detail: nil
        )
        let secondFeed = AnalyticsFeed(
            schemaVersion: 1,
            generatedAt: first.addingTimeInterval(60),
            sourceRepository: "test",
            appleAvailable: true,
            googleAvailable: false,
            commercialAvailable: true,
            reliabilityAvailable: false,
            apps: [secondSnapshot]
        )

        let updated = store.record(feed: secondFeed, products: [product], existing: firstHistory)
        XCTAssertEqual(updated.count, 1)
        XCTAssertEqual(updated.first?.units, 5)
        XCTAssertEqual(updated.first?.proceeds.first?.amount, 8.5)
        XCTAssertEqual(store.load().count, 1)
    }
}
