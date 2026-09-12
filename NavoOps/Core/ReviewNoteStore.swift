import Foundation

struct ReviewNote: Codable, Hashable {
    let snapshotID: String
    var message: String
    var tags: [String]
    var updatedAt: Date
}

final class ReviewNoteStore {
    private let defaults: UserDefaults
    private let key = "navoops.review-notes.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [String: ReviewNote] {
        guard
            let data = defaults.data(forKey: key),
            let notes = try? JSONDecoder().decode([String: ReviewNote].self, from: data)
        else { return [:] }
        return notes
    }

    func save(_ notes: [String: ReviewNote]) {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        defaults.set(data, forKey: key)
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }

    static func tags(in message: String) -> [String] {
        let pattern = #"(?i)\b(?:guideline\s*)?(\d+(?:\.\d+)+(?:\([a-z]\))?)(?=$|\s|[.,;:!?'\"\-])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(message.startIndex..<message.endIndex, in: message)
        let tags = regex.matches(in: message, range: range).compactMap { match -> String? in
            guard match.numberOfRanges > 1,
                  let codeRange = Range(match.range(at: 1), in: message)
            else { return nil }
            return String(message[codeRange])
        }
        return Array(Set(tags)).sorted()
    }
}
