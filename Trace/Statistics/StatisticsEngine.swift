import Foundation

/// A single bucket in the spending trend chart.
struct TrendPoint: Identifiable, Equatable, Sendable {
    var date: Date
    var amount: Double
    var id: Date { date }
}

/// A category row in the breakdown.
struct CategoryTotal: Identifiable, Equatable, Sendable {
    var category: ExpenseCategory
    var amount: Double
    var id: String { category.rawValue }
}

/// Everything the Statistics screen renders for a period. Immutable snapshot —
/// recomputed whenever entries change.
struct Statistics: Equatable, Sendable {
    var period: StatisticsPeriod
    var interval: DateInterval

    var totalSpent: Double
    var totalIncome: Double
    var transactionCount: Int
    var activityCount: Int

    var averageDailySpending: Double
    var categoryTotals: [CategoryTotal]
    var trend: [TrendPoint]

    var net: Double { totalIncome - totalSpent }

    static func empty(period: StatisticsPeriod, interval: DateInterval) -> Statistics {
        Statistics(
            period: period, interval: interval,
            totalSpent: 0, totalIncome: 0, transactionCount: 0, activityCount: 0,
            averageDailySpending: 0, categoryTotals: [], trend: []
        )
    }
}

/// Pure statistics layer. No SwiftUI, no SwiftData — takes `StatEntry` values
/// and a `Calendar`, returns a `Statistics` snapshot.
struct StatisticsEngine {

    var calendar: Calendar
    /// Injectable clock so "average per day so far" and trend padding are testable.
    var now: () -> Date

    init(calendar: Calendar = .current, now: @escaping () -> Date = { Date() }) {
        self.calendar = calendar
        self.now = now
    }

    func statistics<E: StatEntry>(
        for entries: [E],
        period: StatisticsPeriod,
        containing date: Date? = nil
    ) -> Statistics {
        let anchor = date ?? now()
        let interval = period.interval(containing: anchor, calendar: calendar)

        let inRange = entries.filter { interval.contains($0.date) || $0.date == interval.start }

        let expenses = inRange.filter { $0.kind == .expense }
        let incomes = inRange.filter { $0.kind == .income }

        let totalSpent = expenses.compactMap(\.amount).reduce(0, +)
        let totalIncome = incomes.compactMap(\.amount).reduce(0, +)

        let categoryTotals = Self.categoryBreakdown(expenses)
        let trend = trendSeries(expenses, period: period, interval: interval)
        let elapsedDays = elapsedDayCount(in: interval)

        return Statistics(
            period: period,
            interval: interval,
            totalSpent: totalSpent,
            totalIncome: totalIncome,
            transactionCount: expenses.count + incomes.count,
            activityCount: inRange.filter { $0.kind == .activity }.count,
            averageDailySpending: elapsedDays > 0 ? totalSpent / Double(elapsedDays) : totalSpent,
            categoryTotals: categoryTotals,
            trend: trend
        )
    }

    // MARK: - Category breakdown

    private static func categoryBreakdown<E: StatEntry>(_ expenses: [E]) -> [CategoryTotal] {
        var totals: [ExpenseCategory: Double] = [:]
        for expense in expenses {
            let category = expense.category ?? .other
            totals[category, default: 0] += expense.amount ?? 0
        }
        return totals
            .map { CategoryTotal(category: $0.key, amount: $0.value) }
            .filter { $0.amount > 0 }
            .sorted { $0.amount > $1.amount }
    }

    // MARK: - Trend series

    /// One point per bucket across the whole interval, including empty buckets so
    /// the chart has a stable x-axis.
    private func trendSeries<E: StatEntry>(
        _ expenses: [E],
        period: StatisticsPeriod,
        interval: DateInterval
    ) -> [TrendPoint] {
        var buckets: [Date: Double] = [:]

        var cursor = interval.start
        while cursor < interval.end {
            buckets[cursor] = 0
            guard let next = calendar.date(byAdding: period.bucket, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }

        for expense in expenses {
            let key = calendar.dateInterval(of: period.bucket, for: expense.date)?.start
                ?? calendar.startOfDay(for: expense.date)
            if buckets[key] != nil {
                buckets[key, default: 0] += expense.amount ?? 0
            }
        }

        return buckets
            .map { TrendPoint(date: $0.key, amount: $0.value) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Elapsed days

    /// Number of days in the interval that have actually started (so a mid-month
    /// average divides by days-so-far, not the full month).
    private func elapsedDayCount(in interval: DateInterval) -> Int {
        let end = min(now(), interval.end)
        guard end > interval.start else { return 1 }
        let startDay = calendar.startOfDay(for: interval.start)
        let endDay = calendar.startOfDay(for: end)
        let days = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        return max(1, days + 1)
    }
}
