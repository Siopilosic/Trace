import XCTest
import SwiftData
@testable import Trace

/// Covers the Quick Journal `.txt` import end to end: the pure
/// `QuickJournalImport` parser and `JournalActions.importQuickJournal`'s
/// persistence + deduplication, including that it never disturbs existing
/// Journal entries.
final class QuickJournalImportTests: XCTestCase {

    // Interpret Quick Journal's zone-less timestamps in a fixed zone so the
    // expected instants are deterministic.
    private let utc = TimeZone(identifier: "UTC")!

    private func parse(_ raw: String) -> QuickJournalImport.Outcome {
        QuickJournalImport.parse(raw, timeZone: utc)
    }

    private func instant(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: iso)!
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: JournalEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // A well-formed three-entry export, matching the format exactly.
    private let sample = """
    Sep 01, 2026 - 4:06 PM
    First entry text.
    --------------------

    Sep 01, 2026 - 7:21 PM
    Second entry text.
    --------------------

    Sep 01, 2026 - 10:07 PM
    Third entry text.
    --------------------
    """

    // MARK: - Actual export format: separators / timestamps not on their own lines

    /// The exact case reported: the whole export is a single physical line,
    /// `<timestamp> <text> --- <timestamp> <text> --- …`. Must produce one
    /// entry per timestamp.
    func testEntireExportOnOnePhysicalLineProducesOneEntryPerTimestamp() {
        let outcome = parse(
            "Sep 01, 2026 - 4:06 PM entry one --- "
          + "Sep 01, 2026 - 7:21 PM entry two --- "
          + "Sep 01, 2026 - 10:07 PM entry three --- "
          + "Sep 02, 2026 - 4:33 PM entry four ---"
        )
        XCTAssertEqual(outcome.entries.count, 4)
        XCTAssertEqual(outcome.entries.map(\.text), ["entry one", "entry two", "entry three", "entry four"])
        XCTAssertEqual(outcome.entries.map(\.timestamp), [
            instant("2026-09-01T16:06:00Z"),
            instant("2026-09-01T19:21:00Z"),
            instant("2026-09-01T22:07:00Z"),
            instant("2026-09-02T16:33:00Z"),
        ])
        XCTAssertTrue(outcome.failures.isEmpty)
    }

