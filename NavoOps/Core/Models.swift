import Foundation
import SwiftUI

struct ProductApp: Identifiable, Hashable, Codable {
    enum Platform: String, Codable, CaseIterable {
        case iOS = "iOS"
        case android = "Android"
    }

    enum StoreState: String, Codable, CaseIterable {
        case development = "Development"
        case internalTest = "Internal Test"
        case review = "In Review"
        case live = "Live"
        case attention = "Needs Attention"
    }

    let id: UUID
    var name: String
    var repository: String
    var platforms: Set<Platform>
    var appleState: StoreState
    var googleState: StoreState
    var version: String
    var build: String
    var notes: String
    var checklist: ReleaseChecklist

    init(id: UUID = UUID(), name: String, repository: String, platforms: Set<Platform>, appleState: StoreState, googleState: StoreState, version: String, build: String, notes: String = "", checklist: ReleaseChecklist = .init()) {
        self.id = id
        self.name = name
        self.repository = repository
        self.platforms = platforms
        self.appleState = appleState
        self.googleState = googleState
        self.version = version
        self.build = build
        self.notes = notes
        self.checklist = checklist
    }
}

struct ReleaseChecklist: Hashable, Codable {
    var icon = false
    var screenshotsDE = false
    var screenshotsEN = false
    var privacyURL = false
    var eula = false
    var reviewAccess = false
    var billing = false
    var storeTextDE = false
    var storeTextEN = false

    var completed: Int {
        [icon, screenshotsDE, screenshotsEN, privacyURL, eula, reviewAccess, billing, storeTextDE, storeTextEN].filter { $0 }.count
    }

    var total: Int { 9 }
}

struct RepoSnapshot: Identifiable, Hashable, Codable {
    let id: Int
    let name: String
    let fullName: String
    let isPrivate: Bool
    let defaultBranch: String
    let htmlURL: String
    let openIssues: Int
    let updatedAt: Date?
}

struct PullRequestSnapshot: Identifiable, Hashable, Codable {
    let id: Int
    let number: Int
    let title: String
    let repository: String
    let state: String
    let htmlURL: String
    let draft: Bool
    let updatedAt: Date?
}

struct IssueSnapshot: Identifiable, Hashable, Codable {
    let id: Int
    let number: Int
    let title: String
    let repository: String
    let htmlURL: String
    let updatedAt: Date?
}

struct ActivityItem: Identifiable, Hashable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let date: Date
    let tone: Tone

    enum Tone {
        case success, warning, info

        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .info: return .blue
            }
        }
    }
}
