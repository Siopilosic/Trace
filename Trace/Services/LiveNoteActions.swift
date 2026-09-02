import Foundation
import SwiftData

/// Small facade over `ModelContext` for the writes Live Notes performs —
/// mirrors `EntryActions`/`GoalActions`/`JournalActions` so persistence stays
/// in one place per model. Starting/ending the actual Live Activity is
/// `LiveActivityController`'s job, not this one — this only ever touches
/// the persisted record.
enum LiveNoteActions {

    /// The current draft — the most recent non-archived note, if any. The
    /// composer always looks this up before creating anything, so reopening
    /// it never produces a second draft alongside an existing one; it just
    /// keeps editing the one that's already there.
    static func currentDraft(in context: ModelContext) -> LiveNote? {
        var descriptor = FetchDescriptor<LiveNote>(
            predicate: #Predicate { $0.archivedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Returns `nil` and inserts nothing when `text` is empty or
    /// whitespace-only — same invariant `JournalActions.add` enforces.
    @discardableResult
    static func add(text: String, in context: ModelContext) -> LiveNote? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let note = LiveNote(text: trimmed)
        context.insert(note)
        save(context)
        return note
    }

    /// Records which running Live Activity belongs to this note (or clears
    /// it once the activity has ended).
    static func setActivityID(_ id: String?, for note: LiveNote, in context: ModelContext) {
        note.activityID = id
        save(context)
    }

    /// Marks the note archived and clears `activityID` — archiving always
    /// implies the note is no longer live. Never touches `text`/`createdAt`.
    static func archive(_ note: LiveNote, in context: ModelContext) {
        note.archivedAt = Date()
        note.activityID = nil
        save(context)
    }

    /// Un-archives the note. Does not restart a Live Activity — going live
    /// again is a separate, explicit action.
    static func restore(_ note: LiveNote, in context: ModelContext) {
        note.archivedAt = nil
        save(context)
    }

    static func delete(_ note: LiveNote, in context: ModelContext) {
        context.delete(note)
        save(context)
    }

    static func save(_ context: ModelContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Trace failed to save live note: \(error)")
        }
    }

    /// Wipes every Live Note — called alongside the other models' `deleteAll`
    /// so Settings' "Delete All Data" actually deletes all data.
    static func deleteAll(in context: ModelContext) {
        do {
            try context.delete(model: LiveNote.self)
            save(context)
        } catch {
            assertionFailure("Trace failed to delete all live notes: \(error)")
        }
    }

    // MARK: Export / Import — see `EntryActions`' equivalent for the rationale.
    // Deliberately excludes `activityID`: an imported note was never actually
    // live on this device, and re-using a stale activity id would be wrong.

    struct ExportNote: Codable {
        var text: String
        var createdAt: Date
        var archivedAt: Date?
    }

    static func exportPayload(_ notes: [LiveNote]) -> [ExportNote] {
        notes.map { ExportNote(text: $0.text, createdAt: $0.createdAt, archivedAt: $0.archivedAt) }
    }

    /// Inserts one `LiveNote` per imported record and returns how many were
    /// added. Skips empty/whitespace-only text. Never touches existing notes.
    @discardableResult
    static func importPayload(_ payload: [ExportNote], in context: ModelContext) -> Int {
        var imported = 0
        for item in payload {
            let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let note = LiveNote(text: trimmed, createdAt: item.createdAt)
            note.archivedAt = item.archivedAt
            context.insert(note)
            imported += 1
        }
        save(context)
        return imported
    }
}
