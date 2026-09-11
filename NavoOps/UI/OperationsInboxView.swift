import SwiftUI

struct OperationsInboxView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            NavoTheme.background.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 12) {
                    if model.operationsInbox.isEmpty {
                        ContentUnavailableView {
                            Label(L10n.t("Keine offenen Vorgänge", "No open operations"), systemImage: "checkmark.seal.fill")
                        } description: {
                            Text(L10n.t("Builds und Store-Zustände benötigen aktuell keine Aktion.", "Builds and store states currently need no action."))
                        }
                        .frame(minHeight: 260)
                        .navoCard()
                    } else {
                        ForEach(model.operationsInbox) { item in
                            if let productID = item.productID {
                                NavigationLink(value: productID) {
                                    inboxCard(item)
                                }
                                .buttonStyle(.plain)
                            } else {
                                inboxCard(item)
                            }
                        }
                    }
                }
                .padding()
            }
            .refreshable { await model.refreshAll() }
        }
        .navigationTitle(L10n.t("Operations Inbox", "Operations Inbox"))
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

    private func inboxCard(_ item: OperationsInboxItem) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon(for: item))
                .font(.headline)
                .foregroundStyle(color(for: item.priority))
                .frame(width: 42, height: 42)
                .background(color(for: item.priority).opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Text(item.date == .distantPast ? "" : item.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                Text(priorityTitle(item.priority))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color(for: item.priority))
            }
        }
        .navoCard(padding: 14)
    }

    private func icon(for item: OperationsInboxItem) -> String {
        switch item.kind {
        case .build: return "hammer.fill"
        case .apple: return "apple.logo"
        case .google: return "play.rectangle.fill"
        case .release: return "shippingbox.fill"
        case .pullRequest: return "arrow.triangle.pull"
        }
    }

    private func color(for priority: OperationsInboxItem.Priority) -> Color {
        switch priority {
        case .critical: return NavoTheme.danger
        case .action: return NavoTheme.warning
        case .waiting: return NavoTheme.accent
        case .info: return NavoTheme.cyan
        }
    }

    private func priorityTitle(_ priority: OperationsInboxItem.Priority) -> String {
        switch priority {
        case .critical: return L10n.t("SOFORT PRÜFEN", "CHECK NOW")
        case .action: return L10n.t("AKTION OFFEN", "ACTION NEEDED")
        case .waiting: return L10n.t("WARTET EXTERN", "WAITING EXTERNALLY")
        case .info: return L10n.t("INFO", "INFO")
        }
    }
}
