import Foundation

struct PortfolioStore {
    private let defaults: UserDefaults
    private let key = "navoops.portfolio.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadMerged(with seed: [ProductApp]) -> [ProductApp] {
        guard
            let data = defaults.data(forKey: key),
            let stored = try? JSONDecoder().decode([ProductApp].self, from: data)
        else {
            return seed
        }

        let canonicalByID = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
        var merged = stored.map { storedProduct -> ProductApp in
            guard let canonical = canonicalByID[storedProduct.id] else { return storedProduct }
            var product = storedProduct

            // Keep operational/user-edited release data, but migrate newly verified
            // technical metadata required for live store matching.
            product.platforms.formUnion(canonical.platforms)
            if product.storeInfo.appleBundleID?.isEmpty != false {
                product.storeInfo.appleBundleID = canonical.storeInfo.appleBundleID
            }
            if product.storeInfo.androidPackageID?.isEmpty != false {
                product.storeInfo.androidPackageID = canonical.storeInfo.androidPackageID
            }
            if product.storeInfo.privacyURL?.isEmpty != false {
                product.storeInfo.privacyURL = canonical.storeInfo.privacyURL
            }
            if product.storeInfo.supportURL?.isEmpty != false {
                product.storeInfo.supportURL = canonical.storeInfo.supportURL
            }
            if product.storeInfo.marketingURL?.isEmpty != false {
                product.storeInfo.marketingURL = canonical.storeInfo.marketingURL
            }
            product.tags = Array(Set(product.tags + canonical.tags)).sorted()
            return product
        }

        let existingIDs = Set(merged.map(\.id))
        merged.append(contentsOf: seed.filter { !existingIDs.contains($0.id) })
        return merged.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func save(_ products: [ProductApp]) {
        guard let data = try? JSONEncoder().encode(products) else { return }
        defaults.set(data, forKey: key)
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}
