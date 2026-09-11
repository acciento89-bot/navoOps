import Foundation

struct StoreStatusService: Sendable {
    enum ServiceError: LocalizedError {
        case missingToken
        case invalidResponse(Int)
        case invalidPayload

        var errorDescription: String? {
            switch self {
            case .missingToken:
                return L10n.t("GitHub-Token fehlt. Store-Sync benötigt Zugriff auf die Kamilunavo-Bridge.", "GitHub token is missing. Store sync requires access to the Kamilunavo bridge.")
            case .invalidResponse(let status):
                return L10n.t("Store-Bridge antwortete mit HTTP \(status).", "Store bridge returned HTTP \(status).")
            case .invalidPayload:
                return L10n.t("Store-Status konnte nicht gelesen werden.", "Store status could not be decoded.")
            }
        }
    }

    private let owner = "acciento89-bot"
    private let bridgeRepository = "onemorefloor"
    private let feedPath = "generated/navoops/store-status.json"
    private let workflowFile = "navoops-store-feed.yml"

    func fetchFeed() async throws -> StoreStatusFeed {
        guard let token = KeychainStore.githubToken, !token.isEmpty else { throw ServiceError.missingToken }

        var components = URLComponents(string: "https://api.github.com/repos/\(owner)/\(bridgeRepository)/contents/\(feedPath)")!
        components.queryItems = [URLQueryItem(name: "ref", value: "main")]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse(-1) }
        guard 200..<300 ~= http.statusCode else { throw ServiceError.invalidResponse(http.statusCode) }

        let envelope = try JSONDecoder().decode(GitHubContentEnvelope.self, from: data)
        let compact = envelope.content.replacingOccurrences(of: "\n", with: "")
        guard envelope.encoding == "base64", let decoded = Data(base64Encoded: compact) else {
            throw ServiceError.invalidPayload
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(StoreStatusFeed.self, from: decoded)
        } catch {
            throw ServiceError.invalidPayload
        }
    }

    func requestBridgeRefresh() async throws {
        guard let token = KeychainStore.githubToken, !token.isEmpty else { throw ServiceError.missingToken }
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(bridgeRepository)/actions/workflows/\(workflowFile)/dispatches")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.httpBody = try JSONEncoder().encode(DispatchPayload(ref: "main"))

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse(-1) }
        guard http.statusCode == 204 else { throw ServiceError.invalidResponse(http.statusCode) }
    }
}

private struct GitHubContentEnvelope: Decodable {
    let content: String
    let encoding: String
}

private struct DispatchPayload: Encodable {
    let ref: String
}
