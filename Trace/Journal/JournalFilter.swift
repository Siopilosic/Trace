import Foundation

/// Minimal shape Journal's text search needs. Kept separate from `StatEntry`
/// and `HistorySearchable` — Journal has no kind/category, just text.
protocol JournalSearchable {
    var text: String { get }
}

/// Pure text search for Journal — no SwiftUI, no SwiftData. Case-insensitive
/// substring match against the entry's text, nothing else. Date filtering is a
/// separate concern (see ``JournalDateFilter``).
enum JournalFilter {

    static func matches<E: JournalSearchable>(_ entry: E, search: String) -> Bool {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        return entry.text.lowercased().contains(needle)
    }
}
