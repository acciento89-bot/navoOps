import Foundation

struct StoreHistoryStore {
    private let defaults: UserDefaults
    private let key = "navoops.store-history.v1"
    private let maxEvents = 800
    private let retention: TimeInterval = 120 * 24 * 60 * 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [StoreHistoryEvent] {
        guard
            let data = defaults.data(forKey: key),
            let events = try? decoder.decode([StoreHistoryEvent].self, from: data)
        else {
            return []
        }
        return prune(events)
    }

    func record(feed: StoreStatusFeed, products: [ProductApp], existing: [StoreHistoryEvent]) -> [StoreHistoryEvent] {
        var events = prune(existing)

        for snapshot in feed.apps {
            guard let product = products.first(where: snapshot.matches) else { continue }

            let observedAt = observationDate(for: snapshot.provider, feed: feed)
            let previous = events
                .filter { $0.productID == product.id && $0.provider == snapshot.provider }
                .max(by: { $0.observedAt < $1.observedAt })

            let hasChanged: Bool
            if let previous {
                hasChanged = previous.state != snapshot.state ||
                    previous.version != snapshot.version ||
                    previous.build != snapshot.build ||
                    previous.rawState != snapshot.rawState
            } else {
                hasChanged = true
            }

            guard hasChanged else { continue }

            events.append(.init(
                observedAt: observedAt,
                productID: product.id,
                productName: product.name,
                provider: snapshot.provider,
                previousState: previous?.state,
                state: snapshot.state,
                previousVersion: previous?.version,
                version: snapshot.version,
                previousBuild: previous?.build,
                build: snapshot.build,
                rawState: snapshot.rawState
            ))
        }

        events = prune(events)
            .sorted { $0.observedAt > $1.observedAt }
        save(events)
        return events
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }

    private func observationDate(for provider: StoreProvider, feed: StoreStatusFeed) -> Date {
        switch provider {
        case .apple:
            return feed.appleGeneratedAt ?? feed.generatedAt
        case .google:
            return feed.googleGeneratedAt ?? feed.generatedAt
        }
    }

    private func save(_ events: [StoreHistoryEvent]) {
        guard let data = try? encoder.encode(events) else { return }
        defaults.set(data, forKey: key)
    }

    private func prune(_ events: [StoreHistoryEvent]) -> [StoreHistoryEvent] {
        let cutoff = Date().addingTimeInterval(-retention)
        return events
            .filter { $0.observedAt >= cutoff }
            .sorted { $0.observedAt > $1.observedAt }
            .prefix(maxEvents)
            .map { $0 }
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
