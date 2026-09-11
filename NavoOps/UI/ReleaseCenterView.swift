import SwiftUI

struct ReleaseCenterView: View {
    @EnvironmentObject private var model: AppModel
    @State private var filter: Filter = .all

    enum Filter: CaseIterable, Hashable {
        case all
        case attention
        case review
        case live

        var title: String {
            switch self {
            case .all: return L10n.t("Alle", "All")
            case .attention: return L10n.t("Offen", "Attention")
            case .review: return L10n.t("Prüfung", "Review")
            case .live: return "Live"
            }
        }
    }

    private var filteredProducts: [ProductApp] {
        switch filter {
        case .all: return model.products
        case .attention: return model.products.filter(\.needsAttention)
        case .review: return model.products.filter(\.isInReview)
        case .live: return model.products.filter(\.isFullyLive)
        }
    }

    var body: some View {
        ZStack {
            NavoTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    Picker(L10n.t("Filter", "Filter"), selection: $filter) {
                        ForEach(Filter.allCases, id: \.self) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    ForEach(filteredProducts) { product in
                        NavigationLink(value: product.id) {
                            releaseCard(product)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .refreshable { await model.refreshGitHub() }
        }
        .navigationTitle(L10n.t("Release Center", "Release Center"))
    }

    private func releaseCard(_ product: ProductApp) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name).font(.headline)
                    Text("v\(product.version) · Build \(product.build)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let health = model.health(for: product) {
                    BuildBadge(state: health.buildState)
                }
            }

            HStack(spacing: 8) {
                if product.supportsApple { StoreStateBadge(label: "Apple", state: product.appleState) }
                if product.supportsGoogle { StoreStateBadge(label: "Google", state: product.googleState) }
            }

            if product.supportsApple {
                ReadinessBar(label: "Apple", completed: product.checklist.appleCompleted, total: product.checklist.appleTotal)
            }
            if product.supportsGoogle {
                ReadinessBar(label: "Google Play", completed: product.checklist.googleCompleted, total: product.checklist.googleTotal, tint: NavoTheme.cyan)
            }

            if !product.notes.isEmpty {
                Label(product.notes, systemImage: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .navoCard()
    }
}
