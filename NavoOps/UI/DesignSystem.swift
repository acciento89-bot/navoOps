import SwiftUI

enum NavoTheme {
    static let background = Color(red: 0.025, green: 0.035, blue: 0.055)
    static let surface = Color(red: 0.065, green: 0.085, blue: 0.125)
    static let elevated = Color(red: 0.09, green: 0.115, blue: 0.165)
    static let accent = Color(red: 0.12, green: 0.55, blue: 1.0)
    static let cyan = Color(red: 0.12, green: 0.84, blue: 0.96)
    static let success = Color(red: 0.23, green: 0.82, blue: 0.49)
    static let warning = Color(red: 1.0, green: 0.67, blue: 0.2)
    static let danger = Color(red: 1.0, green: 0.31, blue: 0.38)

    static let brandGradient = LinearGradient(
        colors: [accent, cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension View {
    func navoCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(NavoTheme.surface.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
    }
}

extension ProductApp.StoreState {
    var color: Color {
        switch self {
        case .live: return NavoTheme.success
        case .review, .internalTest: return NavoTheme.accent
        case .attention: return NavoTheme.warning
        case .development: return .secondary
        }
    }

    var systemImage: String {
        switch self {
        case .development: return "hammer.fill"
        case .internalTest: return "testtube.2"
        case .review: return "hourglass"
        case .live: return "checkmark.seal.fill"
        case .attention: return "exclamationmark.triangle.fill"
        }
    }
}

extension RepositoryHealth.BuildState {
    var color: Color {
        switch self {
        case .success: return NavoTheme.success
        case .failure: return NavoTheme.danger
        case .running: return NavoTheme.accent
        case .unknown: return .secondary
        }
    }

    var title: String {
        switch self {
        case .success: return L10n.t("Grün", "Passing")
        case .failure: return L10n.t("Fehlgeschlagen", "Failed")
        case .running: return L10n.t("Läuft", "Running")
        case .unknown: return L10n.t("Unbekannt", "Unknown")
        }
    }

    var systemImage: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.octagon.fill"
        case .running: return "arrow.triangle.2.circlepath"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

extension ActivityItem.Tone {
    var color: Color {
        switch self {
        case .success: return NavoTheme.success
        case .warning: return NavoTheme.warning
        case .danger: return NavoTheme.danger
        case .info: return NavoTheme.accent
        }
    }
}

struct NavoLogoMark: View {
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(NavoTheme.brandGradient)
            Text("K")
                .font(.system(size: size * 0.54, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: NavoTheme.accent.opacity(0.35), radius: size * 0.22, y: size * 0.08)
        .accessibilityHidden(true)
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title3.bold())
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    var tint: Color = NavoTheme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Spacer()
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .navoCard()
    }
}

struct StoreStateBadge: View {
    let label: String
    let state: ProductApp.StoreState

    var body: some View {
        Label("\(label) · \(state.localizedTitle)", systemImage: state.systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(state.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(state.color.opacity(0.11), in: Capsule())
    }
}

struct BuildBadge: View {
    let state: RepositoryHealth.BuildState

    var body: some View {
        Label(state.title, systemImage: state.systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(state.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(state.color.opacity(0.11), in: Capsule())
    }
}

struct ReadinessBar: View {
    let label: String
    let completed: Int
    let total: Int
    var tint: Color = NavoTheme.accent

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(completed)/\(total)")
                    .font(.caption.monospacedDigit().weight(.bold))
            }
            ProgressView(value: fraction)
                .tint(fraction >= 1 ? NavoTheme.success : tint)
        }
    }
}

struct ProductCard: View {
    let product: ProductApp
    var health: RepositoryHealth?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(NavoTheme.brandGradient)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(String(product.name.prefix(1)))
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(.headline)
                    Text(product.repository)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let health {
                    Image(systemName: health.buildState.systemImage)
                        .foregroundStyle(health.buildState.color)
                }
            }

            HStack(spacing: 8) {
                if product.supportsApple {
                    StoreStateBadge(label: "Apple", state: product.appleState)
                }
                if product.supportsGoogle {
                    StoreStateBadge(label: "Google", state: product.googleState)
                }
            }

            HStack {
                Label("v\(product.version) (\(product.build))", systemImage: "shippingbox.fill")
                Spacer()
                Text(product.monetization.localizedTitle)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .navoCard()
    }
}
