import XCTest
@testable import Trace

private struct Fixture: JournalSearchable {
    var text: String
}

/// Journal text search: case-insensitive substring against the entry text,
/// and nothing else. Dates are handled by ``JournalDateFilter``, not here.
final class JournalFilterTests: XCTestCase {

    func testEmptySearchMatchesEverything() {
        XCTAssertTrue(JournalFilter.matches(Fixture(text: "Anything at all"), search: ""))
    }

    func testWhitespaceOnlySearchMatchesEverything() {
        XCTAssertTrue(JournalFilter.matches(Fixture(text: "Anything at all"), search: "   "))
    }

    func testSearchMatchesTextCaseInsensitively() {
        let entry = Fixture(text: "Went to the Gym before College")
        XCTAssertTrue(JournalFilter.matches(entry, search: "gym"))
        XCTAssertTrue(JournalFilter.matches(entry, search: "GYM"))
        XCTAssertTrue(JournalFilter.matches(entry, search: "college"))
        XCTAssertFalse(JournalFilter.matches(entry, search: "money"))
    }

    func testSearchMatchesSubstringAnywhereInText() {
        let entry = Fixture(text: "Talked to Shahd about the new Trace design.")
        XCTAssertTrue(JournalFilter.matches(entry, search: "shahd"))
        XCTAssertTrue(JournalFilter.matches(entry, search: "trace"))
        XCTAssertTrue(JournalFilter.matches(entry, search: "sign"))   // mid-word substring
    }

    func testSearchWithNoMatchReturnsFalse() {
        XCTAssertFalse(JournalFilter.matches(Fixture(text: "Quiet day, read a bit."), search: "python"))
    }

    func testSearchLeadingAndTrailingWhitespaceIsIgnored() {
        XCTAssertTrue(JournalFilter.matches(Fixture(text: "bought coffee"), search: "  coffee "))
    }

    // MARK: - Dates are no longer special queries

    func testDateLikeQueriesAreTreatedAsPlainTextOnly() {
        // An entry written on 1 September with no date words in its text.
        let entry = Fixture(text: "A calm morning and a long walk.")
        XCTAssertFalse(JournalFilter.matches(entry, search: "September 1"))
        XCTAssertFalse(JournalFilter.matches(entry, search: "Sep 1"))
        XCTAssertFalse(JournalFilter.matches(entry, search: "09/01/2026"))
        XCTAssertFalse(JournalFilter.matches(entry, search: "Today"))
        XCTAssertFalse(JournalFilter.matches(entry, search: "Yesterday"))
    }

    func testADateStringStillMatchesWhenItLiterallyAppearsInTheText() {
        let entry = Fixture(text: "Reminder: submit the form by September 1.")
        XCTAssertTrue(JournalFilter.matches(entry, search: "September 1"))
    }

    // MARK: - Clearing

    func testClearingSearchRestoresEverything() {
        let a = Fixture(text: "gym session")
        let b = Fixture(text: "grocery run")
        XCTAssertTrue(JournalFilter.matches(a, search: "gym"))
        XCTAssertFalse(JournalFilter.matches(b, search: "gym"))
        // Empty query (as the "×" button leaves it) → both visible again.
        XCTAssertTrue(JournalFilter.matches(a, search: ""))
        XCTAssertTrue(JournalFilter.matches(b, search: ""))
    }
}
