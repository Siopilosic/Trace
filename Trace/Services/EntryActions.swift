import Foundation
import SwiftData

/// Small facade over `ModelContext` for the handful of writes Trace performs.
/// Views call these instead of touching the context directly, so persistence
/// stays in one place.
enum EntryActions {

    @discardableResult
    static func add(_ draft: ParsedDraft, in context: ModelContext) -> Entry {
        let entry = Entry(draft: draft)
        context.insert(entry)
        save(context)
        return entry
    }

    static func delete(_ entry: Entry, in context: ModelContext) {
        context.delete(entry)
        save(context)
    }

    static func save(_ context: ModelContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            // Local-only store; surface in the console but never crash on a log.
            assertionFailure("Trace failed to save: \(error)")
        }
    }

    /// Wipes every entry — backs the "Delete all data" control in Settings.
    static func deleteAll(in context: ModelContext) {
        do {
            try context.delete(model: Entry.self)
            save(context)
        } catch {
            assertionFailure("Trace failed to delete all: \(error)")
        }
    }

    // MARK: Export / Import
    //
    // Local-only data portability — a JSON file the user can keep, move to
    // another device by hand, or re-import. Deliberately not sync: nothing
    // here talks to a server, and import only ever adds records, never
    // replaces or removes what's already on the device.

    struct ExportEntry: Codable {
        var kind: EntryKind
        var title: String
        var amount: Double?
        var durationSeconds: Double?
        var category: ExpenseCategory?
        var noteText: String?
        var date: Date
        var createdAt: Date
    }

    static func exportPayload(_ entries: [Entry]) -> [ExportEntry] {
        entries.map {
            ExportEntry(
                kind: $0.kind, title: $0.title, amount: $0.amount,
                durationSeconds: $0.durationSeconds, category: $0.category,
                noteText: $0.noteText, date: $0.date, createdAt: $0.createdAt
            )
        }
    }

    /// Inserts one `Entry` per imported record and returns how many were
    /// added. Never touches existing entries.
    @discardableResult
    static func importPayload(_ payload: [ExportEntry], in context: ModelContext) -> Int {
        for item in payload {
            let entry = Entry(
                kind: item.kind, title: item.title, amount: item.amount,
                durationSeconds: item.durationSeconds, category: item.category,
                noteText: item.noteText, date: item.date
            )
            entry.createdAt = item.createdAt
            context.insert(entry)
        }
        save(context)
        return payload.count
    }
}
