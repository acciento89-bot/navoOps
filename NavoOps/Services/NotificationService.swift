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
            current[app.id] = app.state.rawValue
            guard let old = previous[app.id], old != app.state.rawValue else { continue }

            switch app.state {
            case .rejected, .attention:
                await send(
                    title: "NavoOps · \(app.provider.title)",
                    body: L10n.t("\(app.appName) benötigt deine Aufmerksamkeit: \(app.detail ?? app.rawState)", "\(app.appName) needs attention: \(app.detail ?? app.rawState)"),
                    thread: "navoops-stores",
                    identifierPrefix: "store-attention"
                )
            case .live:
                await send(
                    title: "NavoOps · \(app.provider.title)",
                    body: L10n.t("\(app.appName) ist jetzt live.", "\(app.appName) is now live."),
                    thread: "navoops-stores",
                    identifierPrefix: "store-live"
                )
            case .review:
                await send(
                    title: "NavoOps · \(app.provider.title)",
                    body: L10n.t("\(app.appName) ist jetzt in Prüfung.", "\(app.appName) is now in review."),
                    thread: "navoops-stores",
                    identifierPrefix: "store-review"
                )
            default:
                break
            }
        }

        saveStates(current, key: storeStateKey)
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
