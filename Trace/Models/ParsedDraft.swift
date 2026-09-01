import Foundation

/// The structured result of interpreting a Quick Add string.
///
/// This is a plain value type with no persistence or UI dependencies so the
/// parser can be unit-tested in isolation and improved freely.
struct ParsedDraft: Equatable, Sendable {
    var kind: EntryKind
    var title: String
    var amount: Double?
    var durationSeconds: Double?
    var category: ExpenseCategory?
    var note: String?

    /// The event time. Quick Add always uses "now"; the detail editor can change it.
    var date: Date

    /// Whether the parser is confident about `kind`. When `false` the UI should
    /// nudge the user to confirm what the entry represents.
    var isConfident: Bool

    init(
        kind: EntryKind,
        title: String = "",
        amount: Double? = nil,
        durationSeconds: Double? = nil,
        category: ExpenseCategory? = nil,
        note: String? = nil,
        date: Date = Date(),
        isConfident: Bool = true
    ) {
        self.kind = kind
        self.title = title
        self.amount = amount
        self.durationSeconds = durationSeconds
        self.category = category
        self.note = note
        self.date = date
        self.isConfident = isConfident
    }
}
