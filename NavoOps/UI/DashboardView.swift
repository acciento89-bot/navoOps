import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 145), spacing: 12)]
    }

    var body: some View {
        ZStack {
            NavoTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    LazyVGrid(columns: metricColumns, spacing: 12) {
                        MetricCard(title: L10n.t("Produkte", "Products"), value: "\(model.products.count)", icon: "square.stack.3d.up.fill")
                        MetricCard(title: L10n.t("Komplett live", "Fully live"), value: "\(model.fullyLiveCount)", icon: "checkmark.seal.fill", tint: NavoTheme.success)
                        MetricCard(title: L10n.t("In Prüfung", "In review"), value: "\(model.reviewCount)", icon: "hourglass")
                        MetricCard(title: L10n.t("Ops Inbox", "Ops inbox"), value: "\(model.operationsInbox.count)", icon: "tray.full.fill", tint: model.operationsInbox.isEmpty ? NavoTheme.success : NavoTheme.warning)
                        MetricCard(title: L10n.t("Buildfehler", "Build failures"), value: "\(model.buildFailureCount)", icon: "xmark.octagon.fill", tint: model.buildFailureCount > 0 ? NavoTheme.danger : NavoTheme.success)
                    }

                    storePulse
                    operationalPulse
                    inboxPreview

                    if !model.attentionProducts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(
                                title: L10n.t("Handlungsbedarf", "Needs attention"),
                                subtitle: L10n.t("Produkte mit offenen Release- oder Store-Problemen", "Products with unresolved release or store issues")
                            )

                            ForEach(model.attentionProducts) { product in
                                NavigationLink(value: product.id) {
                                    ProductCard(product: product, health: model.health(for: product))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    activitySection
                }
                .padding(.horizontal)
                .padding(.bottom, 28)
            }
            .refreshable { await model.refreshAll() }
        }
        .navigationTitle("NavoOps")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.refreshAll() }
                } label: {
                    if model.isRefreshing || model.isRefreshingStores {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(model.isRefreshing || model.isRefreshingStores)
                .accessibilityLabel(L10n.t("Synchronisieren", "Sync"))
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            NavoLogoMark(size: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text("KAMILUNAVO")
                    .font(.caption.weight(.black))
                    .tracking(1.5)
                    .foregroundStyle(NavoTheme.accent)
                Text("Operations Control Center")
                    .font(.title2.bold())
                if let date = model.lastRefresh {
                    Text(L10n.t("GitHub synchronisiert ", "GitHub synced ") + date.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.t("Portfolio, Stores und GitHub an einem Ort", "Portfolio, stores and GitHub in one place"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    private var storePulse: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("Live Store Sync", "Live Store Sync"))
                        .font(.headline)
                    if let generatedAt = model.storeGeneratedAt {
                        Text(L10n.t("Bridge-Stand: ", "Bridge snapshot: ") + generatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(L10n.t("Noch kein Store-Snapshot geladen", "No store snapshot loaded yet"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.title2)
                    .foregroundStyle(NavoTheme.accent)
            }

            HStack(spacing: 8) {
                sourceBadge(title: "Apple", available: model.appleLiveAvailable)
                sourceBadge(title: "Google Play", available: model.googleLiveAvailable)
            }

            if let error = model.storeErrorMessage, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(NavoTheme.warning)
            }
        }
        .navoCard()
    }

    private func sourceBadge(title: String, available: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(available ? NavoTheme.success : NavoTheme.warning)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.semibold))
            Text(available ? "LIVE" : L10n.t("NICHT VERBUNDEN", "NOT CONNECTED"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: Capsule())
    }

    private var operationalPulse: some View {
        let hasFailure = model.buildFailureCount > 0
        let hasCritical = model.operationsInbox.contains { $0.priority == .critical }
        let hasAttention = model.attentionCount > 0
        let tint = (hasFailure || hasCritical) ? NavoTheme.danger : (hasAttention ? NavoTheme.warning : NavoTheme.success)
        let title = hasFailure
            ? L10n.t("Buildfehler erkannt", "Build failures detected")
            : (hasCritical ? L10n.t("Store-Aktion erforderlich", "Store action required") : (hasAttention ? L10n.t("Release-Arbeit offen", "Release work pending") : L10n.t("Systemlage stabil", "Operations stable")))
        let detail = hasFailure
            ? L10n.t("Mindestens ein beobachtetes Repository hat einen fehlgeschlagenen GitHub-Actions-Lauf.", "At least one tracked repository has a failed GitHub Actions run.")
            : L10n.t("\(model.operationsInbox.count) Vorgänge befinden sich aktuell in der Operations Inbox.", "\(model.operationsInbox.count) items are currently in the Operations Inbox.")

        return HStack(spacing: 14) {
            Image(systemName: (hasFailure || hasCritical) ? "bolt.trianglebadge.exclamationmark.fill" : "waveform.path.ecg")
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .navoCard()
    }

    private var inboxPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionTitle(
                    title: L10n.t("Operations Inbox", "Operations Inbox"),
                    subtitle: L10n.t("Builds, Apple, Google Play und Releases priorisiert", "Builds, Apple, Google Play and releases prioritized")
                )
                Spacer()
                NavigationLink {
                    OperationsInboxView()
                } label: {
                    Text(L10n.t("Alle", "All"))
                        .font(.subheadline.weight(.semibold))
                }
            }

            if model.operationsInbox.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(NavoTheme.success)
                    Text(L10n.t("Keine offenen Vorgänge.", "No open operations."))
                        .font(.subheadline)
                    Spacer()
                }
                .navoCard(padding: 13)
            } else {
                ForEach(model.operationsInbox.prefix(4)) { item in
                    NavigationLink(value: item.productID ?? "") {
                        HStack(spacing: 12) {
                            Image(systemName: inboxIcon(item))
                                .foregroundStyle(item.priority == .critical ? NavoTheme.danger : NavoTheme.warning)
                                .frame(width: 34, height: 34)
                                .background((item.priority == .critical ? NavoTheme.danger : NavoTheme.warning).opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .navoCard(padding: 12)
                    }
                    .buttonStyle(.plain)
                    .disabled(item.productID == nil)
                }
            }
        }
    }

    private func inboxIcon(_ item: OperationsInboxItem) -> String {
        switch item.kind {
        case .build: return "hammer.fill"
        case .apple: return "apple.logo"
        case .google: return "play.rectangle.fill"
        case .release: return "shippingbox.fill"
        case .pullRequest: return "arrow.triangle.pull"
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: L10n.t("Aktivität", "Activity"),
                subtitle: L10n.t("Neueste Builds, Pull Requests und Issues", "Latest builds, pull requests and issues")
            )

            if model.activities.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text(L10n.t("Noch keine GitHub-Aktivität", "No GitHub activity yet"))
                    } icon: {
                        Image(systemName: "bolt.horizontal.circle")
                    }
                } description: {
                    Text(L10n.t("Hinterlege einen GitHub-Token und synchronisiere NavoOps.", "Add a GitHub token and sync NavoOps."))
                }
                .frame(minHeight: 180)
                .navoCard()
            } else {
                ForEach(model.activities.prefix(10)) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.headline)
                            .foregroundStyle(item.tone.color)
                            .frame(width: 38, height: 38)
                            .background(item.tone.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(item.date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .navoCard(padding: 13)
                }
            }
        }
    }
}
