import XCTest
@testable import Trace

private struct Fixture: StatEntry {
    var kind: EntryKind
    var title: String = ""
    var amount: Double?
    var durationSeconds: Double?
    var category: ExpenseCategory?
    var date: Date
}

final class CalendarMonthSummaryTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: iso)!
    }

    func testFlagsEachKindSeparately() {
        let entries = [
            Fixture(kind: .expense, amount: 50, date: date("2025-01-10T09:00:00Z")),
            Fixture(kind: .activity, title: "Gym", durationSeconds: 1800, date: date("2025-01-11T09:00:00Z")),
            Fixture(kind: .note, title: "Note", date: date("2025-01-12T09:00:00Z")),
        ]
        let summaries = CalendarMonthSummary.summaries(for: entries, calendar: calendar)

        let day10 = calendar.startOfDay(for: date("2025-01-10T00:00:00Z"))
        let day11 = calendar.startOfDay(for: date("2025-01-11T00:00:00Z"))
        let day12 = calendar.startOfDay(for: date("2025-01-12T00:00:00Z"))

        XCTAssertEqual(summaries[day10]?.hasMoney, true)
        XCTAssertEqual(summaries[day10]?.hasActivity, false)
        XCTAssertEqual(summaries[day11]?.hasActivity, true)
        XCTAssertEqual(summaries[day11]?.hasMoney, false)
        XCTAssertEqual(summaries[day12]?.hasNote, true)
    }

    func testMultipleEntriesSameDayCombineFlags() {
        let entries = [
            Fixture(kind: .expense, amount: 50, date: date("2025-01-10T09:00:00Z")),
            Fixture(kind: .income, amount: 500, date: date("2025-01-10T18:00:00Z")),
            Fixture(kind: .activity, title: "Gym", durationSeconds: 1800, date: date("2025-01-10T20:00:00Z")),
        ]
        let summaries = CalendarMonthSummary.summaries(for: entries, calendar: calendar)
        let day = calendar.startOfDay(for: date("2025-01-10T00:00:00Z"))

        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[day]?.hasMoney, true)
        XCTAssertEqual(summaries[day]?.hasActivity, true)
        XCTAssertEqual(summaries[day]?.hasNote, false)
        XCTAssertFalse(summaries[day]?.isEmpty ?? true)
    }

    func testEmptyEntriesProducesEmptyMap() {
        let summaries = CalendarMonthSummary.summaries(for: [Fixture](), calendar: calendar)
        XCTAssertTrue(summaries.isEmpty)
    }

    func testDaysWithNoEntriesAreAbsentNotEmpty() {
        let entries = [Fixture(kind: .expense, amount: 50, date: date("2025-01-10T09:00:00Z"))]
        let summaries = CalendarMonthSummary.summaries(for: entries, calendar: calendar)
        let untouchedDay = calendar.startOfDay(for: date("2025-01-11T00:00:00Z"))
        XCTAssertNil(summaries[untouchedDay])
    }

    func testEntriesFromDifferentMonthsDoNotLeakBetweenSameDayNumbers() {
        let entries = [
            Fixture(kind: .expense, amount: 10, date: date("2025-08-15T09:00:00Z")),
            Fixture(kind: .activity, title: "Gym", durationSeconds: 1800, date: date("2025-09-15T09:00:00Z")),
            Fixture(kind: .note, title: "Note", date: date("2025-10-15T09:00:00Z")),
        ]
        let summaries = CalendarMonthSummary.summaries(for: entries, calendar: calendar)
        let aug15 = calendar.startOfDay(for: date("2025-08-15T00:00:00Z"))
        let sep15 = calendar.startOfDay(for: date("2025-09-15T00:00:00Z"))
        let oct15 = calendar.startOfDay(for: date("2025-10-15T00:00:00Z"))

        XCTAssertEqual(summaries[aug15]?.hasMoney, true)
        XCTAssertEqual(summaries[aug15]?.hasActivity, false)
        XCTAssertEqual(summaries[sep15]?.hasActivity, true)
        XCTAssertEqual(summaries[sep15]?.hasMoney, false)
        XCTAssertEqual(summaries[oct15]?.hasNote, true)
        XCTAssertEqual(summaries[oct15]?.hasMoney, false)
        XCTAssertEqual(summaries.count, 3)
    }

    // MARK: - gridDays

    func testGridDaysStartsOnFirstWeekdayAndCoversWholeWeeks() {
        let days = CalendarMonthSummary.gridDays(for: date("2025-01-15T12:00:00Z"), calendar: calendar)
        XCTAssertFalse(days.isEmpty)
        XCTAssertEqual(days.count % 7, 0)
        let firstWeekday = calendar.component(.weekday, from: days.first!.date)
        XCTAssertEqual(firstWeekday, calendar.firstWeekday)
    }

    func testGridDaysMarksCurrentMonthCorrectly() {
        let days = CalendarMonthSummary.gridDays(for: date("2025-01-15T12:00:00Z"), calendar: calendar)
        XCTAssertEqual(days.filter(\.isCurrentMonth).count, 31) // January has 31 days
        XCTAssertFalse(days.first!.isCurrentMonth) // leading day borrowed from December
        XCTAssertFalse(days.last!.isCurrentMonth) // trailing day borrowed from February
    }

    func testGridDaysRespectsFirstWeekdayMonday() {
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        let days = CalendarMonthSummary.gridDays(for: date("2025-01-15T12:00:00Z"), calendar: mondayCalendar)
        let firstWeekday = mondayCalendar.component(.weekday, from: days.first!.date)
        XCTAssertEqual(firstWeekday, 2)
    }

    func testGridDaysHandlesShortMonthBoundary() {
        // February 2025 is not a leap year — 28 days, still whole weeks.
        let days = CalendarMonthSummary.gridDays(for: date("2025-02-10T12:00:00Z"), calendar: calendar)
        XCTAssertEqual(days.filter(\.isCurrentMonth).count, 28)
        XCTAssertEqual(days.count % 7, 0)
    }

    // MARK: - weekdaySymbols

    func testWeekdaySymbolsStartFromFirstWeekday() {
        let sundaySymbols = CalendarMonthSummary.weekdaySymbols(calendar: calendar)
        XCTAssertEqual(sundaySymbols.count, 7)

        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        let mondaySymbols = CalendarMonthSummary.weekdaySymbols(calendar: mondayCalendar)
        XCTAssertEqual(mondaySymbols.count, 7)
        XCTAssertEqual(mondaySymbols[0], sundaySymbols[1])
    }
}
