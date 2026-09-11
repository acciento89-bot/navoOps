import Foundation
import Security

struct GitHubService {
    enum ServiceError: Error { case missingToken, invalidResponse }

    private let session = URLSession.shared

    func fetchRepositories() async throws -> [RepoSnapshot] {
        let data = try await request("https://api.github.com/user/repos?per_page=100&sort=updated")
        let items = try JSONDecoder.github.decode([RepoDTO].self, from: data)
        return items.map { RepoSnapshot(id: $0.id, name: $0.name, fullName: $0.full_name, isPrivate: $0.private, defaultBranch: $0.default_branch, htmlURL: $0.html_url, openIssues: $0.open_issues_count, updatedAt: $0.updated_at) }
    }

    func fetchOpenPullRequests() async throws -> [PullRequestSnapshot] {
        let data = try await request("https://api.github.com/search/issues?q=user:acciento89-bot+is:pr+is:open&per_page=100")
        let response = try JSONDecoder.github.decode(SearchResponse.self, from: data)
        return response.items.map { item in
            PullRequestSnapshot(id: item.id, number: item.number, title: item.title, repository: item.repository_url.split(separator: "/").suffix(2).joined(separator: "/"), state: item.state, htmlURL: item.html_url, draft: item.draft ?? false, updatedAt: item.updated_at)
        }
    }

    func fetchOpenIssues() async throws -> [IssueSnapshot] {
        let data = try await request("https://api.github.com/search/issues?q=user:acciento89-bot+is:issue+is:open&per_page=100")
        let response = try JSONDecoder.github.decode(SearchResponse.self, from: data)
        return response.items.map { item in
            IssueSnapshot(id: item.id, number: item.number, title: item.title, repository: item.repository_url.split(separator: "/").suffix(2).joined(separator: "/"), htmlURL: item.html_url, updatedAt: item.updated_at)
        }
    }

    private func request(_ urlString: String) async throws -> Data {
        guard let token = KeychainStore.githubToken, !token.isEmpty else { throw ServiceError.missingToken }
        guard let url = URL(string: urlString) else { throw ServiceError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw ServiceError.invalidResponse }
        return data
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

private struct SearchResponse: Decodable { let items: [SearchItem] }
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

extension JSONDecoder {
    static var github: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum KeychainStore {
    private static let service = "com.kamilunavo.NavoOps"
    private static let account = "github-token"

    static var githubToken: String? {
        get {
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
            var item: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
            SecItemDelete(base as CFDictionary)
            guard let newValue, let data = newValue.data(using: .utf8), !newValue.isEmpty else { return }
            var add = base
            add[kSecValueData as String] = data
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}
