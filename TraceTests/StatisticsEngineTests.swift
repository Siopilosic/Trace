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

final class StatisticsEngineTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 1
        return c
    }()

    /// Fixed "now": Wed 15 Jan 2025, 12:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_736_942_400)

    private func engine() -> StatisticsEngine {
        StatisticsEngine(calendar: calendar, now: { self.now })
    }

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: iso)!
    }

    func testMonthTotals() {
        let entries = [
            Fixture(kind: .expense, amount: 320, durationSeconds: nil, category: .food, date: date("2025-01-02T10:00:00Z")),
            Fixture(kind: .expense, amount: 180, durationSeconds: nil, category: .transport, date: date("2025-01-10T10:00:00Z")),
            Fixture(kind: .income, amount: 20000, durationSeconds: nil, category: nil, date: date("2025-01-01T09:00:00Z")),
            Fixture(kind: .activity, amount: nil, durationSeconds: 3600, category: nil, date: date("2025-01-05T07:00:00Z")),
            // Outside the month — must be excluded.
            Fixture(kind: .expense, amount: 999, durationSeconds: nil, category: .food, date: date("2024-12-31T23:00:00Z")),
        ]

        let stats = engine().statistics(for: entries, period: .month)
        XCTAssertEqual(stats.totalSpent, 500)
        XCTAssertEqual(stats.totalIncome, 20000)
        XCTAssertEqual(stats.net, 19500)
        XCTAssertEqual(stats.transactionCount, 3)
        XCTAssertEqual(stats.activityCount, 1)
    }

    func testCategoryBreakdownSortedDescending() {
        let entries = [
            Fixture(kind: .expense, amount: 100, durationSeconds: nil, category: .food, date: now),
            Fixture(kind: .expense, amount: 400, durationSeconds: nil, category: .transport, date: now),
            Fixture(kind: .expense, amount: 50, durationSeconds: nil, category: nil, date: now),
        ]
        let stats = engine().statistics(for: entries, period: .month)
        XCTAssertEqual(stats.categoryTotals.map(\.category), [.transport, .food, .other])
        XCTAssertEqual(stats.categoryTotals.first?.amount, 400)
    }

    func testAverageDailyUsesElapsedDays() {
        // 15 days elapsed in January by the fixed "now".
        let entries = [
            Fixture(kind: .expense, amount: 1500, durationSeconds: nil, category: .food, date: date("2025-01-03T10:00:00Z"))
        ]
        let stats = engine().statistics(for: entries, period: .month)
        XCTAssertEqual(stats.averageDailySpending, 100, accuracy: 0.001)
    }

    func testWeekBoundariesRespectFirstWeekday() {
        // Week containing Wed 15 Jan with firstWeekday = Sunday → Sun 12 … Sat 18.
        let entries = [
            Fixture(kind: .expense, amount: 10, durationSeconds: nil, category: .food, date: date("2025-01-12T00:30:00Z")),
            Fixture(kind: .expense, amount: 20, durationSeconds: nil, category: .food, date: date("2025-01-18T23:00:00Z")),
            Fixture(kind: .expense, amount: 99, durationSeconds: nil, category: .food, date: date("2025-01-11T23:00:00Z")), // prior Sat
        ]
        let stats = engine().statistics(for: entries, period: .week)
        XCTAssertEqual(stats.totalSpent, 30)
    }

    func testDayPeriodOnlyToday() {
        let entries = [
            Fixture(kind: .expense, amount: 40, durationSeconds: nil, category: .food, date: date("2025-01-15T08:00:00Z")),
            Fixture(kind: .expense, amount: 40, durationSeconds: nil, category: .food, date: date("2025-01-14T08:00:00Z")),
        ]
        let stats = engine().statistics(for: entries, period: .day)
        XCTAssertEqual(stats.totalSpent, 40)
        XCTAssertEqual(stats.averageDailySpending, 40, accuracy: 0.001)
    }

    func testTrendCoversWholeIntervalWithEmptyBuckets() {
        let entries = [
            Fixture(kind: .expense, amount: 100, durationSeconds: nil, category: .food, date: date("2025-01-15T08:00:00Z"))
        ]
        let stats = engine().statistics(for: entries, period: .month)
        XCTAssertEqual(stats.trend.count, 31)
        XCTAssertEqual(stats.trend.map(\.amount).reduce(0, +), 100)
    }

    func testEmptyEntries() {
        let stats = engine().statistics(for: [Fixture](), period: .year)
        XCTAssertEqual(stats.totalSpent, 0)
        XCTAssertEqual(stats.net, 0)
        XCTAssertTrue(stats.categoryTotals.isEmpty)
        XCTAssertEqual(stats.trend.count, 12)
        XCTAssertTrue(stats.activityTotals.isEmpty)
        XCTAssertEqual(stats.activityTrend.count, 12)
    }

    // MARK: - Activity duration / breakdown

    func testTotalActivityDuration() {
        let entries = [
            Fixture(kind: .activity, title: "Gym", durationSeconds: 3600, date: now),
            Fixture(kind: .activity, title: "Python", durationSeconds: 1800, date: now),
            Fixture(kind: .expense, title: "Coffee", amount: 90, date: now), // must be excluded
        ]
        let stats = engine().statistics(for: entries, period: .month)
        XCTAssertEqual(stats.totalActivityDuration, 5400)
    }

    func testActivityBreakdownGroupsByTitleCaseInsensitively() {
        let entries = [
            Fixture(kind: .activity, title: "Python", durationSeconds: 3600, date: date("2025-01-03T10:00:00Z")),
            Fixture(kind: .activity, title: "python", durationSeconds: 1800, date: date("2025-01-05T10:00:00Z")),
            Fixture(kind: .activity, title: "Gym", durationSeconds: 900, date: date("2025-01-06T10:00:00Z")),
        ]
        let stats = engine().statistics(for: entries, period: .month)
        XCTAssertEqual(stats.activityTotals.map(\.name), ["Python", "Gym"])
        XCTAssertEqual(stats.activityTotals[0].totalSeconds, 5400)
        XCTAssertEqual(stats.activityTotals[0].count, 2)
        XCTAssertEqual(stats.activityTotals[1].totalSeconds, 900)
    }

    func testActivityTrendCoversWholeIntervalWithEmptyBuckets() {
        let entries = [
            Fixture(kind: .activity, title: "Gym", durationSeconds: 3600, date: date("2025-01-15T08:00:00Z"))
        ]
        let stats = engine().statistics(for: entries, period: .month)
        XCTAssertEqual(stats.activityTrend.count, 31)
        XCTAssertEqual(stats.activityTrend.map(\.amount).reduce(0, +), 3600)
    }

    // MARK: - Period comparison

    func testComparisonAgainstPreviousMonth() throws {
        let entries = [
            Fixture(kind: .expense, amount: 500, date: date("2025-01-10T10:00:00Z")),   // this month
            Fixture(kind: .expense, amount: 300, date: date("2024-12-15T10:00:00Z")),   // last month
            Fixture(kind: .expense, amount: 999, date: date("2024-11-15T10:00:00Z")),   // two months back — excluded
        ]
        let comparison = try XCTUnwrap(engine().comparison(for: entries, period: .month))
        XCTAssertEqual(comparison.current.totalSpent, 500)
        XCTAssertEqual(comparison.previous.totalSpent, 300)
    }

    func testComparisonHandlesYearBoundary() throws {
        // "Now" is January 2025; the previous month is December 2024.
        let entries = [
            Fixture(kind: .expense, amount: 111, date: date("2024-12-25T10:00:00Z")),
        ]
        let comparison = try XCTUnwrap(engine().comparison(for: entries, period: .month))
        XCTAssertTrue(comparison.previous.interval.start < comparison.current.interval.start)
        XCTAssertEqual(comparison.previous.totalSpent, 111)
    }

    func testComparisonIsNilForDayPeriod() {
        let comparison = engine().comparison(for: [Fixture](), period: .day)
        XCTAssertNil(comparison)
    }

    // MARK: - Balance (all-time, never period-scoped)

    /// The worked example from the product spec: yesterday's activity plus
    /// today's activity, checked against both the cumulative Balance and
    /// today's own Income/Spent/Net.
    func testBalanceCombinesHistoricalAndTodayEntries() {
        let entries = [
            Fixture(kind: .income, amount: 15_000, date: date("2025-01-14T09:00:00Z")),   // yesterday
            Fixture(kind: .expense, amount: 8_000, date: date("2025-01-14T18:00:00Z")),   // yesterday
            Fixture(kind: .income, amount: 20_000, date: date("2025-01-15T09:00:00Z")),   // today
            Fixture(kind: .expense, amount: 1_000, date: date("2025-01-15T18:00:00Z")),   // today
        ]
        XCTAssertEqual(engine().balance(for: entries), 26_000)

        let today = engine().statistics(for: entries, period: .day)
        XCTAssertEqual(today.totalIncome, 20_000)
        XCTAssertEqual(today.totalSpent, 1_000)
        XCTAssertEqual(today.net, 19_000)
    }

    func testBalanceIsNotLimitedToToday() {
        // Only a historical entry, nothing logged today — Balance must still
        // reflect it; it is not "today's balance".
        let entries = [
            Fixture(kind: .income, amount: 5_000, date: date("2024-06-01T09:00:00Z")),
        ]
        XCTAssertEqual(engine().balance(for: entries), 5_000)
        XCTAssertEqual(engine().statistics(for: entries, period: .day).totalIncome, 0)
    }

    func testBalanceIgnoresActivitiesAndNotes() {
        let entries = [
            Fixture(kind: .income, amount: 1_000, date: date("2025-01-10T09:00:00Z")),
            Fixture(kind: .activity, durationSeconds: 3_600, date: date("2025-01-10T10:00:00Z")),
            Fixture(kind: .note, date: date("2025-01-10T11:00:00Z")),
        ]
        XCTAssertEqual(engine().balance(for: entries), 1_000)
    }

    func testBalanceIsZeroWithNoFinancialHistory() {
        XCTAssertEqual(engine().balance(for: [Fixture]()), 0)

        // Activities/notes only — still zero, not broken.
        let nonFinancial = [
            Fixture(kind: .activity, durationSeconds: 1_800, date: date("2025-01-10T09:00:00Z")),
            Fixture(kind: .note, date: date("2025-01-10T10:00:00Z")),
        ]
        XCTAssertEqual(engine().balance(for: nonFinancial), 0)
    }

    func testBalanceUnaffectedByWhichPeriodIsSelectedElsewhere() {
        let entries = [
            Fixture(kind: .income, amount: 15_000, date: date("2025-01-14T09:00:00Z")),
            Fixture(kind: .expense, amount: 8_000, date: date("2025-01-14T18:00:00Z")),
            Fixture(kind: .income, amount: 20_000, date: date("2025-01-15T09:00:00Z")),
            Fixture(kind: .expense, amount: 1_000, date: date("2025-01-15T18:00:00Z")),
        ]
        let balance = engine().balance(for: entries)
        // Computing Statistics for every period first must not perturb it —
        // `balance` takes no period at all, so there is nothing to leak into.
        for period in StatisticsPeriod.allCases {
            _ = engine().statistics(for: entries, period: period)
            XCTAssertEqual(engine().balance(for: entries), balance)
        }
        XCTAssertEqual(balance, 26_000)
    }

    // MARK: - "This month" summary (reuses `statistics(for:period:.month)`)

    /// The compact monthly income/expense line under Balance is just Stats'
    /// existing Month period — this locks in that reuse stays correct as its
    /// own named scenario, distinct from `testMonthTotals`.
    func testThisMonthIncludesOnlyCurrentCalendarMonth() {
        let entries = [
            Fixture(kind: .income, amount: 15_000, date: date("2024-12-20T09:00:00Z")),  // previous month
            Fixture(kind: .expense, amount: 8_000, date: date("2024-12-21T09:00:00Z")),  // previous month
            Fixture(kind: .income, amount: 4_000, date: date("2025-01-03T09:00:00Z")),   // this month
            Fixture(kind: .expense, amount: 1_200, date: date("2025-01-10T09:00:00Z")),  // this month
        ]
        let thisMonth = engine().statistics(for: entries, period: .month)
        XCTAssertEqual(thisMonth.totalIncome, 4_000)
        XCTAssertEqual(thisMonth.totalSpent, 1_200)
    }

    func testThisMonthExcludesPreviousMonthEntries() {
        let entries = [
            Fixture(kind: .income, amount: 9_999, date: date("2024-12-01T09:00:00Z")),
            Fixture(kind: .expense, amount: 9_999, date: date("2024-11-15T09:00:00Z")),
        ]
        let thisMonth = engine().statistics(for: entries, period: .month)
        XCTAssertEqual(thisMonth.totalIncome, 0)
        XCTAssertEqual(thisMonth.totalSpent, 0)
    }

    func testThisMonthIgnoresActivitiesAndNotes() {
        let entries = [
            Fixture(kind: .income, amount: 1_000, date: date("2025-01-05T09:00:00Z")),
            Fixture(kind: .activity, durationSeconds: 3_600, date: date("2025-01-05T10:00:00Z")),
            Fixture(kind: .note, date: date("2025-01-05T11:00:00Z")),
        ]
        let thisMonth = engine().statistics(for: entries, period: .month)
        XCTAssertEqual(thisMonth.totalIncome, 1_000)
        XCTAssertEqual(thisMonth.totalSpent, 0)
    }

    /// The headline scenario: a previous month plus this month, checked
    /// against both scopes at once so a future change can't accidentally
    /// couple them — Balance must stay all-time no matter what "this month" shows.
    func testBalanceIsUnaffectedByThisMonthPresentation() {
        let entries = [
            Fixture(kind: .income, amount: 15_000, date: date("2024-12-20T09:00:00Z")),
            Fixture(kind: .expense, amount: 8_000, date: date("2024-12-21T09:00:00Z")),
            Fixture(kind: .income, amount: 4_000, date: date("2025-01-03T09:00:00Z")),
            Fixture(kind: .expense, amount: 1_200, date: date("2025-01-10T09:00:00Z")),
        ]
        let thisMonth = engine().statistics(for: entries, period: .month)
        XCTAssertEqual(thisMonth.totalIncome, 4_000)
        XCTAssertEqual(thisMonth.totalSpent, 1_200)
        XCTAssertEqual(engine().balance(for: entries), 15_000 - 8_000 + 4_000 - 1_200)
    }
}
