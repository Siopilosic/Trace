import XCTest
import SwiftData
@testable import Trace

/// Regression coverage for the Quick Add duration bug at the persistence
/// layer: `EntryActions.add` — the exact call `QuickAddView.save()` makes —
/// must carry a `ParsedDraft`'s activity duration into the saved `Entry`.
final class EntryActionsTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Entry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func testActivityDurationPersists_45Minutes() throws {
        let context = try makeContext()
        let draft = ParsedDraft(kind: .activity, title: "Study", durationSeconds: 2_700)

        let entry = EntryActions.add(draft, in: context)

        XCTAssertEqual(entry.durationSeconds, 2_700)
        let refetched = try context.fetch(FetchDescriptor<Entry>()).first
        XCTAssertEqual(refetched?.durationSeconds, 2_700)
    }

    func testActivityDurationPersists_1h30m() throws {
        let context = try makeContext()
        let draft = ParsedDraft(kind: .activity, title: "Study", durationSeconds: 5_400)

        let entry = EntryActions.add(draft, in: context)

        XCTAssertEqual(entry.durationSeconds, 5_400)
        let refetched = try context.fetch(FetchDescriptor<Entry>()).first
        XCTAssertEqual(refetched?.durationSeconds, 5_400)
    }

    func testActivityDurationPersists_1h1m() throws {
        let context = try makeContext()
        let draft = ParsedDraft(kind: .activity, title: "Study", durationSeconds: 3_660)

        let entry = EntryActions.add(draft, in: context)

        XCTAssertEqual(entry.durationSeconds, 3_660)
        let refetched = try context.fetch(FetchDescriptor<Entry>()).first
        XCTAssertEqual(refetched?.durationSeconds, 3_660)
    }

    func testActivityWithNoDurationPersistsAsNil() throws {
        let context = try makeContext()
        let draft = ParsedDraft(kind: .activity, title: "Gym", durationSeconds: nil)

        let entry = EntryActions.add(draft, in: context)

        XCTAssertNil(entry.durationSeconds)
    }

    func testDeleteAllRemovesEveryEntry() throws {
        let context = try makeContext()
        EntryActions.add(ParsedDraft(kind: .expense, title: "Coffee", amount: 90), in: context)
        EntryActions.add(ParsedDraft(kind: .activity, title: "Gym", durationSeconds: 3_600), in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Entry>()).count, 2)

        EntryActions.deleteAll(in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Entry>()).count, 0)
    }

    // MARK: - Export / Import

    func testExportPayloadIncludesAllEntries() throws {
        let context = try makeContext()
        EntryActions.add(ParsedDraft(kind: .expense, title: "Coffee", amount: 90), in: context)
        EntryActions.add(ParsedDraft(kind: .income, title: "Bonus", amount: 500), in: context)

        let payload = EntryActions.exportPayload(try context.fetch(FetchDescriptor<Entry>()))
        XCTAssertEqual(payload.count, 2)
        XCTAssertTrue(payload.contains { $0.title == "Coffee" && $0.kind == .expense })
    }

    func testImportPayloadAddsEntriesWithoutTouchingExisting() throws {
        let context = try makeContext()
        EntryActions.add(ParsedDraft(kind: .note, title: "Already here"), in: context)

        let payload = [
            EntryActions.ExportEntry(
                kind: .expense, title: "Imported expense", amount: 250, durationSeconds: nil,
                category: .food, noteText: nil, date: Date(), createdAt: Date()
            )
        ]
        let count = EntryActions.importPayload(payload, in: context)

        XCTAssertEqual(count, 1)
        let all = try context.fetch(FetchDescriptor<Entry>())
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains { $0.title == "Imported expense" && $0.amount == 250 })
    }

    // MARK: - Balance reacts to real mutations (not just the pure calculation)

    private func balance(in context: ModelContext) throws -> Double {
        let entries = try context.fetch(FetchDescriptor<Entry>())
        return StatisticsEngine().balance(for: entries)
    }

    func testEditingAnIncomeAmountChangesBalance() throws {
        let context = try makeContext()
        let salary = EntryActions.add(ParsedDraft(kind: .income, title: "Salary", amount: 10_000), in: context)
        XCTAssertEqual(try balance(in: context), 10_000)

        salary.amount = 12_000
        EntryActions.save(context)

        XCTAssertEqual(try balance(in: context), 12_000)
    }

    func testEditingAnExpenseAmountChangesBalance() throws {
        let context = try makeContext()
        let rent = EntryActions.add(ParsedDraft(kind: .expense, title: "Rent", amount: 4_000), in: context)
        XCTAssertEqual(try balance(in: context), -4_000)

        rent.amount = 4_500
        EntryActions.save(context)

        XCTAssertEqual(try balance(in: context), -4_500)
    }

    func testChangingAnEntrysKindDuringEditingUpdatesBalanceCorrectly() throws {
        // An entry edited from Expense to Activity must stop counting toward
        // Balance — the final saved `kind` is what matters, not the original.
        let context = try makeContext()
        let entry = EntryActions.add(ParsedDraft(kind: .expense, title: "Gym class", amount: 300), in: context)
        XCTAssertEqual(try balance(in: context), -300)

        entry.kind = .activity
        entry.durationSeconds = 3_600
        EntryActions.save(context)

        XCTAssertEqual(try balance(in: context), 0)
    }

    func testDeletingAnIncomeEntryChangesBalance() throws {
        let context = try makeContext()
        let bonus = EntryActions.add(ParsedDraft(kind: .income, title: "Bonus", amount: 2_000), in: context)
        EntryActions.add(ParsedDraft(kind: .expense, title: "Groceries", amount: 500), in: context)
        XCTAssertEqual(try balance(in: context), 1_500)

        EntryActions.delete(bonus, in: context)

        XCTAssertEqual(try balance(in: context), -500)
    }

    func testDeletingAnExpenseEntryChangesBalance() throws {
        let context = try makeContext()
        EntryActions.add(ParsedDraft(kind: .income, title: "Bonus", amount: 2_000), in: context)
        let groceries = EntryActions.add(ParsedDraft(kind: .expense, title: "Groceries", amount: 500), in: context)
        XCTAssertEqual(try balance(in: context), 1_500)

        EntryActions.delete(groceries, in: context)

        XCTAssertEqual(try balance(in: context), 2_000)
    }
}
