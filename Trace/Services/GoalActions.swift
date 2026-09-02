import Foundation
import SwiftData

/// Small facade over `ModelContext` for the writes Goals performs — mirrors
/// `EntryActions` so persistence stays in one place per model.
enum GoalActions {

    @discardableResult
    static func add(
        metric: GoalMetric, targetValue: Double, activityName: String?, in context: ModelContext
    ) -> Goal {
        let goal = Goal(metric: metric, targetValue: targetValue, activityName: activityName)
        context.insert(goal)
        save(context)
        return goal
    }

    static func delete(_ goal: Goal, in context: ModelContext) {
        context.delete(goal)
        save(context)
    }

    static func save(_ context: ModelContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Trace failed to save goal: \(error)")
        }
    }

    /// Wipes every goal — called alongside `EntryActions.deleteAll` so
    /// Settings' "Delete All Data" actually deletes all data, not just
    /// entries with goals left silently behind.
    static func deleteAll(in context: ModelContext) {
        do {
            try context.delete(model: Goal.self)
            save(context)
        } catch {
            assertionFailure("Trace failed to delete all goals: \(error)")
        }
    }

    // MARK: Export / Import — see `EntryActions`' equivalent for the rationale.

    struct ExportGoal: Codable {
        var metric: GoalMetric
        var targetValue: Double
        var activityName: String?
        var createdAt: Date
    }

    static func exportPayload(_ goals: [Goal]) -> [ExportGoal] {
        goals.map {
            ExportGoal(metric: $0.metric, targetValue: $0.targetValue, activityName: $0.activityName, createdAt: $0.createdAt)
        }
    }

    /// Inserts one `Goal` per imported record and returns how many were
    /// added. Never touches existing goals.
    @discardableResult
    static func importPayload(_ payload: [ExportGoal], in context: ModelContext) -> Int {
        for item in payload {
            let goal = Goal(metric: item.metric, targetValue: item.targetValue, activityName: item.activityName)
            goal.createdAt = item.createdAt
            context.insert(goal)
        }
        save(context)
        return payload.count
    }
}
