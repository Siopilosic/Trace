import XCTest
@testable import Trace

final class QuickEntryParserTests: XCTestCase {
    let parser = QuickEntryParser(now: { Date(timeIntervalSince1970: 1_700_000_000) })

    func testExpenseWithDescriptionAndAmount() throws {
        let draft = try XCTUnwrap(parser.parse("McDonald's 320"))
        XCTAssertEqual(draft.kind, .expense)
        XCTAssertEqual(draft.title, "McDonald's")
        XCTAssertEqual(draft.amount, 320)
        XCTAssertEqual(draft.category, .food)
        XCTAssertTrue(draft.isConfident)
    }

    func testLowercaseExpenseIsCapitalised() throws {
        let draft = try XCTUnwrap(parser.parse("coffee 90"))
        XCTAssertEqual(draft.kind, .expense)
        XCTAssertEqual(draft.title, "Coffee")
        XCTAssertEqual(draft.amount, 90)
        XCTAssertEqual(draft.category, .food)
    }

    func testTransportCategoryInference() throws {
        let draft = try XCTUnwrap(parser.parse("Uber 180"))
        XCTAssertEqual(draft.amount, 180)
        XCTAssertEqual(draft.category, .transport)
    }

    func testIncomeFromCue() throws {
        let draft = try XCTUnwrap(parser.parse("Got paid 20000"))
        XCTAssertEqual(draft.kind, .income)
        XCTAssertEqual(draft.amount, 20000)
        XCTAssertNil(draft.category)
    }

    func testIncomeKSuffix() throws {
        let draft = try XCTUnwrap(parser.parse("salary 20k"))
        XCTAssertEqual(draft.kind, .income)
        XCTAssertEqual(draft.amount, 20000)
    }

    func testThousandsSeparator() throws {
        let draft = try XCTUnwrap(parser.parse("Rent 4,500"))
        XCTAssertEqual(draft.amount, 4500)
        XCTAssertEqual(draft.category, .bills)
    }

    func testCurrencyTokensStripped() throws {
        let draft = try XCTUnwrap(parser.parse("Groceries 250 EGP"))
        XCTAssertEqual(draft.title, "Groceries")
        XCTAssertEqual(draft.amount, 250)
    }

    func testActivityHours() throws {
        let draft = try XCTUnwrap(parser.parse("Gym 1h"))
        XCTAssertEqual(draft.kind, .activity)
        XCTAssertEqual(draft.title, "Gym")
        XCTAssertEqual(draft.durationSeconds, 3600)
    }

    func testActivityMinutes() throws {
        let draft = try XCTUnwrap(parser.parse("Python 45m"))
        XCTAssertEqual(draft.kind, .activity)
        XCTAssertEqual(draft.title, "Python")
        XCTAssertEqual(draft.durationSeconds, 2700)
    }

    func testActivityCompoundDuration() throws {
        let draft = try XCTUnwrap(parser.parse("Run 1h 30m"))
        XCTAssertEqual(draft.kind, .activity)
        XCTAssertEqual(draft.durationSeconds, 5400)
    }

    func testNoteFromSentence() throws {
        let draft = try XCTUnwrap(parser.parse("Today was actually a really good day"))
        XCTAssertEqual(draft.kind, .note)
        XCTAssertTrue(draft.isConfident)
        XCTAssertEqual(draft.note, "Today was actually a really good day")
    }

    func testAmbiguousShortFragmentIsUnconfident() throws {
        let draft = try XCTUnwrap(parser.parse("Gym"))
        XCTAssertFalse(draft.isConfident)
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(parser.parse("   "))
    }

    func testExpenseWithoutDescriptionIsUnconfident() throws {
        let draft = try XCTUnwrap(parser.parse("500"))
        XCTAssertEqual(draft.kind, .expense)
        XCTAssertEqual(draft.amount, 500)
        XCTAssertFalse(draft.isConfident)
    }

    func testDecimalAmount() throws {
        let draft = try XCTUnwrap(parser.parse("Snack 12.50"))
        XCTAssertEqual(draft.amount, 12.5)
    }
}
