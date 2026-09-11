import Foundation

extension AppModel {
    var intelligence: PortfolioIntelligence {
        let insights = opsInsights
        let critical = insights.filter { $0.severity == .critical }.count
        let actions = insights.filter { $0.severity == .action }.count
        let warnings = insights.filter { $0.severity == .warning }.count
        let score = max(0, 100 - min(36, critical * 12) - min(30, actions * 6) - min(14, warnings * 2))

        let dualPlatform = products.filter { $0.supportsApple && $0.supportsGoogle }
        let aligned = dualPlatform.filter(isCrossPlatformAligned).count
        let unhealthyIDs = Set(insights.compactMap { insight -> String? in
            guard insight.severity != .info else { return nil }
            return insight.productID
        })

        let expectedApple = products.filter(\.supportsApple).count
        let expectedGoogle = products.filter(\.supportsGoogle).count
        let matchedApple = products.filter { $0.supportsApple && storeSnapshot(for: $0, provider: .apple) != nil }.count
        let matchedGoogle = products.filter { $0.supportsGoogle && storeSnapshot(for: $0, provider: .google) != nil }.count
        let health = Array(healthByRepository.values)

        return .init(
            score: score,
            criticalCount: critical,
            actionCount: actions,
            warningCount: warnings,
            healthyCount: products.filter { !unhealthyIDs.contains($0.id) }.count,
            alignedCount: aligned,
            dualPlatformCount: dualPlatform.count,
            appleMatched: matchedApple,
            appleExpected: expectedApple,
            googleMatched: matchedGoogle,
            googleExpected: expectedGoogle,
            passingBuilds: health.filter { $0.buildState == .success }.count,
            failedBuilds: health.filter { $0.buildState == .failure }.count,
            runningBuilds: health.filter { $0.buildState == .running }.count,
            unknownBuilds: health.filter { $0.buildState == .unknown }.count
        )
    }

    var productIntelligence: [ProductIntelligenceSnapshot] {
        products.map { product in
            let insights = insights(for: product)
            let critical = insights.filter { $0.severity == .critical }.count
            let actions = insights.filter { $0.severity == .action }.count
            let warnings = insights.filter { $0.severity == .warning }.count
            let score = max(0, 100 - critical * 25 - actions * 12 - warnings * 5)
            return .init(
                product: product,
                apple: storeSnapshot(for: product, provider: .apple),
                google: storeSnapshot(for: product, provider: .google),
                health: health(for: product),
                score: score,
                insightCount: insights.filter { $0.severity != .info }.count,
                isAligned: isCrossPlatformAligned(product)
            )
        }
        .sorted {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.product.name.localizedCaseInsensitiveCompare($1.product.name) == .orderedAscending
        }
    }

