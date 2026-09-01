import Foundation
import SwiftData

/// The single persisted record type in Trace.
///
/// One generic model covers expenses, income, activities and notes. Fields not
/// relevant to a given ``EntryKind`` stay `nil`. Every attribute has a default
/// value and there are no unique constraints, so a CloudKit-backed container
/// could be dropped in later without a migration.
@Model
final class Entry {
    /// Stable identity for display and navigation. Safe for future iCloud sync.
    var uuid: UUID = UUID()

    /// SwiftData stores `RawRepresentable` enums natively on iOS 17+.
    var kind: EntryKind = EntryKind.expense
    var category: ExpenseCategory?

    var title: String = ""

    /// Money amount in the user's currency (expense / income). `nil` otherwise.
    var amount: Double?

    /// Activity length in seconds. `nil` unless `kind == .activity`.
    var durationSeconds: Double?

    /// Free text for `.note` entries, or an optional annotation on any entry.
    var noteText: String?

    /// When the logged thing happened. Defaults to creation time, user-editable.
    var date: Date = Date()

    /// Immutable audit timestamp.
    var createdAt: Date = Date()

    init(
        kind: EntryKind,
        title: String,
        amount: Double? = nil,
        durationSeconds: Double? = nil,
        category: ExpenseCategory? = nil,
        noteText: String? = nil,
        date: Date = Date()
    ) {
        self.uuid = UUID()
        self.kind = kind
        self.category = category
        self.title = title
        self.amount = amount
        self.durationSeconds = durationSeconds
        self.noteText = noteText
        self.date = date
        self.createdAt = Date()
    }
}

// MARK: - StatEntry conformance

extension Entry: StatEntry {}

// MARK: - Building from a parsed draft

extension Entry {
    convenience init(draft: ParsedDraft) {
        self.init(
            kind: draft.kind,
            title: draft.title,
            amount: draft.amount,
            durationSeconds: draft.durationSeconds,
            category: draft.category,
            noteText: draft.note,
            date: draft.date
        )
    }

    /// The signed amount for display: expenses negative, income positive.
    var signedAmount: Double? {
        guard let amount else { return nil }
        return kind == .expense ? -amount : amount
    }
}
