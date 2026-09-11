import Foundation

extension AppModel {
    var storeInventory: [StoreAppSnapshot] {
        (storeFeed?.apps ?? []).sorted {
            if $0.provider != $1.provider { return $0.provider.rawValue < $1.provider.rawValue }
            return $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
        }
    }

    var untrackedStoreApps: [StoreAppSnapshot] {
        storeInventory.filter { snapshot in
            !products.contains(where: snapshot.matches)
        }
    }

    func product(matching snapshot: StoreAppSnapshot) -> ProductApp? {
        products.first(where: snapshot.matches)
    }
}
