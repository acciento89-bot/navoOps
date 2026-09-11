import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var products: [ProductApp]
    @Published var repositories: [RepoSnapshot] = []
    @Published var pullRequests: [PullRequestSnapshot] = []
    @Published var issues: [IssueSnapshot] = []
    @Published var healthByRepository: [String: RepositoryHealth] = [:]
    @Published var activities: [ActivityItem] = []
    @Published var isRefreshing = false
    @Published var lastRefresh: Date?
    @Published var errorMessage: String?

    private let github = GitHubService()
    private let portfolioStore = PortfolioStore()

    init() {
        products = portfolioStore.loadMerged(with: ProductCatalog.seed)
    }

    var fullyLiveCount: Int { products.filter(\.isFullyLive).count }
    var reviewCount: Int { products.filter(\.isInReview).count }
    var attentionCount: Int { products.filter(\.needsAttention).count }
    var buildFailureCount: Int { healthByRepository.values.filter { $0.buildState == .failure }.count }

    var attentionProducts: [ProductApp] {
        products.filter(\.needsAttention)
    }

    func health(for product: ProductApp) -> RepositoryHealth? {
        healthByRepository[product.repository]
    }

    func pullRequests(for product: ProductApp) -> [PullRequestSnapshot] {
        pullRequests.filter { repositoryMatches($0.repository, product.repository) }
    }

    func issues(for product: ProductApp) -> [IssueSnapshot] {
        issues.filter { repositoryMatches($0.repository, product.repository) }
    }

    func refreshGitHub() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let trackedRepositories = Array(Set(products.map(\.repository)))
        async let healthTask = github.fetchRepositoryHealth(repositories: trackedRepositories)

        do {
            async let reposTask = github.fetchRepositories()
            async let prsTask = github.fetchOpenPullRequests()
            async let issuesTask = github.fetchOpenIssues()

            let (repos, prs, issueList) = try await (reposTask, prsTask, issuesTask)
            let health = await healthTask

            repositories = repos
            pullRequests = prs
            issues = issueList
            healthByRepository = health
            lastRefresh = .now
            activities = buildActivities()
            errorMessage = nil

            await NotificationService.shared.processWorkflowHealth(health)
            BackgroundSyncService.shared.schedule()
        } catch {
            healthByRepository = await healthTask
            activities = buildActivities()
            errorMessage = error.localizedDescription
        }
    }

    func update(_ product: ProductApp) {
        guard let index = products.firstIndex(where: { $0.id == product.id }) else { return }
        products[index] = product
        portfolioStore.save(products)
    }

    func resetPortfolio() {
        portfolioStore.reset()
        products = ProductCatalog.seed
        portfolioStore.save(products)
    }

    func createIssue(for product: ProductApp, title: String, body: String) async throws -> IssueSnapshot {
        let issue = try await github.createIssue(repository: product.repository, title: title, body: body)
        issues.insert(issue, at: 0)
        activities = buildActivities()
        return issue
    }

    private func repositoryMatches(_ fullName: String, _ repository: String) -> Bool {
        fullName == repository || fullName.hasSuffix("/\(repository)")
    }

    private func buildActivities() -> [ActivityItem] {
        let workflows = healthByRepository.values.compactMap { health -> ActivityItem? in
            guard let date = health.workflowUpdatedAt else { return nil }
            switch health.buildState {
            case .failure:
                return ActivityItem(
                    id: "workflow-\(health.repository)-failure-\(date.timeIntervalSince1970)",
                    icon: "xmark.octagon.fill",
                    title: L10n.t("Build fehlgeschlagen", "Build failed"),
                    subtitle: "\(health.repository) · \(health.workflowName ?? "GitHub Actions")",
                    date: date,
                    tone: .danger
                )
            case .success:
                return ActivityItem(
                    id: "workflow-\(health.repository)-success-\(date.timeIntervalSince1970)",
                    icon: "checkmark.circle.fill",
                    title: L10n.t("Build erfolgreich", "Build succeeded"),
                    subtitle: "\(health.repository) · \(health.workflowName ?? "GitHub Actions")",
                    date: date,
                    tone: .success
                )
            case .running:
                return ActivityItem(
                    id: "workflow-\(health.repository)-running-\(date.timeIntervalSince1970)",
                    icon: "arrow.triangle.2.circlepath",
                    title: L10n.t("Build läuft", "Build running"),
                    subtitle: "\(health.repository) · \(health.workflowName ?? "GitHub Actions")",
                    date: date,
                    tone: .info
                )
            case .unknown:
                return nil
            }
        }

        let prItems = pullRequests.prefix(8).map {
            ActivityItem(
                id: "pr-\($0.id)",
                icon: "arrow.triangle.pull",
                title: "PR #\($0.number): \($0.title)",
                subtitle: $0.repository,
                date: $0.updatedAt ?? .distantPast,
                tone: .info
            )
        }

        let issueItems = issues.prefix(8).map {
            ActivityItem(
                id: "issue-\($0.id)",
                icon: "exclamationmark.circle.fill",
                title: "Issue #\($0.number): \($0.title)",
                subtitle: $0.repository,
                date: $0.updatedAt ?? .distantPast,
                tone: .warning
            )
        }

        return (workflows + prItems + issueItems)
            .sorted { $0.date > $1.date }
            .prefix(20)
            .map { $0 }
    }
}
