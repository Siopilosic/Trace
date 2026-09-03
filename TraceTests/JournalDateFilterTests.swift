import XCTest
@testable import Trace

/// Pure date-filter logic. Calendar-day boundaries in a fixed calendar/zone —
/// nothing here depends on the machine clock or mutates any entry.
final class JournalDateFilterTests: XCTestCase {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US")
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: iso)!
    }

    private func monthAnchor(_ year: Int, _ month: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    }

    private func contains(_ filter: JournalDateFilter, _ iso: String) -> Bool {
        filter.contains(date(iso), calendar: calendar)
    }

    // MARK: - All

    func testAllMatchesEverythingAndIsNotActive() {
        XCTAssertTrue(contains(.all, "1999-01-01T00:00:00Z"))
        XCTAssertTrue(contains(.all, "2050-12-31T23:59:59Z"))
        XCTAssertFalse(JournalDateFilter.all.isActive)
    }

    // MARK: - Specific day

    func testSpecificDayIncludesTheWholeCalendarDayOnly() {
        let filter = JournalDateFilter.day(date("2026-09-01T13:00:00Z"))
        XCTAssertTrue(filter.isActive)
        XCTAssertTrue(contains(filter, "2026-09-01T00:00:00Z"))   // exactly start of day
        XCTAssertTrue(contains(filter, "2026-09-01T23:59:59Z"))   // exactly end of day
        XCTAssertFalse(contains(filter, "2026-08-31T23:59:59Z"))  // day before
        XCTAssertFalse(contains(filter, "2026-09-02T00:00:00Z"))  // day after
    }

    // MARK: - Specific month

    func testSpecificMonthIncludesEveryDayOfThatMonthAndYear() {
        let filter = JournalDateFilter.month(monthAnchor(2026, 9))
        XCTAssertTrue(contains(filter, "2026-09-01T00:00:00Z"))
        XCTAssertTrue(contains(filter, "2026-09-30T23:30:00Z"))
        XCTAssertFalse(contains(filter, "2026-08-31T23:30:00Z"))
        XCTAssertFalse(contains(filter, "2026-10-01T00:30:00Z"))
    }

    func testSpecificMonthDoesNotMatchTheSameMonthInAnotherYear() {
        let filter = JournalDateFilter.month(monthAnchor(2026, 9))
        XCTAssertFalse(contains(filter, "2025-09-15T12:00:00Z"))
        XCTAssertFalse(contains(filter, "2027-09-15T12:00:00Z"))
    }

    func testJanuaryAndDecemberMonthFiltersRespectYear() {
        XCTAssertTrue(contains(.month(monthAnchor(2027, 1)), "2027-01-31T22:00:00Z"))
        XCTAssertFalse(contains(.month(monthAnchor(2027, 1)), "2026-12-31T22:00:00Z"))
        XCTAssertTrue(contains(.month(monthAnchor(2026, 12)), "2026-12-01T01:00:00Z"))
        XCTAssertFalse(contains(.month(monthAnchor(2026, 12)), "2027-01-01T01:00:00Z"))
    }

    // MARK: - Custom range (inclusive both ends)

    func testRangeIsInclusiveOfBothEndDays() {
        let filter = JournalDateFilter.range(
            from: date("2026-09-01T09:00:00Z"),
            to: date("2026-09-15T18:00:00Z")
        )
        XCTAssertTrue(contains(filter, "2026-09-01T00:00:00Z"))   // start day, midnight
        XCTAssertTrue(contains(filter, "2026-09-15T23:59:59Z"))   // end day, last second
        XCTAssertTrue(contains(filter, "2026-09-08T12:00:00Z"))   // middle
        XCTAssertFalse(contains(filter, "2026-08-31T23:59:59Z"))  // day before start
        XCTAssertFalse(contains(filter, "2026-09-16T00:00:00Z"))  // day after end
    }

    func testRangeIgnoresArgumentOrder() {
        let forward = JournalDateFilter.range(from: date("2026-09-01T00:00:00Z"), to: date("2026-09-10T00:00:00Z"))
        let reversed = JournalDateFilter.range(from: date("2026-09-10T00:00:00Z"), to: date("2026-09-01T00:00:00Z"))
        for iso in ["2026-09-01T05:00:00Z", "2026-09-05T05:00:00Z", "2026-09-10T23:00:00Z"] {
            XCTAssertEqual(contains(forward, iso), contains(reversed, iso), iso)
            XCTAssertTrue(contains(reversed, iso))
        }
    }

    func testRangeAcrossAMonthBoundary() {
        let filter = JournalDateFilter.range(from: date("2026-08-28T00:00:00Z"), to: date("2026-09-03T00:00:00Z"))
        XCTAssertTrue(contains(filter, "2026-08-28T00:00:00Z"))
        XCTAssertTrue(contains(filter, "2026-08-31T23:00:00Z"))
        XCTAssertTrue(contains(filter, "2026-09-03T23:00:00Z"))
        XCTAssertFalse(contains(filter, "2026-09-04T00:00:00Z"))
    }

    func testRangeAcrossAYearBoundary() {
        let filter = JournalDateFilter.range(from: date("2026-12-30T00:00:00Z"), to: date("2027-01-02T00:00:00Z"))
        XCTAssertTrue(contains(filter, "2026-12-31T23:00:00Z"))
        XCTAssertTrue(contains(filter, "2027-01-01T00:30:00Z"))
        XCTAssertTrue(contains(filter, "2027-01-02T23:00:00Z"))
        XCTAssertFalse(contains(filter, "2027-01-03T00:00:00Z"))
        XCTAssertFalse(contains(filter, "2026-12-29T23:00:00Z"))
    }

    func testSingleDayRange() {
        let filter = JournalDateFilter.range(from: date("2026-09-05T08:00:00Z"), to: date("2026-09-05T20:00:00Z"))
        XCTAssertTrue(contains(filter, "2026-09-05T00:00:00Z"))
        XCTAssertTrue(contains(filter, "2026-09-05T23:59:00Z"))
        XCTAssertFalse(contains(filter, "2026-09-06T00:00:00Z"))
    }

    // MARK: - Time zone

    func testComparisonHonoursTheCalendarTimeZone() {
        var pacific = calendar
        pacific.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let filter = JournalDateFilter.day(date("2026-09-02T12:00:00Z")) // noon UTC = 05:00 LA, Sep 2
        // 2026-09-03 06:00 UTC = 2026-09-02 23:00 in LA → still the filtered day.
        XCTAssertTrue(filter.contains(date("2026-09-03T06:00:00Z"), calendar: pacific))
        // 2026-09-03 08:00 UTC = 2026-09-03 01:00 in LA → the next LA day.
        XCTAssertFalse(filter.contains(date("2026-09-03T08:00:00Z"), calendar: pacific))
    }

    // MARK: - Combined with text search

    private struct Entry: JournalSearchable { var text: String; var createdAt: Date }

    private func visible(_ entries: [Entry], search: String, filter: JournalDateFilter) -> [Entry] {
        entries.filter {
            filter.contains($0.createdAt, calendar: calendar) && JournalFilter.matches($0, search: search)
        }
    }

    func testSearchAndDateFilterCombineWithAnd() {
        let entries = [
            Entry(text: "gym then work", createdAt: date("2026-09-03T08:00:00Z")),   // Sept, gym
            Entry(text: "gym then lunch", createdAt: date("2026-10-03T08:00:00Z")),  // Oct, gym
            Entry(text: "quiet reading", createdAt: date("2026-09-10T08:00:00Z")),   // Sept, no gym
        ]
        let september = JournalDateFilter.month(monthAnchor(2026, 9))

        // search + date filter → only September entries containing "gym"
        XCTAssertEqual(visible(entries, search: "gym", filter: september).map(\.text), ["gym then work"])
        // date filter, no search → all September entries
        XCTAssertEqual(visible(entries, search: "", filter: september).map(\.text).sorted(),
                       ["gym then work", "quiet reading"])
        // search, no date filter → all "gym" entries
        XCTAssertEqual(visible(entries, search: "gym", filter: .all).map(\.text).sorted(),
                       ["gym then lunch", "gym then work"])
        // neither → everything
        XCTAssertEqual(visible(entries, search: "", filter: .all).count, 3)
    }

    func testClearingTheDateFilterRestoresAllDates() {
        let entries = [
            Entry(text: "a", createdAt: date("2026-09-03T08:00:00Z")),
            Entry(text: "b", createdAt: date("2026-11-03T08:00:00Z")),
        ]
        XCTAssertEqual(visible(entries, search: "", filter: .month(monthAnchor(2026, 9))).count, 1)
        XCTAssertEqual(visible(entries, search: "", filter: .all).count, 2)
    }

    // MARK: - Labels

    func testActiveFilterProducesALabelAndAllDoesNot() {
        XCTAssertNil(JournalDateFilter.all.label(calendar: calendar))
        XCTAssertEqual(JournalDateFilter.day(date("2026-09-01T12:00:00Z")).label(calendar: calendar), "September 1, 2026")
        XCTAssertEqual(JournalDateFilter.month(monthAnchor(2026, 9)).label(calendar: calendar), "September 2026")
        XCTAssertEqual(
            JournalDateFilter.range(from: date("2026-09-01T00:00:00Z"), to: date("2026-09-15T00:00:00Z")).label(calendar: calendar),
            "Sep 1 – Sep 15, 2026"
        )
    }
}
