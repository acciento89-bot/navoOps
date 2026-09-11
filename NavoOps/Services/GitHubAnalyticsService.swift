import Foundation

struct GitHubAnalyticsService: Sendable {
    enum ServiceError: LocalizedError {
        case missingToken
        case invalidURL
        case invalidResponse(Int)

        var errorDescription: String? {
            switch self {
            case .missingToken: return L10n.t("GitHub-Token fehlt.", "GitHub token is missing.")
            case .invalidURL: return L10n.t("Ungültige GitHub-URL.", "Invalid GitHub URL.")
            case .invalidResponse(let status): return "GitHub HTTP \(status)"
            }
        }
    }

    private let owner = "acciento89-bot"
    private let pageSize = 100
    private let maximumPages = 10

    func fetch(repositories: [String]) async -> [String: RepositoryAnalytics] {
        guard KeychainStore.githubToken?.isEmpty == false else { return [:] }
        let unique = Array(Set(repositories)).sorted()
        let mergedCounts = (try? await fetchMergedPRCounts(since: cutoffDate)) ?? [:]

        return await withTaskGroup(of: (String, RepositoryAnalytics).self) { group in
            for repository in unique {
                group.addTask {
                    let snapshot = await fetchRepository(repository, mergedPRCount: mergedCounts[repository] ?? 0)
                    return (repository, snapshot)
                }
            }

            var result: [String: RepositoryAnalytics] = [:]
            for await (repository, snapshot) in group {
                result[repository] = snapshot
            }
            return result
        }
    }

    private var cutoffDate: Date {
        Date().addingTimeInterval(-30 * 24 * 60 * 60)
    }

    private func fetchRepository(_ repository: String, mergedPRCount: Int) async -> RepositoryAnalytics {
        async let commitsTask = fetchCommitCount(repository: repository, since: cutoffDate)
        async let workflowsTask = fetchWorkflowStats(repository: repository, since: cutoffDate)

        let commits = (try? await commitsTask) ?? 0
        let workflows = (try? await workflowsTask) ?? (0, 0, 0)

        return RepositoryAnalytics(
            repository: repository,
            commitCount30d: commits,
            mergedPRCount30d: mergedPRCount,
            workflowRuns30d: workflows.0,
            workflowSuccessCount30d: workflows.1,
            workflowFailureCount30d: workflows.2,
            calculatedAt: .now
        )
    }

    private func fetchCommitCount(repository: String, since: Date) async throws -> Int {
        let iso = ISO8601DateFormatter().string(from: since)
        var count = 0

        for page in 1...maximumPages {
            let url = try makeURL(path: "/repos/\(owner)/\(repository)/commits", query: [
                URLQueryItem(name: "since", value: iso),
                URLQueryItem(name: "per_page", value: String(pageSize)),
                URLQueryItem(name: "page", value: String(page))
            ])
            let data = try await request(url)
            let items = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
            count += items.count
            if items.count < pageSize { break }
        }
        return count
    }

    private func fetchWorkflowStats(repository: String, since: Date) async throws -> (Int, Int, Int) {
        var completedCount = 0
        var successCount = 0
        var failureCount = 0
        let failureConclusions: Set<String> = ["failure", "cancelled", "timed_out", "action_required", "startup_failure", "stale"]

        for page in 1...maximumPages {
            let url = try makeURL(path: "/repos/\(owner)/\(repository)/actions/runs", query: [
                URLQueryItem(name: "per_page", value: String(pageSize)),
                URLQueryItem(name: "page", value: String(page))
            ])
            let data = try await request(url)
            let payload = try JSONDecoder.github.decode(WorkflowAnalyticsResponse.self, from: data)
            if payload.workflow_runs.isEmpty { break }

            let inWindow = payload.workflow_runs.filter { ($0.updated_at ?? .distantPast) >= since }
            let completed = inWindow.filter { $0.status == "completed" }
            completedCount += completed.count
            successCount += completed.filter { $0.conclusion == "success" }.count
            failureCount += completed.filter { $0.conclusion.map(failureConclusions.contains) == true }.count

            let reachedOlderData = payload.workflow_runs.contains { ($0.updated_at ?? .distantPast) < since }
            if payload.workflow_runs.count < pageSize || reachedOlderData { break }
        }

        return (completedCount, successCount, failureCount)
    }

    private func fetchMergedPRCounts(since: Date) async throws -> [String: Int] {
        let date = Self.dateOnly.string(from: since)
        let query = "user:\(owner) is:pr is:merged merged:>=\(date)"
        var counts: [String: Int] = [:]

        for page in 1...maximumPages {
            let url = try makeURL(path: "/search/issues", query: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "per_page", value: String(pageSize)),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "sort", value: "updated"),
                URLQueryItem(name: "order", value: "desc")
            ])
            let data = try await request(url)
            let payload = try JSONDecoder.github.decode(MergedPRSearchResponse.self, from: data)

            for item in payload.items {
                let components = item.repository_url.split(separator: "/")
                guard let repository = components.last.map(String.init) else { continue }
                counts[repository, default: 0] += 1
            }

            if payload.items.count < pageSize || page * pageSize >= min(payload.total_count, 1000) { break }
        }
        return counts
    }

    private func makeURL(path: String, query: [URLQueryItem] = []) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        components.path = path
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw ServiceError.invalidURL }
        return url
    }

    private func request(_ url: URL) async throws -> Data {
        guard let token = KeychainStore.githubToken, !token.isEmpty else { throw ServiceError.missingToken }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse(-1) }
        guard 200..<300 ~= http.statusCode else { throw ServiceError.invalidResponse(http.statusCode) }
        return data
    }

    private static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct WorkflowAnalyticsResponse: Decodable {
    let workflow_runs: [WorkflowAnalyticsRun]
}

private struct WorkflowAnalyticsRun: Decodable {
    let status: String
    let conclusion: String?
    let updated_at: Date?
}

private struct MergedPRSearchResponse: Decodable {
    let total_count: Int
    let items: [MergedPRSearchItem]
}

private struct MergedPRSearchItem: Decodable {
    let repository_url: String
}
