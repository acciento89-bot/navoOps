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
        case .all:
            return model.products
        case .attention:
            return model.attentionProducts
        case .review:
            return model.products.filter { product in
                (product.supportsApple && model.resolvedAppleState(for: product) == .review) ||
                (product.supportsGoogle && model.resolvedGoogleState(for: product) == .review)
            }
        case .live:
            return model.products.filter { product in
                let appleOK = !product.supportsApple || model.resolvedAppleState(for: product) == .live
                let googleOK = !product.supportsGoogle || model.resolvedGoogleState(for: product) == .live
                return appleOK && googleOK
            }
        }
    }

    private var reviewIssueCount: Int {
        model.storeFeed?.apps.filter {
            $0.state == .rejected || $0.state == .attention || $0.review?.requiresAction == true
        }.count ?? 0
    }

    private var activeReviewCount: Int {
        model.storeFeed?.apps.filter {
            $0.state == .review || $0.state == .processing
        }.count ?? 0
    }

    var body: some View {
        ZStack {
            NavoTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    storeSourceSummary
                    reviewCenterSummary

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
            .refreshable { await model.refreshAll() }
        }
        .navigationTitle(L10n.t("Release Center", "Release Center"))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    ReviewCenterView()
                } label: {
                    Image(systemName: "exclamationmark.bubble.fill")
                }
                .accessibilityLabel(L10n.t("Review Center", "Review Center"))

                NavigationLink {
                    StoreInventoryView()
                } label: {
                    Image(systemName: "storefront.fill")
                }
                .accessibilityLabel(L10n.t("Store Inventar", "Store Inventory"))
            }
        }
    }

    private var storeSourceSummary: some View {
        HStack(spacing: 12) {
            sourcePill("Apple", available: model.appleLiveAvailable)
            sourcePill("Google Play", available: model.googleLiveAvailable)
            Spacer()
            if !model.untrackedStoreApps.isEmpty {
                Text("+\(model.untrackedStoreApps.count)")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(NavoTheme.warning)
                    .accessibilityLabel(L10n.t("\(model.untrackedStoreApps.count) ungetrackte Store-Apps", "\(model.untrackedStoreApps.count) untracked store apps"))
            }
            if let date = model.storeGeneratedAt {
                Text(date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navoCard(padding: 12)
    }

    private var reviewCenterSummary: some View {
        NavigationLink {
            ReviewCenterView()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: reviewIssueCount > 0 ? "exclamationmark.bubble.fill" : "bubble.left.and.text.bubble.right.fill")
                    .font(.title3)
                    .foregroundStyle(reviewIssueCount > 0 ? NavoTheme.danger : NavoTheme.accent)
                    .frame(width: 42, height: 42)
                    .background((reviewIssueCount > 0 ? NavoTheme.danger : NavoTheme.accent).opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("Review Center", "Review Center"))
                        .font(.headline)
                    Text(L10n.t(
                        "\(reviewIssueCount) Probleme · \(activeReviewCount) in Prüfung",
                        "\(reviewIssueCount) issues · \(activeReviewCount) in review"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .navoCard(padding: 13)
        }
        .buttonStyle(.plain)
    }

    private func sourcePill(_ name: String, available: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(available ? NavoTheme.success : NavoTheme.warning)
                .frame(width: 7, height: 7)
            Text(name)
                .font(.caption.weight(.semibold))
            Text(available ? "LIVE" : L10n.t("LOKAL", "LOCAL"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }

    private func releaseCard(_ product: ProductApp) -> some View {
        let appleSnapshot = model.storeSnapshot(for: product, provider: .apple)
        let googleSnapshot = model.storeSnapshot(for: product, provider: .google)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name).font(.headline)
                    Text("v\(model.resolvedVersion(for: product)) · Build \(model.resolvedBuild(for: product))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let health = model.health(for: product) {
                    BuildBadge(state: health.buildState)
                }
            }

            HStack(spacing: 8) {
                if product.supportsApple {
                    StoreStateBadge(label: appleSnapshot == nil ? "Apple" : "Apple · Live", state: model.resolvedAppleState(for: product))
                }
                if product.supportsGoogle {
                    StoreStateBadge(label: googleSnapshot == nil ? "Google" : "Google · Live", state: model.resolvedGoogleState(for: product))
                }
            }

            if let appleSnapshot {
                storeDetail(snapshot: appleSnapshot)
            }
            if let googleSnapshot {
                storeDetail(snapshot: googleSnapshot)
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

    @ViewBuilder
    private func storeDetail(snapshot: StoreAppSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: snapshot.provider == .apple ? "apple.logo" : "play.rectangle.fill")
                    .foregroundStyle(.secondary)
                Text(snapshot.rawState)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if let updated = snapshot.updatedAt {
                    Text(updated, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if let reviewState = snapshot.review?.displayState {
                Label(reviewState, systemImage: snapshot.review?.requiresAction == true ? "exclamationmark.bubble.fill" : "bubble.left.and.text.bubble.right")
                    .font(.caption2.monospaced())
                    .foregroundStyle(snapshot.review?.requiresAction == true ? NavoTheme.danger : Color.secondary)
                    .lineLimit(2)
            }
        }
    }
}
