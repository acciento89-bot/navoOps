import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            productNavigation { DashboardView() }
                .tabItem { Label(L10n.t("Übersicht", "Dashboard"), systemImage: "square.grid.2x2.fill") }

            productNavigation { AppsView() }
                .tabItem { Label(L10n.t("Apps", "Apps"), systemImage: "square.stack.3d.up.fill") }

            productNavigation { ReleaseCenterView() }
                .tabItem { Label(L10n.t("Releases", "Releases"), systemImage: "shippingbox.fill") }

            NavigationStack { GitHubView() }
                .tabItem { Label("GitHub", systemImage: "point.3.connected.trianglepath.dotted") }

            NavigationStack { SettingsView() }
                .tabItem { Label(L10n.t("Einstellungen", "Settings"), systemImage: "gearshape.fill") }
        }
        .tint(NavoTheme.accent)
        .task {
            if KeychainStore.githubToken != nil, model.lastRefresh == nil {
                await model.refreshAll()
            }
        }
    }

    @ViewBuilder
    private func productNavigation<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .navigationDestination(for: String.self) { productID in
                    ProductRouteView(productID: productID)
                }
        }
    }
}

private struct ProductRouteView: View {
    @EnvironmentObject private var model: AppModel
    let productID: String

    var body: some View {
        if let product = model.products.first(where: { $0.id == productID }) {
            ProductDetailView(product: product)
        } else {
            ContentUnavailableView {
                Label {
                    Text(L10n.t("App nicht gefunden", "App not found"))
                } icon: {
                    Image(systemName: "questionmark.app")
                }
            }
        }
    }
}
