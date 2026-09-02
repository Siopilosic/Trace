import SwiftUI

/// One goal's progress — label, "current / target", proportional bar. An
/// over-target `.spendingLimit` is called out explicitly rather than the bar
/// just quietly capping at full.
struct GoalRow: View {
    let goal: Goal
    let progress: GoalProgress

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            ProportionalBarRow(
                label: title,
                valueText: Format.goalProgress(
                    current: progress.current, target: progress.target, isMoney: goal.metric.isMoney
                ),
                fraction: progress.fraction,
                valueTint: isOverspent ? .traceNegative : (isAchieved ? .tracePositive : .secondary),
                barTint: isOverspent ? .traceNegative : (isAchieved ? .tracePositive : .traceAccent)
            )
            if isOverspent {
                Text("Over by \(Format.money(progress.overAmount))")
                    .font(.caption)
                    .foregroundStyle(Color.traceNegative)
            }
        }
    }

    private var title: String {
        switch goal.metric {
        case .spendingLimit: return "Monthly Spending"
        case .savingsTarget: return "Savings"
        case .activityTime:
            let name = goal.activityName?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (name?.isEmpty == false ? name : nil) ?? "Activity"
        }
    }

    /// Exceeding target only reads as a problem for a spending limit — going
    /// over on savings or activity time is a good thing, not a warning.
    private var isOverspent: Bool {
        goal.metric == .spendingLimit && progress.isOverTarget
    }

    /// Reaching or passing a savings/activity target is worth a quiet nod —
    /// the same positive tint used for income, not a badge or celebration.
    /// `>=` (via `fraction`, not `isOverTarget`) so landing exactly on the
    /// target counts as achieved too.
    private var isAchieved: Bool {
        goal.metric != .spendingLimit && progress.fraction >= 1.0
    }
}
