import Combine
import Foundation
import LocalAuthentication

@MainActor
final class SecurityService: ObservableObject {
    @Published private(set) var isUnlocked: Bool
    @Published private(set) var lockEnabled: Bool
    @Published var lastError: String?

    private let defaults = UserDefaults.standard
    private let lockKey = "navoops.security.device-lock.v1"

    init() {
        let enabled = defaults.bool(forKey: lockKey)
        lockEnabled = enabled
        isUnlocked = !enabled
    }

    var canUseDeviceAuthentication: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func setLockEnabled(_ enabled: Bool) async {
        if enabled {
            guard await authenticate() else { return }
            defaults.set(true, forKey: lockKey)
            lockEnabled = true
            isUnlocked = true
        } else {
            defaults.set(false, forKey: lockKey)
            lockEnabled = false
            isUnlocked = true
            lastError = nil
        }
    }

    func lock() {
        guard lockEnabled else { return }
        isUnlocked = false
    }

    @discardableResult
    func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = L10n.t("Abbrechen", "Cancel")

        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            lastError = policyError?.localizedDescription ?? L10n.t("Geräteauthentifizierung ist nicht verfügbar.", "Device authentication is unavailable.")
            return false
        }

        do {
            let reason = L10n.t("NavoOps und interne Kamilunavo-Daten entsperren.", "Unlock NavoOps and internal Kamilunavo data.")
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if success {
                isUnlocked = true
                lastError = nil
            }
            return success
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}
