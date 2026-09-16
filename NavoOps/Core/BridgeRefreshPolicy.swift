import Foundation

enum BridgeRefreshPolicy {
    static func providersAdvanced(
        appleGeneratedAt: Date?,
        googleGeneratedAt: Date?,
        previousApple: Date?,
        previousGoogle: Date?,
        waitForApple: Bool,
        waitForGoogle: Bool
    ) -> Bool {
        (!waitForApple || advanced(appleGeneratedAt, beyond: previousApple)) &&
        (!waitForGoogle || advanced(googleGeneratedAt, beyond: previousGoogle))
    }

    private static func advanced(_ current: Date?, beyond previous: Date?) -> Bool {
        guard let current else { return false }
        guard let previous else { return true }
        return current > previous
    }
}
