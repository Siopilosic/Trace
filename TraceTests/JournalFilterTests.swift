import XCTest
@testable import Trace

private struct Fixture: JournalSearchable {
    var text: String
}

final class JournalFilterTests: XCTestCase {

    func testEmptySearchMatchesEverything() {
        let entry = Fixture(text: "Anything at all")
        XCTAssertTrue(JournalFilter.matches(entry, search: ""))
    }

    func testWhitespaceOnlySearchMatchesEverything() {
        let entry = Fixture(text: "Anything at all")
        XCTAssertTrue(JournalFilter.matches(entry, search: "   "))
    }

    func testSearchMatchesTextCaseInsensitively() {
        let entry = Fixture(text: "Today was actually a really good day.")
        XCTAssertTrue(JournalFilter.matches(entry, search: "good day"))
        XCTAssertTrue(JournalFilter.matches(entry, search: "GOOD DAY"))
        XCTAssertFalse(JournalFilter.matches(entry, search: "bad day"))
    }

    func testSearchMatchesSubstringAnywhereInText() {
        let entry = Fixture(text: "Started working on the new Trace design.")
        XCTAssertTrue(JournalFilter.matches(entry, search: "trace"))
        XCTAssertTrue(JournalFilter.matches(entry, search: "design"))
    }

    func testSearchWithNoMatchReturnsFalse() {
        let entry = Fixture(text: "Quiet day, read a bit.")
        XCTAssertFalse(JournalFilter.matches(entry, search: "python"))
    }
}
