import SwiftUI

struct GitHubView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            NavoTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    summary

                    if let error = model.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(NavoTheme.warning)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .navoCard()
                    }

                    repositoryHealth
                    pullRequests
                    issues
                }
                .padding()
            }
            .refreshable { await model.refreshGitHub() }
        }
        .navigationTitle("GitHub")
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

    private var summary: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
            MetricCard(title: L10n.t("Repositories", "Repositories"), value: "\(model.repositories.count)", icon: "shippingbox.fill")
            MetricCard(title: L10n.t("Offene PRs", "Open PRs"), value: "\(model.pullRequests.count)", icon: "arrow.triangle.pull")
            MetricCard(title: L10n.t("Offene Issues", "Open issues"), value: "\(model.issues.count)", icon: "exclamationmark.circle.fill", tint: NavoTheme.warning)
            MetricCard(title: L10n.t("Buildfehler", "Build failures"), value: "\(model.buildFailureCount)", icon: "xmark.octagon.fill", tint: model.buildFailureCount > 0 ? NavoTheme.danger : NavoTheme.success)
        }
    }

    private var repositoryHealth: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("Repository Health", "Repository Health"), subtitle: L10n.t("Letzter Commit und letzter GitHub-Actions-Lauf", "Latest commit and latest GitHub Actions run"))

            if model.healthByRepository.isEmpty {
                emptyCard(L10n.t("Noch keine Repository-Daten geladen.", "No repository data loaded yet."), icon: "point.3.connected.trianglepath.dotted")
            } else {
                ForEach(model.healthByRepository.values.sorted(by: { $0.repository.localizedCaseInsensitiveCompare($1.repository) == .orderedAscending })) { health in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(health.repository).font(.headline.monospaced())
                            Spacer()
                            BuildBadge(state: health.buildState)
                        }
                        if let message = health.latestCommitMessage {
                            Text(message).font(.subheadline).lineLimit(2)
                        }
                        HStack {
                            if let date = health.latestCommitAt {
                                Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                            }
                            Spacer()
                            if let urlString = health.workflowURL, let url = URL(string: urlString) {
                                Link(L10n.t("Workflow", "Workflow"), destination: url)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .navoCard()
                }
            }
        }
    }

    private var pullRequests: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("Offene Pull Requests", "Open Pull Requests"))
            if model.pullRequests.isEmpty {
                emptyCard(L10n.t("Keine offenen Pull Requests geladen.", "No open pull requests loaded."), icon: "arrow.triangle.pull")
            } else {
                ForEach(model.pullRequests.prefix(20)) { pr in
                    if let url = URL(string: pr.htmlURL) {
                        Link(destination: url) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: pr.draft ? "pencil.circle.fill" : "arrow.triangle.pull")
                                    .foregroundStyle(NavoTheme.accent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("#\(pr.number) · \(pr.title)").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                    Text(pr.repository).font(.caption.monospaced()).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .navoCard(padding: 13)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var issues: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("Offene Issues", "Open Issues"))
            if model.issues.isEmpty {
                emptyCard(L10n.t("Keine offenen Issues geladen.", "No open issues loaded."), icon: "exclamationmark.circle")
            } else {
                ForEach(model.issues.prefix(20)) { issue in
                    if let url = URL(string: issue.htmlURL) {
                        Link(destination: url) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(NavoTheme.warning)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("#\(issue.number) · \(issue.title)").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                    Text(issue.repository).font(.caption.monospaced()).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .navoCard(padding: 13)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func emptyCard(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            .navoCard()
    }
}
