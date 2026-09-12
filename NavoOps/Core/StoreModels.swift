import Foundation

enum StoreProvider: String, Codable, CaseIterable, Hashable {
    case apple
    case google

    var title: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google Play"
        }
    }
}

struct StoreReviewSnapshot: Codable, Hashable {
    enum ReasonAvailability: String, Codable, Hashable {
        case api
        case consoleOnly
        case unavailable
    }

    let submissionID: String?
    let submissionState: String?
    let itemStates: [String]
    let submittedAt: Date?
    let track: String?
    let lifecycleState: String?
    let reason: String?
    let reasonAvailability: ReasonAvailability
    let consoleURL: String?

    init(
        submissionID: String? = nil,
        submissionState: String? = nil,
        itemStates: [String] = [],
        submittedAt: Date? = nil,
        track: String? = nil,
        lifecycleState: String? = nil,
        reason: String? = nil,
        reasonAvailability: ReasonAvailability = .unavailable,
        consoleURL: String? = nil
    ) {
        self.submissionID = submissionID
        self.submissionState = submissionState
        self.itemStates = itemStates
        self.submittedAt = submittedAt
        self.track = track
        self.lifecycleState = lifecycleState
        self.reason = reason
        self.reasonAvailability = reasonAvailability
        self.consoleURL = consoleURL
    }

    var requiresAction: Bool {
        let states = ([submissionState, lifecycleState].compactMap { $0 } + itemStates).map { $0.uppercased() }
        return states.contains { state in
            state.contains("REJECT") ||
            state.contains("NOT_APPROVED") ||
            state.contains("UNRESOLVED") ||
            state.contains("NOT_SENT_FOR_REVIEW") ||
            state.contains("APPROVED_NOT_PUBLISHED")
        }
    }

    var displayState: String? {
        if let submissionState, !submissionState.isEmpty { return submissionState }
        if let lifecycleState, !lifecycleState.isEmpty { return lifecycleState }
        return itemStates.first
    }
}

struct StoreStatusFeed: Codable, Hashable {
    let schemaVersion: Int
    let generatedAt: Date
    let sourceRepository: String?
    let appleAvailable: Bool
    let googleAvailable: Bool
    let apps: [StoreAppSnapshot]
    let appleGeneratedAt: Date?
    let googleGeneratedAt: Date?

    init(
        schemaVersion: Int,
        generatedAt: Date,
        sourceRepository: String?,
        appleAvailable: Bool,
        googleAvailable: Bool,
        apps: [StoreAppSnapshot],
        appleGeneratedAt: Date? = nil,
        googleGeneratedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.sourceRepository = sourceRepository
        self.appleAvailable = appleAvailable
        self.googleAvailable = googleAvailable
        self.apps = apps
        self.appleGeneratedAt = appleGeneratedAt
        self.googleGeneratedAt = googleGeneratedAt
    }
}

struct StoreAppSnapshot: Identifiable, Codable, Hashable {
    enum State: String, Codable, CaseIterable, Hashable {
        case development
        case processing
        case internalTest
        case review
        case live
        case rejected
        case attention
        case unavailable

        var productState: ProductApp.StoreState {
            switch self {
            case .development, .processing:
                return .development
            case .internalTest:
                return .internalTest
            case .review:
                return .review
            case .live:
                return .live
            case .rejected, .attention:
                return .attention
            case .unavailable:
                return .development
            }
        }
    }

    var id: String {
        "\(provider.rawValue):\(externalID ?? bundleOrPackageID ?? appName)"
    }

    let provider: StoreProvider
    let appName: String
    let externalID: String?
    let bundleOrPackageID: String?
    let version: String?
    let build: String?
    let rawState: String
    let state: State
    let updatedAt: Date?
    let detail: String?
    let review: StoreReviewSnapshot?

    init(
        provider: StoreProvider,
        appName: String,
        externalID: String?,
        bundleOrPackageID: String?,
        version: String?,
        build: String?,
        rawState: String,
        state: State,
        updatedAt: Date?,
        detail: String?,
        review: StoreReviewSnapshot? = nil
    ) {
        self.provider = provider
        self.appName = appName
        self.externalID = externalID
        self.bundleOrPackageID = bundleOrPackageID
        self.version = version
        self.build = build
        self.rawState = rawState
        self.state = state
        self.updatedAt = updatedAt
        self.detail = detail
        self.review = review
    }
}

struct OperationsInboxItem: Identifiable, Hashable {
    enum Priority: Int, Comparable, Hashable {
        case critical = 3
        case action = 2
        case waiting = 1
        case info = 0

        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    enum Kind: Hashable {
        case build
        case apple
        case google
        case release
        case pullRequest
    }

    let id: String
    let productID: String?
    let title: String
    let detail: String
    let priority: Priority
    let kind: Kind
    let date: Date
}

extension StoreAppSnapshot {
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
        var normalized = value.lowercased(with: Locale(identifier: "de_DE"))
        normalized = normalized
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "ß", with: "ss")

        return normalized
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "de_DE"))
            .filter { $0.isLetter || $0.isNumber }
    }
}
