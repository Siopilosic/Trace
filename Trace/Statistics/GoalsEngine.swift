import Foundation

/// A goal's progress for the current month. `current`/`target` are always the
/// real, uncapped numbers — overspending a `.spendingLimit` must stay visible,
/// never silently clamped away. `fraction` is the one clamped value, and it
/// exists only to size a progress bar.
struct GoalProgress: Equatable, Sendable {
    var current: Double
    var target: Double
    var fraction: Double

    var isOverTarget: Bool { current > target }
    var overAmount: Double { max(0, current - target) }

    init(current: Double, target: Double) {
        self.current = current
        self.target = target
        if target > 0 {
            self.fraction = min(1, max(0, current / target))
        } else {
            self.fraction = current > 0 ? 1 : 0
        }
    }
}

/// Pure goal-progress layer, mirroring `StatisticsEngine`'s shape. Every goal's
/// progress is derived from already-logged entries — nothing here is manually
/// tracked separately from the entries themselves.
struct GoalsEngine {
    var calendar: Calendar
    var now: () -> Date

    init(calendar: Calendar = .current, now: @escaping () -> Date = { Date() }) {
        self.calendar = calendar
        self.now = now
    }

    private var statisticsEngine: StatisticsEngine {
        StatisticsEngine(calendar: calendar, now: now)
    }

    /// Progress for `goal` against the current calendar month.
    func progress<E: StatEntry>(for goal: Goal, entries: [E]) -> GoalProgress {
        switch goal.metric {
        case .spendingLimit:
            let stats = statisticsEngine.statistics(for: entries, period: .month)
            return GoalProgress(current: stats.totalSpent, target: goal.targetValue)

        case .savingsTarget:
            // Income − Expenses for the month, per spec — this is `Statistics.net`.
            let stats = statisticsEngine.statistics(for: entries, period: .month)
            return GoalProgress(current: stats.net, target: goal.targetValue)

        case .activityTime:
            let interval = StatisticsPeriod.month.interval(containing: now(), calendar: calendar)
            let name = normalized(goal.activityName)
            let seconds = entries
                .filter { $0.kind == .activity && interval.contains($0.date) }
                .filter { normalized($0.title) == name }
                .compactMap(\.durationSeconds)
                .reduce(0, +)
            return GoalProgress(current: seconds, target: goal.targetValue)
        }
    }

    private func normalized(_ text: String?) -> String {
        (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
