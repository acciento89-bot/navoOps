import Foundation

struct AnalyticsHistoryStore {
    private let defaults: UserDefaults
    private let key = "navoops.analytics-history.v1"
    private let retention: TimeInterval = 180 * 24 * 60 * 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [AnalyticsObservation] {
        guard
            let data = defaults.data(forKey: key),
            let observations = try? JSONDecoder().decode([AnalyticsObservation].self, from: data)
        else { return [] }
        return prune(observations)
    }

    func record(feed: AnalyticsFeed, products: [ProductApp], existing: [AnalyticsObservation]) -> [AnalyticsObservation] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for snapshot in feed.apps {
            guard let product = products.first(where: { snapshot.matches($0) }) else { continue }
            let observedAt = snapshot.periodEnd ?? feed.generatedAt
            let observation = AnalyticsObservation(
                productID: product.id,
                provider: snapshot.provider,
                observedAt: observedAt,
                dayKey: formatter.string(from: observedAt),
                units: snapshot.units,
                downloads: snapshot.downloads,
                proceeds: snapshot.proceeds,
                activeSubscriptions: snapshot.activeSubscriptions,
                crashRate: snapshot.userPerceivedCrashRate ?? snapshot.crashRate,
                anrRate: snapshot.userPerceivedAnrRate ?? snapshot.anrRate
            )
            byID[observation.id] = observation
        }

        let result = prune(Array(byID.values)).sorted { $0.observedAt < $1.observedAt }
        save(result)
        return result
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }

    private func save(_ observations: [AnalyticsObservation]) {
        guard let data = try? JSONEncoder().encode(observations) else { return }
        defaults.set(data, forKey: key)
    }

    private func prune(_ observations: [AnalyticsObservation]) -> [AnalyticsObservation] {
        let cutoff = Date().addingTimeInterval(-retention)
        return observations.filter { $0.observedAt >= cutoff }
    }
}
