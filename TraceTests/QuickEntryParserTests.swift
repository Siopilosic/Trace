import XCTest
@testable import Trace

final class QuickEntryParserTests: XCTestCase {
    let parser = QuickEntryParser(now: { Date(timeIntervalSince1970: 1_700_000_000) })

    // MARK: - Expense: amount + category, empty description

    func testParsedExpenseAmountAndCategoryButEmptyDescription() throws {
        let draft = try XCTUnwrap(parser.parse("McDonald's 320"))
        XCTAssertEqual(draft.kind, .expense)
        XCTAssertEqual(draft.amount, 320)
        XCTAssertEqual(draft.category, .food)
        XCTAssertEqual(draft.title, "", "a parsed expense's description starts empty")
        XCTAssertTrue(draft.isConfident, "a recognisable merchant is still a confident expense")
    }

    func testNormalExpenseDescriptionStartsEmpty() throws {
        let draft = try XCTUnwrap(parser.parse("lunch 150"))
        XCTAssertEqual(draft.amount, 150)
        XCTAssertEqual(draft.category, .food)   // category inference still runs on "lunch"
        XCTAssertEqual(draft.title, "")
    }

    func testLowercaseExpenseStillInfersCategoryWithoutFillingDescription() throws {
        let draft = try XCTUnwrap(parser.parse("coffee 90"))
        XCTAssertEqual(draft.kind, .expense)
        XCTAssertEqual(draft.amount, 90)
        XCTAssertEqual(draft.category, .food)
        XCTAssertEqual(draft.title, "")
    }

    func testTransportCategoryInference() throws {
        let draft = try XCTUnwrap(parser.parse("Uber 180"))
        XCTAssertEqual(draft.amount, 180)
        XCTAssertEqual(draft.category, .transport)
    }

    func testCurrencyTokensDoNotBleedIntoDescriptionAndAmountIsClean() throws {
        let draft = try XCTUnwrap(parser.parse("Groceries 250 EGP"))
        XCTAssertEqual(draft.amount, 250)
        XCTAssertEqual(draft.category, .food)
        XCTAssertEqual(draft.title, "")
    }

    // MARK: - Amount semantics: money vs. numbers in prose

    func testBareNumberIsAnAmount() throws {
        let draft = try XCTUnwrap(parser.parse("300"))
        XCTAssertEqual(draft.kind, .expense)
        XCTAssertEqual(draft.amount, 300)      // 300, never 3
    }

    func testMultiDigitAmountsStayIntact() throws {
        XCTAssertEqual(try XCTUnwrap(parser.parse("300")).amount, 300)
        XCTAssertEqual(try XCTUnwrap(parser.parse("1500")).amount, 1500)
        XCTAssertEqual(try XCTUnwrap(parser.parse("2500 EGP")).amount, 2500)
        XCTAssertEqual(try XCTUnwrap(parser.parse("Rent 4,500")).amount, 4500)
    }

    func testCurrencyAfterNumber() throws {
        XCTAssertEqual(try XCTUnwrap(parser.parse("300 EGP")).amount, 300)
        XCTAssertEqual(try XCTUnwrap(parser.parse("300 egp")).amount, 300)
    }

    func testCurrencyBeforeNumber() throws {
        XCTAssertEqual(try XCTUnwrap(parser.parse("EGP 300")).amount, 300)
        XCTAssertEqual(try XCTUnwrap(parser.parse("$50 tip")).amount, 50)
    }

    func testTrailingNumberAfterALabelIsAnAmount() throws {
        XCTAssertEqual(try XCTUnwrap(parser.parse("lunch 300")).amount, 300)
        XCTAssertEqual(try XCTUnwrap(parser.parse("Uber 180")).amount, 180)
    }

    func testSpendingCueMakesAMidSentenceNumberAnAmount() throws {
        let draft = try XCTUnwrap(parser.parse("spent 300 on lunch"))
        XCTAssertEqual(draft.amount, 300)
        XCTAssertEqual(draft.category, .food)
    }

    func testKSuffixMultiplier() throws {
        XCTAssertEqual(try XCTUnwrap(parser.parse("20k")).amount, 20000)
        XCTAssertEqual(try XCTUnwrap(parser.parse("salary 20k")).amount, 20000)
    }

    // Numbers that are plainly part of a sentence — no amount invented.

    func testNumberOfSandwichesIsNotAnAmount() throws {
        let draft = try XCTUnwrap(parser.parse("I ate 300 sandwiches"))
        XCTAssertNil(draft.amount)
    }

    func testNumberOfPushupsIsNotAnAmount() throws {
        let draft = try XCTUnwrap(parser.parse("I did 45 pushups"))
        XCTAssertNil(draft.amount)
    }

    func testNumberOfMoviesIsNotAnAmount() throws {
        let draft = try XCTUnwrap(parser.parse("I watched 3 movies"))
        XCTAssertNil(draft.amount)      // and definitely not 3,000,000
    }

    func testNumberOfBooksIsNotAnAmount() throws {
        let draft = try XCTUnwrap(parser.parse("I have 300 books"))
        XCTAssertNil(draft.amount)
    }

    func testHoursInProseParseAsDurationNotAmount() throws {
        let draft = try XCTUnwrap(parser.parse("I studied for 2 hours"))
        XCTAssertNil(draft.amount)
        XCTAssertEqual(draft.kind, .activity)
        XCTAssertEqual(draft.durationSeconds, 7200)
    }

    // MARK: - Income

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

    // MARK: - Duration / activity

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

    // MARK: - No structured content

    /// No generic "note" kind to fall back to anymore — Live Note / Journal
    /// replace it. Text with no number/duration anywhere defaults to expense
    /// but stays unconfident, so Quick Add's kind picker nudges the user to
    /// pick explicitly.
    func testSentenceWithNoNumberIsUnconfidentExpense() throws {
        let draft = try XCTUnwrap(parser.parse("Today was actually a really good day"))
        XCTAssertEqual(draft.kind, .expense)
        XCTAssertFalse(draft.isConfident)
        XCTAssertEqual(draft.title, "Today was actually a really good day")
    }

    func testAmbiguousShortFragmentIsUnconfident() throws {
        let draft = try XCTUnwrap(parser.parse("Gym"))
        XCTAssertFalse(draft.isConfident)
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(parser.parse("   "))
    }

    func testBareAmountWithoutDescriptionIsUnconfident() throws {
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
