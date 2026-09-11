import Foundation

enum L10n {
    static var isGerman: Bool {
        Locale.current.language.languageCode?.identifier.lowercased() == "de"
    }

    static func t(_ de: String, _ en: String) -> String {
        isGerman ? de : en
    }
}

extension ProductApp.StoreState {
    var localizedTitle: String {
        switch self {
        case .development: return L10n.t("Entwicklung", "Development")
        case .internalTest: return L10n.t("Interner Test", "Internal Test")
        case .review: return L10n.t("In Prüfung", "In Review")
        case .live: return "Live"
        case .attention: return L10n.t("Handlungsbedarf", "Needs Attention")
        }
    }
}

extension ProductApp.Monetization {
    var localizedTitle: String {
        switch self {
        case .free: return L10n.t("Kostenlos", "Free")
        case .paid: return L10n.t("Kostenpflichtig", "Paid")
        case .oneTime: return L10n.t("Einmalkauf", "One-time purchase")
        case .subscription: return L10n.t("Abo", "Subscription")
        case .mixed: return L10n.t("Gemischt", "Mixed")
        }
    }
}
