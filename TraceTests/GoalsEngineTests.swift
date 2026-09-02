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

final class GoalsEngineTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Fixed "now": Wed 15 Jan 2025, 12:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_736_942_400)

    private func engine() -> GoalsEngine {
        GoalsEngine(calendar: calendar, now: { self.now })
    }

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: iso)!
    }

    func testSpendingLimitUnderTarget() {
        let goal = Goal(metric: .spendingLimit, targetValue: 10_000)
        let entries = [
            Fixture(kind: .expense, amount: 7_240, date: date("2025-01-10T10:00:00Z")),
            Fixture(kind: .expense, amount: 999, date: date("2024-12-31T10:00:00Z")), // excluded
        ]
        let progress = engine().progress(for: goal, entries: entries)
        XCTAssertEqual(progress.current, 7_240)
        XCTAssertEqual(progress.target, 10_000)
        XCTAssertEqual(progress.fraction, 0.724, accuracy: 0.0001)
        XCTAssertFalse(progress.isOverTarget)
        XCTAssertEqual(progress.overAmount, 0)
    }

    func testSpendingLimitOverTargetIsNotHidden() {
        let goal = Goal(metric: .spendingLimit, targetValue: 10_000)
        let entries = [
            Fixture(kind: .expense, amount: 12_000, date: date("2025-01-10T10:00:00Z")),
        ]
        let progress = engine().progress(for: goal, entries: entries)
        // Real numbers stay uncapped — the UI must be able to show "12,000 / 10,000".
        XCTAssertEqual(progress.current, 12_000)
        XCTAssertEqual(progress.target, 10_000)
        // Only the bar-sizing fraction is clamped.
        XCTAssertEqual(progress.fraction, 1.0)
        XCTAssertTrue(progress.isOverTarget)
        XCTAssertEqual(progress.overAmount, 2_000)
    }

    func testSavingsTargetIsIncomeMinusExpenses() {
        let goal = Goal(metric: .savingsTarget, targetValue: 5_000)
        let entries = [
            Fixture(kind: .income, amount: 20_000, date: date("2025-01-02T10:00:00Z")),
            Fixture(kind: .expense, amount: 16_500, date: date("2025-01-10T10:00:00Z")),
        ]
        let progress = engine().progress(for: goal, entries: entries)
        XCTAssertEqual(progress.current, 3_500) // 20,000 - 16,500
        XCTAssertEqual(progress.fraction, 0.7, accuracy: 0.0001)
    }

    func testSavingsTargetNegativeNetClampsFractionNotCurrent() {
        let goal = Goal(metric: .savingsTarget, targetValue: 5_000)
        let entries = [
            Fixture(kind: .income, amount: 1_000, date: date("2025-01-02T10:00:00Z")),
            Fixture(kind: .expense, amount: 4_000, date: date("2025-01-10T10:00:00Z")),
        ]
        let progress = engine().progress(for: goal, entries: entries)
        XCTAssertEqual(progress.current, -3_000)
        XCTAssertEqual(progress.fraction, 0)
        XCTAssertFalse(progress.isOverTarget)
    }

    func testActivityTimeMatchesTitleCaseInsensitivelyWithinMonth() {
        let goal = Goal(metric: .activityTime, targetValue: 36_000, activityName: "Python") // 10h
        let entries = [
            Fixture(kind: .activity, title: "Python", durationSeconds: 3_600, date: date("2025-01-03T10:00:00Z")),
            Fixture(kind: .activity, title: "python", durationSeconds: 1_800, date: date("2025-01-05T10:00:00Z")),
            Fixture(kind: .activity, title: "Gym", durationSeconds: 9_000, date: date("2025-01-06T10:00:00Z")), // different activity
            Fixture(kind: .activity, title: "Python", durationSeconds: 7_200, date: date("2024-12-20T10:00:00Z")), // last month, excluded
        ]
        let progress = engine().progress(for: goal, entries: entries)
        XCTAssertEqual(progress.current, 5_400) // 3600 + 1800
        XCTAssertEqual(progress.target, 36_000)
    }

    func testZeroTargetDoesNotDivideByZero() {
        let goal = Goal(metric: .spendingLimit, targetValue: 0)
        let progressWithSpend = engine().progress(
            for: goal,
            entries: [Fixture(kind: .expense, amount: 50, date: date("2025-01-10T10:00:00Z"))]
        )
        XCTAssertEqual(progressWithSpend.fraction, 1)

        let progressWithNoSpend = engine().progress(for: goal, entries: [Fixture]())
        XCTAssertEqual(progressWithNoSpend.fraction, 0)
    }

    func testMultipleGoalsComputeIndependentlyFromTheSameEntries() {
        let spending = Goal(metric: .spendingLimit, targetValue: 1_000)
        let savings = Goal(metric: .savingsTarget, targetValue: 2_000)
        let gym = Goal(metric: .activityTime, targetValue: 3_600, activityName: "Gym")

        let entries = [
            Fixture(kind: .income, amount: 5_000, date: date("2025-01-02T10:00:00Z")),
            Fixture(kind: .expense, amount: 800, date: date("2025-01-10T10:00:00Z")),
            Fixture(kind: .activity, title: "Gym", durationSeconds: 1_800, date: date("2025-01-06T10:00:00Z")),
        ]
        let e = engine()

        let spendingProgress = e.progress(for: spending, entries: entries)
        let savingsProgress = e.progress(for: savings, entries: entries)
        let gymProgress = e.progress(for: gym, entries: entries)

        XCTAssertEqual(spendingProgress.current, 800)
        XCTAssertEqual(savingsProgress.current, 4_200) // 5000 - 800
        XCTAssertEqual(gymProgress.current, 1_800)
        // None of the three should have leaked state into another.
        XCTAssertEqual(spendingProgress.target, 1_000)
        XCTAssertEqual(savingsProgress.target, 2_000)
        XCTAssertEqual(gymProgress.target, 3_600)
    }
}
