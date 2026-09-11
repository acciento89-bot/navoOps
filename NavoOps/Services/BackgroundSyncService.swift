import BackgroundTasks
import Foundation

final class BackgroundSyncService: @unchecked Sendable {
    static let shared = BackgroundSyncService()

    static let taskIdentifier = "com.kamilunavo.NavoOps.refresh"

    private init() {}

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handle(refreshTask)
        }
    }

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handle(_ task: BGAppRefreshTask) {
        schedule()

        let work = Task {
            guard KeychainStore.githubToken != nil else {
                task.setTaskCompleted(success: false)
                return
            }

            let products = PortfolioStore().loadMerged(with: ProductCatalog.seed)
            let repositories = Array(Set(products.map(\.repository)))

            async let healthTask = GitHubService().fetchRepositoryHealth(repositories: repositories)
            async let storeTask = try? StoreStatusService().fetchFeed()

            let health = await healthTask
            await NotificationService.shared.processWorkflowHealth(health)

            if let feed = await storeTask {
                await NotificationService.shared.processStoreFeed(feed)
            }

            task.setTaskCompleted(success: !Task.isCancelled)
        }

        task.expirationHandler = {
            work.cancel()
        }
    }
}
