import Foundation

/// A single bucket in a trend chart (spending or activity time).
struct TrendPoint: Identifiable, Equatable, Sendable {
    var date: Date
    var amount: Double
    var id: Date { date }
}

/// A category row in the money breakdown.
struct CategoryTotal: Identifiable, Equatable, Sendable {
    var category: ExpenseCategory
    var amount: Double
    var id: String { category.rawValue }
}

/// An activity row in the activity breakdown — entries grouped by title
/// (trimmed, case-insensitive), e.g. all "Python" entries summed together.
struct ActivityTotal: Identifiable, Equatable, Sendable {
    var name: String
    var totalSeconds: Double
    var count: Int
    var id: String { name.lowercased() }
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
    var totalActivityDuration: Double

    var averageDailySpending: Double
    var categoryTotals: [CategoryTotal]
    var activityTotals: [ActivityTotal]
    var trend: [TrendPoint]
    var activityTrend: [TrendPoint]

    var net: Double { totalIncome - totalSpent }

    static func empty(period: StatisticsPeriod, interval: DateInterval) -> Statistics {
        Statistics(
            period: period, interval: interval,
            totalSpent: 0, totalIncome: 0, transactionCount: 0,
            activityCount: 0, totalActivityDuration: 0,
            averageDailySpending: 0, categoryTotals: [], activityTotals: [],
            trend: [], activityTrend: []
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
        let activities = inRange.filter { $0.kind == .activity }

        let totalSpent = expenses.compactMap(\.amount).reduce(0, +)
        let totalIncome = incomes.compactMap(\.amount).reduce(0, +)
        let totalActivityDuration = activities.compactMap(\.durationSeconds).reduce(0, +)

        let categoryTotals = Self.categoryBreakdown(expenses)
        let activityTotals = Self.activityBreakdown(activities)
        let trend = trendSeries(expenses, period: period, interval: interval, value: \.amount)
        let activityTrend = trendSeries(activities, period: period, interval: interval, value: \.durationSeconds)
        let elapsedDays = elapsedDayCount(in: interval)

        return Statistics(
            period: period,
            interval: interval,
            totalSpent: totalSpent,
            totalIncome: totalIncome,
            transactionCount: expenses.count + incomes.count,
            activityCount: activities.count,
            totalActivityDuration: totalActivityDuration,
            averageDailySpending: elapsedDays > 0 ? totalSpent / Double(elapsedDays) : totalSpent,
            categoryTotals: categoryTotals,
            activityTotals: activityTotals,
            trend: trend,
            activityTrend: activityTrend
        )
    }

    /// The same period a period ago (previous week/month/year), for "compared
    /// with last month" captions. `nil` for `.day` — a single-day delta isn't a
    /// meaningful comparison — and `nil` if the calendar can't shift back.
    func comparison<E: StatEntry>(
        for entries: [E],
        period: StatisticsPeriod,
        containing date: Date? = nil
    ) -> (current: Statistics, previous: Statistics)? {
        guard period != .day else { return nil }
        let current = statistics(for: entries, period: period, containing: date ?? now())
        guard let previousAnchor = calendar.date(
            byAdding: period.component, value: -1, to: current.interval.start
        ) else { return nil }
        let previous = statistics(for: entries, period: period, containing: previousAnchor)
        return (current, previous)
    }

    /// All-time income minus all-time expenses — the user's overall running
    /// balance. Deliberately separate from `Statistics`/`statistics(for:period:)`:
    /// it is never bounded by a `DateInterval` and never resets when the
    /// selected period changes. Activities and notes never affect it.
    func balance<E: StatEntry>(for entries: [E]) -> Double {
        entries.reduce(0) { total, entry in
            switch entry.kind {
            case .income: return total + (entry.amount ?? 0)
            case .expense: return total - (entry.amount ?? 0)
            case .activity, .note: return total
            }
        }
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

    // MARK: - Activity breakdown

    private static func activityBreakdown<E: StatEntry>(_ activities: [E]) -> [ActivityTotal] {
        var totals: [String: (name: String, seconds: Double, count: Int)] = [:]
        for activity in activities {
            let name = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let key = name.lowercased()
            var entry = totals[key] ?? (name: name, seconds: 0, count: 0)
            entry.seconds += activity.durationSeconds ?? 0
            entry.count += 1
            totals[key] = entry
        }
        return totals.values
            .map { ActivityTotal(name: $0.name, totalSeconds: $0.seconds, count: $0.count) }
            .sorted { $0.totalSeconds > $1.totalSeconds }
    }

    // MARK: - Trend series

    /// One point per bucket across the whole interval, including empty buckets so
    /// the chart has a stable x-axis. `value` extracts whatever's being trended
    /// (expense amount, activity duration, ...) from each source entry.
    private func trendSeries<E: StatEntry>(
        _ source: [E],
        period: StatisticsPeriod,
        interval: DateInterval,
        value: (E) -> Double?
    ) -> [TrendPoint] {
        var buckets: [Date: Double] = [:]

        var cursor = interval.start
        while cursor < interval.end {
            buckets[cursor] = 0
            guard let next = calendar.date(byAdding: period.bucket, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }

        for item in source {
            let key = calendar.dateInterval(of: period.bucket, for: item.date)?.start
                ?? calendar.startOfDay(for: item.date)
            if buckets[key] != nil {
                buckets[key, default: 0] += value(item) ?? 0
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
