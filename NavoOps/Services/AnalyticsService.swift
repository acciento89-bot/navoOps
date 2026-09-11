import Foundation

struct AnalyticsService: Sendable {
    enum ServiceError: LocalizedError {
        case missingToken
        case invalidResponse(Int)
        case invalidPayload
        case allBridgesUnavailable

        var errorDescription: String? {
            switch self {
            case .missingToken:
                return L10n.t("GitHub-Token fehlt. Analytics benötigt Zugriff auf die Kamilunavo-Bridge.", "GitHub token is missing. Analytics requires access to the Kamilunavo bridge.")
            case .invalidResponse(let status):
                return L10n.t("Analytics-Bridge antwortete mit HTTP \(status).", "Analytics bridge returned HTTP \(status).")
            case .invalidPayload:
                return L10n.t("Analytics-Daten konnten nicht gelesen werden.", "Analytics data could not be decoded.")
            case .allBridgesUnavailable:
                return L10n.t("Noch keine Analytics-Bridge verfügbar.", "No analytics bridge is available yet.")
            }
        }
    }

    private struct Bridge: Sendable {
        let repository: String
        let feedPath: String
        let workflowFile: String
    }

    private let owner = "acciento89-bot"
    private let appleBridge = Bridge(
        repository: "onemorefloor",
        feedPath: "generated/navoops/apple-analytics.json",
        workflowFile: "navoops-store-feed.yml"
    )
    private let googleBridge = Bridge(
        repository: "maengelfix",
        feedPath: "generated/navoops/google-analytics.json",
        workflowFile: "navoops-google-store-feed.yml"
    )

    func fetchFeed() async throws -> AnalyticsFeed {
        guard let token = KeychainStore.githubToken, !token.isEmpty else { throw ServiceError.missingToken }

        async let appleTask: AnalyticsFeed? = try? fetch(appleBridge, token: token)
        async let googleTask: AnalyticsFeed? = try? fetch(googleBridge, token: token)
        let (apple, google) = await (appleTask, googleTask)

        let feeds = [apple, google].compactMap { $0 }
        guard !feeds.isEmpty else { throw ServiceError.allBridgesUnavailable }

        let apps = Dictionary(
            feeds.flatMap(\.apps).map { ($0.id, $0) },
            uniquingKeysWith: { _, newest in newest }
        ).values.sorted {
            if $0.provider != $1.provider { return $0.provider.rawValue < $1.provider.rawValue }
            return $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
        }

        return AnalyticsFeed(
            schemaVersion: feeds.map(\.schemaVersion).max() ?? 1,
            generatedAt: feeds.map(\.generatedAt).max() ?? .now,
            sourceRepository: feeds.compactMap(\.sourceRepository).joined(separator: ", "),
            appleAvailable: apple?.appleAvailable == true,
            googleAvailable: google?.googleAvailable == true,
            commercialAvailable: feeds.contains(where: \.commercialAvailable),
            reliabilityAvailable: feeds.contains(where: \.reliabilityAvailable),
            apps: apps,
            notes: feeds.flatMap(\.notes),
            appleGeneratedAt: apple?.generatedAt,
            googleGeneratedAt: google?.generatedAt
        )
    }

    func requestRefresh() async throws {
        guard let token = KeychainStore.githubToken, !token.isEmpty else { throw ServiceError.missingToken }
        async let apple = dispatchSafely(appleBridge, token: token)
        async let google = dispatchSafely(googleBridge, token: token)
        let (appleOK, googleOK) = await (apple, google)
        guard appleOK || googleOK else { throw ServiceError.allBridgesUnavailable }
    }

    private func fetch(_ bridge: Bridge, token: String) async throws -> AnalyticsFeed {
        var components = URLComponents(string: "https://api.github.com/repos/\(owner)/\(bridge.repository)/contents/\(bridge.feedPath)")!
        components.queryItems = [URLQueryItem(name: "ref", value: "main")]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse(-1) }
        guard 200..<300 ~= http.statusCode else { throw ServiceError.invalidResponse(http.statusCode) }

        let envelope = try JSONDecoder().decode(AnalyticsGitHubEnvelope.self, from: data)
        let compact = envelope.content.replacingOccurrences(of: "\n", with: "")
        guard envelope.encoding == "base64", let decoded = Data(base64Encoded: compact) else {
            throw ServiceError.invalidPayload
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let feed = try? decoder.decode(AnalyticsFeed.self, from: decoded) else {
            throw ServiceError.invalidPayload
        }
        return feed
    }

    private func dispatchSafely(_ bridge: Bridge, token: String) async -> Bool {
        do {
            try await dispatch(bridge, token: token)
            return true
        } catch {
            return false
        }
    }

    private func dispatch(_ bridge: Bridge, token: String) async throws {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(bridge.repository)/actions/workflows/\(bridge.workflowFile)/dispatches")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.httpBody = try JSONEncoder().encode(AnalyticsDispatchPayload(ref: "main"))

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse(-1) }
        guard http.statusCode == 204 else { throw ServiceError.invalidResponse(http.statusCode) }
    }
}

private struct AnalyticsGitHubEnvelope: Decodable {
    let content: String
    let encoding: String
}

private struct AnalyticsDispatchPayload: Encodable {
    let ref: String
}
