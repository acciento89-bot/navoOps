import Foundation

struct OpsInsight: Identifiable, Hashable {
    enum Severity: Int, Comparable, Hashable, CaseIterable {
        case critical = 3
        case action = 2
        case warning = 1
        case info = 0

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    enum Kind: Hashable {
        case build
        case store
        case release
        case parity
        case readiness
        case freshness
        case inventory
        case github
        case history
    }

    let id: String
    let productID: String?
    let title: String
    let detail: String
    let recommendation: String
    let severity: Severity
    let kind: Kind
    let provider: StoreProvider?
    let date: Date?
}

struct ProductIntelligenceSnapshot: Identifiable, Hashable {
    var id: String { product.id }

    let product: ProductApp
    let apple: StoreAppSnapshot?
    let google: StoreAppSnapshot?
    let health: RepositoryHealth?
    let score: Int
    let insightCount: Int
    let isAligned: Bool
}

struct StoreHistoryEvent: Identifiable, Codable, Hashable {
    var id: String {
        "\(productID):\(provider.rawValue):\(observedAt.timeIntervalSince1970)"
    }

    let observedAt: Date
    let productID: String
    let productName: String
    let provider: StoreProvider
    let previousState: StoreAppSnapshot.State?
    let state: StoreAppSnapshot.State
    let previousVersion: String?
    let version: String?
    let previousBuild: String?
    let build: String?
    let rawState: String

    var changedState: Bool {
        previousState != nil && previousState != state
    }

    var changedVersion: Bool {
        previousVersion != nil && (previousVersion != version || previousBuild != build)
    }
}

struct PortfolioIntelligence: Hashable {
    let score: Int
    let criticalCount: Int
    let actionCount: Int
    let warningCount: Int
    let healthyCount: Int
    let alignedCount: Int
    let dualPlatformCount: Int
    let appleMatched: Int
    let appleExpected: Int
    let googleMatched: Int
    let googleExpected: Int
    let passingBuilds: Int
    let failedBuilds: Int
    let runningBuilds: Int
    let unknownBuilds: Int

    var alignmentPercent: Int {
        guard dualPlatformCount > 0 else { return 100 }
        return Int((Double(alignedCount) / Double(dualPlatformCount) * 100).rounded())
    }

    var appleCoveragePercent: Int {
        guard appleExpected > 0 else { return 100 }
        return Int((Double(appleMatched) / Double(appleExpected) * 100).rounded())
    }

    var googleCoveragePercent: Int {
        guard googleExpected > 0 else { return 100 }
        return Int((Double(googleMatched) / Double(googleExpected) * 100).rounded())
    }
}
