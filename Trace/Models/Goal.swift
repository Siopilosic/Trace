import Foundation
import SwiftData

/// What a `Goal` measures. Deliberately small — three goal shapes cover the
/// useful cases without becoming a goal-management system.
enum GoalMetric: String, Codable, CaseIterable, Identifiable, Sendable {
    case spendingLimit
    case savingsTarget
    case activityTime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spendingLimit: return "Monthly Spending Limit"
        case .savingsTarget: return "Monthly Savings Target"
        case .activityTime: return "Activity Target"
        }
    }

    /// Short enough to sit in a 3-way segmented control.
    var shortTitle: String {
        switch self {
        case .spendingLimit: return "Spending"
        case .savingsTarget: return "Savings"
        case .activityTime: return "Activity"
        }
    }

    /// Whether this metric is measured in money (vs. duration).
    var isMoney: Bool { self != .activityTime }
}

/// A lightweight, optional target the user sets themselves. Progress is always
/// computed from existing logged entries (see `GoalsEngine`) — a goal never
/// requires separate manual tracking.
///
/// Additive to the schema: a new, independent model registered alongside
/// `Entry`. Adding it does not touch `Entry`'s table or require a migration.
@Model
final class Goal {
    var uuid: UUID = UUID()

    var metric: GoalMetric = GoalMetric.spendingLimit

    /// EGP for `.spendingLimit` / `.savingsTarget`, seconds for `.activityTime`.
    var targetValue: Double = 0

    /// Only set (and only meaningful) when `metric == .activityTime` — the
    /// entry title this goal tracks, matched case-insensitively.
    var activityName: String?

    var createdAt: Date = Date()

    init(metric: GoalMetric, targetValue: Double, activityName: String? = nil) {
        self.uuid = UUID()
        self.metric = metric
        self.targetValue = targetValue
        self.activityName = metric == .activityTime ? activityName : nil
        self.createdAt = Date()
    }
}
