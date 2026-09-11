import Foundation

struct GitHubQuickActionsService: Sendable {
    enum ServiceError: LocalizedError {
        case missingToken
        case invalidWorkflowURL
        case invalidResponse(Int)

        var errorDescription: String? {
            switch self {
            case .missingToken:
                return L10n.t("GitHub-Token fehlt.", "GitHub token is missing.")
            case .invalidWorkflowURL:
                return L10n.t("Workflow-ID konnte nicht ermittelt werden.", "Workflow ID could not be resolved.")
            case .invalidResponse(let code):
                return L10n.t("GitHub Quick Action fehlgeschlagen (HTTP \(code)).", "GitHub quick action failed (HTTP \(code)).")
            }
        }
    }

    func rerunFailedJobs(workflowURL: String) async throws {
        guard let token = KeychainStore.githubToken, !token.isEmpty else { throw ServiceError.missingToken }
        guard let runID = runID(from: workflowURL) else { throw ServiceError.invalidWorkflowURL }

        let url = URL(string: "https://api.github.com/repos/acciento89-bot/\(repository(from: workflowURL))/actions/runs/\(runID)/rerun-failed-jobs")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse(-1) }
        guard 200..<300 ~= http.statusCode else { throw ServiceError.invalidResponse(http.statusCode) }
    }

    private func runID(from workflowURL: String) -> Int? {
        guard let url = URL(string: workflowURL) else { return nil }
        let parts = url.pathComponents
        guard let runsIndex = parts.firstIndex(of: "runs"), parts.indices.contains(runsIndex + 1) else { return nil }
        return Int(parts[runsIndex + 1])
    }

    private func repository(from workflowURL: String) -> String {
        guard let url = URL(string: workflowURL) else { return "" }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2 else { return "" }
        return parts[1]
    }
}
