import Foundation

/// Minimal shape Journal's search needs. Kept separate from `StatEntry` and
/// `HistorySearchable` — Journal has no kind/category, just text.
protocol JournalSearchable {
    var text: String { get }
}

/// Pure text search — no SwiftUI, no SwiftData. Journal has no type/category
/// filter the way History does, just a single search field.
enum JournalFilter {
    static func matches<E: JournalSearchable>(_ entry: E, search: String) -> Bool {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        return entry.text.lowercased().contains(needle)
    }
}
