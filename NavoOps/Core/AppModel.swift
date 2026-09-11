import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var products: [ProductApp] = ProductCatalog.seed
    @Published var repositories: [RepoSnapshot] = []
    @Published var pullRequests: [PullRequestSnapshot] = []
    @Published var issues: [IssueSnapshot] = []
    @Published var activities: [ActivityItem] = []
    @Published var isRefreshing = false
    @Published var lastRefresh: Date?
    @Published var errorMessage: String?

    private let github = GitHubService()

    var liveCount: Int {
        products.filter { $0.appleState == .live || $0.googleState == .live }.count
    }

    var reviewCount: Int {
        products.filter { $0.appleState == .review || $0.googleState == .review }.count
    }

    var attentionCount: Int {
        products.filter { $0.appleState == .attention || $0.googleState == .attention }.count
    }

    func refreshGitHub() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            async let repos = github.fetchRepositories()
            async let prs = github.fetchOpenPullRequests()
            async let issueList = github.fetchOpenIssues()
            repositories = try await repos
            pullRequests = try await prs
            issues = try await issueList
            lastRefresh = .now
            activities = buildActivities()
            errorMessage = nil
        } catch GitHubService.ServiceError.missingToken {
            errorMessage = "GitHub-Token fehlt. In Einstellungen hinterlegen."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(_ product: ProductApp) {
        guard let index = products.firstIndex(where: { $0.id == product.id }) else { return }
        products[index] = product
    }

    private func buildActivities() -> [ActivityItem] {
        let prItems = pullRequests.prefix(6).map {
            ActivityItem(icon: "arrow.triangle.pull", title: "PR #\($0.number): \($0.title)", subtitle: $0.repository, date: $0.updatedAt ?? .now, tone: .info)
        }
        let issueItems = issues.prefix(6).map {
            ActivityItem(icon: "exclamationmark.circle", title: "Issue #\($0.number): \($0.title)", subtitle: $0.repository, date: $0.updatedAt ?? .now, tone: .warning)
        }
        return (prItems + issueItems).sorted { $0.date > $1.date }
    }
}

enum ProductCatalog {
    static let seed: [ProductApp] = [
        .init(name: "NavoKids", repository: "navokids", platforms: [.iOS, .android], appleState: .review, googleState: .review, version: "1.0", build: "12", checklist: ready()),
        .init(name: "ZweiCheck", repository: "zweicheck", platforms: [.iOS, .android], appleState: .live, googleState: .internalTest, version: "1.0", build: "1", checklist: ready()),
        .init(name: "ArbeitsKlar", repository: "arbeitsklar", platforms: [.iOS, .android], appleState: .review, googleState: .review, version: "1.0", build: "1", checklist: ready()),
        .init(name: "WärmeTakt", repository: "w-rmetakt", platforms: [.iOS, .android], appleState: .development, googleState: .development, version: "1.0", build: "1"),
        .init(name: "Reklaio", repository: "reklaio", platforms: [.iOS, .android], appleState: .live, googleState: .internalTest, version: "1.0", build: "1", checklist: ready()),
        .init(name: "MängelFix", repository: "maengelfix", platforms: [.iOS, .android], appleState: .live, googleState: .review, version: "1.0.4", build: "5", checklist: ready()),
        .init(name: "NavoPass", repository: "navopass", platforms: [.iOS, .android], appleState: .review, googleState: .development, version: "1.0", build: "5"),
        .init(name: "KeepMeter", repository: "keepmeter", platforms: [.iOS, .android], appleState: .review, googleState: .development, version: "1.0.3", build: "3"),
        .init(name: "Kintaroq", repository: "kamilunavo", platforms: [.iOS], appleState: .review, googleState: .development, version: "1.0", build: "1"),
        .init(name: "Idle Handwerker", repository: "appideenchatgpt", platforms: [.iOS, .android], appleState: .development, googleState: .attention, version: "1.3.0", build: "8", notes: "Android-Build prüfen: native App statt WebView."),
        .init(name: "KälteCalc", repository: "SHK", platforms: [.iOS, .android], appleState: .review, googleState: .development, version: "1.0", build: "5"),
        .init(name: "LüftungsCalc", repository: "SHK", platforms: [.iOS, .android], appleState: .review, googleState: .development, version: "1.0", build: "1"),
        .init(name: "RohrCalc", repository: "SHK", platforms: [.iOS, .android], appleState: .review, googleState: .development, version: "1.0", build: "1"),
        .init(name: "HeizkörperCalc", repository: "SHK", platforms: [.iOS, .android], appleState: .review, googleState: .development, version: "1.0", build: "1"),
        .init(name: "VolumeCalc", repository: "AnlagenVolumen", platforms: [.iOS, .android], appleState: .development, googleState: .attention, version: "1.0", build: "1", notes: "Android Statusbar/Topbar und Kontrast prüfen."),
        .init(name: "BrennerCalc", repository: "BrennerCalc", platforms: [.android], appleState: .development, googleState: .review, version: "1.0", build: "1"),
        .init(name: "HydroCalc", repository: "HydroCalc", platforms: [.android], appleState: .development, googleState: .attention, version: "1.0", build: "1", notes: "Store-Assets und EN-Metadaten vervollständigen."),
        .init(name: "MAGCalc", repository: "MAGCalc", platforms: [.android], appleState: .development, googleState: .development, version: "1.0", build: "1")
    ]

    private static func ready() -> ReleaseChecklist {
        .init(icon: true, screenshotsDE: true, screenshotsEN: true, privacyURL: true, eula: true, reviewAccess: true, billing: true, storeTextDE: true, storeTextEN: true)
    }
}
