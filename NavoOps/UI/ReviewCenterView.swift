import SwiftUI

struct ReviewCenterView: View {
    @EnvironmentObject private var model: AppModel
    @State private var filter: Filter = .attention

    private enum Filter: CaseIterable, Hashable {
        case attention
        case review
        case all

        var title: String {
            switch self {
            case .attention: return L10n.t("Probleme", "Issues")
            case .review: return L10n.t("In Prüfung", "In Review")
            case .all: return L10n.t("Alle", "All")
            }
        }
    }

    private var snapshots: [StoreAppSnapshot] {
        let items = model.storeFeed?.apps.filter { snapshot in
            switch filter {
            case .attention:
                return snapshot.state == .rejected || snapshot.state == .attention || snapshot.review?.requiresAction == true
            case .review:
                return snapshot.state == .review || snapshot.state == .processing
            case .all:
                return snapshot.review != nil || snapshot.state == .review || snapshot.state == .rejected || snapshot.state == .attention
            }
        } ?? []

        return items.sorted {
            let leftPriority = priority($0)
            let rightPriority = priority($1)
            if leftPriority != rightPriority { return leftPriority > rightPriority }
            return ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast)
        }
    }

    var body: some View {
        ZStack {
            NavoTheme.background.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 12) {
                    sourceNotice

                    Picker(L10n.t("Review-Filter", "Review filter"), selection: $filter) {
                        ForEach(Filter.allCases, id: \.self) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    if snapshots.isEmpty {
                        ContentUnavailableView {
                            Label(L10n.t("Keine Review-Fälle", "No review cases"), systemImage: "checkmark.seal.fill")
                        } description: {
                            Text(L10n.t("Für diesen Filter liegen aktuell keine Review-Daten vor.", "There is currently no review data for this filter."))
                        }
                        .padding(.top, 40)
                    } else {
                        ForEach(snapshots) { snapshot in
                            NavigationLink {
                                ReviewIssueDetailView(snapshot: snapshot)
                            } label: {
                                reviewCard(snapshot)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .refreshable { await model.refreshStores() }
        }
        .navigationTitle(L10n.t("Review Center", "Review Center"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.requestStoreBridgeRefresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel(L10n.t("Store-Review-Daten aktualisieren", "Refresh store review data"))
            }
        }
    }

    private var sourceNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.t("Review Intelligence", "Review Intelligence"), systemImage: "exclamationmark.bubble.fill")
                .font(.headline)
            Text(L10n.t(
                "NavoOps liest alle Review-Zustände, die Apple und Google über ihre offiziellen APIs bereitstellen. Die exakten Reviewer-Nachrichten bzw. Richtliniengründe werden von beiden Plattformen derzeit nicht über die öffentliche API ausgeliefert. Solche Texte kannst du pro Fall lokal ergänzen.",
                "NavoOps reads all review states Apple and Google expose through their official APIs. Exact reviewer messages and policy reasons are currently not exposed by either public API. You can store those texts locally per case."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .navoCard(padding: 14)
    }

    private func reviewCard(_ snapshot: StoreAppSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: snapshot.provider == .apple ? "apple.logo" : "play.rectangle.fill")
                    .font(.headline)
                    .foregroundStyle(providerColor(snapshot.provider))
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.appName)
                        .font(.headline)
                    Text(snapshot.provider.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                stateLabel(snapshot)
            }

            HStack(spacing: 12) {
                if let version = snapshot.version {
                    Label("v\(version)", systemImage: "tag")
                }
                if let build = snapshot.build {
                    Label(L10n.t("Build \(build)", "Build \(build)"), systemImage: "shippingbox")
                }
                if let track = snapshot.review?.track {
                    Label(track, systemImage: "point.3.connected.trianglepath.dotted")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            if let review = snapshot.review {
                if let state = review.displayState {
                    Text(state)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if !review.itemStates.isEmpty {
                    Text(review.itemStates.joined(separator: " · "))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            } else {
                Text(snapshot.rawState)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .navoCard()
    }

    private func stateLabel(_ snapshot: StoreAppSnapshot) -> some View {
        let title: String
        let color: Color
        switch snapshot.state {
        case .rejected, .attention:
            title = L10n.t("Aktion", "Action")
            color = NavoTheme.danger
        case .review:
            title = L10n.t("Prüfung", "Review")
            color = NavoTheme.accent
        case .processing:
            title = L10n.t("Verarbeitung", "Processing")
            color = NavoTheme.warning
        case .live:
            title = "Live"
            color = NavoTheme.success
        default:
            title = snapshot.state.rawValue
            color = .secondary
        }

        return Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func providerColor(_ provider: StoreProvider) -> Color {
        provider == .apple ? NavoTheme.accent : NavoTheme.cyan
    }

    private func priority(_ snapshot: StoreAppSnapshot) -> Int {
        if snapshot.state == .rejected || snapshot.review?.requiresAction == true { return 3 }
        if snapshot.state == .attention { return 2 }
        if snapshot.state == .review { return 1 }
        return 0
    }
}

struct ReviewIssueDetailView: View {
    @EnvironmentObject private var model: AppModel
    let snapshot: StoreAppSnapshot

    @State private var localMessage = ""
    @State private var saved = false

    private let noteStore = ReviewNoteStore()

    private var product: ProductApp? {
        model.products.first(where: snapshot.matches)
    }

    private var tags: [String] {
        ReviewNoteStore.tags(in: localMessage)
    }

    var body: some View {
        Form {
            Section(L10n.t("Fall", "Case")) {
                LabeledContent(L10n.t("App", "App"), value: snapshot.appName)
                LabeledContent(L10n.t("Plattform", "Platform"), value: snapshot.provider.title)
                if let version = snapshot.version { LabeledContent(L10n.t("Version", "Version"), value: version) }
                if let build = snapshot.build { LabeledContent(L10n.t("Build", "Build"), value: build) }
                LabeledContent(L10n.t("Store-Status", "Store status"), value: snapshot.rawState)
                if let updatedAt = snapshot.updatedAt {
                    LabeledContent(L10n.t("Aktualisiert", "Updated")) { Text(updatedAt, style: .relative) }
                }
            }
            .listRowBackground(NavoTheme.surface)

            if let review = snapshot.review {
                Section(L10n.t("Offizielle Review-Daten", "Official review data")) {
                    if let submission = review.submissionState {
                        LabeledContent(L10n.t("Submission", "Submission"), value: submission)
                    }
                    if let track = review.track {
                        LabeledContent("Track", value: track)
                    }
                    if let lifecycle = review.lifecycleState {
                        LabeledContent(L10n.t("Lifecycle", "Lifecycle"), value: lifecycle)
                    }
                    if !review.itemStates.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L10n.t("Review-Items", "Review items"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(review.itemStates.joined(separator: "\n"))
                                .font(.caption.monospaced())
                        }
                    }
                    if let submittedAt = review.submittedAt {
                        LabeledContent(L10n.t("Eingereicht", "Submitted")) { Text(submittedAt, style: .relative) }
                    }
                    if let reason = review.reason, !reason.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L10n.t("Prüfgrund", "Review reason"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(reason)
                        }
                    } else {
                        Label(
                            L10n.t(
                                "Der exakte Reviewer-Text ist über die öffentliche Store-API nicht verfügbar.",
                                "The exact reviewer message is not available through the public store API."
                            ),
                            systemImage: "lock.doc"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    if let urlString = review.consoleURL, let url = URL(string: urlString) {
                        Link(
                            snapshot.provider == .apple ? L10n.t("In App Store Connect öffnen", "Open in App Store Connect") : L10n.t("In Play Console öffnen", "Open in Play Console"),
                            destination: url
                        )
                    }
                }
                .listRowBackground(NavoTheme.surface)
            }

            Section(L10n.t("Beanstandung / Nachricht", "Issue / message")) {
                Text(L10n.t(
                    "Wenn Apple oder Google einen konkreten Richtlinien-Text zeigt, kannst du ihn hier einfügen. Er bleibt nur lokal auf diesem Gerät.",
                    "If Apple or Google shows a specific policy message, paste it here. It stays local on this device."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)

                TextEditor(text: $localMessage)
                    .frame(minHeight: 150)
                    .font(.body)

                if !tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text("Guideline \(tag)")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(NavoTheme.warning.opacity(0.14), in: Capsule())
                        }
                    }
                }

                Button {
                    saveLocalMessage()
                } label: {
                    Label(saved ? L10n.t("Gespeichert", "Saved") : L10n.t("Lokal speichern", "Save locally"), systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                }
            }
            .listRowBackground(NavoTheme.surface)

            if let product {
                Section(L10n.t("Aktionen", "Actions")) {
                    NavigationLink(value: product.id) {
                        Label(L10n.t("App-Details öffnen", "Open app details"), systemImage: "app.badge")
                    }
                }
                .listRowBackground(NavoTheme.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(NavoTheme.background)
        .navigationTitle(L10n.t("Review-Details", "Review Details"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadLocalMessage() }
        .onChange(of: localMessage) { _, _ in saved = false }
    }

    private func loadLocalMessage() {
        localMessage = noteStore.load()[snapshot.id]?.message ?? ""
        saved = !localMessage.isEmpty
    }

    private func saveLocalMessage() {
        let trimmed = localMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        var notes = noteStore.load()
        if trimmed.isEmpty {
            notes.removeValue(forKey: snapshot.id)
        } else {
            notes[snapshot.id] = ReviewNote(
                snapshotID: snapshot.id,
                message: trimmed,
                tags: ReviewNoteStore.tags(in: trimmed),
                updatedAt: .now
            )
        }
        noteStore.save(notes)
        localMessage = trimmed
        saved = true
    }
}