    /// Same one-line shape, but end to end through persistence: exactly four
    /// `JournalEntry` records with the right timestamps and text.
    func testOneLineExportImportsAsFourJournalEntries() throws {
        let context = try makeContext()
        let outcome = parse(
            "Sep 01, 2026 - 4:06 PM Had a slow morning, then a long walk. --- "
          + "Sep 01, 2026 - 7:21 PM Cooked dinner with M. --- "
          + "Sep 01, 2026 - 10:07 PM Read for an hour before bed. --- "
          + "Sep 02, 2026 - 4:33 PM Quiet afternoon at the office. ---"
        )
        let result = JournalActions.importQuickJournal(outcome.entries, in: context)
        XCTAssertEqual(result.imported, 4)

        let stored = try context.fetch(FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        ))
        XCTAssertEqual(stored.map(\.text), [
            "Had a slow morning, then a long walk.",
            "Cooked dinner with M.",
            "Read for an hour before bed.",
            "Quiet afternoon at the office.",
        ])
        XCTAssertEqual(stored.map(\.createdAt), [
            instant("2026-09-01T16:06:00Z"),
            instant("2026-09-01T19:21:00Z"),
            instant("2026-09-01T22:07:00Z"),
            instant("2026-09-02T16:33:00Z"),
        ])
        XCTAssertEqual(stored.map(\.updatedAt), stored.map(\.createdAt))
    }

    /// Multi-line entries with bare `---` separators (not 20 hyphens), each on
    /// its own line — the "conceptual" layout from the report.
    func testMultilineEntriesWithBareTripleDashSeparators() {
        let outcome = parse("""
        Sep 01, 2026 - 4:06 PM
        First entry.
        Second line of the first entry.
        ---
        Sep 01, 2026 - 7:21 PM
        The second entry,
        which also spans
        several lines.
        ---
        Sep 02, 2026 - 4:33 PM
        Third.
        ---
        """)
        XCTAssertEqual(outcome.entries.map(\.text), [
            "First entry.\nSecond line of the first entry.",
            "The second entry,\nwhich also spans\nseveral lines.",
            "Third.",
        ])
        XCTAssertEqual(outcome.entries.map(\.timestamp), [
            instant("2026-09-01T16:06:00Z"),
            instant("2026-09-01T19:21:00Z"),
            instant("2026-09-02T16:33:00Z"),
        ])
        XCTAssertTrue(outcome.failures.isEmpty)
    }

    /// Separators glued to the surrounding text with no spaces at all.
    func testSeparatorsWithNoSurroundingWhitespace() {
        let outcome = parse("Sep 01, 2026 - 4:06 PM\nentry one\n---\nSep 01, 2026 - 7:21 PM\nentry two\n---")
        XCTAssertEqual(outcome.entries.map(\.text), ["entry one", "entry two"])
    }

    /// A one-line export where an entry's own text contains a Markdown `---`
    /// rule — it must not end the entry early.
    func testInlineTripleDashInsideOneLineEntryIsPreserved() {
        let outcome = parse(
            "Sep 01, 2026 - 4:06 PM pros --- cons, weighed them --- "
          + "Sep 01, 2026 - 7:21 PM decided ---"
        )
        XCTAssertEqual(outcome.entries.count, 2)
        XCTAssertEqual(outcome.entries.first?.text, "pros --- cons, weighed them")
        XCTAssertEqual(outcome.entries.last?.text, "decided")
    }

    // MARK: - Parser: multiple entries, date/time, ordering

    func testParsesEveryEntry() {
        let outcome = parse(sample)
        XCTAssertTrue(outcome.failures.isEmpty)
        XCTAssertEqual(outcome.entries.map(\.text), [
            "First entry text.", "Second entry text.", "Third entry text.",
        ])
    }

    func testParsesExactDateAndTime() {
        let outcome = parse(sample)
        XCTAssertEqual(outcome.entries.map(\.timestamp), [
            instant("2026-09-01T16:06:00Z"),
            instant("2026-09-01T19:21:00Z"),
            instant("2026-09-01T22:07:00Z"),
        ])
    }

    func testParsesMidnightAndNoon() {
        let outcome = parse("""
        Dec 25, 2026 - 12:00 AM
        Midnight.
        --------------------

        Dec 25, 2026 - 12:00 PM
        Noon.
        --------------------
        """)
        XCTAssertEqual(outcome.entries.map(\.timestamp), [
            instant("2026-12-25T00:00:00Z"),
            instant("2026-12-25T12:00:00Z"),
        ])
    }

    func testEntriesKeepFileOrderAndAreChronological() throws {
        let context = try makeContext()
        let outcome = parse(sample)
        JournalActions.importQuickJournal(outcome.entries, in: context)

        let stored = try context.fetch(FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        ))
        XCTAssertEqual(stored.map(\.text), [
            "First entry text.", "Second entry text.", "Third entry text.",
        ])
        XCTAssertEqual(stored.map(\.createdAt), stored.map(\.createdAt).sorted())
    }

    // MARK: - Text preservation

    func testPreservesMultilineTextExactly() {
        let body = "Line one.\nLine two.\n\nA new paragraph after a blank line.\n    An indented line."
        let outcome = parse("""
        Sep 02, 2026 - 8:00 AM
        \(body)
        --------------------
        """)
        XCTAssertEqual(outcome.entries.count, 1)
        XCTAssertEqual(outcome.entries.first?.text, body)
    }

    func testPreservesLeadingAndTrailingWhitespaceInBody() throws {
        // A Quick Journal entry that begins with an indented line and ends with
        // trailing spaces — stored verbatim, unlike the JSON import path.
        let raw = "Sep 02, 2026 - 8:00 AM\n  indented first line\nlast line   \n--------------------"
        let outcome = parse(raw)
        XCTAssertEqual(outcome.entries.first?.text, "  indented first line\nlast line   ")

        let context = try makeContext()
        JournalActions.importQuickJournal(outcome.entries, in: context)
        let stored = try XCTUnwrap(try context.fetch(FetchDescriptor<JournalEntry>()).first)
        XCTAssertEqual(stored.text, "  indented first line\nlast line   ")
    }

    // MARK: - Dashes inside journal text

    func testShortDashRunsInsideEntryArePreserved() {
        let body = "Before.\n---\nBetween two rules.\n-----\nAfter a 19-dash line:\n-------------------\nEnd."
        let outcome = parse("""
        Sep 03, 2026 - 9:00 AM
        \(body)
        --------------------
        """)
        XCTAssertEqual(outcome.entries.count, 1)
        XCTAssertEqual(outcome.entries.first?.text, body)
        XCTAssertTrue(outcome.failures.isEmpty)
    }

    func testDashRunsInsideAnEntryAreNeverTreatedAsSeparators() {
        // Only the trailing separator that precedes the next timestamp (or the
        // end of the file) is stripped. Every dash run inside the text — even a
        // full 20-hyphen line — is kept verbatim.
        let outcome = parse("""
        Sep 03, 2026 - 9:00 AM
        Real content.
        --------------------
        More content after a full-width rule.
        ---
        """)
        XCTAssertEqual(outcome.entries.count, 1)
        XCTAssertEqual(
            outcome.entries.first?.text,
            "Real content.\n--------------------\nMore content after a full-width rule."
        )
        XCTAssertTrue(outcome.failures.isEmpty)
    }

    func testHeaderLikeLineInsideBodyIsNotASplit() {
        // "Aug 15, 2026 - 9:00 AM" is a valid timestamp but is not preceded by
        // a separator, so it stays part of the entry's text.
        let outcome = parse("""
        Sep 01, 2026 - 4:06 PM
        I noted the original time was:
        Aug 15, 2026 - 9:00 AM
        and moved on.
        ---
        """)
        XCTAssertEqual(outcome.entries.count, 1)
        XCTAssertEqual(
            outcome.entries.first?.text,
            "I noted the original time was:\nAug 15, 2026 - 9:00 AM\nand moved on."
        )
    }

    // MARK: - Malformed / empty input

    func testEmptyInputProducesNothing() {
        let outcome = parse("")
        XCTAssertTrue(outcome.entries.isEmpty)
        XCTAssertTrue(outcome.failures.isEmpty)
    }

    func testWhitespaceOnlyInputProducesNothing() {
        let outcome = parse("   \n\n\t\n")
        XCTAssertTrue(outcome.entries.isEmpty)
        XCTAssertTrue(outcome.failures.isEmpty)
    }

    func testFileWithNoRecognizableHeaderIsReportedNotDiscarded() {
        let outcome = parse("just some notes\nwith no timestamps at all")
        XCTAssertTrue(outcome.entries.isEmpty)
        XCTAssertEqual(outcome.failures.count, 1)
        XCTAssertEqual(outcome.failures.first?.line, 1)
    }

    func testUnrecognizedTimestampTextIsKeptWithThePrecedingEntryNotDiscarded() {
        // "Sept 1st 2026, 4pm" is not a valid Quick Journal timestamp, so it
        // never opens an entry. Its text is not lost — it stays part of the
        // entry it falls inside. Real Quick Journal exports never contain a
        // malformed timestamp (they are machine-generated).
        let outcome = parse("""
        Sep 01, 2026 - 4:06 PM
        Good entry.
        ---
        Sept 1st 2026, 4pm
        Text under a broken timestamp.
        ---
        Sep 02, 2026 - 9:00 AM
        Another good entry.
        ---
        """)
        XCTAssertEqual(outcome.entries.count, 2)
        XCTAssertEqual(
            outcome.entries.first?.text,
            "Good entry.\n---\nSept 1st 2026, 4pm\nText under a broken timestamp."
        )
        XCTAssertEqual(outcome.entries.last?.text, "Another good entry.")
        XCTAssertTrue(outcome.entries.first?.text.contains("Text under a broken timestamp.") ?? false)
    }

    func testHeaderWithNoBodyIsReported() {
        let outcome = parse("""
        Sep 01, 2026 - 4:06 PM
        --------------------

        Sep 02, 2026 - 9:00 AM
        Has text.
        --------------------
        """)
        XCTAssertEqual(outcome.entries.map(\.text), ["Has text."])
        XCTAssertEqual(outcome.failures.count, 1)
        XCTAssertEqual(outcome.failures.first?.line, 1)
        XCTAssertTrue(outcome.failures.first?.reason.contains("no text") ?? false)
    }

    func testTrailingEntryWithoutClosingSeparatorStillImports() {
        let outcome = parse("""
        Sep 01, 2026 - 4:06 PM
        Closed entry.
        --------------------

        Sep 02, 2026 - 9:00 AM
        Last entry, export truncated before its separator.
        """)
        XCTAssertEqual(outcome.entries.map(\.text), [
            "Closed entry.", "Last entry, export truncated before its separator.",
        ])
        XCTAssertTrue(outcome.failures.isEmpty)
    }

    func testCRLFLineEndingsAreHandled() {
        let raw = "Sep 01, 2026 - 4:06 PM\r\nWindows line endings.\r\n--------------------\r\n"
        let outcome = parse(raw)
        XCTAssertEqual(outcome.entries.map(\.text), ["Windows line endings."])
        XCTAssertEqual(outcome.entries.first?.timestamp, instant("2026-09-01T16:06:00Z"))
    }

    // MARK: - Persistence: createdAt / updatedAt

    func testImportedEntryUsesParsedTimestampAsCreatedAtWithUpdatedAtEqual() throws {
        let context = try makeContext()
        let outcome = parse(sample)
        JournalActions.importQuickJournal(outcome.entries, in: context)

        let stored = try context.fetch(FetchDescriptor<JournalEntry>())
        for entry in stored {
            // updatedAt starts equal to createdAt, exactly like a new entry…
            XCTAssertEqual(entry.createdAt, entry.updatedAt)
            // …and createdAt is the original timestamp, not the import moment.
            XCTAssertGreaterThan(abs(entry.createdAt.timeIntervalSinceNow), 60)
        }
        XCTAssertEqual(
            Set(stored.map(\.createdAt)),
            [instant("2026-09-01T16:06:00Z"), instant("2026-09-01T19:21:00Z"), instant("2026-09-01T22:07:00Z")]
        )
    }

    // MARK: - Does not disturb existing entries

    func testImportAddsToAnExistingJournalWithoutDeletingAnything() throws {
        let context = try makeContext()
        let existing = try XCTUnwrap(
            JournalActions.add(text: "Written directly in Trace.", createdAt: instant("2025-01-01T09:00:00Z"), in: context)
        )

        let outcome = parse(sample)
        let result = JournalActions.importQuickJournal(outcome.entries, in: context)

        XCTAssertEqual(result.imported, 3)
        let all = try context.fetch(FetchDescriptor<JournalEntry>())
        XCTAssertEqual(all.count, 4)
        XCTAssertTrue(all.contains { $0.uuid == existing.uuid })
        XCTAssertTrue(all.contains { $0.text == "Written directly in Trace." })
    }

    // MARK: - Deduplication

    func testReimportingTheSameFileCreatesNoDuplicates() throws {
        let context = try makeContext()
        let outcome = parse(sample)

        let first = JournalActions.importQuickJournal(outcome.entries, in: context)
        XCTAssertEqual(first.imported, 3)
        XCTAssertEqual(first.duplicatesSkipped, 0)

        let second = JournalActions.importQuickJournal(outcome.entries, in: context)
        XCTAssertEqual(second.imported, 0)
        XCTAssertEqual(second.duplicatesSkipped, 3)

        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 3)
    }

    func testDedupeMatchesOnBothTimestampAndText() throws {
        let context = try makeContext()
        // Same timestamp as sample entry 1, different text → not a duplicate.
        JournalActions.add(text: "A different entry at the same minute.",
                           createdAt: instant("2026-09-01T16:06:00Z"), in: context)

        let result = JournalActions.importQuickJournal(parse(sample).entries, in: context)
        XCTAssertEqual(result.imported, 3)
        XCTAssertEqual(result.duplicatesSkipped, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 4)
    }

    func testDedupeAlsoConsidersArchivedEntries() throws {
        let context = try makeContext()
        let outcome = parse(sample)
        JournalActions.importQuickJournal(outcome.entries, in: context)

        let all = try context.fetch(FetchDescriptor<JournalEntry>())
        JournalActions.archive(all[0], in: context)

        let again = JournalActions.importQuickJournal(outcome.entries, in: context)
        XCTAssertEqual(again.imported, 0)
        XCTAssertEqual(again.duplicatesSkipped, 3)
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 3)
    }

    func testImportIsIdempotentAcrossAContainerReopen() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let storeURL = dir.appendingPathComponent("qj.store")
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        let outcome = parse(sample)
        do {
            let context = ModelContext(try ModelContainer(for: JournalEntry.self, configurations: ModelConfiguration(url: storeURL)))
            JournalActions.importQuickJournal(outcome.entries, in: context)
        }
        let reopened = ModelContext(try ModelContainer(for: JournalEntry.self, configurations: ModelConfiguration(url: storeURL)))
        let result = JournalActions.importQuickJournal(outcome.entries, in: reopened)
        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.duplicatesSkipped, 3)
        XCTAssertEqual(try reopened.fetch(FetchDescriptor<JournalEntry>()).count, 3)
    }

    // MARK: - Compatibility with Journal date grouping / search
    //
    // Imported entries keep their original Quick Journal timestamp as
    // `createdAt`, so the pure Journal date helpers must place and find them
    // by that date. These tests exercise the helpers against imported
    // entries — they do not touch the importer.

    func testImportedEntriesGroupUnderTheCorrectDayHeader() throws {
        let context = try makeContext()
        // One-line export spanning two calendar days.
        let outcome = parse(
            "Sep 01, 2026 - 4:06 PM morning --- "
          + "Sep 01, 2026 - 10:07 PM night --- "
          + "Sep 03, 2026 - 9:00 AM later ---"
        )
        JournalActions.importQuickJournal(outcome.entries, in: context)

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let reference = instant("2026-09-03T12:00:00Z") // "today" = Sep 3

        let stored = try context.fetch(FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        ))
        let headers = stored.map {
            JournalDate.sectionTitle(for: $0.createdAt, calendar: calendar, reference: reference)
        }
        XCTAssertEqual(headers, ["Tuesday, September 1", "Tuesday, September 1", "Today"])
    }

    func testImportedEntryIsMatchedByTheDateFilterAndByTextSearch() throws {
        let context = try makeContext()
        let outcome = parse("Sep 01, 2026 - 4:06 PM lunch at the usual place ---")
        JournalActions.importQuickJournal(outcome.entries, in: context)

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let entry = try XCTUnwrap(try context.fetch(FetchDescriptor<JournalEntry>()).first)
        // The imported entry keeps its original createdAt, so the date filter
        // places it on 1 September 2026.
        XCTAssertTrue(JournalDateFilter.day(instant("2026-09-01T00:00:00Z")).contains(entry.createdAt, calendar: calendar))
        XCTAssertTrue(JournalDateFilter.month(calendar.date(from: DateComponents(year: 2026, month: 9))!).contains(entry.createdAt, calendar: calendar))
        XCTAssertFalse(JournalDateFilter.day(instant("2026-09-10T00:00:00Z")).contains(entry.createdAt, calendar: calendar))
        // Text search still works on the imported text.
        XCTAssertTrue(JournalFilter.matches(entry, search: "lunch"))
    }

    // MARK: - Report text

    func testReportMentionsImportedDuplicatesAndFailures() {
        let message = JournalSettingsView.quickJournalMessage(
            result: .init(imported: 5, duplicatesSkipped: 2),
            failures: [.init(line: 12, snippet: "bad", reason: "Entry has a timestamp but no text — not imported.")]
        )
        XCTAssertTrue(message.contains("Imported 5 entries."))
        XCTAssertTrue(message.contains("2 already in your journal"))
        XCTAssertTrue(message.contains("Line 12"))
    }
}
