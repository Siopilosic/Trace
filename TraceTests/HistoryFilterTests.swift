import XCTest
@testable import Trace

private struct Fixture: HistorySearchable {
    var kind: EntryKind
    var title: String
    var noteText: String?
    var category: ExpenseCategory?
}

final class HistoryFilterTests: XCTestCase {

    func testAllMatchesEveryKind() {
        let kinds: [EntryKind] = [.expense, .income, .activity, .note]
        for kind in kinds {
            let entry = Fixture(kind: kind, title: "Anything", noteText: nil, category: nil)
            XCTAssertTrue(HistoryFilter.matches(entry, search: "", type: .all))
        }
    }

    func testTypeFilterOnlyMatchesItsKind() {
        let expense = Fixture(kind: .expense, title: "Uber", noteText: nil, category: .transport)
        let activity = Fixture(kind: .activity, title: "Uber-themed workout", noteText: nil, category: nil)

        XCTAssertTrue(HistoryFilter.matches(expense, search: "", type: .expenses))
        XCTAssertFalse(HistoryFilter.matches(activity, search: "", type: .expenses))
        XCTAssertTrue(HistoryFilter.matches(activity, search: "", type: .activities))
    }

    func testSearchMatchesTitleCaseInsensitively() {
        let entry = Fixture(kind: .activity, title: "Gym", noteText: nil, category: nil)
        XCTAssertTrue(HistoryFilter.matches(entry, search: "gym", type: .all))
        XCTAssertTrue(HistoryFilter.matches(entry, search: "GYM", type: .all))
        XCTAssertFalse(HistoryFilter.matches(entry, search: "python", type: .all))
    }

    func testSearchMatchesNoteText() {
        let entry = Fixture(kind: .note, title: "Reflection", noteText: "Today was a good day", category: nil)
        XCTAssertTrue(HistoryFilter.matches(entry, search: "good day", type: .all))
    }

    func testSearchMatchesCategoryDisplayName() {
        let entry = Fixture(kind: .expense, title: "Zara", noteText: nil, category: .shopping)
        XCTAssertTrue(HistoryFilter.matches(entry, search: "shopping", type: .all))
    }

    func testSearchAndTypeFilterCombineWithAnd() {
        // "Search 'gym' + Activities → only matching activity entries" — a
        // non-activity entry containing "gym" must not slip through.
        let gymActivity = Fixture(kind: .activity, title: "Gym", noteText: nil, category: nil)
        let gymExpense = Fixture(kind: .expense, title: "Gym membership", noteText: nil, category: .bills)

        XCTAssertTrue(HistoryFilter.matches(gymActivity, search: "gym", type: .activities))
        XCTAssertFalse(HistoryFilter.matches(gymExpense, search: "gym", type: .activities))
    }

    func testSearchAndExpenseFilterExample() {
        // "Search 'uber' + Expenses → only matching expense entries."
        let uberExpense = Fixture(kind: .expense, title: "Uber", noteText: nil, category: .transport)
        let uberNote = Fixture(kind: .note, title: "Uber was late today", noteText: nil, category: nil)

        XCTAssertTrue(HistoryFilter.matches(uberExpense, search: "uber", type: .expenses))
        XCTAssertFalse(HistoryFilter.matches(uberNote, search: "uber", type: .expenses))
    }

    func testEmptySearchWithTypeFilterMatchesAllOfThatType() {
        let activity = Fixture(kind: .activity, title: "Anything at all", noteText: nil, category: nil)
        XCTAssertTrue(HistoryFilter.matches(activity, search: "", type: .activities))
        XCTAssertFalse(HistoryFilter.matches(activity, search: "", type: .income))
    }

    // `.notes` is no longer a type filter — Note is legacy-only (Live Note
    // replaces it) and any existing note entries still show up under `.all`.
    func testAllStillMatchesLegacyNoteEntries() {
        let note = Fixture(kind: .note, title: "Anything at all", noteText: nil, category: nil)
        XCTAssertTrue(HistoryFilter.matches(note, search: "", type: .all))
    }
}
