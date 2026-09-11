import Foundation

extension AppModel {
    func rerunFailedWorkflow(for product: ProductApp) async throws {
        guard let health = health(for: product), let workflowURL = health.workflowURL else {
            throw GitHubQuickActionsService.ServiceError.invalidWorkflowURL
        }
        try await GitHubQuickActionsService().rerunFailedJobs(workflowURL: workflowURL)

        // GitHub accepts the re-run asynchronously. Give the Actions API a moment
        // before refreshing so the UI can switch from failed to running.
        try? await Task.sleep(for: .milliseconds(900))
        await refreshGitHub()
    }
}
