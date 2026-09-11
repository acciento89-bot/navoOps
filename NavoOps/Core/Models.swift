import Foundation

struct ProductApp: Identifiable, Hashable, Codable {
    enum Platform: String, Codable, CaseIterable, Hashable {
        case iOS
        case android
    }

    enum StoreState: String, Codable, CaseIterable, Hashable {
        case development
        case internalTest
        case review
        case live
        case attention
    }

    enum Monetization: String, Codable, CaseIterable, Hashable {
        case free
        case paid
        case oneTime
        case subscription
        case mixed
    }

    let id: String
    var name: String
    var repository: String
    var platforms: Set<Platform>
    var appleState: StoreState
    var googleState: StoreState
    var version: String
    var build: String
    var notes: String
    var checklist: ReleaseChecklist
    var storeInfo: StoreInfo
    var monetization: Monetization
    var tags: [String]

    init(
        id: String,
        name: String,
        repository: String,
        platforms: Set<Platform>,
        appleState: StoreState,
        googleState: StoreState,
        version: String,
        build: String,
        notes: String = "",
        checklist: ReleaseChecklist = .init(),
        storeInfo: StoreInfo = .init(),
        monetization: Monetization = .free,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.repository = repository
        self.platforms = platforms
        self.appleState = appleState
        self.googleState = googleState
        self.version = version
        self.build = build
        self.notes = notes
        self.checklist = checklist
        self.storeInfo = storeInfo
        self.monetization = monetization
        self.tags = tags
    }

    var supportsApple: Bool { platforms.contains(.iOS) }
    var supportsGoogle: Bool { platforms.contains(.android) }

    var needsAttention: Bool {
        (supportsApple && appleState == .attention) || (supportsGoogle && googleState == .attention)
    }

    var isInReview: Bool {
        (supportsApple && appleState == .review) || (supportsGoogle && googleState == .review)
    }

    var isFullyLive: Bool {
        let appleOK = !supportsApple || appleState == .live
        let googleOK = !supportsGoogle || googleState == .live
        return appleOK && googleOK
    }
}

struct StoreInfo: Hashable, Codable {
    var appleBundleID: String?
    var androidPackageID: String?
    var privacyURL: String?
    var supportURL: String?
    var marketingURL: String?

    init(
        appleBundleID: String? = nil,
        androidPackageID: String? = nil,
        privacyURL: String? = "https://www.kamilunavo.com/privacy",
        supportURL: String? = "https://www.kamilunavo.com",
        marketingURL: String? = "https://www.kamilunavo.com"
    ) {
        self.appleBundleID = appleBundleID
        self.androidPackageID = androidPackageID
        self.privacyURL = privacyURL
        self.supportURL = supportURL
        self.marketingURL = marketingURL
    }
}

struct ReleaseChecklist: Hashable, Codable {
    var icon = false
    var screenshotsDE = false
    var screenshotsEN = false
    var privacyURL = false
    var storeTextDE = false
    var storeTextEN = false

    var eula = false
    var applePrivacy = false
    var appleReviewAccess = false
    var appleBilling = false

    var googleFeatureGraphic = false
    var googleDataSafety = false
    var googleAppAccess = false
    var googleBilling = false

    private var common: [Bool] {
        [icon, screenshotsDE, screenshotsEN, privacyURL, storeTextDE, storeTextEN]
    }

    var appleCompleted: Int {
        (common + [eula, applePrivacy, appleReviewAccess, appleBilling]).filter { $0 }.count
    }

    var appleTotal: Int { 10 }

    var googleCompleted: Int {
        (common + [googleFeatureGraphic, googleDataSafety, googleAppAccess, googleBilling]).filter { $0 }.count
    }

    var googleTotal: Int { 10 }

    var readyForApple: Bool { appleCompleted == appleTotal }
    var readyForGoogle: Bool { googleCompleted == googleTotal }

    static var fullyReady: ReleaseChecklist {
        .init(
            icon: true,
            screenshotsDE: true,
            screenshotsEN: true,
            privacyURL: true,
            storeTextDE: true,
            storeTextEN: true,
            eula: true,
            applePrivacy: true,
            appleReviewAccess: true,
            appleBilling: true,
            googleFeatureGraphic: true,
            googleDataSafety: true,
            googleAppAccess: true,
            googleBilling: true
        )
    }
}

struct RepoSnapshot: Identifiable, Hashable, Codable {
    let id: Int
    let name: String
    let fullName: String
    let isPrivate: Bool
    let defaultBranch: String
    let htmlURL: String
    let openIssues: Int
    let updatedAt: Date?
}

struct PullRequestSnapshot: Identifiable, Hashable, Codable {
    let id: Int
    let number: Int
    let title: String
    let repository: String
    let state: String
    let htmlURL: String
    let draft: Bool
    let updatedAt: Date?
}

struct IssueSnapshot: Identifiable, Hashable, Codable {
    let id: Int
    let number: Int
    let title: String
    let repository: String
    let htmlURL: String
    let updatedAt: Date?
}

struct RepositoryHealth: Identifiable, Hashable, Codable {
    enum BuildState: String, Codable, Hashable {
        case success
        case failure
        case running
        case unknown
    }

    var id: String { repository }
    let repository: String
    let latestCommitSHA: String?
    let latestCommitMessage: String?
    let latestCommitURL: String?
    let latestCommitAt: Date?
    let workflowName: String?
    let workflowRunNumber: Int?
    let workflowURL: String?
    let workflowUpdatedAt: Date?
    let buildState: BuildState

    static func unavailable(repository: String) -> RepositoryHealth {
        .init(
            repository: repository,
            latestCommitSHA: nil,
            latestCommitMessage: nil,
            latestCommitURL: nil,
            latestCommitAt: nil,
            workflowName: nil,
            workflowRunNumber: nil,
            workflowURL: nil,
            workflowUpdatedAt: nil,
            buildState: .unknown
        )
    }
}

struct ActivityItem: Identifiable, Hashable {
    enum Tone: Hashable {
        case success
        case warning
        case danger
        case info
    }

    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let date: Date
    let tone: Tone

    init(id: String = UUID().uuidString, icon: String, title: String, subtitle: String, date: Date, tone: Tone) {
        self.id = id
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.date = date
        self.tone = tone
    }
}
