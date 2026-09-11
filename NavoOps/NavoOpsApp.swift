import SwiftUI

@main
@MainActor
struct NavoOpsApp: App {
    @StateObject private var appModel = AppModel()
    @StateObject private var security = SecurityService()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BackgroundSyncService.shared.register()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if security.lockEnabled && !security.isUnlocked {
                    LockScreenView()
                } else {
                    RootView()
                }
            }
            .environmentObject(appModel)
            .environmentObject(security)
            .preferredColorScheme(.dark)
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .background:
                    security.lock()
                    BackgroundSyncService.shared.schedule()
                case .active, .inactive:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}
