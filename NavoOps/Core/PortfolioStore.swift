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

        let existingIDs = Set(stored.map(\.id))
        let newProducts = seed.filter { !existingIDs.contains($0.id) }
        return (stored + newProducts).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func save(_ products: [ProductApp]) {
        guard let data = try? JSONEncoder().encode(products) else { return }
        defaults.set(data, forKey: key)
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}
