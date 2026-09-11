import Foundation
import Security

struct GitHubService: Sendable {
    enum ServiceError: LocalizedError {
        case missingToken
        case invalidURL
        case invalidResponse(Int)

        var errorDescription: String? {
            switch self {
            case .missingToken:
                return L10n.t("GitHub-Token fehlt. In Einstellungen hinterlegen.", "GitHub token is missing. Add it in Settings.")
            case .invalidURL:
                return L10n.t("Ungültige GitHub-URL.", "Invalid GitHub URL.")
            case .invalidResponse(let status):
                return L10n.t("GitHub antwortete mit HTTP \(status).", "GitHub returned HTTP \(status).")
            }
        }
    }

    private let owner = "acciento89-bot"

    func fetchRepositories() async throws -> [RepoSnapshot] {
        let url = try makeURL(path: "/user/repos", query: [
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "affiliation", value: "owner,collaborator,organization_member")
        ])
        let data = try await request(url)
        let items = try JSONDecoder.github.decode([RepoDTO].self, from: data)
        return items.map {
            RepoSnapshot(
                id: $0.id,
                name: $0.name,
                fullName: $0.full_name,
                isPrivate: $0.private,
                defaultBranch: $0.default_branch,
                htmlURL: $0.html_url,
                openIssues: $0.open_issues_count,
                updatedAt: $0.updated_at
            )
        }
    }

    func fetchOpenPullRequests() async throws -> [PullRequestSnapshot] {
        let query = "user:\(owner) is:pr is:open"
        let url = try makeURL(path: "/search/issues", query: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "sort", value: "updated")
        ])
        let data = try await request(url)
        let response = try JSONDecoder.github.decode(SearchResponse.self, from: data)
        return response.items.map { item in
            PullRequestSnapshot(
                id: item.id,
                number: item.number,
                title: item.title,
                repository: repositoryName(from: item.repository_url),
                state: item.state,
                htmlURL: item.html_url,
                draft: item.draft ?? false,
                updatedAt: item.updated_at
            )
        }
    }

    func fetchOpenIssues() async throws -> [IssueSnapshot] {
        let query = "user:\(owner) is:issue is:open"
        let url = try makeURL(path: "/search/issues", query: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "sort", value: "updated")
        ])
        let data = try await request(url)
        let response = try JSONDecoder.github.decode(SearchResponse.self, from: data)
        return response.items.map { item in
            IssueSnapshot(
                id: item.id,
                number: item.number,
                title: item.title,
                repository: repositoryName(from: item.repository_url),
                htmlURL: item.html_url,
                updatedAt: item.updated_at
            )
        }
    }

    func fetchRepositoryHealth(repositories: [String]) async -> [String: RepositoryHealth] {
        let unique = Array(Set(repositories)).sorted()
        return await withTaskGroup(of: (String, RepositoryHealth).self) { group in
            for repository in unique {
                group.addTask {
                    let health = await fetchHealth(repository: repository)
                    return (repository, health)
                }
            }

            var result: [String: RepositoryHealth] = [:]
            for await (repository, health) in group {
                result[repository] = health
            }
            return result
        }
    }

    func createIssue(repository: String, title: String, body: String) async throws -> IssueSnapshot {
        let url = try makeURL(path: "/repos/\(owner)/\(repository)/issues")
        let payload = try JSONEncoder().encode(CreateIssuePayload(title: title, body: body))
        let data = try await request(url, method: "POST", body: payload)
        let item = try JSONDecoder.github.decode(CreatedIssueDTO.self, from: data)
        return IssueSnapshot(
            id: item.id,
            number: item.number,
            title: item.title,
            repository: "\(owner)/\(repository)",
            htmlURL: item.html_url,
            updatedAt: item.updated_at
        )
    }

    private func fetchHealth(repository: String) async -> RepositoryHealth {
        async let commitRequest = fetchLatestCommit(repository: repository)
        async let workflowRequest = fetchLatestWorkflow(repository: repository)

        let commit = try? await commitRequest
        let workflow = try? await workflowRequest

        let buildState: RepositoryHealth.BuildState
        if let workflow {
            if workflow.status != "completed" {
                buildState = .running
            } else {
                switch workflow.conclusion {
                case "success": buildState = .success
                case "failure", "cancelled", "timed_out", "action_required", "startup_failure", "stale": buildState = .failure
                default: buildState = .unknown
                }
            }
        } else {
            buildState = .unknown
        }

        return RepositoryHealth(
            repository: repository,
            latestCommitSHA: commit?.sha,
            latestCommitMessage: commit?.commit.message.components(separatedBy: "\n").first,
            latestCommitURL: commit?.html_url,
            latestCommitAt: commit?.commit.committer?.date,
            workflowName: workflow?.name,
            workflowRunNumber: workflow?.run_number,
            workflowURL: workflow?.html_url,
            workflowUpdatedAt: workflow?.updated_at,
            buildState: buildState
        )
    }

    private func fetchLatestCommit(repository: String) async throws -> CommitDTO? {
        let url = try makeURL(path: "/repos/\(owner)/\(repository)/commits", query: [URLQueryItem(name: "per_page", value: "1")])
        let data = try await request(url)
        return try JSONDecoder.github.decode([CommitDTO].self, from: data).first
    }

    private func fetchLatestWorkflow(repository: String) async throws -> WorkflowRunDTO? {
        let url = try makeURL(path: "/repos/\(owner)/\(repository)/actions/runs", query: [URLQueryItem(name: "per_page", value: "1")])
        let data = try await request(url)
        return try JSONDecoder.github.decode(WorkflowRunsResponse.self, from: data).workflow_runs.first
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

    private func request(_ url: URL, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let token = KeychainStore.githubToken, !token.isEmpty else { throw ServiceError.missingToken }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse(-1) }
        guard 200..<300 ~= http.statusCode else { throw ServiceError.invalidResponse(http.statusCode) }
        return data
    }

    private func repositoryName(from repositoryURL: String) -> String {
        repositoryURL.split(separator: "/").suffix(2).joined(separator: "/")
    }
}

