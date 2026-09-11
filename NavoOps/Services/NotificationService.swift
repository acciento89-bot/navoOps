import Foundation
import UserNotifications

actor NotificationService {
    static let shared = NotificationService()

    private let stateKey = "navoops.notifications.workflow-state.v1"

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
        let previous = loadPreviousStates()
        var current: [String: String] = [:]

        for (repository, item) in health {
            current[repository] = item.buildState.rawValue
            guard item.buildState == .failure, previous[repository] != RepositoryHealth.BuildState.failure.rawValue else { continue }
            await sendBuildFailure(repository: repository, workflowName: item.workflowName)
        }

        saveStates(current)
    }

    private func sendBuildFailure(repository: String, workflowName: String?) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "NavoOps · Build failed"
        content.body = workflowName.map { "\(repository): \($0)" } ?? repository
        content.sound = .default
        content.threadIdentifier = "navoops-builds"

        let request = UNNotificationRequest(
            identifier: "build-failure-\(repository)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func loadPreviousStates() -> [String: String] {
        guard
            let data = UserDefaults.standard.data(forKey: stateKey),
            let states = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return states
    }

    private func saveStates(_ states: [String: String]) {
        guard let data = try? JSONEncoder().encode(states) else { return }
        UserDefaults.standard.set(data, forKey: stateKey)
    }
}
