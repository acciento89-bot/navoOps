import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2.fill") }
            NavigationStack { AppsView() }
                .tabItem { Label("Apps", systemImage: "square.stack.3d.up.fill") }
            NavigationStack { GitHubView() }
                .tabItem { Label("GitHub", systemImage: "point.3.connected.trianglepath.dotted") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.blue)
        .task {
            if KeychainStore.githubToken != nil {
                await model.refreshGitHub()
            }
        }
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("KAMILUNAVO")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.blue)
                    Text("Operations Control Center")
                        .font(.largeTitle.bold())
                    Text("Portfolio, Releases und GitHub an einem Ort.")
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricCard(title: "Apps", value: "\(model.products.count)", icon: "square.stack.3d.up")
                    MetricCard(title: "Live", value: "\(model.liveCount)", icon: "checkmark.seal.fill")
                    MetricCard(title: "In Review", value: "\(model.reviewCount)", icon: "hourglass")
                    MetricCard(title: "Attention", value: "\(model.attentionCount)", icon: "exclamationmark.triangle.fill")
                }

                SectionHeader(title: "Needs attention")
                ForEach(model.products.filter { $0.appleState == .attention || $0.googleState == .attention }) { product in
                    ProductRow(product: product)
                }

                SectionHeader(title: "Activity")
                if model.activities.isEmpty {
                    ContentUnavailableView("Noch keine Aktivität", systemImage: "bolt.horizontal.circle", description: Text("GitHub synchronisieren, um Pull Requests und Issues zu sehen."))
                        .frame(minHeight: 180)
                } else {
                    ForEach(model.activities.prefix(8)) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.icon)
                                .foregroundStyle(item.tone.color)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                                Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.date, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("NavoOps")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.refreshGitHub() }
                } label: {
                    if model.isRefreshing { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                }
                .disabled(model.isRefreshing)
            }
        }
    }
}

private struct AppsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""

    var filtered: [ProductApp] {
        guard !query.isEmpty else { return model.products }
        return model.products.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.repository.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List(filtered) { product in
            NavigationLink(value: product.id) { ProductRow(product: product) }
        }
        .searchable(text: $query, prompt: "App oder Repository")
        .navigationTitle("Apps")
        .navigationDestination(for: UUID.self) { id in
            if let product = model.products.first(where: { $0.id == id }) {
                ProductDetailView(product: product)
            }
        }
    }
}

private struct ProductDetailView: View {
    @EnvironmentObject private var model: AppModel
    @State var product: ProductApp

    var body: some View {
        Form {
            Section("Release") {
                LabeledContent("Version", value: product.version)
                LabeledContent("Build", value: product.build)
                Picker("Apple", selection: $product.appleState) {
                    ForEach(ProductApp.StoreState.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("Google", selection: $product.googleState) {
                    ForEach(ProductApp.StoreState.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            }

            Section("Store Readiness") {
                ChecklistToggle(title: "App Icon", value: $product.checklist.icon)
                ChecklistToggle(title: "Screenshots DE", value: $product.checklist.screenshotsDE)
                ChecklistToggle(title: "Screenshots EN", value: $product.checklist.screenshotsEN)
                ChecklistToggle(title: "Privacy URL", value: $product.checklist.privacyURL)
                ChecklistToggle(title: "EULA", value: $product.checklist.eula)
                ChecklistToggle(title: "Review Access", value: $product.checklist.reviewAccess)
                ChecklistToggle(title: "Billing / IAP", value: $product.checklist.billing)
                ChecklistToggle(title: "Store Text DE", value: $product.checklist.storeTextDE)
                ChecklistToggle(title: "Store Text EN", value: $product.checklist.storeTextEN)
                ProgressView(value: Double(product.checklist.completed), total: Double(product.checklist.total))
            }

            Section("Repository") {
                LabeledContent("GitHub", value: product.repository)
                if let url = URL(string: "https://github.com/acciento89-bot/\(product.repository)") {
                    Link("Repository öffnen", destination: url)
                }
            }

            Section("Notizen") {
                TextField("Interne Notiz", text: $product.notes, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.update(product) }
    }
}

private struct GitHubView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            if let error = model.errorMessage {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
            }

            Section("Repositories") {
                if model.repositories.isEmpty {
                    Text("Noch nicht synchronisiert").foregroundStyle(.secondary)
                } else {
                    ForEach(model.repositories) { repo in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(repo.name).fontWeight(.semibold)
                                Text(repo.fullName).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if repo.isPrivate { Image(systemName: "lock.fill").foregroundStyle(.secondary) }
                        }
                    }
                }
            }

            Section("Open Pull Requests") {
                if model.pullRequests.isEmpty { Text("Keine geladen").foregroundStyle(.secondary) }
                ForEach(model.pullRequests) { pr in
                    Link(destination: URL(string: pr.htmlURL)!) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("#\(pr.number) \(pr.title)").fontWeight(.semibold)
                            Text(pr.repository).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Open Issues") {
                if model.issues.isEmpty { Text("Keine geladen").foregroundStyle(.secondary) }
                ForEach(model.issues) { issue in
                    Link(destination: URL(string: issue.htmlURL)!) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("#\(issue.number) \(issue.title)").fontWeight(.semibold)
                            Text(issue.repository).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("GitHub")
        .refreshable { await model.refreshGitHub() }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var token = KeychainStore.githubToken ?? ""
    @State private var saved = false

    var body: some View {
        Form {
            Section("GitHub") {
                SecureField("Fine-grained token", text: $token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Token sicher speichern") {
                    KeychainStore.githubToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
                    saved = true
                    Task { await model.refreshGitHub() }
                }
                if saved { Label("In Keychain gespeichert", systemImage: "checkmark.shield.fill").foregroundStyle(.green) }
                Button("Token entfernen", role: .destructive) {
                    KeychainStore.githubToken = nil
                    token = ""
                    saved = false
                }
            }

            Section("Organisation") {
                LabeledContent("Name", value: "Kamilunavo")
                LabeledContent("App", value: "NavoOps 1.0")
                Text("Für interne Verteilung über Apple Business Manager / Custom Apps vorgesehen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon).foregroundStyle(.blue)
                Spacer()
                Text(value).font(.system(size: 30, weight: .bold, design: .rounded))
            }
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct ProductRow: View {
    let product: ProductApp

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue.gradient)
                .frame(width: 44, height: 44)
                .overlay(Text(String(product.name.prefix(1))).font(.headline.bold()).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name).fontWeight(.semibold)
                Text(product.repository).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                StateBadge(state: product.appleState, prefix: "A")
                if product.platforms.contains(.android) { StateBadge(state: product.googleState, prefix: "G") }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StateBadge: View {
    let state: ProductApp.StoreState
    let prefix: String

    var color: Color {
        switch state {
        case .live: return .green
        case .review, .internalTest: return .blue
        case .attention: return .orange
        case .development: return .secondary
        }
    }

    var body: some View {
        Text("\(prefix) · \(state.rawValue)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
    }
}

private struct ChecklistToggle: View {
    let title: String
    @Binding var value: Bool
    var body: some View { Toggle(title, isOn: $value) }
}

private struct SectionHeader: View {
    let title: String
    var body: some View { Text(title).font(.title3.bold()).padding(.top, 4) }
}
