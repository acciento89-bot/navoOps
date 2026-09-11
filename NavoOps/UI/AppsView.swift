import SwiftUI

struct AppsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""

    private var filtered: [ProductApp] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return model.products }
        return model.products.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.repository.localizedCaseInsensitiveContains(query) ||
            $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    var body: some View {
        ZStack {
            NavoTheme.background.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filtered) { product in
                        NavigationLink(value: product.id) {
                            ProductCard(product: product, health: model.health(for: product))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(L10n.t("Apps", "Apps"))
        .searchable(text: $query, prompt: L10n.t("App, Repository oder Tag", "App, repository or tag"))
    }
}

struct ProductDetailView: View {
    @EnvironmentObject private var model: AppModel
    @State private var product: ProductApp
    @State private var showIssueComposer = false

    init(product: ProductApp) {
        _product = State(initialValue: product)
    }

    var body: some View {
        Form {
            summarySection
            intelligenceSection
            releaseSection
            readinessSection
            githubSection
            storeSection
            notesSection
        }
        .scrollContentBackground(.hidden)
        .background(NavoTheme.background)
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: product) { updated in
            model.update(updated)
        }
        .sheet(isPresented: $showIssueComposer) {
            IssueComposerView(product: product)
                .environmentObject(model)
        }
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(NavoTheme.brandGradient)
                    .frame(width: 62, height: 62)
                    .overlay(Text(String(product.name.prefix(1))).font(.title2.bold()).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 5) {
                    Text(product.name).font(.title3.bold())
                    Text(product.repository).font(.caption.monospaced()).foregroundStyle(.secondary)
                    Text(product.monetization.localizedTitle).font(.caption).foregroundStyle(NavoTheme.accent)
                }
            }
        }
        .listRowBackground(NavoTheme.surface)
    }

    private var intelligenceSection: some View {
        let insights = model.insights(for: product)
        let actionable = insights.filter { $0.severity != .info }
        let snapshot = model.productIntelligence.first { $0.product.id == product.id }

        return Section(L10n.t("Ops Intelligence", "Ops Intelligence")) {
            HStack {
                Label(L10n.t("Produkt-Score", "Product score"), systemImage: "brain.head.profile")
                Spacer()
                Text("\(snapshot?.score ?? 100)")
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(productScoreColor(snapshot?.score ?? 100))
            }

            if product.supportsApple && product.supportsGoogle {
                HStack {
                    Text(L10n.t("Store-Parität", "Store parity"))
                    Spacer()
                    Label(
                        model.isCrossPlatformAligned(product) ? L10n.t("Synchron", "Aligned") : L10n.t("Drift", "Drift"),
                        systemImage: model.isCrossPlatformAligned(product) ? "checkmark.circle.fill" : "arrow.left.arrow.right.circle.fill"
                    )
                    .font(.caption.weight(.bold))
                    .foregroundStyle(model.isCrossPlatformAligned(product) ? NavoTheme.success : NavoTheme.warning)
                }
            }

            if actionable.isEmpty {
                Label(L10n.t("Keine offenen operativen Risiken erkannt.", "No open operational risks detected."), systemImage: "checkmark.seal.fill")
                    .foregroundStyle(NavoTheme.success)
            } else {
                ForEach(actionable.prefix(5)) { insight in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 7) {
                            Image(systemName: insight.kind.systemImage)
                                .foregroundStyle(insight.severity.color)
                            Text(insight.title)
                                .font(.subheadline.weight(.semibold))
                        }
                        Text(insight.recommendation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            NavigationLink {
                InsightsView()
            } label: {
                Label(L10n.t("Gesamte Ops Intelligence öffnen", "Open full Ops Intelligence"), systemImage: "chart.xyaxis.line")
            }
        }
        .listRowBackground(NavoTheme.surface)
    }

    private func productScoreColor(_ score: Int) -> Color {
        if score >= 85 { return NavoTheme.success }
        if score >= 65 { return NavoTheme.warning }
        return NavoTheme.danger
    }

    private var releaseSection: some View {
        Section(L10n.t("Release", "Release")) {
            HStack {
                Text(L10n.t("Live-Version", "Live version"))
                Spacer()
                Text(model.resolvedVersion(for: product))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(L10n.t("Live-Build", "Live build"))
                Spacer()
                Text(model.resolvedBuild(for: product))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            TextField(L10n.t("Lokale Version / Fallback", "Local version / fallback"), text: $product.version)
                .textInputAutocapitalization(.never)
            TextField(L10n.t("Lokaler Build / Fallback", "Local build / fallback"), text: $product.build)
                .keyboardType(.numberPad)

            if product.supportsApple {
                HStack {
                    Text("Apple")
                    Spacer()
                    StoreStateBadge(label: model.storeSnapshot(for: product, provider: .apple) == nil ? L10n.t("Lokal", "Local") : "Live", state: model.resolvedAppleState(for: product))
                }
                if model.storeSnapshot(for: product, provider: .apple) == nil {
                    Picker(L10n.t("Apple Fallback", "Apple fallback"), selection: $product.appleState) {
                        ForEach(ProductApp.StoreState.allCases, id: \.self) { state in
                            Text(state.localizedTitle).tag(state)
                        }
                    }
                }
            }

            if product.supportsGoogle {
                HStack {
                    Text("Google Play")
                    Spacer()
                    StoreStateBadge(label: model.storeSnapshot(for: product, provider: .google) == nil ? L10n.t("Lokal", "Local") : "Live", state: model.resolvedGoogleState(for: product))
                }
                if model.storeSnapshot(for: product, provider: .google) == nil {
                    Picker(L10n.t("Google Fallback", "Google fallback"), selection: $product.googleState) {
                        ForEach(ProductApp.StoreState.allCases, id: \.self) { state in
                            Text(state.localizedTitle).tag(state)
                        }
                    }
                }
            }

            Picker(L10n.t("Monetarisierung", "Monetization"), selection: $product.monetization) {
                ForEach(ProductApp.Monetization.allCases, id: \.self) { value in
                    Text(value.localizedTitle).tag(value)
                }
            }
        }
        .listRowBackground(NavoTheme.surface)
    }

    private var readinessSection: some View {
        Section(L10n.t("Store Readiness", "Store Readiness")) {
            checklistToggle(L10n.t("App-Icon", "App icon"), $product.checklist.icon)
            checklistToggle(L10n.t("Screenshots DE", "Screenshots DE"), $product.checklist.screenshotsDE)
            checklistToggle(L10n.t("Screenshots EN", "Screenshots EN"), $product.checklist.screenshotsEN)
            checklistToggle(L10n.t("Datenschutz-URL", "Privacy URL"), $product.checklist.privacyURL)
            checklistToggle(L10n.t("Store-Text DE", "Store text DE"), $product.checklist.storeTextDE)
            checklistToggle(L10n.t("Store-Text EN", "Store text EN"), $product.checklist.storeTextEN)

            if product.supportsApple {
                DisclosureGroup("Apple") {
                    checklistToggle("EULA", $product.checklist.eula)
                    checklistToggle(L10n.t("App-Datenschutz", "App Privacy"), $product.checklist.applePrivacy)
                    checklistToggle(L10n.t("Review-Zugang", "Review access"), $product.checklist.appleReviewAccess)
                    checklistToggle(L10n.t("StoreKit / IAP", "StoreKit / IAP"), $product.checklist.appleBilling)
                }
                ReadinessBar(label: "Apple", completed: product.checklist.appleCompleted, total: product.checklist.appleTotal)
            }

            if product.supportsGoogle {
                DisclosureGroup("Google Play") {
                    checklistToggle(L10n.t("Vorstellungsgrafik", "Feature graphic"), $product.checklist.googleFeatureGraphic)
                    checklistToggle(L10n.t("Datensicherheit", "Data safety"), $product.checklist.googleDataSafety)
                    checklistToggle(L10n.t("App-Zugriff", "App access"), $product.checklist.googleAppAccess)
                    checklistToggle(L10n.t("Play Billing", "Play Billing"), $product.checklist.googleBilling)
                }
                ReadinessBar(label: "Google Play", completed: product.checklist.googleCompleted, total: product.checklist.googleTotal, tint: NavoTheme.cyan)
            }
        }
        .listRowBackground(NavoTheme.surface)
    }

    private var githubSection: some View {
        Section("GitHub") {
            LabeledContent(L10n.t("Repository", "Repository"), value: product.repository)

            if let health = model.health(for: product) {
                HStack {
                    Text(L10n.t("Build", "Build"))
                    Spacer()
                    BuildBadge(state: health.buildState)
                }

                if let message = health.latestCommitMessage {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("Letzter Commit", "Latest commit"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(message)
                            .font(.subheadline)
                            .lineLimit(3)
                    }
                }

                if health.buildState == .failure, health.workflowURL != nil {
                    WorkflowRerunButton(product: product)
                }

                if let urlString = health.workflowURL, let url = URL(string: urlString) {
                    Link(L10n.t("Letzten Workflow öffnen", "Open latest workflow"), destination: url)
                }
            } else {
                Text(L10n.t("Noch nicht synchronisiert", "Not synced yet"))
                    .foregroundStyle(.secondary)
            }

            let prs = model.pullRequests(for: product)
            let issues = model.issues(for: product)
            LabeledContent(L10n.t("Offene PRs", "Open PRs"), value: "\(prs.count)")
            LabeledContent(L10n.t("Offene Issues", "Open issues"), value: "\(issues.count)")

            Button {
                showIssueComposer = true
            } label: {
                Label(L10n.t("GitHub-Issue erstellen", "Create GitHub issue"), systemImage: "plus.circle.fill")
            }

            if let url = URL(string: "https://github.com/acciento89-bot/\(product.repository)") {
                Link(L10n.t("Repository öffnen", "Open repository"), destination: url)
            }
        }
        .listRowBackground(NavoTheme.surface)
    }

    private var storeSection: some View {
        Section(L10n.t("Store-Informationen", "Store Information")) {
            if let apple = model.storeSnapshot(for: product, provider: .apple) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("App Store Connect · LIVE", systemImage: "apple.logo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NavoTheme.success)
                    Text("\(apple.rawState) · v\(apple.version ?? "–") · Build \(apple.build ?? "–")")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    if let duration = model.observedStateDuration(for: product, provider: .apple) {
                        Text(L10n.t("Aktueller Status seit mindestens ", "Current status observed for at least ") + duration.formattedOpsDuration)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if let google = model.storeSnapshot(for: product, provider: .google) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Google Play · LIVE", systemImage: "play.rectangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NavoTheme.success)
                    Text("\(google.rawState) · v\(google.version ?? "–") · Build \(google.build ?? "–")")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    if let duration = model.observedStateDuration(for: product, provider: .google) {
                        Text(L10n.t("Aktueller Status seit mindestens ", "Current status observed for at least ") + duration.formattedOpsDuration)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if product.supportsApple {
                TextField("Apple Bundle ID", text: Binding(
                    get: { product.storeInfo.appleBundleID ?? "" },
                    set: { product.storeInfo.appleBundleID = $0.isEmpty ? nil : $0 }
                ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }

            if product.supportsGoogle {
                TextField("Android Package ID", text: Binding(
                    get: { product.storeInfo.androidPackageID ?? "" },
                    set: { product.storeInfo.androidPackageID = $0.isEmpty ? nil : $0 }
                ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }

            if let privacy = product.storeInfo.privacyURL, let url = URL(string: privacy) {
                Link(L10n.t("Datenschutz öffnen", "Open privacy policy"), destination: url)
            }
            if let support = product.storeInfo.supportURL, let url = URL(string: support) {
                Link(L10n.t("Support öffnen", "Open support"), destination: url)
            }
        }
        .listRowBackground(NavoTheme.surface)
    }

    private var notesSection: some View {
        Section(L10n.t("Interne Notizen", "Internal Notes")) {
            TextField(L10n.t("Release-Notiz", "Release note"), text: $product.notes, axis: .vertical)
                .lineLimit(3...8)
        }
        .listRowBackground(NavoTheme.surface)
    }

    private func checklistToggle(_ title: String, _ value: Binding<Bool>) -> some View {
        Toggle(title, isOn: value)
    }
}

private struct WorkflowRerunButton: View {
    @EnvironmentObject private var model: AppModel
    let product: ProductApp
    @State private var isRunning = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task { await rerun() }
            } label: {
                if isRunning {
                    HStack { ProgressView(); Text(L10n.t("Workflow wird neu gestartet …", "Restarting workflow …")) }
                } else {
                    Label(L10n.t("Fehlgeschlagene Jobs neu starten", "Rerun failed jobs"), systemImage: "arrow.clockwise.circle.fill")
                }
            }
            .disabled(isRunning)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(NavoTheme.danger)
            }
        }
    }

    private func rerun() async {
        isRunning = true
        errorMessage = nil
        defer { isRunning = false }
        do {
            try await model.rerunFailedWorkflow(for: product)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct IssueComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel

    let product: ProductApp
    @State private var title: String
    @State private var bodyText: String
    @State private var isSending = false
    @State private var errorMessage: String?

    init(product: ProductApp) {
        self.product = product
        _title = State(initialValue: "[\(product.name)] ")
        _bodyText = State(initialValue: "NavoOps\n\nVersion: \(product.version)\nBuild: \(product.build)\nApple: \(product.appleState.localizedTitle)\nGoogle: \(product.googleState.localizedTitle)\n")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.t("Issue", "Issue")) {
                    TextField(L10n.t("Titel", "Title"), text: $title)
                    TextField(L10n.t("Beschreibung", "Description"), text: $bodyText, axis: .vertical)
                        .lineLimit(8...18)
                }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(NavoTheme.danger)
                    }
                }
            }
            .navigationTitle(L10n.t("Neues GitHub-Issue", "New GitHub Issue"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Abbrechen", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSending { ProgressView() } else { Text(L10n.t("Erstellen", "Create")) }
                    }
                    .disabled(isSending || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func submit() async {
        isSending = true
        defer { isSending = false }
        do {
            _ = try await model.createIssue(for: product, title: title.trimmingCharacters(in: .whitespacesAndNewlines), body: bodyText)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension TimeInterval {
    var formattedOpsDuration: String {
        let hours = Int(self / 3600)
        if hours < 1 { return L10n.t("< 1 Std.", "< 1 hr") }
        if hours < 24 { return L10n.t("\(hours) Std.", "\(hours) hr") }
        let days = max(1, hours / 24)
        return L10n.t("\(days) Tage", "\(days) days")
    }
}
