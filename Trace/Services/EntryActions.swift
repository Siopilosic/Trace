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
}
