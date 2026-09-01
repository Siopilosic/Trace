import XCTest
@testable import Trace

private struct Fixture: StatEntry {
    var kind: EntryKind
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
    }
}
