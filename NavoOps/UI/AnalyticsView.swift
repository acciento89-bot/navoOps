import Charts
import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject private var model: AppModel

    private var summary: PortfolioAnalyticsSummary { model.portfolioAnalytics }
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var sortedEngineering: [RepositoryAnalytics] {
        model.repositoryAnalytics.values.sorted { lhs, rhs in
            if lhs.commitCount30d != rhs.commitCount30d { return lhs.commitCount30d > rhs.commitCount30d }
            return lhs.repository < rhs.repository
        }
    }

    var body: some View {
        ZStack {
            NavoTheme.background.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    header
                    overview
                    commercialSection
                    releaseSection
                    reliabilitySection
                    engineeringSection
                    trendSection
                    sourceSection
                }
                .padding()
            }
        }
        .navigationTitle(L10n.t("Analytics", "Analytics"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.refreshAll() }
                } label: {
                    if model.isRefreshing || model.isRefreshingStores || model.isRefreshingAnalytics {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.t("Business & Release Intelligence", "Business & Release Intelligence"), systemImage: "chart.line.uptrend.xyaxis")
                .font(.title2.bold())
            Text(L10n.t(
                "Kommerzielle Store-Daten, Release-Geschwindigkeit, Review-Zeiten, Zuverlässigkeit und GitHub-Engineering-Metriken in einer Ansicht.",
                "Commercial store data, release velocity, review timing, reliability and GitHub engineering metrics in one view."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var overview: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            MetricCard(title: L10n.t("Releases · 30 Tage", "Releases · 30 days"), value: "\(summary.releases30d)", icon: "shippingbox.fill", tint: NavoTheme.success)
            MetricCard(title: L10n.t("Commits · 30 Tage", "Commits · 30 days"), value: "\(summary.commits30d)", icon: "point.3.filled.connected.trianglepath.dotted", tint: NavoTheme.accent)
            MetricCard(title: L10n.t("Gemergte PRs · 30 Tage", "Merged PRs · 30 days"), value: "\(summary.mergedPRs30d)", icon: "arrow.triangle.merge", tint: NavoTheme.cyan)
            MetricCard(title: L10n.t("CI-Erfolgsquote", "CI success rate"), value: summary.workflowSuccessRate30d?.formattedPercent ?? "–", icon: "checkmark.seal.fill", tint: (summary.workflowSuccessRate30d ?? 1) >= 0.9 ? NavoTheme.success : NavoTheme.warning)
        }
    }

    @ViewBuilder
    private var commercialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("Kommerziell", "Commercial"), subtitle: L10n.t("Nur Werte aus tatsächlich verfügbaren Store-Berichten", "Only values from actually available store reports"))

            LazyVGrid(columns: columns, spacing: 12) {
                MetricCard(title: L10n.t("Einheiten", "Units"), value: summary.commercialUnits.map { String($0) } ?? "–", icon: "cart.fill")
                MetricCard(title: L10n.t("Downloads", "Downloads"), value: summary.downloads.map { String($0) } ?? "–", icon: "arrow.down.app.fill", tint: NavoTheme.cyan)
                MetricCard(title: L10n.t("Abo-Produkte", "Subscription products"), value: "\(summary.configuredSubscriptions)", icon: "repeat.circle.fill", tint: NavoTheme.accent)
                MetricCard(title: L10n.t("Einmalkäufe", "One-time products"), value: "\(summary.configuredOneTimeProducts)", icon: "creditcard.fill", tint: NavoTheme.cyan)
            }

            if !summary.proceedsByCurrency.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("Erlöse nach Währung", "Proceeds by currency"))
                        .font(.headline)
                    ForEach(summary.proceedsByCurrency) { amount in
                        HStack {
                            Text(amount.currency)
                                .font(.subheadline.monospaced())
                            Spacer()
                            Text(amount.amount.formatted(.currency(code: amount.currency)))
                                .font(.headline.monospacedDigit())
                        }
                    }
                }
                .navoCard()
            }

            if summary.monetizationProductsNeedingAction > 0 {
                Label(
                    L10n.t("\(summary.monetizationProductsNeedingAction) Monetarisierungsprodukte benötigen Aktion.", "\(summary.monetizationProductsNeedingAction) monetization products need action."),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(NavoTheme.warning)
                .navoCard()
            }
        }
    }

    private var releaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("Release Intelligence", "Release Intelligence"), subtitle: L10n.t("Aus lokal beobachteten Store-Statuswechseln", "From locally observed store-state transitions"))

            LazyVGrid(columns: columns, spacing: 12) {
                MetricCard(title: L10n.t("Releases · 90 Tage", "Releases · 90 days"), value: "\(summary.releases90d)", icon: "calendar.badge.checkmark", tint: NavoTheme.success)
                MetricCard(title: L10n.t("Apple Review Ø", "Apple review avg"), value: formatDuration(summary.averageObservedAppleReview), icon: "apple.logo")
                MetricCard(title: L10n.t("Google Review Ø", "Google review avg"), value: formatDuration(summary.averageObservedGoogleReview), icon: "play.rectangle.fill", tint: NavoTheme.cyan)
                MetricCard(title: L10n.t("Aktuell in Review", "Currently in review"), value: "\(model.reviewCount)", icon: "hourglass")
            }

            let activeReviews = model.products.compactMap { product -> ActiveReview? in
                if let age = model.currentReviewAge(for: product, provider: .apple) {
                    return ActiveReview(id: "apple:\(product.id)", product: product, provider: .apple, age: age)
                }
                if let age = model.currentReviewAge(for: product, provider: .google) {
                    return ActiveReview(id: "google:\(product.id)", product: product, provider: .google, age: age)
                }
                return nil
            }.sorted { $0.age > $1.age }

            if !activeReviews.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("Laufende Reviews", "Active reviews")).font(.headline)
                    ForEach(activeReviews.prefix(8)) { review in
                        NavigationLink(value: review.product.id) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(review.product.name).font(.subheadline.weight(.semibold))
                                    Text(review.provider.title).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(formatDuration(review.age))
                                    .font(.caption.monospacedDigit().weight(.bold))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .navoCard()
            }
        }
    }

    @ViewBuilder
    private var reliabilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("Zuverlässigkeit", "Reliability"), subtitle: L10n.t("Google Play Vitals, sofern die Reporting-Berechtigung verfügbar ist", "Google Play Vitals when reporting access is available"))

            LazyVGrid(columns: columns, spacing: 12) {
                MetricCard(title: L10n.t("Höchste Crash-Rate", "Highest crash rate"), value: summary.worstCrashRate?.formattedPercent ?? "–", icon: "bolt.trianglebadge.exclamationmark.fill", tint: rateTint(summary.worstCrashRate, warning: 0.01))
                MetricCard(title: L10n.t("Höchste ANR-Rate", "Highest ANR rate"), value: summary.worstANRRate?.formattedPercent ?? "–", icon: "hourglass", tint: rateTint(summary.worstANRRate, warning: 0.005))
            }

            let risks = model.analyticsRiskProducts()
            if !risks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("Auffälligkeiten", "Signals")).font(.headline)
                    ForEach(Array(risks.prefix(8).enumerated()), id: \.offset) { _, item in
                        NavigationLink(value: item.0.id) {
                            HStack {
                                Text(item.0.name).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(item.1).font(.caption).foregroundStyle(NavoTheme.warning)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .navoCard()
            }
        }
    }

    private var engineeringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: L10n.t("Engineering", "Engineering"), subtitle: L10n.t("GitHub-Aktivität und CI der letzten 30 Tage", "GitHub activity and CI over the last 30 days"))
                Spacer()
                NavigationLink {
                    GitHubView()
                } label: {
                    Image(systemName: "arrow.up.right.square")
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(sortedEngineering.prefix(12).enumerated()), id: \.element.id) { index, repo in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(repo.repository).font(.subheadline.weight(.semibold))
                            Text(L10n.t("\(repo.commitCount30d) Commits · \(repo.mergedPRCount30d) PRs", "\(repo.commitCount30d) commits · \(repo.mergedPRCount30d) PRs"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(repo.workflowSuccessRate?.formattedPercent ?? "–")
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(ciTint(repo.workflowSuccessRate))
                    }
                    .padding(.vertical, 10)
                    if index < min(sortedEngineering.count, 12) - 1 {
                        Divider().opacity(0.2)
                    }
                }
            }
            .navoCard()
        }
    }

    @ViewBuilder
    private var trendSection: some View {
        let points = model.analyticsHistory.compactMap { observation -> AnalyticsUnitPoint? in
            guard let units = observation.units else { return nil }
            return AnalyticsUnitPoint(id: observation.id, date: observation.observedAt, value: units, provider: observation.provider.title)
        }

        if points.count >= 2 {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: L10n.t("Einheiten-Trend", "Units trend"), subtitle: L10n.t("Bis zu 180 Tage lokaler Verlauf", "Up to 180 days of local history"))
                Chart(points) { point in
                    LineMark(
                        x: .value(L10n.t("Datum", "Date"), point.date),
                        y: .value(L10n.t("Einheiten", "Units"), point.value)
                    )
                    .foregroundStyle(by: .value(L10n.t("Store", "Store"), point.provider))
                    PointMark(
                        x: .value(L10n.t("Datum", "Date"), point.date),
                        y: .value(L10n.t("Einheiten", "Units"), point.value)
                    )
                    .foregroundStyle(by: .value(L10n.t("Store", "Store"), point.provider))
                }
                .frame(height: 220)
                .chartLegend(position: .bottom)
                .navoCard()
            }
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("Datenabdeckung", "Data coverage"), subtitle: L10n.t("NavoOps zeigt keine erfundenen Kennzahlen", "NavoOps does not fabricate metrics"))

            VStack(alignment: .leading, spacing: 10) {
                sourceRow("App Store Connect", available: model.analyticsFeed?.appleAvailable == true, date: model.analyticsFeed?.appleGeneratedAt)
                sourceRow("Google Play", available: model.analyticsFeed?.googleAvailable == true, date: model.analyticsFeed?.googleGeneratedAt)
                sourceRow(L10n.t("Kommerzielle Berichte", "Commercial reports"), available: model.analyticsFeed?.commercialAvailable == true, date: model.analyticsFeed?.generatedAt)
                sourceRow(L10n.t("Reliability / Vitals", "Reliability / Vitals"), available: model.analyticsFeed?.reliabilityAvailable == true, date: model.analyticsFeed?.generatedAt)

                if let error = model.analyticsErrorMessage {
                    Text(error).font(.caption).foregroundStyle(NavoTheme.warning)
                }

                ForEach(model.analyticsFeed?.notes ?? [], id: \.self) { note in
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            }
            .navoCard()
        }
    }

    private func sourceRow(_ title: String, available: Bool, date: Date?) -> some View {
        HStack {
            Image(systemName: available ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(available ? NavoTheme.success : .secondary)
            Text(title).font(.subheadline)
            Spacer()
            if let date {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatDuration(_ interval: TimeInterval?) -> String {
        guard let interval else { return "–" }
        let minutes = max(0, Int(interval / 60))
        let days = minutes / 1_440
        let hours = (minutes % 1_440) / 60
        let remainingMinutes = minutes % 60

        if days > 0 {
            return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        }
        if hours > 0 {
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }
        return "\(remainingMinutes)m"
    }

    private func ciTint(_ rate: Double?) -> Color {
        guard let rate else { return .secondary }
        if rate >= 0.95 { return NavoTheme.success }
        if rate >= 0.80 { return NavoTheme.warning }
        return NavoTheme.danger
    }

    private func rateTint(_ rate: Double?, warning: Double) -> Color {
        guard let rate else { return .secondary }
        return rate >= warning ? NavoTheme.warning : NavoTheme.success
    }
}

private struct ActiveReview: Identifiable {
    let id: String
    let product: ProductApp
    let provider: StoreProvider
    let age: TimeInterval
}

private struct AnalyticsUnitPoint: Identifiable {
    let id: String
    let date: Date
    let value: Int
    let provider: String
}
