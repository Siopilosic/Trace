import Foundation

/// The four things Trace can remember. Deliberately small — the generic model
/// keeps Trace from being permanently locked into finance.
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
}
