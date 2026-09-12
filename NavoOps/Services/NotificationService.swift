import Foundation
import UserNotifications

actor NotificationService {
    static let shared = NotificationService()

    private let workflowStateKey = "navoops.notifications.workflow-state.v1"
    private let storeStateKey = "navoops.notifications.store-state.v1"

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func processWorkflowHealth(_ health: [String: RepositoryHealth]) async {
        let previous = loadPreviousStates(key: workflowStateKey)
        var current: [String: String] = [:]

        for (repository, item) in health {
            current[repository] = item.buildState.rawValue
            guard item.buildState == .failure, previous[repository] != RepositoryHealth.BuildState.failure.rawValue else { continue }
            await send(
                title: "NavoOps · Build failed",
                body: item.workflowName.map { "\(repository): \($0)" } ?? repository,
                thread: "navoops-builds",
                identifierPrefix: "build-failure"
            )
        }

        saveStates(current, key: workflowStateKey)
    }

    func processStoreFeed(_ feed: StoreStatusFeed) async {
        let previous = loadPreviousStates(key: storeStateKey)
        var current: [String: String] = [:]

        for app in feed.apps {
            let fingerprint = storeFingerprint(app)
            current[app.id] = fingerprint

            guard let old = previous[app.id] else { continue }

            // Migrate the old coarse state-only cache without firing a notification
            // for every app on the first run of the richer review model.
            if old == app.state.rawValue {
                continue
            }

            guard old != fingerprint else { continue }

            switch app.state {
            case .rejected, .attention:
                await send(
                    title: "NavoOps · \(app.provider.title)",
                    body: L10n.t(
                        "\(app.appName) benötigt deine Aufmerksamkeit: \(reviewDetail(app))",
                        "\(app.appName) needs attention: \(reviewDetail(app))"
                    ),
                    thread: "navoops-stores",
                    identifierPrefix: "store-attention"
                )
            case .live:
                let version = app.version.map { " v\($0)" } ?? ""
                await send(
                    title: "NavoOps · \(app.provider.title)",
                    body: L10n.t("\(app.appName)\(version) ist jetzt live.", "\(app.appName)\(version) is now live."),
                    thread: "navoops-stores",
                    identifierPrefix: "store-live"
                )
            case .review:
                await send(
                    title: "NavoOps · \(app.provider.title)",
                    body: L10n.t(
                        "\(app.appName): \(reviewDetail(app))",
                        "\(app.appName): \(reviewDetail(app))"
                    ),
                    thread: "navoops-stores",
                    identifierPrefix: "store-review"
                )
            case .processing:
                await send(
                    title: "NavoOps · \(app.provider.title)",
                    body: L10n.t(
                        "\(app.appName) wird verarbeitet: \(reviewDetail(app))",
                        "\(app.appName) is processing: \(reviewDetail(app))"
                    ),
                    thread: "navoops-stores",
                    identifierPrefix: "store-processing"
                )
            default:
                break
            }
        }

        saveStates(current, key: storeStateKey)
    }

    private func storeFingerprint(_ app: StoreAppSnapshot) -> String {
        let reviewState = app.review?.displayState ?? ""
        let itemStates = app.review?.itemStates.sorted().joined(separator: ",") ?? ""
        return [app.state.rawValue, app.rawState, reviewState, itemStates].joined(separator: "|")
    }

    private func reviewDetail(_ app: StoreAppSnapshot) -> String {
        if let detail = app.detail, !detail.isEmpty { return detail }
        if let state = app.review?.displayState, !state.isEmpty { return state }
        return app.rawState
    }

    private func send(title: String, body: String, thread: String, identifierPrefix: String) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = thread

        let request = UNNotificationRequest(
            identifier: "\(identifierPrefix)-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func loadPreviousStates(key: String) -> [String: String] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let states = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return states
    }

    private func saveStates(_ states: [String: String], key: String) {
        guard let data = try? JSONEncoder().encode(states) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
