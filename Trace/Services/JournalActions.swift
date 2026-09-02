import Foundation
import SwiftData

/// Small facade over `ModelContext` for the writes Journal performs — mirrors
/// `EntryActions`/`GoalActions` so persistence stays in one place per model.
enum JournalActions {

    /// Returns `nil` and inserts nothing when `text` is empty or
    /// whitespace-only — prevents ever persisting a blank journal entry.
    /// Persists the trimmed text (leading/trailing only; internal blank
    /// lines in a multi-paragraph entry are preserved).
    @discardableResult
    static func add(text: String, createdAt: Date = Date(), in context: ModelContext) -> JournalEntry? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let entry = JournalEntry(text: trimmed, createdAt: createdAt)
        context.insert(entry)
        save(context)
        return entry
    }

    /// Deviates from `EntryActions`/`GoalActions`' mutate-then-save
    /// convention (neither `Entry` nor `Goal` has an `update` — their
    /// editors mutate the `@Model` object's properties directly and call the
    /// bare `save(context)`): the empty/whitespace invariant needs to be
    /// enforced somewhere callable directly by tests, not only by a disabled
    /// Save button in the editor. Returns `false` and leaves the entry
    /// completely untouched (including `updatedAt`) when the new text is
    /// empty/whitespace-only. `createdAt` is never touched here — editing
    /// never changes a journal entry's place in the timeline.
    @discardableResult
    static func update(_ entry: JournalEntry, text: String, in context: ModelContext) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        entry.text = trimmed
        entry.updatedAt = Date()
        save(context)
        return true
    }

    static func delete(_ entry: JournalEntry, in context: ModelContext) {
        context.delete(entry)
        save(context)
    }

    /// Hides the entry from the normal Journal timeline without deleting it.
    /// Never touches `text`/`createdAt`/`updatedAt`.
    static func archive(_ entry: JournalEntry, in context: ModelContext) {
        entry.archivedAt = Date()
        save(context)
    }

    /// Un-archives the entry. `createdAt` was never touched by `archive`, so
    /// the entry naturally reappears at its original chronological position
    /// in the day-grouped timeline — nothing else needs to change for that.
    static func restore(_ entry: JournalEntry, in context: ModelContext) {
        entry.archivedAt = nil
        save(context)
    }

    static func save(_ context: ModelContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Trace failed to save journal entry: \(error)")
        }
    }

    /// Wipes every journal entry — called alongside `EntryActions.deleteAll`
    /// and `GoalActions.deleteAll` so Settings' "Delete All Data" actually
    /// deletes all data.
    static func deleteAll(in context: ModelContext) {
        do {
            try context.delete(model: JournalEntry.self)
            save(context)
        } catch {
            assertionFailure("Trace failed to delete all journal entries: \(error)")
        }
    }

    // MARK: Export / Import — see `EntryActions`' equivalent for the rationale.

    struct ExportEntry: Codable {
        var text: String
        var createdAt: Date
        var updatedAt: Date
        var archivedAt: Date?
    }

    static func exportPayload(_ entries: [JournalEntry]) -> [ExportEntry] {
        entries.map { ExportEntry(text: $0.text, createdAt: $0.createdAt, updatedAt: $0.updatedAt, archivedAt: $0.archivedAt) }
    }

    /// Inserts one `JournalEntry` per imported record and returns how many
    /// were added. Skips any record whose text is empty/whitespace-only —
    /// same invariant `add`/`update` already enforce. Never touches existing
    /// entries. Preserves archived state — export is a full backup, "archive
    /// is not deletion" applies here too.
    @discardableResult
    static func importPayload(_ payload: [ExportEntry], in context: ModelContext) -> Int {
        var imported = 0
        for item in payload {
            let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let entry = JournalEntry(text: trimmed, createdAt: item.createdAt)
            entry.updatedAt = item.updatedAt
            entry.archivedAt = item.archivedAt
            context.insert(entry)
            imported += 1
        }
        save(context)
        return imported
    }
}
