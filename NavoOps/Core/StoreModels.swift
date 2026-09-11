import Foundation

enum StoreProvider: String, Codable, CaseIterable, Hashable {
    case apple
    case google

    var title: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google Play"
        }
    }
}

struct StoreStatusFeed: Codable, Hashable {
    let schemaVersion: Int
    let generatedAt: Date
    let sourceRepository: String?
    let appleAvailable: Bool
    let googleAvailable: Bool
    let apps: [StoreAppSnapshot]
}

struct StoreAppSnapshot: Identifiable, Codable, Hashable {
    enum State: String, Codable, CaseIterable, Hashable {
        case development
        case processing
        case internalTest
        case review
        case live
        case rejected
        case attention
        case unavailable

        var productState: ProductApp.StoreState {
            switch self {
            case .development, .processing:
                return .development
            case .internalTest:
                return .internalTest
            case .review:
                return .review
            case .live:
                return .live
            case .rejected, .attention:
                return .attention
            case .unavailable:
                return .development
            }
        }
    }

    var id: String {
        "\(provider.rawValue):\(externalID ?? bundleOrPackageID ?? appName)"
    }

    let provider: StoreProvider
    let appName: String
    let externalID: String?
    let bundleOrPackageID: String?
    let version: String?
    let build: String?
    let rawState: String
    let state: State
    let updatedAt: Date?
    let detail: String?
}

struct OperationsInboxItem: Identifiable, Hashable {
    enum Priority: Int, Comparable, Hashable {
        case critical = 3
        case action = 2
        case waiting = 1
        case info = 0

        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    enum Kind: Hashable {
        case build
        case apple
        case google
        case release
        case pullRequest
    }

    let id: String
    let productID: String?
    let title: String
    let detail: String
    let priority: Priority
    let kind: Kind
    let date: Date
}

extension StoreAppSnapshot {
    func matches(_ product: ProductApp) -> Bool {
        if provider == .apple,
           let expected = product.storeInfo.appleBundleID?.lowercased(),
           let actual = bundleOrPackageID?.lowercased(),
           expected == actual {
            return true
        }

        if provider == .google,
           let expected = product.storeInfo.androidPackageID?.lowercased(),
           let actual = bundleOrPackageID?.lowercased(),
           expected == actual {
            return true
        }

        return Self.normalize(appName) == Self.normalize(product.name)
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}
