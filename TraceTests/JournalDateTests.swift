import XCTest
@testable import Trace

/// Pure day-header logic for the Journal timeline: `Today` / `Yesterday` /
/// `EEEE, MMMM d`, computed from `createdAt` relative to a reference calendar
/// day — never a rolling 24-hour window, never stored.
final class JournalDateTests: XCTestCase {

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

    private func title(_ iso: String, reference: String) -> String {
        JournalDate.sectionTitle(for: date(iso), calendar: calendar, reference: date(reference))
    }

    // Reference day: Thursday, 3 September 2026.

    func testTodayHeader() {
        XCTAssertEqual(title("2026-09-03T00:05:00Z", reference: "2026-09-03T10:00:00Z"), "Today")
        XCTAssertEqual(title("2026-09-03T23:55:00Z", reference: "2026-09-03T10:00:00Z"), "Today")
    }

    func testYesterdayHeader() {
        XCTAssertEqual(title("2026-09-02T00:05:00Z", reference: "2026-09-03T10:00:00Z"), "Yesterday")
        XCTAssertEqual(title("2026-09-02T23:55:00Z", reference: "2026-09-03T10:00:00Z"), "Yesterday")
    }

    func testTwoDaysAgoUsesWeekdayMonthDay() {
        XCTAssertEqual(title("2026-09-01T12:00:00Z", reference: "2026-09-03T10:00:00Z"), "Tuesday, September 1")
    }

    func testOlderEntryHasNoRelativeLabelAndNoYear() {
        XCTAssertEqual(title("2026-08-31T12:00:00Z", reference: "2026-09-03T10:00:00Z"), "Monday, August 31")
        XCTAssertEqual(title("2026-08-20T12:00:00Z", reference: "2026-09-03T10:00:00Z"), "Thursday, August 20")
    }

    func testHeaderNeverAppendsTheDateToTodayOrYesterday() {
        XCTAssertEqual(title("2026-09-03T09:00:00Z", reference: "2026-09-03T10:00:00Z"), "Today")
        XCTAssertFalse(title("2026-09-03T09:00:00Z", reference: "2026-09-03T10:00:00Z").contains("September"))
        XCTAssertFalse(title("2026-09-02T09:00:00Z", reference: "2026-09-03T10:00:00Z").contains(","))
    }

    // MARK: Month / year boundaries

    func testMonthBoundary() {
        // Reference 1 September → 31 August is "Yesterday", 30 August is dated.
        XCTAssertEqual(title("2026-08-31T12:00:00Z", reference: "2026-09-01T10:00:00Z"), "Yesterday")
        XCTAssertEqual(title("2026-08-30T12:00:00Z", reference: "2026-09-01T10:00:00Z"), "Sunday, August 30")
    }

    func testYearBoundary() {
        // Reference 1 January 2027.
        XCTAssertEqual(title("2027-01-01T00:30:00Z", reference: "2027-01-01T10:00:00Z"), "Today")
        XCTAssertEqual(title("2026-12-31T23:30:00Z", reference: "2027-01-01T10:00:00Z"), "Yesterday")
        XCTAssertEqual(title("2026-12-30T12:00:00Z", reference: "2027-01-01T10:00:00Z"), "Wednesday, December 30")
    }

    // MARK: Reference-day changes

    func testLabelsShiftWhenTheReferenceDayAdvances() {
        let entry = "2026-09-03T12:00:00Z"
        XCTAssertEqual(title(entry, reference: "2026-09-03T10:00:00Z"), "Today")
        XCTAssertEqual(title(entry, reference: "2026-09-04T10:00:00Z"), "Yesterday")
        XCTAssertEqual(title(entry, reference: "2026-09-05T10:00:00Z"), "Thursday, September 3")
    }

    // MARK: Calendar-day, not rolling 24 hours

    func testUsesCalendarDayComparisonNotAnElapsedWindow() {
        // 09:00 on the 2nd → 10:00 on the 3rd is 25 hours, but it is still the
        // previous calendar day.
        XCTAssertEqual(title("2026-09-02T09:00:00Z", reference: "2026-09-03T10:00:00Z"), "Yesterday")
        // 23:30 on the 2nd → 00:30 on the 3rd is one hour, but crosses midnight.
        XCTAssertEqual(title("2026-09-02T23:30:00Z", reference: "2026-09-03T00:30:00Z"), "Yesterday")
        // Same calendar day, ~24h apart at the extremes → still "Today".
        XCTAssertEqual(title("2026-09-03T00:01:00Z", reference: "2026-09-03T23:59:00Z"), "Today")
    }

    // MARK: Time-zone awareness

    func testComparisonHonoursTheCalendarTimeZone() {
        var pacific = calendar
        pacific.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        // 2026-09-03 06:00 UTC is 2026-09-02 23:00 in Los Angeles.
        let entry = date("2026-09-03T06:00:00Z")
        let reference = date("2026-09-03T20:00:00Z") // 13:00 LA, same LA day as… no: entry is LA Sep 2
        XCTAssertEqual(
            JournalDate.sectionTitle(for: entry, calendar: pacific, reference: reference),
            "Yesterday"
        )
    }
}
