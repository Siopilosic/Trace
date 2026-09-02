import XCTest
import SwiftData
@testable import Trace

/// Exercises `JournalActions` against real `ModelContext`s — creation,
/// ordering, editing, deletion, and the empty-text guard, plus persistence
/// across a fresh `ModelContainer` (standing in for an app relaunch).
final class JournalActionsTests: XCTestCase {

    // MARK: In-memory: create / order / edit / delete mechanics

    private func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: JournalEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: iso)!
    }

    // MARK: Persistence

    func testAddPersistsTextAndTimestamps() throws {
        let context = try makeInMemoryContext()
        let entry = try XCTUnwrap(JournalActions.add(text: "Today was a good day.", in: context))

        XCTAssertEqual(entry.text, "Today was a good day.")
        XCTAssertEqual(entry.createdAt, entry.updatedAt)
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 1)
    }

    func testFetchReturnsAddedEntry() throws {
        let context = try makeInMemoryContext()
        JournalActions.add(text: "First entry.", in: context)
        JournalActions.add(text: "Second entry.", in: context)

        let fetched = try context.fetch(FetchDescriptor<JournalEntry>())
        XCTAssertEqual(fetched.count, 2)
        XCTAssertTrue(fetched.contains { $0.text == "First entry." })
        XCTAssertTrue(fetched.contains { $0.text == "Second entry." })
    }

    // MARK: Ordering (newest first by createdAt)

    func testEntriesOrderNewestFirstByCreatedAt() throws {
        let context = try makeInMemoryContext()
        JournalActions.add(text: "Oldest", createdAt: date("2025-01-01T09:00:00Z"), in: context)
        JournalActions.add(text: "Middle", createdAt: date("2025-01-02T09:00:00Z"), in: context)
        JournalActions.add(text: "Newest", createdAt: date("2025-01-03T09:00:00Z"), in: context)

        let sorted = try context.fetch(FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
        XCTAssertEqual(sorted.map(\.text), ["Newest", "Middle", "Oldest"])
    }

    func testEditingAnOlderEntryDoesNotChangeItsOrder() throws {
        let context = try makeInMemoryContext()
        let older = try XCTUnwrap(JournalActions.add(text: "Old text", createdAt: date("2025-01-01T09:00:00Z"), in: context))
        JournalActions.add(text: "Newer entry", createdAt: date("2025-01-05T09:00:00Z"), in: context)

        JournalActions.update(older, text: "Edited old text", in: context)

        let sorted = try context.fetch(FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
        XCTAssertEqual(sorted.map(\.text), ["Newer entry", "Edited old text"])
    }

    // MARK: Editing

    func testUpdateChangesTextAndBumpsUpdatedAtButNotCreatedAt() throws {
        let context = try makeInMemoryContext()
        let entry = try XCTUnwrap(JournalActions.add(text: "Original", createdAt: date("2025-01-01T09:00:00Z"), in: context))
        let originalCreatedAt = entry.createdAt
        let originalUpdatedAt = entry.updatedAt

        let didUpdate = JournalActions.update(entry, text: "Revised", in: context)

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(entry.text, "Revised")
        XCTAssertEqual(entry.createdAt, originalCreatedAt)
        XCTAssertNotEqual(entry.updatedAt, originalUpdatedAt)
    }

    func testUpdatePreservesInternalBlankLinesButTrimsEdges() throws {
        let context = try makeInMemoryContext()
        let entry = try XCTUnwrap(JournalActions.add(text: "Original", in: context))

        JournalActions.update(entry, text: "  First paragraph.\n\nSecond paragraph.  \n", in: context)

        XCTAssertEqual(entry.text, "First paragraph.\n\nSecond paragraph.")
    }

    // MARK: Deletion

    func testDeleteRemovesOnlyThatEntry() throws {
        let context = try makeInMemoryContext()
        let keep = try XCTUnwrap(JournalActions.add(text: "Keep me", in: context))
        let remove = try XCTUnwrap(JournalActions.add(text: "Remove me", in: context))

        JournalActions.delete(remove, in: context)

        let remaining = try context.fetch(FetchDescriptor<JournalEntry>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.uuid, keep.uuid)
    }

    func testDeleteAllRemovesEveryJournalEntry() throws {
        let context = try makeInMemoryContext()
        JournalActions.add(text: "One", in: context)
        JournalActions.add(text: "Two", in: context)
        JournalActions.add(text: "Three", in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 3)

        JournalActions.deleteAll(in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 0)
    }

    // MARK: Archive / Restore

    func testArchiveSetsArchivedAtAndPreservesTextAndCreatedAt() throws {
        let context = try makeInMemoryContext()
        let entry = try XCTUnwrap(JournalActions.add(text: "Started working on the new design.", createdAt: date("2025-01-01T09:00:00Z"), in: context))

        JournalActions.archive(entry, in: context)

        XCTAssertTrue(entry.isArchived)
        XCTAssertEqual(entry.text, "Started working on the new design.")
        XCTAssertEqual(entry.createdAt, date("2025-01-01T09:00:00Z"))
    }

    func testRestoreClearsArchivedAtAndPreservesCreatedAtAndText() throws {
        let context = try makeInMemoryContext()
        let entry = try XCTUnwrap(JournalActions.add(text: "Quiet day.", createdAt: date("2025-01-01T09:00:00Z"), in: context))
        JournalActions.archive(entry, in: context)

        JournalActions.restore(entry, in: context)

        XCTAssertFalse(entry.isArchived)
        XCTAssertEqual(entry.text, "Quiet day.")
        XCTAssertEqual(entry.createdAt, date("2025-01-01T09:00:00Z"))
    }

    /// The exact predicate `JournalView` uses for its `@Query` — archived
    /// entries must never appear in the normal (active) fetch.
    func testArchivedEntriesExcludedFromActiveFetch() throws {
        let context = try makeInMemoryContext()
        let active = try XCTUnwrap(JournalActions.add(text: "Still active", in: context))
        let archived = try XCTUnwrap(JournalActions.add(text: "Now archived", in: context))
        JournalActions.archive(archived, in: context)

        let activeOnly = try context.fetch(FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.archivedAt == nil }
        ))

        XCTAssertEqual(activeOnly.map(\.uuid), [active.uuid])
    }

    /// The inverse predicate `JournalArchiveView` uses — only archived
    /// entries should appear there.
    func testOnlyArchivedEntriesAppearInArchiveFetch() throws {
        let context = try makeInMemoryContext()
        let active = try XCTUnwrap(JournalActions.add(text: "Still active", in: context))
        let archived = try XCTUnwrap(JournalActions.add(text: "Now archived", in: context))
        JournalActions.archive(archived, in: context)
        _ = active

        let archivedOnly = try context.fetch(FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.archivedAt != nil }
        ))

        XCTAssertEqual(archivedOnly.map(\.uuid), [archived.uuid])
    }

    /// Restoring an entry must return it to its exact original chronological
    /// position — since `archive`/`restore` never touch `createdAt`, this
    /// falls out of the existing newest-first sort automatically.
    func testRestoredEntryReturnsToOriginalChronologicalPosition() throws {
        let context = try makeInMemoryContext()
        let oldest = try XCTUnwrap(JournalActions.add(text: "Oldest", createdAt: date("2025-01-01T09:00:00Z"), in: context))
        let middle = try XCTUnwrap(JournalActions.add(text: "Middle", createdAt: date("2025-01-02T09:00:00Z"), in: context))
        let newest = try XCTUnwrap(JournalActions.add(text: "Newest", createdAt: date("2025-01-03T09:00:00Z"), in: context))

        JournalActions.archive(middle, in: context)
        JournalActions.restore(middle, in: context)

        let activeSortedNewestFirst = try context.fetch(FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.archivedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
        XCTAssertEqual(activeSortedNewestFirst.map(\.uuid), [newest.uuid, middle.uuid, oldest.uuid])
    }

    // MARK: Empty / whitespace-only text is rejected

    func testAddingEmptyTextDoesNotPersist() throws {
        let context = try makeInMemoryContext()
        let result = JournalActions.add(text: "", in: context)

        XCTAssertNil(result)
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 0)
    }

    func testAddingWhitespaceOnlyTextDoesNotPersist() throws {
        let context = try makeInMemoryContext()
        let result = JournalActions.add(text: "   \n\t  ", in: context)

        XCTAssertNil(result)
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 0)
    }

    func testUpdatingToEmptyTextIsRejectedAndLeavesEntryUnchanged() throws {
        let context = try makeInMemoryContext()
        let entry = try XCTUnwrap(JournalActions.add(text: "Keep this", in: context))
        let originalUpdatedAt = entry.updatedAt

        let didUpdate = JournalActions.update(entry, text: "   ", in: context)

        XCTAssertFalse(didUpdate)
        XCTAssertEqual(entry.text, "Keep this")
        XCTAssertEqual(entry.updatedAt, originalUpdatedAt)
    }

    // MARK: Export / Import

    func testExportPayloadIncludesAllEntries() throws {
        let context = try makeInMemoryContext()
        JournalActions.add(text: "First", createdAt: date("2025-01-01T09:00:00Z"), in: context)
        JournalActions.add(text: "Second", createdAt: date("2025-01-02T09:00:00Z"), in: context)

        let entries = try context.fetch(FetchDescriptor<JournalEntry>())
        let payload = JournalActions.exportPayload(entries)

        XCTAssertEqual(payload.count, 2)
        XCTAssertTrue(payload.contains { $0.text == "First" })
        XCTAssertTrue(payload.contains { $0.text == "Second" })
    }

    func testImportPayloadAddsEntriesWithoutTouchingExisting() throws {
        let context = try makeInMemoryContext()
        JournalActions.add(text: "Already here", in: context)

        let payload = [
            JournalActions.ExportEntry(text: "Imported one", createdAt: date("2025-01-01T09:00:00Z"), updatedAt: date("2025-01-01T09:00:00Z")),
            JournalActions.ExportEntry(text: "Imported two", createdAt: date("2025-01-02T09:00:00Z"), updatedAt: date("2025-01-02T09:00:00Z")),
        ]
        let count = JournalActions.importPayload(payload, in: context)

        XCTAssertEqual(count, 2)
        let all = try context.fetch(FetchDescriptor<JournalEntry>())
        XCTAssertEqual(all.count, 3)
        XCTAssertTrue(all.contains { $0.text == "Already here" })
        XCTAssertTrue(all.contains { $0.text == "Imported one" })
    }

    func testImportPayloadSkipsEmptyOrWhitespaceRecords() throws {
        let context = try makeInMemoryContext()
        let payload = [
            JournalActions.ExportEntry(text: "Real entry", createdAt: date("2025-01-01T09:00:00Z"), updatedAt: date("2025-01-01T09:00:00Z")),
            JournalActions.ExportEntry(text: "   ", createdAt: date("2025-01-01T09:00:00Z"), updatedAt: date("2025-01-01T09:00:00Z")),
        ]
        let count = JournalActions.importPayload(payload, in: context)

        XCTAssertEqual(count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 1)
    }

    func testExportThenImportRoundTripsThroughJSON() throws {
        let source = try makeInMemoryContext()
        JournalActions.add(text: "Round trip me", createdAt: date("2025-06-01T12:00:00Z"), in: source)

        let payload = JournalActions.exportPayload(try source.fetch(FetchDescriptor<JournalEntry>()))
        let data = try JSONExport.encoder.encode(payload)
        let decoded = try JSONExport.decoder.decode([JournalActions.ExportEntry].self, from: data)

        let destination = try makeInMemoryContext()
        let count = JournalActions.importPayload(decoded, in: destination)

        XCTAssertEqual(count, 1)
        let imported = try XCTUnwrap(try destination.fetch(FetchDescriptor<JournalEntry>()).first)
        XCTAssertEqual(imported.text, "Round trip me")
        XCTAssertEqual(imported.createdAt.timeIntervalSince1970, date("2025-06-01T12:00:00Z").timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: On-disk: survives a fresh container (simulated relaunch)

    private func makeOnDiskContainer(at url: URL) throws -> ModelContainer {
        try ModelContainer(for: JournalEntry.self, configurations: ModelConfiguration(url: url))
    }

    func testJournalEntriesSurviveContainerRecreation() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let storeURL = dir.appendingPathComponent("relaunch-test.store")
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        do {
            let container = try makeOnDiskContainer(at: storeURL)
            let context = ModelContext(container)
            JournalActions.add(text: "Survives a relaunch", createdAt: date("2025-01-01T09:00:00Z"), in: context)
        }

        // A brand new container over the same file stands in for the app
        // being relaunched — nothing here shares state with the block above.
        let reopened = try makeOnDiskContainer(at: storeURL)
        let context = ModelContext(reopened)
        let entries = try context.fetch(FetchDescriptor<JournalEntry>())

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.text, "Survives a relaunch")
    }

    func testDeleteSurvivesContainerRecreation() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let storeURL = dir.appendingPathComponent("relaunch-delete-test.store")
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        do {
            let container = try makeOnDiskContainer(at: storeURL)
            let context = ModelContext(container)
            let entry = JournalActions.add(text: "Delete me", in: context)!
            JournalActions.add(text: "Keep me", in: context)
            JournalActions.delete(entry, in: context)
        }

        let reopened = try makeOnDiskContainer(at: storeURL)
        let entries = try ModelContext(reopened).fetch(FetchDescriptor<JournalEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.text, "Keep me")
    }
}
