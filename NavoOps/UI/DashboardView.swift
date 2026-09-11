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
                        MetricCard(title: L10n.t("Buildfehler", "Build failures"), value: "\(model.buildFailureCount)", icon: "xmark.octagon.fill", tint: model.buildFailureCount > 0 ? NavoTheme.danger : NavoTheme.success)
                    }

                    operationalPulse

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
            .refreshable { await model.refreshGitHub() }
        }
        .navigationTitle("NavoOps")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.refreshGitHub() }
                } label: {
                    if model.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(model.isRefreshing)
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
                Text(L10n.t("Operations Control Center", "Operations Control Center"))
                    .font(.title2.bold())
                if let date = model.lastRefresh {
                    Text(L10n.t("Synchronisiert ", "Synced ") + date.formatted(date: .omitted, time: .shortened))
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

    private var operationalPulse: some View {
        let hasFailure = model.buildFailureCount > 0
        let hasAttention = model.attentionCount > 0
        let tint = hasFailure ? NavoTheme.danger : (hasAttention ? NavoTheme.warning : NavoTheme.success)
        let title = hasFailure
            ? L10n.t("Buildfehler erkannt", "Build failures detected")
            : (hasAttention ? L10n.t("Release-Arbeit offen", "Release work pending") : L10n.t("Systemlage stabil", "Operations stable"))
        let detail = hasFailure
            ? L10n.t("Mindestens ein beobachtetes Repository hat einen fehlgeschlagenen GitHub-Actions-Lauf.", "At least one tracked repository has a failed GitHub Actions run.")
            : L10n.t("\(model.attentionCount) Produkte benötigen aktuell manuelle Aufmerksamkeit.", "\(model.attentionCount) products currently need manual attention.")

        return HStack(spacing: 14) {
            Image(systemName: hasFailure ? "bolt.trianglebadge.exclamationmark.fill" : "waveform.path.ecg")
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

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: L10n.t("Aktivität", "Activity"),
                subtitle: L10n.t("Neueste Builds, Pull Requests und Issues", "Latest builds, pull requests and issues")
            )

            if model.activities.isEmpty {
                ContentUnavailableView(
                    L10n.t("Noch keine GitHub-Aktivität", "No GitHub activity yet"),
                    systemImage: "bolt.horizontal.circle",
                    description: Text(L10n.t("Hinterlege einen GitHub-Token und synchronisiere NavoOps.", "Add a GitHub token and sync NavoOps."))
                )
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
