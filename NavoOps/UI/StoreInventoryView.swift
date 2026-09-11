import SwiftUI

struct StoreInventoryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var provider: StoreProvider?

    private var snapshots: [StoreAppSnapshot] {
        guard let provider else { return model.storeInventory }
        return model.storeInventory.filter { $0.provider == provider }
    }

    var body: some View {
        ZStack {
            NavoTheme.background.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 12) {
                    sourceSummary

                    Picker(L10n.t("Store", "Store"), selection: $provider) {
                        Text(L10n.t("Alle", "All")).tag(StoreProvider?.none)
                        Text("Apple").tag(StoreProvider?.some(.apple))
                        Text("Google Play").tag(StoreProvider?.some(.google))
                    }
                    .pickerStyle(.segmented)

                    if snapshots.isEmpty {
                        ContentUnavailableView {
                            Label(L10n.t("Keine Live-Daten", "No live data"), systemImage: "point.3.filled.connected.trianglepath.dotted")
                        } description: {
                            Text(L10n.t("Für diesen Store ist noch kein Snapshot verfügbar.", "No snapshot is available for this store yet."))
                        }
                        .frame(minHeight: 260)
                        .navoCard()
                    } else {
                        ForEach(snapshots) { snapshot in
                            snapshotCard(snapshot)
                        }
                    }
                }
                .padding()
            }
            .refreshable { await model.refreshStores() }
        }
        .navigationTitle(L10n.t("Store Inventar", "Store Inventory"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.refreshStores() }
                } label: {
                    if model.isRefreshingStores { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                }
                .disabled(model.isRefreshingStores)
            }
        }
    }

    private var sourceSummary: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t("Store-Snapshot", "Store snapshot"))
                    .font(.headline)
                Text(L10n.t("\(model.storeInventory.count) Einträge · \(model.untrackedStoreApps.count) noch nicht im NavoOps-Portfolio", "\(model.storeInventory.count) entries · \(model.untrackedStoreApps.count) not yet tracked in NavoOps"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let date = model.storeGeneratedAt {
                Text(date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .navoCard()
    }

    @ViewBuilder
    private func snapshotCard(_ snapshot: StoreAppSnapshot) -> some View {
        if let product = model.product(matching: snapshot) {
            NavigationLink(value: product.id) {
                card(snapshot, tracked: true)
            }
            .buttonStyle(.plain)
        } else {
            card(snapshot, tracked: false)
        }
    }

    private func card(_ snapshot: StoreAppSnapshot, tracked: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: snapshot.provider == .apple ? "apple.logo" : "play.rectangle.fill")
                .font(.headline)
                .foregroundStyle(snapshot.provider == .apple ? .primary : NavoTheme.cyan)
                .frame(width: 40, height: 40)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(snapshot.appName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(tracked ? L10n.t("GETRACKT", "TRACKED") : L10n.t("NEU", "NEW"))
                        .font(.caption2.weight(.black))
                        .foregroundStyle(tracked ? NavoTheme.success : NavoTheme.warning)
                }

                if let id = snapshot.bundleOrPackageID {
                    Text(id)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    StoreStateBadge(label: snapshot.provider.title, state: snapshot.state.productState)
                    if let version = snapshot.version {
                        Text("v\(version)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if let build = snapshot.build {
                        Text("#\(build)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                Text(snapshot.rawState)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .navoCard(padding: 13)
    }
}
