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
    @Published var storeFeed: StoreStatusFeed?
    @Published var storeHistory: [StoreHistoryEvent] = []
    @Published var isRefreshing = false
    @Published var isRefreshingStores = false
    @Published var lastRefresh: Date?
    @Published var errorMessage: String?
    @Published var storeErrorMessage: String?
    @Published var storeRefreshRequested = false

    private let github = GitHubService()
    private let storeStatus = StoreStatusService()
    private let portfolioStore = PortfolioStore()
    private let storeHistoryStore = StoreHistoryStore()

    init() {
        products = portfolioStore.loadMerged(with: ProductCatalog.seed)
        storeHistory = storeHistoryStore.load()
    }

    var fullyLiveCount: Int {
        products.filter { product in
            let appleOK = !product.supportsApple || resolvedAppleState(for: product) == .live
            let googleOK = !product.supportsGoogle || resolvedGoogleState(for: product) == .live
            return appleOK && googleOK
        }.count
    }

    var reviewCount: Int {
        products.filter { product in
            (product.supportsApple && resolvedAppleState(for: product) == .review) ||
            (product.supportsGoogle && resolvedGoogleState(for: product) == .review)
        }.count
    }

    var attentionCount: Int { attentionProducts.count }
    var buildFailureCount: Int { healthByRepository.values.filter { $0.buildState == .failure }.count }

    var attentionProducts: [ProductApp] {
        products.filter { product in
            (product.supportsApple && resolvedAppleState(for: product) == .attention) ||
            (product.supportsGoogle && resolvedGoogleState(for: product) == .attention)
        }
    }

    var storeGeneratedAt: Date? { storeFeed?.generatedAt }
    var appleLiveAvailable: Bool { storeFeed?.appleAvailable == true }
    var googleLiveAvailable: Bool { storeFeed?.googleAvailable == true }

    var operationsInbox: [OperationsInboxItem] {
        var items: [OperationsInboxItem] = []

        for product in products {
            if let health = health(for: product), health.buildState == .failure {
                items.append(.init(
                    id: "build:\(product.id):\(health.workflowRunNumber ?? 0)",
                    productID: product.id,
                    title: L10n.t("Build fehlgeschlagen · \(product.name)", "Build failed · \(product.name)"),
                    detail: health.workflowName ?? "GitHub Actions",
                    priority: .critical,
                    kind: .build,
                    date: health.workflowUpdatedAt ?? .distantPast
                ))
            }

            if let apple = storeSnapshot(for: product, provider: .apple) {
                if apple.state == .rejected || apple.state == .attention {
                    items.append(.init(
                        id: "apple:\(apple.id):attention",
                        productID: product.id,
                        title: L10n.t("Apple benötigt Aktion · \(product.name)", "Apple needs action · \(product.name)"),
                        detail: apple.detail ?? apple.rawState,
                        priority: .critical,
                        kind: .apple,
                        date: apple.updatedAt ?? storeFeed?.generatedAt ?? .distantPast
                    ))
                } else if apple.state == .review || apple.state == .processing {
                    items.append(.init(
                        id: "apple:\(apple.id):waiting",
                        productID: product.id,
                        title: L10n.t("Apple wartet · \(product.name)", "Waiting on Apple · \(product.name)"),
                        detail: apple.detail ?? apple.rawState,
                        priority: .waiting,
                        kind: .apple,
                        date: apple.updatedAt ?? storeFeed?.generatedAt ?? .distantPast
                    ))
                }
            }

            if let google = storeSnapshot(for: product, provider: .google) {
                if google.state == .rejected || google.state == .attention {
                    items.append(.init(
                        id: "google:\(google.id):attention",
                        productID: product.id,
                        title: L10n.t("Google Play benötigt Aktion · \(product.name)", "Google Play needs action · \(product.name)"),
                        detail: google.detail ?? google.rawState,
                        priority: .critical,
                        kind: .google,
                        date: google.updatedAt ?? storeFeed?.generatedAt ?? .distantPast
                    ))
                } else if google.state == .review || google.state == .processing {
                    items.append(.init(
                        id: "google:\(google.id):waiting",
                        productID: product.id,
                        title: L10n.t("Google Play wartet · \(product.name)", "Waiting on Google Play · \(product.name)"),
                        detail: google.detail ?? google.rawState,
                        priority: .waiting,
                        kind: .google,
                        date: google.updatedAt ?? storeFeed?.generatedAt ?? .distantPast
                    ))
                }
            }

            if product.needsAttention,
               storeSnapshot(for: product, provider: .apple) == nil,
               storeSnapshot(for: product, provider: .google) == nil {
                items.append(.init(
                    id: "release:\(product.id)",
                    productID: product.id,
                    title: L10n.t("Release-Arbeit offen · \(product.name)", "Release work pending · \(product.name)"),
                    detail: product.notes.isEmpty ? L10n.t("Manueller Produktstatus benötigt Aufmerksamkeit.", "Manual product status needs attention.") : product.notes,
                    priority: .action,
                    kind: .release,
                    date: .distantPast
                ))
            }
        }

        return items.sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.date > $1.date
        }
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

    func storeSnapshot(for product: ProductApp, provider: StoreProvider) -> StoreAppSnapshot? {
        storeFeed?.apps.first { $0.provider == provider && $0.matches(product) }
    }

    func resolvedAppleState(for product: ProductApp) -> ProductApp.StoreState {
        storeSnapshot(for: product, provider: .apple)?.state.productState ?? product.appleState
    }

    func resolvedGoogleState(for product: ProductApp) -> ProductApp.StoreState {
        storeSnapshot(for: product, provider: .google)?.state.productState ?? product.googleState
    }

    func resolvedVersion(for product: ProductApp) -> String {
        storeSnapshot(for: product, provider: .apple)?.version ??
        storeSnapshot(for: product, provider: .google)?.version ??
        product.version
    }

    func resolvedBuild(for product: ProductApp) -> String {
        storeSnapshot(for: product, provider: .apple)?.build ??
        storeSnapshot(for: product, provider: .google)?.build ??
        product.build
    }

    func refreshAll() async {
        await refreshGitHub()
        await refreshStores()
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

    func refreshStores() async {
        guard !isRefreshingStores else { return }
        isRefreshingStores = true
        defer { isRefreshingStores = false }

        do {
            let feed = try await storeStatus.fetchFeed()
            storeFeed = feed
            storeHistory = storeHistoryStore.record(feed: feed, products: products, existing: storeHistory)
            storeErrorMessage = nil
            storeRefreshRequested = false
            await NotificationService.shared.processStoreFeed(feed)
        } catch {
            storeErrorMessage = error.localizedDescription
        }
    }

    func requestStoreBridgeRefresh() async {
        do {
            try await storeStatus.requestBridgeRefresh()
            storeRefreshRequested = true
            storeErrorMessage = nil
        } catch {
            storeErrorMessage = error.localizedDescription
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

    func resetStoreHistory() {
        storeHistoryStore.reset()
        storeHistory = []
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
