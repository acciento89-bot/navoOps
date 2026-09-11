import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject private var security: SecurityService

    var body: some View {
        ZStack {
            NavoTheme.background.ignoresSafeArea()

            VStack(spacing: 22) {
                NavoLogoMark(size: 86)
                VStack(spacing: 7) {
                    Text("NavoOps")
                        .font(.largeTitle.bold())
                    Text(L10n.t("Kamilunavo Operations ist gesperrt", "Kamilunavo Operations is locked"))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await security.authenticate() }
                } label: {
                    Label(L10n.t("Entsperren", "Unlock"), systemImage: "faceid")
                        .font(.headline)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 13)
                        .background(NavoTheme.brandGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                if let error = security.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(NavoTheme.warning)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
            }
            .padding(30)
        }
    }
}