private struct RepoDTO: Decodable {
    let id: Int
    let name: String
    let full_name: String
    let `private`: Bool
    let default_branch: String
    let html_url: String
    let open_issues_count: Int
    let updated_at: Date?
}

private struct SearchResponse: Decodable {
    let items: [SearchItem]
}

private struct SearchItem: Decodable {
    let id: Int
    let number: Int
    let title: String
    let state: String
    let html_url: String
    let repository_url: String
    let draft: Bool?
    let updated_at: Date?
}

private struct CommitDTO: Decodable {
    let sha: String
    let html_url: String
    let commit: CommitPayload
}

private struct CommitPayload: Decodable {
    let message: String
    let committer: GitActor?
}

private struct GitActor: Decodable {
    let date: Date?
}

private struct WorkflowRunsResponse: Decodable {
    let workflow_runs: [WorkflowRunDTO]
}

private struct WorkflowRunDTO: Decodable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let html_url: String
    let run_number: Int
    let updated_at: Date?
}

private struct CreateIssuePayload: Encodable {
    let title: String
    let body: String
}

private struct CreatedIssueDTO: Decodable {
    let id: Int
    let number: Int
    let title: String
    let html_url: String
    let updated_at: Date?
}

extension JSONDecoder {
    static var github: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum KeychainStore {
    private static let service = "com.kamilunavo.NavoOps"
    private static let githubAccount = "github-token"

    static var githubToken: String? {
        get { read(account: githubAccount) }
        set { write(newValue, account: githubAccount) }
    }

    private static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ value: String?, account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)

        guard let value, !value.isEmpty, let data = value.data(using: .utf8) else { return }
        var item = base
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