    var opsInsights: [OpsInsight] {
        var insights: [OpsInsight] = systemInsights
        for product in products {
            insights.append(contentsOf: insights(for: product))
        }

        return insights.sorted {
            if $0.severity != $1.severity { return $0.severity > $1.severity }
            let lhsDate = $0.date ?? .distantPast
            let rhsDate = $1.date ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    var recentStoreTransitions: [StoreHistoryEvent] {
        storeHistory
            .filter { $0.changedState || $0.changedVersion }
            .sorted { $0.observedAt > $1.observedAt }
    }

    func insights(for product: ProductApp) -> [OpsInsight] {
        var result: [OpsInsight] = []
        let apple = storeSnapshot(for: product, provider: .apple)
        let google = storeSnapshot(for: product, provider: .google)
        let health = health(for: product)

        if health?.buildState == .failure {
            result.append(.init(
                id: "\(product.id):build-failure",
                productID: product.id,
                title: L10n.t("Build rot · \(product.name)", "Build red · \(product.name)"),
                detail: health?.workflowName ?? "GitHub Actions",
                recommendation: L10n.t("Fehlgeschlagene Jobs neu starten und Logs prüfen.", "Rerun failed jobs and inspect the logs."),
                severity: .critical,
                kind: .build,
                provider: nil,
                date: health?.workflowUpdatedAt
            ))
        } else if health?.buildState == .running {
            result.append(.init(
                id: "\(product.id):build-running",
                productID: product.id,
                title: L10n.t("Build läuft · \(product.name)", "Build running · \(product.name)"),
                detail: health?.workflowName ?? "GitHub Actions",
                recommendation: L10n.t("Kein Eingriff nötig; Ergebnis abwarten.", "No action needed; wait for the result."),
                severity: .info,
                kind: .build,
                provider: nil,
                date: health?.workflowUpdatedAt
            ))
        }

        appendStoreInsight(snapshot: apple, product: product, provider: .apple, into: &result)
        appendStoreInsight(snapshot: google, product: product, provider: .google, into: &result)

        if product.supportsApple && appleLiveAvailable && apple == nil {
            result.append(.init(
                id: "\(product.id):apple-unmatched",
                productID: product.id,
                title: L10n.t("Apple-Zuordnung fehlt · \(product.name)", "Apple mapping missing · \(product.name)"),
                detail: product.storeInfo.appleBundleID ?? L10n.t("Keine Bundle-ID hinterlegt", "No bundle ID configured"),
                recommendation: L10n.t("Bundle-ID prüfen und Store-Inventar abgleichen.", "Verify the bundle ID and reconcile store inventory."),
                severity: .warning,
                kind: .inventory,
                provider: .apple,
                date: storeGeneratedAt
            ))
        }

        if product.supportsGoogle && googleLiveAvailable && google == nil {
            result.append(.init(
                id: "\(product.id):google-unmatched",
                productID: product.id,
                title: L10n.t("Google-Zuordnung fehlt · \(product.name)", "Google mapping missing · \(product.name)"),
                detail: product.storeInfo.androidPackageID ?? L10n.t("Keine Package-ID hinterlegt", "No package ID configured"),
                recommendation: L10n.t("Package-ID prüfen und Store-Inventar abgleichen.", "Verify the package ID and reconcile store inventory."),
                severity: .warning,
                kind: .inventory,
                provider: .google,
                date: storeGeneratedAt
            ))
        }

        if product.supportsApple && product.supportsGoogle, let apple, let google {
            let appleState = apple.state.productState
            let googleState = google.state.productState
            if appleState != googleState {
                let oneLive = appleState == .live || googleState == .live
                result.append(.init(
                    id: "\(product.id):state-drift:\(apple.state.rawValue):\(google.state.rawValue)",
                    productID: product.id,
                    title: L10n.t("Store-Drift · \(product.name)", "Store drift · \(product.name)"),
                    detail: "Apple: \(appleState.localizedTitle) · Google: \(googleState.localizedTitle)",
                    recommendation: oneLive
                        ? L10n.t("Die noch nicht live geschaltete Plattform priorisieren.", "Prioritize the platform that is not live yet.")
                        : L10n.t("Release-Zustände beider Stores abgleichen.", "Reconcile the release states across both stores."),
                    severity: oneLive ? .action : .warning,
                    kind: .parity,
                    provider: nil,
                    date: storeGeneratedAt
                ))
            }

            if let appleVersion = semanticVersion(from: apple.version),
               let googleVersion = semanticVersion(from: google.version),
               appleVersion != googleVersion {
                result.append(.init(
                    id: "\(product.id):version-drift:\(appleVersion):\(googleVersion)",
                    productID: product.id,
                    title: L10n.t("Versions-Drift · \(product.name)", "Version drift · \(product.name)"),
                    detail: "Apple \(appleVersion) · Google \(googleVersion)",
                    recommendation: L10n.t("Prüfen, ob die Plattformen absichtlich unterschiedliche Releases fahren.", "Check whether the platforms are intentionally on different releases."),
                    severity: .warning,
                    kind: .parity,
                    provider: nil,
                    date: storeGeneratedAt
                ))
            }
        }

        if product.supportsApple,
           !product.checklist.readyForApple,
           resolvedAppleState(for: product) != .live,
           resolvedAppleState(for: product) != .review {
            let missing = product.checklist.appleTotal - product.checklist.appleCompleted
            result.append(.init(
                id: "\(product.id):apple-readiness",
                productID: product.id,
                title: L10n.t("Apple-Readiness unvollständig · \(product.name)", "Apple readiness incomplete · \(product.name)"),
                detail: L10n.t("\(missing) Checklistenpunkte offen", "\(missing) checklist items open"),
                recommendation: L10n.t("Store-Readiness vor dem nächsten Submit vervollständigen.", "Complete store readiness before the next submission."),
                severity: .warning,
                kind: .readiness,
                provider: .apple,
                date: nil
            ))
        }

        if product.supportsGoogle,
           !product.checklist.readyForGoogle,
           resolvedGoogleState(for: product) != .live,
           resolvedGoogleState(for: product) != .review {
            let missing = product.checklist.googleTotal - product.checklist.googleCompleted
            result.append(.init(
                id: "\(product.id):google-readiness",
                productID: product.id,
                title: L10n.t("Google-Readiness unvollständig · \(product.name)", "Google readiness incomplete · \(product.name)"),
                detail: L10n.t("\(missing) Checklistenpunkte offen", "\(missing) checklist items open"),
                recommendation: L10n.t("Play-Store-Readiness vor dem nächsten Submit vervollständigen.", "Complete Play Store readiness before the next submission."),
                severity: .warning,
                kind: .readiness,
                provider: .google,
                date: nil
            ))
        }

        let openPRs = pullRequests(for: product).count
        if openPRs > 0 {
            result.append(.init(
                id: "\(product.id):prs:\(openPRs)",
                productID: product.id,
                title: L10n.t("\(openPRs) offene PRs · \(product.name)", "\(openPRs) open PRs · \(product.name)"),
                detail: L10n.t("Noch nicht gemergte Änderungen können den nächsten Release beeinflussen.", "Unmerged changes may affect the next release."),
                recommendation: L10n.t("PRs vor Release-Freigabe prüfen.", "Review PRs before approving the next release."),
                severity: .info,
                kind: .github,
                provider: nil,
                date: pullRequests(for: product).compactMap(\.updatedAt).max()
            ))
        }

        return result
    }

    func isCrossPlatformAligned(_ product: ProductApp) -> Bool {
        guard product.supportsApple && product.supportsGoogle else { return true }
        guard let apple = storeSnapshot(for: product, provider: .apple),
              let google = storeSnapshot(for: product, provider: .google) else { return false }

        guard apple.state.productState == google.state.productState else { return false }

        if let appleVersion = semanticVersion(from: apple.version),
           let googleVersion = semanticVersion(from: google.version) {
            return appleVersion == googleVersion
        }
        return true
    }

    func observedStateDuration(for product: ProductApp, provider: StoreProvider) -> TimeInterval? {
        guard let current = storeSnapshot(for: product, provider: provider) else { return nil }
        let matching = storeHistory
            .filter { $0.productID == product.id && $0.provider == provider }
            .sorted { $0.observedAt < $1.observedAt }
        guard !matching.isEmpty else { return nil }

        var start = matching.first?.observedAt
        for event in matching {
            if event.state == current.state {
                start = event.observedAt
            } else if event.observedAt > (start ?? .distantPast) {
                start = nil
            }
        }
        guard let start else { return nil }
        return max(0, Date().timeIntervalSince(start))
    }

    func semanticVersion(from text: String?) -> String? {
        guard let text,
              let range = text.range(of: #"\d+\.\d+(?:\.\d+)?"#, options: .regularExpression) else {
            return nil
        }
        let raw = String(text[range])
        var components = raw.split(separator: ".").map(String.init)
        while components.count < 3 { components.append("0") }
        return components.prefix(3).joined(separator: ".")
    }

    private var systemInsights: [OpsInsight] {
        var result: [OpsInsight] = []

        if !appleLiveAvailable {
            result.append(.init(
                id: "system:apple-source",
                productID: nil,
                title: L10n.t("Apple-Livequelle nicht verfügbar", "Apple live source unavailable"),
                detail: L10n.t("App Store Connect kann aktuell nicht als Livequelle verwendet werden.", "App Store Connect cannot currently be used as a live source."),
                recommendation: L10n.t("Bridge und App-Store-Connect-Authentifizierung prüfen.", "Check the bridge and App Store Connect authentication."),
                severity: .action,
                kind: .freshness,
                provider: .apple,
                date: storeGeneratedAt
            ))
        }

        if !googleLiveAvailable {
            result.append(.init(
                id: "system:google-source",
                productID: nil,
                title: L10n.t("Google-Livequelle nicht verfügbar", "Google live source unavailable"),
                detail: L10n.t("Google Play kann aktuell nicht als Livequelle verwendet werden.", "Google Play cannot currently be used as a live source."),
                recommendation: L10n.t("OIDC-, Play-API- und Dienstkonto-Berechtigungen prüfen.", "Check OIDC, Play API and service-account permissions."),
                severity: .action,
                kind: .freshness,
                provider: .google,
                date: storeGeneratedAt
            ))
        }

        if let generatedAt = storeGeneratedAt {
            let age = Date().timeIntervalSince(generatedAt)
            if age > 3 * 60 * 60 {
                result.append(.init(
                    id: "system:stale-store-feed",
                    productID: nil,
                    title: L10n.t("Store-Daten veraltet", "Store data stale"),
                    detail: L10n.t("Letzter Store-Snapshot ist älter als 3 Stunden.", "The latest store snapshot is more than 3 hours old."),
                    recommendation: L10n.t("Bridge-Refresh auslösen und Feed prüfen.", "Trigger a bridge refresh and verify the feed."),
                    severity: .critical,
                    kind: .freshness,
                    provider: nil,
                    date: generatedAt
                ))
            } else if age > 90 * 60 {
                result.append(.init(
                    id: "system:aging-store-feed",
                    productID: nil,
                    title: L10n.t("Store-Snapshot wird alt", "Store snapshot aging"),
                    detail: L10n.t("Der letzte Snapshot ist älter als 90 Minuten.", "The latest snapshot is more than 90 minutes old."),
                    recommendation: L10n.t("Bei Bedarf einen manuellen Bridge-Refresh starten.", "Trigger a manual bridge refresh if needed."),
                    severity: .warning,
                    kind: .freshness,
                    provider: nil,
                    date: generatedAt
                ))
            }
        }

        if !untrackedStoreApps.isEmpty {
            result.append(.init(
                id: "system:untracked-store-apps:\(untrackedStoreApps.count)",
                productID: nil,
                title: L10n.t("\(untrackedStoreApps.count) Store-Apps nicht zugeordnet", "\(untrackedStoreApps.count) store apps untracked"),
                detail: L10n.t("Store-Inventar enthält Apps, die noch keinem Portfolio-Eintrag zugeordnet sind.", "Store inventory contains apps that are not mapped to the portfolio yet."),
                recommendation: L10n.t("Store-Inventar öffnen und Zuordnung ergänzen.", "Open store inventory and add the missing mappings."),
                severity: .warning,
                kind: .inventory,
                provider: nil,
                date: storeGeneratedAt
            ))
        }

        return result
    }

    private func appendStoreInsight(
        snapshot: StoreAppSnapshot?,
        product: ProductApp,
        provider: StoreProvider,
        into result: inout [OpsInsight]
    ) {
        guard let snapshot else { return }
        let storeName = provider.title

        switch snapshot.state {
        case .rejected:
            result.append(.init(
                id: "\(product.id):\(provider.rawValue):rejected",
                productID: product.id,
                title: L10n.t("\(storeName) abgelehnt · \(product.name)", "\(storeName) rejected · \(product.name)"),
                detail: snapshot.detail ?? snapshot.rawState,
                recommendation: L10n.t("Ablehnungsgrund öffnen, korrigieren und neuen Release vorbereiten.", "Open the rejection reason, fix it and prepare a new release."),
                severity: .critical,
                kind: .store,
                provider: provider,
                date: snapshot.updatedAt ?? storeGeneratedAt
            ))
        case .attention:
            result.append(.init(
                id: "\(product.id):\(provider.rawValue):attention",
                productID: product.id,
                title: L10n.t("\(storeName) wartet auf Aktion · \(product.name)", "\(storeName) awaits action · \(product.name)"),
                detail: snapshot.detail ?? snapshot.rawState,
                recommendation: L10n.t("Release-Datensatz prüfen und den nächsten erforderlichen Store-Schritt ausführen.", "Review the release record and perform the next required store action."),
                severity: .action,
                kind: .store,
                provider: provider,
                date: snapshot.updatedAt ?? storeGeneratedAt
            ))
        case .review, .processing:
            let duration = observedStateDuration(for: product, provider: provider)
            let durationText = duration.map(formatDuration) ?? L10n.t("seit erstem beobachteten Snapshot", "since the first observed snapshot")
            result.append(.init(
                id: "\(product.id):\(provider.rawValue):waiting:\(snapshot.state.rawValue)",
                productID: product.id,
                title: L10n.t("\(storeName) in Bearbeitung · \(product.name)", "\(storeName) processing · \(product.name)"),
                detail: L10n.t("Status beobachtet: \(durationText)", "Observed status: \(durationText)"),
                recommendation: L10n.t("Kein Eingriff nötig, solange keine neue Store-Aktion angefordert wird.", "No action needed unless the store requests another step."),
                severity: .info,
                kind: .store,
                provider: provider,
                date: snapshot.updatedAt ?? storeGeneratedAt
            ))
        case .development, .internalTest, .live, .unavailable:
            break
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        if hours < 1 { return L10n.t("unter 1 Stunde", "under 1 hour") }
        if hours < 24 { return L10n.t("ca. \(hours) Std.", "about \(hours) hr") }
        let days = max(1, hours / 24)
        return L10n.t("ca. \(days) Tage", "about \(days) days")
    }
}
