import Foundation

/// The things Trace can remember on the quick-logged `Entry` timeline.
/// Deliberately small — the generic model keeps Trace from being permanently
/// locked into finance.
///
/// `.note` is legacy-only: Live Note now replaces the generic "jot something
/// down" case. The enum case stays so `Entry` rows already persisted with
/// `kind == .note` keep decoding and displaying correctly — see `creatable`
/// for the set actually offered anywhere a user picks a kind.
enum EntryKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case expense
    case income
    case activity
    case note

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        case .activity: return "Activity"
        case .note: return "Note"
        }
    }

    var symbolName: String {
        switch self {
        case .expense: return "arrow.down.left"
        case .income: return "arrow.up.right"
        case .activity: return "circle.dotted"
        case .note: return "text.alignleft"
        }
    }

    var isMoney: Bool { self == .expense || self == .income }

    /// The kinds a user can actually choose when creating or editing an
    /// entry — everywhere in the app that offers a kind picker for new or
    /// existing (non-note) entries uses this instead of `allCases`.
    static let creatable: [EntryKind] = [.expense, .income, .activity]
}
