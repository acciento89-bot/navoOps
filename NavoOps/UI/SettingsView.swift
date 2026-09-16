import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var security: SecurityService

    @State private var token = KeychainStore.githubToken ?? ""
    @State private var tokenSaved = false
    @State private var notificationStatus = ""
    @State private var showResetConfirmation = false
    @State private var showHistoryResetConfirmation = false
    @State private var showAnalyticsHistoryResetConfirmation = false

    var body: some View {
        Form {
            githubSection
            storeBridgeSection
            analyticsBridgeSection
            intelligenceSection
            securitySection
            notificationsSection
            organizationSection
            maintenanceSection
        }
        .scrollContentBackground(.hidden)
        .background(NavoTheme.background)
        .navigationTitle(L10n.t("Einstellungen", "Settings"))
        .task { await refreshNotificationStatus() }
        .confirmationDialog(
            L10n.t("Portfolio auf Werkseinstellungen zurücksetzen?", "Reset portfolio to defaults?"),
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.t("Zurücksetzen", "Reset"), role: .destructive) { model.resetPortfolio() }
            Button(L10n.t("Abbrechen", "Cancel"), role: .cancel) {}
        }
        .confirmationDialog(
            L10n.t("Lokalen Store-Verlauf löschen?", "Delete local store history?"),
            isPresented: $showHistoryResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.t("Verlauf löschen", "Delete history"), role: .destructive) { model.resetStoreHistory() }
            Button(L10n.t("Abbrechen", "Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.t(
                "Dadurch gehen nur die lokal beobachteten Status- und Versionswechsel verloren. Live-Store-Daten werden nicht verändert.",
                "This only removes locally observed state and version transitions. Live store data is not changed."
            ))
        }
        .confirmationDialog(
            L10n.t("Lokalen Analytics-Verlauf löschen?", "Delete local analytics history?"),
            isPresented: $showAnalyticsHistoryResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.t("Analytics-Verlauf löschen", "Delete analytics history"), role: .destructive) { model.resetAnalyticsHistory() }
            Button(L10n.t("Abbrechen", "Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.t(
                "Nur die lokal gespeicherten historischen Messpunkte werden entfernt. Bridge- und Store-Daten bleiben unverändert.",
                "Only locally stored historical measurement points are removed. Bridge and store data remain unchanged."
            ))
        }
    }

    private var githubSection: some View {
        Section("GitHub") {
            SecureField(L10n.t("Fine-grained Token", "Fine-grained token"), text: $token)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                KeychainStore.githubToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
                tokenSaved = true
                Task { await model.refreshAll() }
            } label: {
                Label(L10n.t("Token sicher speichern", "Save token securely"), systemImage: "key.fill")
            }

            if tokenSaved || KeychainStore.githubToken != nil {
                Label(L10n.t("Token liegt ausschließlich im iOS-Keychain.", "Token is stored only in iOS Keychain."), systemImage: "checkmark.shield.fill")
                    .font(.footnote)
                    .foregroundStyle(NavoTheme.success)
            }

            Button(L10n.t("Token entfernen", "Remove token"), role: .destructive) {
                KeychainStore.githubToken = nil
                token = ""
                tokenSaved = false
                model.repositories = []
                model.pullRequests = []
                model.issues = []
                model.healthByRepository = [:]
                model.repositoryAnalytics = [:]
                model.storeFeed = nil
                model.analyticsFeed = nil
            }

            Text(L10n.t(
                "Für private Repositories: Fine-grained Token mit Read-Zugriff auf Contents, Metadata, Pull Requests und Actions. Für Issues oder Bridge-Refresh zusätzlich die jeweilige Write-Berechtigung.",
                "For private repositories: use a fine-grained token with read access to Contents, Metadata, Pull Requests and Actions. Issue creation or bridge refresh additionally requires the corresponding write permission."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .listRowBackground(NavoTheme.surface)
    }

    private var storeBridgeSection: some View {
        Section(L10n.t("Store Bridge", "Store Bridge")) {
            LabeledContent("Apple") {
                Label(
                    model.appleLiveAvailable ? "Live" : L10n.t("Lokal/Fallback", "Local/Fallback"),
                    systemImage: model.appleLiveAvailable ? "checkmark.circle.fill" : "exclamationmark.circle"
                )
                .foregroundStyle(model.appleLiveAvailable ? NavoTheme.success : NavoTheme.warning)
            }

            if let generated = model.generatedAt(for: .apple) {
                LabeledContent(L10n.t("Apple-Snapshot", "Apple snapshot"), value: generated.formatted(date: .abbreviated, time: .shortened))
            }

            LabeledContent("Google Play") {
                Label(
                    model.googleLiveAvailable ? "Live" : L10n.t("Lokal/Fallback", "Local/Fallback"),
                    systemImage: model.googleLiveAvailable ? "checkmark.circle.fill" : "exclamationmark.circle"
                )
                .foregroundStyle(model.googleLiveAvailable ? NavoTheme.success : NavoTheme.warning)
            }

            if let generated = model.generatedAt(for: .google) {
                LabeledContent(L10n.t("Google-Snapshot", "Google snapshot"), value: generated.formatted(date: .abbreviated, time: .shortened))
            }

            Button {
                Task { await model.refreshStores() }
            } label: {
                Label(L10n.t("Store-Status laden", "Load store status"), systemImage: "arrow.down.circle.fill")
            }
            .disabled(model.isRefreshingStores || KeychainStore.githubToken == nil)

            Button {
                Task { await model.requestStoreBridgeRefresh() }
            } label: {
                Label(L10n.t("Bridge jetzt aktualisieren", "Refresh bridge now"), systemImage: "bolt.horizontal.circle.fill")
            }
            .disabled(model.isRefreshingStores || KeychainStore.githubToken == nil)

            if model.storeRefreshRequested {
                Label(
                    L10n.t("Bridge-Refresh wurde angefordert. Der neue Snapshot erscheint nach Abschluss des GitHub-Workflows.", "Bridge refresh was requested. The new snapshot appears after the GitHub workflow completes."),
                    systemImage: "clock.badge.checkmark"
                )
                .font(.footnote)
                .foregroundStyle(NavoTheme.accent)
            }

            if let error = model.storeErrorMessage, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(NavoTheme.warning)
            }

            Text(L10n.t(
                "Apple-/Google-Zugangsdaten werden nicht in der App gespeichert. NavoOps liest ausschließlich bereinigte Status-Snapshots der Kamilunavo-Bridges über GitHub.",
                "Apple/Google credentials are never stored in the app. NavoOps only reads sanitized status snapshots generated by the Kamilunavo bridges through GitHub."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .listRowBackground(NavoTheme.surface)
    }

    private var analyticsBridgeSection: some View {
        Section(L10n.t("Analytics Bridge", "Analytics Bridge")) {
            LabeledContent("App Store Connect") {
                Label(
                    model.analyticsFeed?.appleAvailable == true ? "Live" : L10n.t("Nicht verfügbar", "Unavailable"),
                    systemImage: model.analyticsFeed?.appleAvailable == true ? "checkmark.circle.fill" : "minus.circle"
                )
                .foregroundStyle(model.analyticsFeed?.appleAvailable == true ? NavoTheme.success : .secondary)
            }

            if let date = model.analyticsFeed?.appleGeneratedAt {
                LabeledContent(L10n.t("Apple Analytics", "Apple analytics"), value: date.formatted(date: .abbreviated, time: .shortened))
            }

            LabeledContent("Google Play") {
                Label(
                    model.analyticsFeed?.googleAvailable == true ? "Live" : L10n.t("Nicht verfügbar", "Unavailable"),
                    systemImage: model.analyticsFeed?.googleAvailable == true ? "checkmark.circle.fill" : "minus.circle"
                )
                .foregroundStyle(model.analyticsFeed?.googleAvailable == true ? NavoTheme.success : .secondary)
            }

            if let date = model.analyticsFeed?.googleGeneratedAt {
                LabeledContent(L10n.t("Google Analytics", "Google analytics"), value: date.formatted(date: .abbreviated, time: .shortened))
            }

            LabeledContent(L10n.t("Kommerzielle Daten", "Commercial data"), value: model.analyticsFeed?.commercialAvailable == true ? L10n.t("Verfügbar", "Available") : "–")
            LabeledContent(L10n.t("Reliability / Vitals", "Reliability / Vitals"), value: model.analyticsFeed?.reliabilityAvailable == true ? L10n.t("Verfügbar", "Available") : "–")
            LabeledContent(L10n.t("Historische Messpunkte", "Historical data points"), value: "\(model.analyticsHistory.count)")

            NavigationLink {
                AnalyticsView()
            } label: {
                Label(L10n.t("Business & Release Intelligence öffnen", "Open Business & Release Intelligence"), systemImage: "chart.line.uptrend.xyaxis")
            }

            Button {
                Task { await model.refreshAnalytics() }
            } label: {
                Label(L10n.t("Analytics laden", "Load analytics"), systemImage: "arrow.down.circle.fill")
            }
            .disabled(model.isRefreshingAnalytics || KeychainStore.githubToken == nil)

            Button {
                Task { await model.requestAnalyticsBridgeRefresh() }
            } label: {
                Label(L10n.t("Analytics-Bridges aktualisieren", "Refresh analytics bridges"), systemImage: "bolt.horizontal.circle.fill")
            }
            .disabled(model.isRefreshingAnalytics || KeychainStore.githubToken == nil)

            if let error = model.analyticsErrorMessage, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(NavoTheme.warning)
            }

            Text(L10n.t(
                "Kommerzielle Kennzahlen und Vitals werden nur angezeigt, wenn die jeweilige Apple-/Google-Reportingquelle sie tatsächlich liefert. Fehlende Werte bleiben leer.",
                "Commercial metrics and Vitals are only shown when the respective Apple/Google reporting source actually provides them. Missing values remain empty."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .listRowBackground(NavoTheme.surface)
    }

    private var intelligenceSection: some View {
        let intelligence = model.intelligence
        return Section(L10n.t("Ops Intelligence", "Ops Intelligence")) {
            LabeledContent(L10n.t("Portfolio-Score", "Portfolio score"), value: "\(intelligence.score)/100")
            LabeledContent(L10n.t("Kritische Signale", "Critical signals"), value: "\(intelligence.criticalCount)")
            LabeledContent(L10n.t("Offene Aktionen", "Open actions"), value: "\(intelligence.actionCount)")
            LabeledContent(L10n.t("Store-Parität", "Store parity"), value: "\(intelligence.alignmentPercent)%")
            LabeledContent(L10n.t("Gespeicherte Store-Ereignisse", "Stored store events"), value: "\(model.storeHistory.count)")

            NavigationLink {
                InsightsView()
            } label: {
                Label(L10n.t("Ops Intelligence öffnen", "Open Ops Intelligence"), systemImage: "brain.head.profile")
            }

            Text(L10n.t(
                "Der Score ist eine deterministische interne Heuristik aus echten Store-, Readiness- und Build-Signalen. Er ist kein Store-Ranking und keine Umsatzprognose.",
                "The score is a deterministic internal heuristic based on real store, readiness and build signals. It is not a store ranking or revenue forecast."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .listRowBackground(NavoTheme.surface)
    }

    private var securitySection: some View {
        Section(L10n.t("Sicherheit", "Security")) {
            Toggle(
                L10n.t("Mit Face ID / Gerätecode sperren", "Lock with Face ID / device passcode"),
                isOn: Binding(
                    get: { security.lockEnabled },
                    set: { enabled in Task { await security.setLockEnabled(enabled) } }
                )
            )
            .disabled(!security.canUseDeviceAuthentication && !security.lockEnabled)

            if let error = security.lastError {
                Text(error).font(.footnote).foregroundStyle(NavoTheme.warning)
            }

            Text(L10n.t(
                "NavoOps sperrt sich beim Verlassen der App. GitHub-Zugangsdaten verbleiben im Keychain und Store-Secrets verbleiben ausschließlich in der Bridge.",
                "NavoOps locks when leaving the app. GitHub credentials remain in Keychain and store secrets remain exclusively in the bridge."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .listRowBackground(NavoTheme.surface)
    }

    private var notificationsSection: some View {
        Section(L10n.t("Benachrichtigungen", "Notifications")) {
            LabeledContent(L10n.t("Status", "Status"), value: notificationStatus)
            Button {
                Task {
                    _ = await NotificationService.shared.requestAuthorization()
                    await refreshNotificationStatus()
                }
            } label: {
                Label(L10n.t("Ops-Warnungen aktivieren", "Enable Ops alerts"), systemImage: "bell.badge.fill")
            }

            Button {
                BackgroundSyncService.shared.schedule()
            } label: {
                Label(L10n.t("Hintergrund-Sync vormerken", "Schedule background sync"), systemImage: "clock.arrow.2.circlepath")
            }

            Text(L10n.t(
                "NavoOps meldet neu erkannte Buildfehler sowie relevante Apple-/Google-Statuswechsel wie Prüfung, Ablehnung oder Livegang lokal auf dem Gerät.",
                "NavoOps locally notifies you about newly detected build failures and relevant Apple/Google state changes such as review, rejection or going live."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .listRowBackground(NavoTheme.surface)
    }

    private var organizationSection: some View {
        Section(L10n.t("Organisation", "Organization")) {
            LabeledContent(L10n.t("Unternehmen", "Company"), value: "Kamilunavo")
            LabeledContent("Bundle ID", value: "com.kamilunavo.NavoOps")
            LabeledContent(L10n.t("Version", "Version"), value: appVersion)
            LabeledContent(L10n.t("Verteilung", "Distribution"), value: "Apple Business Custom App")
            Text(L10n.t(
                "NavoOps ist für eine private Custom-App-Zuweisung an die Kamilunavo-Organisation in App Store Connect vorbereitet.",
                "NavoOps is prepared for private Custom App assignment to the Kamilunavo organization in App Store Connect."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .listRowBackground(NavoTheme.surface)
    }

    private var maintenanceSection: some View {
        Section(L10n.t("Wartung", "Maintenance")) {
            Button {
                Task { await model.forceRefreshAll() }
            } label: {
                if model.isRefreshing || model.isRefreshingStores || model.isRefreshingAnalytics {
                    ProgressView()
                } else {
                    Label(L10n.t("Alles synchronisieren", "Sync everything"), systemImage: "arrow.clockwise")
                }
            }
            .disabled(model.isRefreshing || model.isRefreshingStores || model.isRefreshingAnalytics || KeychainStore.githubToken == nil)

            Button(L10n.t("Store-Verlauf löschen", "Delete store history"), role: .destructive) {
                showHistoryResetConfirmation = true
            }
            .disabled(model.storeHistory.isEmpty)

            Button(L10n.t("Analytics-Verlauf löschen", "Delete analytics history"), role: .destructive) {
                showAnalyticsHistoryResetConfirmation = true
            }
            .disabled(model.analyticsHistory.isEmpty)

            Button(L10n.t("Portfolio zurücksetzen", "Reset portfolio"), role: .destructive) {
                showResetConfirmation = true
            }
        }
        .listRowBackground(NavoTheme.surface)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.3"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "4"
        return "\(version) (\(build))"
    }

    private func refreshNotificationStatus() async {
        let status = await NotificationService.shared.authorizationStatus()
        notificationStatus = switch status {
        case .authorized: L10n.t("Erlaubt", "Authorized")
        case .denied: L10n.t("Abgelehnt", "Denied")
        case .provisional: L10n.t("Vorläufig", "Provisional")
        case .ephemeral: L10n.t("Temporär", "Ephemeral")
        case .notDetermined: L10n.t("Nicht angefragt", "Not requested")
        @unknown default: L10n.t("Unbekannt", "Unknown")
        }
    }
}
