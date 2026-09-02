import Foundation
import SwiftData

/// A personal diary entry — longer-form writing, deliberately separate from
/// the quick logged `Entry` timeline (including `Entry.kind == .note`).
///
/// Intentionally minimal: text and two timestamps, nothing else. No mood,
/// tags, categories, location, weather, photos, prompts, word counts, or
/// streaks — those are explicitly out of scope.
///
/// Additive to the schema: a third, fully independent model registered
/// alongside `Entry` and `Goal`. Adding it does not touch either of their
/// tables or require a migration. Deliberately does NOT conform to
/// `StatEntry` or `HistorySearchable` — journal entries must stay invisible
/// to `StatisticsEngine`, `GoalsEngine`, and History's list by construction,
/// not by convention.
@Model
final class JournalEntry {
    /// Stable identity for display and navigation. Safe for future iCloud sync.
    var uuid: UUID = UUID()

    var text: String = ""

    /// The canonical, immutable journal timestamp — when the entry was first
    /// written. Ordering and day-grouping both key off this, never
    /// `updatedAt`; editing an entry never changes it and never reorders it.
    var createdAt: Date = Date()

    /// Bumped whenever the text is edited. Purely informational — never
    /// affects ordering or day-grouping.
    var updatedAt: Date = Date()

    /// Non-nil once archived. Archive is a visibility flag, not deletion —
    /// it never touches `text`, `createdAt`, or `updatedAt`, so a restored
    /// entry returns to exactly its original chronological position.
    var archivedAt: Date?

    var isArchived: Bool { archivedAt != nil }

    init(text: String, createdAt: Date = Date()) {
        self.uuid = UUID()
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

// MARK: - JournalSearchable conformance

extension JournalEntry: JournalSearchable {}
