import XCTest
import SwiftData
@testable import Trace

/// Exercises `LiveNoteActions` against real `ModelContext`s — creation, the
/// empty-text guard, activity-id tracking, archive/restore, deletion, and
/// export/import.
final class LiveNoteActionsTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: LiveNote.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: Persistence

    func testAddPersistsTrimmedText() throws {
        let context = try makeContext()
        let note = try XCTUnwrap(LiveNoteActions.add(text: "  Buy groceries after class  ", in: context))

        XCTAssertEqual(note.text, "Buy groceries after class")
        XCTAssertNil(note.activityID)
        XCTAssertNil(note.archivedAt)
        XCTAssertEqual(try context.fetch(FetchDescriptor<LiveNote>()).count, 1)
    }

    // MARK: Empty / whitespace rejected — same invariant as JournalActions

    func testAddingEmptyTextDoesNotPersist() throws {
        let context = try makeContext()
        XCTAssertNil(LiveNoteActions.add(text: "", in: context))
        XCTAssertEqual(try context.fetch(FetchDescriptor<LiveNote>()).count, 0)
    }

    func testAddingWhitespaceOnlyTextDoesNotPersist() throws {
        let context = try makeContext()
        XCTAssertNil(LiveNoteActions.add(text: "   \n\t ", in: context))
        XCTAssertEqual(try context.fetch(FetchDescriptor<LiveNote>()).count, 0)
    }

    // MARK: Activity id / live state

    func testSetActivityIDMarksNoteLive() throws {
        let context = try makeContext()
        let note = try XCTUnwrap(LiveNoteActions.add(text: "Ask Sara about the trip", in: context))
        XCTAssertFalse(note.isLive)

        LiveNoteActions.setActivityID("abc-123", for: note, in: context)

        XCTAssertTrue(note.isLive)
        XCTAssertEqual(note.activityID, "abc-123")
    }

    /// What "Go Live" turning OFF actually does at the persistence layer —
    /// the composer must never lose the note's text just because the Live
    /// Activity ended.
    func testClearingActivityIDEndsLiveStateButPreservesText() throws {
        let context = try makeContext()
        let note = try XCTUnwrap(LiveNoteActions.add(text: "Buy groceries after class", in: context))
        LiveNoteActions.setActivityID("abc-123", for: note, in: context)

        LiveNoteActions.setActivityID(nil, for: note, in: context)

        XCTAssertFalse(note.isLive)
        XCTAssertEqual(note.text, "Buy groceries after class")
        XCTAssertFalse(note.isArchived) // turning live off is not archiving
    }

    // MARK: Current draft — the composer's "find, don't duplicate" lookup

    func testCurrentDraftIsNilWhenNoNotesExist() throws {
        let context = try makeContext()
        XCTAssertNil(LiveNoteActions.currentDraft(in: context))
    }

    func testCurrentDraftReturnsTheMostRecentNonArchivedNote() throws {
        let context = try makeContext()
        let older = try XCTUnwrap(LiveNoteActions.add(text: "Older draft", in: context))
        older.createdAt = Date(timeIntervalSince1970: 1_000)
        let newer = try XCTUnwrap(LiveNoteActions.add(text: "Newer draft", in: context))
        newer.createdAt = Date(timeIntervalSince1970: 2_000)
        LiveNoteActions.save(context)

        XCTAssertEqual(LiveNoteActions.currentDraft(in: context)?.uuid, newer.uuid)
    }

    func testCurrentDraftExcludesArchivedNotes() throws {
        let context = try makeContext()
        let archived = try XCTUnwrap(LiveNoteActions.add(text: "Archived", in: context))
        LiveNoteActions.archive(archived, in: context)

        XCTAssertNil(LiveNoteActions.currentDraft(in: context))
    }

    /// The exact scenario "reopening the composer must not create a second
    /// draft" depends on: an archived note sitting in the store must never
    /// be mistaken for the current one.
    func testCurrentDraftFindsTheActiveNoteEvenAlongsideArchivedOnes() throws {
        let context = try makeContext()
        let archived = try XCTUnwrap(LiveNoteActions.add(text: "Archived", in: context))
        LiveNoteActions.archive(archived, in: context)
        let active = try XCTUnwrap(LiveNoteActions.add(text: "Current draft", in: context))

        XCTAssertEqual(LiveNoteActions.currentDraft(in: context)?.uuid, active.uuid)
    }

    /// Mirrors exactly what the composer does on every keystroke: look up
    /// the current draft first, only call `add` when there truly isn't one
    /// yet. Simulating that loop twice must still leave exactly one note.
    func testReusingCurrentDraftNeverCreatesADuplicate() throws {
        let context = try makeContext()

        func typeCharacter(_ text: String) {
            if let draft = LiveNoteActions.currentDraft(in: context) {
                draft.text = text
                LiveNoteActions.save(context)
            } else {
                LiveNoteActions.add(text: text, in: context)
            }
        }

        typeCharacter("B")
        typeCharacter("Bu")
        typeCharacter("Buy groceries")

        let all = try context.fetch(FetchDescriptor<LiveNote>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.text, "Buy groceries")
    }

    // MARK: Archive / restore

    func testArchiveSetsArchivedAtClearsActivityIDAndPreservesText() throws {
        let context = try makeContext()
        let note = try XCTUnwrap(LiveNoteActions.add(text: "Buy groceries after class", in: context))
        LiveNoteActions.setActivityID("abc-123", for: note, in: context)

        LiveNoteActions.archive(note, in: context)

        XCTAssertTrue(note.isArchived)
        XCTAssertNil(note.activityID)
        XCTAssertEqual(note.text, "Buy groceries after class")
    }

    func testRestoreClearsArchivedAtWithoutRestartingActivity() throws {
        let context = try makeContext()
        let note = try XCTUnwrap(LiveNoteActions.add(text: "Buy groceries after class", in: context))
        LiveNoteActions.archive(note, in: context)

        LiveNoteActions.restore(note, in: context)

        XCTAssertFalse(note.isArchived)
        XCTAssertFalse(note.isLive) // restoring never re-activates the Live Activity
    }

    // MARK: Deletion

    func testDeleteRemovesOnlyThatNote() throws {
        let context = try makeContext()
        let keep = try XCTUnwrap(LiveNoteActions.add(text: "Keep me", in: context))
        let remove = try XCTUnwrap(LiveNoteActions.add(text: "Remove me", in: context))

        LiveNoteActions.delete(remove, in: context)

        let remaining = try context.fetch(FetchDescriptor<LiveNote>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.uuid, keep.uuid)
    }

    func testDeleteAllRemovesEveryLiveNote() throws {
        let context = try makeContext()
        LiveNoteActions.add(text: "One", in: context)
        LiveNoteActions.add(text: "Two", in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<LiveNote>()).count, 2)

        LiveNoteActions.deleteAll(in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<LiveNote>()).count, 0)
    }

    // MARK: Export / Import

    func testExportPayloadIncludesArchivedState() throws {
        let context = try makeContext()
        let note = try XCTUnwrap(LiveNoteActions.add(text: "Archived one", in: context))
        LiveNoteActions.archive(note, in: context)
        LiveNoteActions.add(text: "Active one", in: context)

        let payload = LiveNoteActions.exportPayload(try context.fetch(FetchDescriptor<LiveNote>()))
        XCTAssertEqual(payload.count, 2)
        XCTAssertTrue(payload.contains { $0.text == "Archived one" && $0.archivedAt != nil })
        XCTAssertTrue(payload.contains { $0.text == "Active one" && $0.archivedAt == nil })
    }

    func testImportPayloadAddsNotesWithoutTouchingExisting() throws {
        let context = try makeContext()
        LiveNoteActions.add(text: "Already here", in: context)

        let payload = [LiveNoteActions.ExportNote(text: "Imported", createdAt: Date(), archivedAt: nil)]
        let count = LiveNoteActions.importPayload(payload, in: context)

        XCTAssertEqual(count, 1)
        let all = try context.fetch(FetchDescriptor<LiveNote>())
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains { $0.text == "Imported" })
    }

    func testImportPayloadSkipsEmptyRecords() throws {
        let context = try makeContext()
        let payload = [
            LiveNoteActions.ExportNote(text: "Real note", createdAt: Date(), archivedAt: nil),
            LiveNoteActions.ExportNote(text: "   ", createdAt: Date(), archivedAt: nil),
        ]
        let count = LiveNoteActions.importPayload(payload, in: context)

        XCTAssertEqual(count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<LiveNote>()).count, 1)
    }

    func testImportedNoteNeverCarriesOverAStaleActivityID() throws {
        // Even if a future export format somehow included one, importPayload
        // never sets activityID — an imported note was never live on this device.
        let context = try makeContext()
        let payload = [LiveNoteActions.ExportNote(text: "Imported", createdAt: Date(), archivedAt: nil)]
        LiveNoteActions.importPayload(payload, in: context)

        let note = try XCTUnwrap(try context.fetch(FetchDescriptor<LiveNote>()).first)
        XCTAssertNil(note.activityID)
    }

    // MARK: On-disk: survives a fresh container (simulated relaunch)

    private func makeOnDiskContainer(at url: URL) throws -> ModelContainer {
        try ModelContainer(for: LiveNote.self, configurations: ModelConfiguration(url: url))
    }

    /// "Closes the app, reopens Trace, the text is still there" — a fresh
    /// `ModelContainer` over the same file stands in for a relaunch.
    func testDraftSurvivesContainerRecreation() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let storeURL = dir.appendingPathComponent("relaunch-test.store")
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        do {
            let container = try makeOnDiskContainer(at: storeURL)
            let context = ModelContext(container)
            LiveNoteActions.add(text: "Buy groceries after class", in: context)
        }

        let reopened = try makeOnDiskContainer(at: storeURL)
        let context = ModelContext(reopened)
        let draft = LiveNoteActions.currentDraft(in: context)

        XCTAssertEqual(draft?.text, "Buy groceries after class")
    }
}
