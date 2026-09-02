import Foundation

/// The type filter shown alongside History's search. No `.notes` case —
/// Note is legacy-only and no longer a filterable category; any pre-existing
/// note entries still show up under `.all`, just aren't specifically
/// filterable anymore.
enum HistoryTypeFilter: String, CaseIterable, Identifiable, Sendable {
    case all, expenses, income, activities

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .expenses: return "Expenses"
        case .income: return "Income"
        case .activities: return "Activities"
        }
    }

    /// `nil` for `.all` — matches every kind.
    var kind: EntryKind? {
        switch self {
        case .all: return nil
        case .expenses: return .expense
        case .income: return .income
        case .activities: return .activity
        }
    }
}

/// Minimal shape History's search needs. Kept separate from `StatEntry` —
/// search touches `noteText`, which the statistics layer never needs.
protocol HistorySearchable {
    var kind: EntryKind { get }
    var title: String { get }
    var noteText: String? { get }
    var category: ExpenseCategory? { get }
}

/// Pure combined search + type filter — no SwiftUI, no SwiftData. Search and
/// the type filter always combine with AND: a type filter narrows which
/// entries are eligible, search text then narrows further.
enum HistoryFilter {
    static func matches<E: HistorySearchable>(_ entry: E, search: String, type: HistoryTypeFilter) -> Bool {
        if let kind = type.kind, entry.kind != kind { return false }

        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }

        return entry.title.lowercased().contains(needle)
            || (entry.noteText?.lowercased().contains(needle) ?? false)
            || (entry.category?.displayName.lowercased().contains(needle) ?? false)
    }
}
