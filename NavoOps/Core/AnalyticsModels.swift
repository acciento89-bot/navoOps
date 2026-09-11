import Foundation

struct CurrencyAmount: Identifiable, Codable, Hashable {
    var id: String { currency }
    let currency: String
    let amount: Double
}

struct AppAnalyticsSnapshot: Identifiable, Codable, Hashable {
    var id: String {
        "\(provider.rawValue):\(externalID ?? bundleOrPackageID ?? appName)"
    }

    let provider: StoreProvider
    let appName: String
    let externalID: String?
    let bundleOrPackageID: String?
    let periodStart: Date?
    let periodEnd: Date?

    // Commercial metrics are optional because store/report roles differ.
    let units: Int?
    let downloads: Int?
    let proceeds: [CurrencyAmount]
    let activeSubscriptions: Int?

    // Monetization configuration health.
    let subscriptionProducts: Int?
    let oneTimeProducts: Int?
    let productsNeedingAction: Int?

    // Reliability metrics. Values are fractions, e.g. 0.012 == 1.2%.
    let crashRate: Double?
    let userPerceivedCrashRate: Double?
    let anrRate: Double?
    let userPerceivedAnrRate: Double?

    let detail: String?

    func matches(_ product: ProductApp) -> Bool {
        if provider == .apple,
           let expected = product.storeInfo.appleBundleID?.lowercased(),
           let actual = bundleOrPackageID?.lowercased(),
           expected == actual {
            return true
        }

        if provider == .google,
           let expected = product.storeInfo.androidPackageID?.lowercased(),
           let actual = bundleOrPackageID?.lowercased(),
           expected == actual {
            return true
        }

        return Self.normalize(appName) == Self.normalize(product.name)
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased(with: Locale(identifier: "de_DE"))
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "ß", with: "ss")
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "de_DE"))
            .filter { $0.isLetter || $0.isNumber }
    }
}

struct AnalyticsFeed: Codable, Hashable {
    let schemaVersion: Int
    let generatedAt: Date
    let sourceRepository: String?
    let appleAvailable: Bool
    let googleAvailable: Bool
    let commercialAvailable: Bool
    let reliabilityAvailable: Bool
    let apps: [AppAnalyticsSnapshot]
    let notes: [String]
    let appleGeneratedAt: Date?
    let googleGeneratedAt: Date?

    init(
        schemaVersion: Int,
        generatedAt: Date,
        sourceRepository: String?,
        appleAvailable: Bool,
        googleAvailable: Bool,
        commercialAvailable: Bool,
        reliabilityAvailable: Bool,
        apps: [AppAnalyticsSnapshot],
        notes: [String] = [],
        appleGeneratedAt: Date? = nil,
        googleGeneratedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.sourceRepository = sourceRepository
        self.appleAvailable = appleAvailable
        self.googleAvailable = googleAvailable
        self.commercialAvailable = commercialAvailable
        self.reliabilityAvailable = reliabilityAvailable
        self.apps = apps
        self.notes = notes
        self.appleGeneratedAt = appleGeneratedAt
        self.googleGeneratedAt = googleGeneratedAt
    }
}

struct AnalyticsObservation: Identifiable, Codable, Hashable {
    var id: String { "\(provider.rawValue):\(productID):\(dayKey)" }
    let productID: String
    let provider: StoreProvider
    let observedAt: Date
    let dayKey: String
    let units: Int?
    let downloads: Int?
    let proceeds: [CurrencyAmount]
    let activeSubscriptions: Int?
    let crashRate: Double?
    let anrRate: Double?
}

struct RepositoryAnalytics: Identifiable, Codable, Hashable {
    var id: String { repository }
    let repository: String
    let commitCount30d: Int
    let mergedPRCount30d: Int
    let workflowRuns30d: Int
    let workflowSuccessCount30d: Int
    let workflowFailureCount30d: Int
    let calculatedAt: Date

    var workflowSuccessRate: Double? {
        guard workflowRuns30d > 0 else { return nil }
        return Double(workflowSuccessCount30d) / Double(workflowRuns30d)
    }
}

struct PortfolioAnalyticsSummary: Hashable {
    let releases30d: Int
    let releases90d: Int
    let averageObservedAppleReview: TimeInterval?
    let averageObservedGoogleReview: TimeInterval?
    let configuredSubscriptions: Int
    let configuredOneTimeProducts: Int
    let monetizationProductsNeedingAction: Int
    let commercialUnits: Int?
    let downloads: Int?
    let proceedsByCurrency: [CurrencyAmount]
    let worstCrashRate: Double?
    let worstANRRate: Double?
    let commits30d: Int
    let mergedPRs30d: Int
    let workflowSuccessRate30d: Double?
}
