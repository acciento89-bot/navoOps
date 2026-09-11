import Foundation

extension AppModel {
    var portfolioAnalytics: PortfolioAnalyticsSummary {
        let now = Date()
        let releases30 = releaseTransitions(since: now.addingTimeInterval(-30 * 24 * 60 * 60)).count
        let releases90 = releaseTransitions(since: now.addingTimeInterval(-90 * 24 * 60 * 60)).count
        let appleReview = average(reviewDurations(provider: .apple))
        let googleReview = average(reviewDurations(provider: .google))

        let snapshots = analyticsFeed?.apps ?? []
        let subscriptions = snapshots.compactMap(\.subscriptionProducts).reduce(0, +)
        let oneTime = snapshots.compactMap(\.oneTimeProducts).reduce(0, +)
        let actionProducts = snapshots.compactMap(\.productsNeedingAction).reduce(0, +)

        let unitValues = snapshots.compactMap(\.units)
        let downloadValues = snapshots.compactMap(\.downloads)
        var proceeds: [String: Double] = [:]
        for amount in snapshots.flatMap(\.proceeds) {
            proceeds[amount.currency, default: 0] += amount.amount
        }

        let engineering = Array(repositoryAnalytics.values)
        let workflowRuns = engineering.reduce(0) { $0 + $1.workflowRuns30d }
        let workflowSuccess = engineering.reduce(0) { $0 + $1.workflowSuccessCount30d }

        return PortfolioAnalyticsSummary(
            releases30d: releases30,
            releases90d: releases90,
            averageObservedAppleReview: appleReview,
            averageObservedGoogleReview: googleReview,
            configuredSubscriptions: subscriptions,
            configuredOneTimeProducts: oneTime,
            monetizationProductsNeedingAction: actionProducts,
            commercialUnits: unitValues.isEmpty ? nil : unitValues.reduce(0, +),
            downloads: downloadValues.isEmpty ? nil : downloadValues.reduce(0, +),
            proceedsByCurrency: proceeds.map { CurrencyAmount(currency: $0.key, amount: $0.value) }.sorted { $0.currency < $1.currency },
            worstCrashRate: snapshots.compactMap { $0.userPerceivedCrashRate ?? $0.crashRate }.max(),
            worstANRRate: snapshots.compactMap { $0.userPerceivedAnrRate ?? $0.anrRate }.max(),
            commits30d: engineering.reduce(0) { $0 + $1.commitCount30d },
            mergedPRs30d: engineering.reduce(0) { $0 + $1.mergedPRCount30d },
            workflowSuccessRate30d: workflowRuns == 0 ? nil : Double(workflowSuccess) / Double(workflowRuns)
        )
    }

    func analyticsSnapshots(for product: ProductApp) -> [AppAnalyticsSnapshot] {
        (analyticsFeed?.apps ?? []).filter { $0.matches(product) }
    }

    func analyticsHistory(for product: ProductApp, provider: StoreProvider? = nil) -> [AnalyticsObservation] {
        analyticsHistory
            .filter { $0.productID == product.id && (provider == nil || $0.provider == provider) }
            .sorted { $0.observedAt < $1.observedAt }
    }

    func releaseTransitions(since date: Date) -> [StoreHistoryEvent] {
        storeHistory.filter {
            $0.observedAt >= date &&
            $0.state == .live &&
            $0.previousState != nil &&
            $0.previousState != .live
        }
    }

    func currentReviewAge(for product: ProductApp, provider: StoreProvider) -> TimeInterval? {
        guard storeSnapshot(for: product, provider: provider)?.state == .review else { return nil }
        let events = storeHistory
            .filter { $0.productID == product.id && $0.provider == provider }
            .sorted { $0.observedAt < $1.observedAt }
        guard let start = events.last(where: { $0.state == .review && $0.previousState != .review })?.observedAt else { return nil }
        return max(0, Date().timeIntervalSince(start))
    }

    func reviewDurations(provider: StoreProvider) -> [TimeInterval] {
        let groups = Dictionary(grouping: storeHistory.filter { $0.provider == provider }, by: \.productID)
        var durations: [TimeInterval] = []

        for events in groups.values {
            let ordered = events.sorted { $0.observedAt < $1.observedAt }
            var reviewStart: Date?
            for event in ordered {
                if event.state == .review {
                    if event.previousState != .review || reviewStart == nil {
                        reviewStart = event.observedAt
                    }
                } else if event.previousState == .review, let start = reviewStart {
                    let duration = event.observedAt.timeIntervalSince(start)
                    if duration >= 0 { durations.append(duration) }
                    reviewStart = nil
                }
            }
        }
        return durations
    }

    func analyticsRiskProducts() -> [(ProductApp, String)] {
        products.compactMap { product in
            let snapshots = analyticsSnapshots(for: product)
            let crash = snapshots.compactMap { $0.userPerceivedCrashRate ?? $0.crashRate }.max()
            let anr = snapshots.compactMap { $0.userPerceivedAnrRate ?? $0.anrRate }.max()
            let actionProducts = snapshots.compactMap(\.productsNeedingAction).reduce(0, +)

            if let crash, crash >= 0.01 {
                return (product, L10n.t("Crash-Rate \(crash.formattedPercent)", "Crash rate \(crash.formattedPercent)"))
            }
            if let anr, anr >= 0.005 {
                return (product, L10n.t("ANR-Rate \(anr.formattedPercent)", "ANR rate \(anr.formattedPercent)"))
            }
            if actionProducts > 0 {
                return (product, L10n.t("\(actionProducts) Monetarisierungsprodukte benötigen Aktion", "\(actionProducts) monetization products need action"))
            }
            return nil
        }
    }

    private func average(_ values: [TimeInterval]) -> TimeInterval? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

extension Double {
    var formattedPercent: String {
        self.formatted(.percent.precision(.fractionLength(0...2)))
    }
}
