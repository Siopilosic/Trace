import XCTest
import SwiftData
@testable import Trace

/// Exercises `GoalActions` against real `ModelContext`s — creation, editing,
/// and deletion for each goal type, plus persistence across a fresh
/// `ModelContainer` (standing in for an app relaunch).
final class GoalActionsTests: XCTestCase {

    // MARK: In-memory: create / edit / delete mechanics

    private func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Goal.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func testAddSpendingLimitGoal() throws {
        let context = try makeInMemoryContext()
        let goal = GoalActions.add(metric: .spendingLimit, targetValue: 5_000, activityName: nil, in: context)
        XCTAssertEqual(goal.metric, .spendingLimit)
        XCTAssertEqual(goal.targetValue, 5_000)
        XCTAssertNil(goal.activityName)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Goal>()).count, 1)
    }

    func testAddSavingsGoal() throws {
        let context = try makeInMemoryContext()
        let goal = GoalActions.add(metric: .savingsTarget, targetValue: 3_000, activityName: nil, in: context)
        XCTAssertEqual(goal.metric, .savingsTarget)
        XCTAssertEqual(goal.targetValue, 3_000)
    }

    func testAddActivityGoal() throws {
        let context = try makeInMemoryContext()
        let goal = GoalActions.add(metric: .activityTime, targetValue: 36_000, activityName: "Python", in: context)
        XCTAssertEqual(goal.metric, .activityTime)
        XCTAssertEqual(goal.activityName, "Python")
    }

    func testEditingChangesTargetAndPersists() throws {
        let context = try makeInMemoryContext()
        let goal = GoalActions.add(metric: .spendingLimit, targetValue: 1_000, activityName: nil, in: context)

        goal.targetValue = 2_500
        GoalActions.save(context)

        let refetched = try context.fetch(FetchDescriptor<Goal>()).first
        XCTAssertEqual(refetched?.targetValue, 2_500)
    }

    func testEditingCanChangeMetricAndActivityName() throws {
        let context = try makeInMemoryContext()
        let goal = GoalActions.add(metric: .activityTime, targetValue: 3_600, activityName: "Gym", in: context)

        goal.metric = .activityTime
        goal.activityName = "Reading"
        GoalActions.save(context)

        let refetched = try context.fetch(FetchDescriptor<Goal>()).first
        XCTAssertEqual(refetched?.activityName, "Reading")
    }

    func testDeleteRemovesGoal() throws {
        let context = try makeInMemoryContext()
        let goal = GoalActions.add(metric: .spendingLimit, targetValue: 1_000, activityName: nil, in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Goal>()).count, 1)

        GoalActions.delete(goal, in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Goal>()).count, 0)
    }

    func testDeleteAllRemovesEveryGoal() throws {
        let context = try makeInMemoryContext()
        GoalActions.add(metric: .spendingLimit, targetValue: 1_000, activityName: nil, in: context)
        GoalActions.add(metric: .savingsTarget, targetValue: 2_000, activityName: nil, in: context)
        GoalActions.add(metric: .activityTime, targetValue: 3_600, activityName: "Gym", in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Goal>()).count, 3)

        GoalActions.deleteAll(in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Goal>()).count, 0)
    }

    func testDeletingOneGoalLeavesOthersIntact() throws {
        let context = try makeInMemoryContext()
        let keep = GoalActions.add(metric: .spendingLimit, targetValue: 1_000, activityName: nil, in: context)
        let remove = GoalActions.add(metric: .savingsTarget, targetValue: 2_000, activityName: nil, in: context)

        GoalActions.delete(remove, in: context)

        let remaining = try context.fetch(FetchDescriptor<Goal>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.uuid, keep.uuid)
    }

    // MARK: Export / Import

    func testExportPayloadIncludesAllGoals() throws {
        let context = try makeInMemoryContext()
        GoalActions.add(metric: .spendingLimit, targetValue: 5_000, activityName: nil, in: context)
        GoalActions.add(metric: .activityTime, targetValue: 3_600, activityName: "Gym", in: context)

        let payload = GoalActions.exportPayload(try context.fetch(FetchDescriptor<Goal>()))
        XCTAssertEqual(payload.count, 2)
        XCTAssertTrue(payload.contains { $0.metric == .activityTime && $0.activityName == "Gym" })
    }

    func testImportPayloadAddsGoalsWithoutTouchingExisting() throws {
        let context = try makeInMemoryContext()
        GoalActions.add(metric: .spendingLimit, targetValue: 1_000, activityName: nil, in: context)

        let payload = [
            GoalActions.ExportGoal(metric: .savingsTarget, targetValue: 3_000, activityName: nil, createdAt: Date())
        ]
        let count = GoalActions.importPayload(payload, in: context)

        XCTAssertEqual(count, 1)
        let all = try context.fetch(FetchDescriptor<Goal>())
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains { $0.metric == .savingsTarget && $0.targetValue == 3_000 })
    }

    // MARK: On-disk: survives a fresh container (simulated relaunch)

    private func makeOnDiskContainer(at url: URL) throws -> ModelContainer {
        try ModelContainer(for: Goal.self, configurations: ModelConfiguration(url: url))
    }

    func testGoalsSurviveContainerRecreation() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let storeURL = dir.appendingPathComponent("relaunch-test.store")
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        do {
            let container = try makeOnDiskContainer(at: storeURL)
            let context = ModelContext(container)
            GoalActions.add(metric: .spendingLimit, targetValue: 5_000, activityName: nil, in: context)
            GoalActions.add(metric: .activityTime, targetValue: 3_600, activityName: "Gym", in: context)
        }

        // A brand new container over the same file stands in for the app
        // being relaunched — nothing here shares state with the block above.
        let reopened = try makeOnDiskContainer(at: storeURL)
        let context = ModelContext(reopened)
        let goals = try context.fetch(FetchDescriptor<Goal>())

        XCTAssertEqual(goals.count, 2)
        XCTAssertTrue(goals.contains { $0.metric == .spendingLimit && $0.targetValue == 5_000 })
        XCTAssertTrue(goals.contains { $0.metric == .activityTime && $0.activityName == "Gym" })
    }

    func testDeleteSurvivesContainerRecreation() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let storeURL = dir.appendingPathComponent("relaunch-delete-test.store")
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        do {
            let container = try makeOnDiskContainer(at: storeURL)
            let context = ModelContext(container)
            let goal = GoalActions.add(metric: .spendingLimit, targetValue: 5_000, activityName: nil, in: context)
            GoalActions.add(metric: .savingsTarget, targetValue: 2_000, activityName: nil, in: context)
            GoalActions.delete(goal, in: context)
        }

        let reopened = try makeOnDiskContainer(at: storeURL)
        let goals = try ModelContext(reopened).fetch(FetchDescriptor<Goal>())
        XCTAssertEqual(goals.count, 1)
        XCTAssertEqual(goals.first?.metric, .savingsTarget)
    }
}
