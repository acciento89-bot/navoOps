import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var filter: InsightFilter = .all

    private enum InsightFilter: String, CaseIterable, Identifiable {
        case all
        case critical
        case action
        case warning
        case info

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return L10n.t("Alle", "All")
            case .critical: return L10n.t("Kritisch", "Critical")
            case .action: return L10n.t("Aktion", "Action")
            case .warning: return L10n.t("Hinweise", "Warnings")
            case .info: return L10n.t("Info", "Info")
            }
        }

        func includes(_ insight: OpsInsight) -> Bool {
            switch self {
            case .all: return true
            case .critical: return insight.severity == .critical
            case .action: return insight.severity == .action
            case .warning: return insight.severity == .warning
            case .info: return insight.severity == .info
            }
        }
    }

    private var filteredInsights: [OpsInsight] {
        model.opsInsights.filter(filter.includes)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 145), spacing: 12)]
    }

    var body: some View {
        ZStack {
            NavoTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    intelligenceHeader
                    scoreSection
                    coverageSection
                    prioritySection
                    paritySection
                    transitionsSection
                    repositorySection
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .refreshable { await model.refreshAll() }
        }
        .navigationTitle(L10n.t("Ops Intelligence", "Ops Intelligence"))
        .navigationBarTitleDisplayMode(.inline)
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
            }
        }
    }

    private var intelligenceHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(NavoTheme.brandGradient)
                Image(systemName: "brain.head.profile.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text("KAMILUNAVO INTELLIGENCE")
                    .font(.caption2.weight(.black))
                    .tracking(1.4)
                    .foregroundStyle(NavoTheme.accent)
                Text(L10n.t("Prioritäten statt Rohdaten", "Priorities instead of raw data"))
                    .font(.title3.bold())
                Text(L10n.t(
                    "Store-, Release- und GitHub-Signale werden zu konkreten nächsten Schritten verdichtet.",
                    "Store, release and GitHub signals are condensed into concrete next actions."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    private var scoreSection: some View {
        let metrics = model.intelligence
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: L10n.t("Portfolio-Lage", "Portfolio health"),
                subtitle: L10n.t("Deterministischer Ops-Score aus Store-, Build- und Readiness-Signalen", "Deterministic Ops score from store, build and readiness signals")
            )

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: CGFloat(metrics.score) / 100)
                        .stroke(scoreColor(metrics.score), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(metrics.score)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                        Text("OPS")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: 9) {
                    scoreLine(L10n.t("Kritisch", "Critical"), metrics.criticalCount, NavoTheme.danger)
                    scoreLine(L10n.t("Aktion", "Action"), metrics.actionCount, NavoTheme.warning)
                    scoreLine(L10n.t("Hinweise", "Warnings"), metrics.warningCount, NavoTheme.cyan)
                    scoreLine(L10n.t("Ohne offene Risiken", "Without open risks"), metrics.healthyCount, NavoTheme.success)
                }
                Spacer(minLength: 0)
            }
            .navoCard()

            LazyVGrid(columns: columns, spacing: 12) {
                MetricCard(title: L10n.t("Store-Parität", "Store parity"), value: "\(metrics.alignmentPercent)%", icon: "arrow.left.arrow.right.circle.fill", tint: metrics.alignmentPercent == 100 ? NavoTheme.success : NavoTheme.warning)
                MetricCard(title: L10n.t("Apple-Abdeckung", "Apple coverage"), value: "\(metrics.appleCoveragePercent)%", icon: "apple.logo", tint: metrics.appleCoveragePercent == 100 ? NavoTheme.success : NavoTheme.warning)
                MetricCard(title: L10n.t("Google-Abdeckung", "Google coverage"), value: "\(metrics.googleCoveragePercent)%", icon: "play.rectangle.fill", tint: metrics.googleCoveragePercent == 100 ? NavoTheme.success : NavoTheme.warning)
                MetricCard(title: L10n.t("CI grün", "CI passing"), value: "\(metrics.passingBuilds)", icon: "checkmark.circle.fill", tint: metrics.failedBuilds == 0 ? NavoTheme.success : NavoTheme.warning)
            }
        }
    }

    private var coverageSection: some View {
        let metrics = model.intelligence
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: L10n.t("Datenqualität", "Data quality"),
                subtitle: L10n.t("Abdeckung und Aktualität der Livequellen", "Coverage and freshness of live sources")
            )

            VStack(spacing: 14) {
                coverageRow(
                    title: "Apple",
                    value: "\(metrics.appleMatched)/\(metrics.appleExpected)",
                    fraction: metrics.appleExpected == 0 ? 1 : Double(metrics.appleMatched) / Double(metrics.appleExpected),
                    available: model.appleLiveAvailable
                )
                coverageRow(
                    title: "Google Play",
                    value: "\(metrics.googleMatched)/\(metrics.googleExpected)",
                    fraction: metrics.googleExpected == 0 ? 1 : Double(metrics.googleMatched) / Double(metrics.googleExpected),
                    available: model.googleLiveAvailable
                )

                Divider().overlay(Color.white.opacity(0.06))

                HStack {
                    Label(L10n.t("Store-Snapshot", "Store snapshot"), systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let date = model.storeGeneratedAt {
                        Text(date, style: .relative)
                            .font(.caption.monospacedDigit().weight(.semibold))
                    } else {
                        Text("–").foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
            }
            .navoCard()
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                SectionTitle(
                    title: L10n.t("Nächste Aktionen", "Next actions"),
                    subtitle: L10n.t("Automatisch priorisierte operative Einsichten", "Automatically prioritized operational insights")
                )
                Spacer()
                Text("\(filteredInsights.count)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Picker(L10n.t("Filter", "Filter"), selection: $filter) {
                ForEach(InsightFilter.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if filteredInsights.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(NavoTheme.success)
                    Text(L10n.t("Für diesen Filter gibt es keine offenen Signale.", "There are no open signals for this filter."))
                        .font(.subheadline)
                    Spacer()
                }
                .navoCard()
            } else {
                ForEach(filteredInsights.prefix(30)) { insight in
                    insightLink(insight)
                }
            }
        }
    }

    @ViewBuilder
    private func insightLink(_ insight: OpsInsight) -> some View {
        if let productID = insight.productID {
            NavigationLink(value: productID) {
                InsightCard(insight: insight)
            }
            .buttonStyle(.plain)
        } else {
            InsightCard(insight: insight)
        }
    }

    private var paritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: L10n.t("Plattform-Matrix", "Platform matrix"),
                subtitle: L10n.t("Apple und Google Play direkt nebeneinander", "Apple and Google Play side by side")
            )

            ForEach(model.productIntelligence.filter { $0.product.supportsApple && $0.product.supportsGoogle }) { snapshot in
                NavigationLink(value: snapshot.product.id) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snapshot.product.name)
                                    .font(.headline)
                                Text(snapshot.product.repository)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Label(
                                snapshot.isAligned ? L10n.t("Synchron", "Aligned") : L10n.t("Drift", "Drift"),
                                systemImage: snapshot.isAligned ? "checkmark.circle.fill" : "arrow.left.arrow.right.circle.fill"
                            )
                            .font(.caption.weight(.bold))
                            .foregroundStyle(snapshot.isAligned ? NavoTheme.success : NavoTheme.warning)
                        }

                        HStack(spacing: 8) {
                            StoreStateBadge(label: "Apple", state: model.resolvedAppleState(for: snapshot.product))
                            StoreStateBadge(label: "Google", state: model.resolvedGoogleState(for: snapshot.product))
                        }

                        HStack {
                            versionLabel("Apple", snapshot.apple?.version)
                            Spacer()
                            versionLabel("Google", snapshot.google?.version)
                        }

                        if snapshot.insightCount > 0 {
                            Text(L10n.t("\(snapshot.insightCount) operative Hinweise", "\(snapshot.insightCount) operational signals"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(NavoTheme.warning)
                        }
                    }
                    .navoCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var transitionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: L10n.t("Status-Verlauf", "Status history"),
                subtitle: L10n.t("Seit NavoOps 1.2 lokal beobachtete Store-Änderungen", "Store changes observed locally since NavoOps 1.2")
            )

            if model.recentStoreTransitions.isEmpty {
                Text(L10n.t(
                    "Noch keine Übergänge aufgezeichnet. Ab jetzt speichert NavoOps Status- und Versionswechsel lokal für bis zu 120 Tage.",
                    "No transitions recorded yet. NavoOps now stores status and version changes locally for up to 120 days."
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .navoCard()
            } else {
                ForEach(model.recentStoreTransitions.prefix(15)) { event in
                    HStack(spacing: 12) {
                        Image(systemName: event.provider == .apple ? "apple.logo" : "play.rectangle.fill")
                            .foregroundStyle(NavoTheme.accent)
                            .frame(width: 36, height: 36)
                            .background(NavoTheme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 11))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.productName)
                                .font(.subheadline.weight(.semibold))
                            Text(historyDetail(event))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(event.observedAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .navoCard(padding: 12)
                }
            }
        }
    }

    private var repositorySection: some View {
        let metrics = model.intelligence
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: L10n.t("Repository-Gesundheit", "Repository health"),
                subtitle: L10n.t("Letzter bekannter Actions-Zustand der beobachteten Repositories", "Latest known Actions state for tracked repositories")
            )

            HStack(spacing: 10) {
                repoPill(L10n.t("Grün", "Passing"), metrics.passingBuilds, NavoTheme.success)
                repoPill(L10n.t("Rot", "Failed"), metrics.failedBuilds, NavoTheme.danger)
                repoPill(L10n.t("Läuft", "Running"), metrics.runningBuilds, NavoTheme.accent)
                repoPill("?", metrics.unknownBuilds, .secondary)
            }
            .navoCard()
        }
    }

    private func scoreLine(_ title: String, _ value: Int, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.caption)
            Spacer()
            Text("\(value)").font(.caption.monospacedDigit().weight(.bold))
        }
    }

    private func coverageRow(title: String, value: String, fraction: Double, available: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                HStack(spacing: 7) {
                    Circle()
                        .fill(available ? NavoTheme.success : NavoTheme.danger)
                        .frame(width: 7, height: 7)
                    Text(title).font(.subheadline.weight(.semibold))
                }
                Spacer()
                Text(value).font(.caption.monospacedDigit().weight(.bold))
            }
            ProgressView(value: min(1, max(0, fraction)))
                .tint(fraction >= 1 ? NavoTheme.success : NavoTheme.warning)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 85 { return NavoTheme.success }
        if score >= 65 { return NavoTheme.warning }
        return NavoTheme.danger
    }

    private func versionLabel(_ title: String, _ version: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.tertiary)
            Text(model.semanticVersion(from: version) ?? version ?? "–")
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
        }
    }

    private func historyDetail(_ event: StoreHistoryEvent) -> String {
        if event.changedState, let previous = event.previousState {
            return "\(event.provider.title): \(previous.productState.localizedTitle) → \(event.state.productState.localizedTitle)"
        }
        if event.changedVersion {
            let old = model.semanticVersion(from: event.previousVersion) ?? event.previousVersion ?? "–"
            let new = model.semanticVersion(from: event.version) ?? event.version ?? "–"
            return "\(event.provider.title): \(old) → \(new)"
        }
        return "\(event.provider.title): \(event.state.productState.localizedTitle)"
    }

    private func repoPill(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3.monospacedDigit().bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct InsightCard: View {
    let insight: OpsInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: insight.kind.systemImage)
                    .font(.headline)
                    .foregroundStyle(insight.severity.color)
                    .frame(width: 38, height: 38)
                    .background(insight.severity.color.opacity(0.11), in: RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(insight.severity.title.uppercased())
                            .font(.caption2.weight(.black))
                            .foregroundStyle(insight.severity.color)
                        if let provider = insight.provider {
                            Text(provider.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(insight.title)
                        .font(.subheadline.weight(.bold))
                    Text(insight.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            }

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption)
                    .foregroundStyle(NavoTheme.accent)
                Text(insight.recommendation)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .navoCard(padding: 13)
    }
}

extension OpsInsight.Severity {
    var color: Color {
        switch self {
        case .critical: return NavoTheme.danger
        case .action: return NavoTheme.warning
        case .warning: return NavoTheme.cyan
        case .info: return NavoTheme.accent
        }
    }

    var title: String {
        switch self {
        case .critical: return L10n.t("Kritisch", "Critical")
        case .action: return L10n.t("Aktion", "Action")
        case .warning: return L10n.t("Hinweis", "Warning")
        case .info: return L10n.t("Info", "Info")
        }
    }
}

extension OpsInsight.Kind {
    var systemImage: String {
        switch self {
        case .build: return "hammer.fill"
        case .store: return "storefront.fill"
        case .parity: return "arrow.left.arrow.right.circle.fill"
        case .readiness: return "checklist"
        case .freshness: return "clock.badge.exclamationmark.fill"
        case .inventory: return "square.stack.3d.up.badge.a"
        case .github: return "point.3.connected.trianglepath.dotted"
        case .history: return "clock.arrow.circlepath"
        }
    }
}
