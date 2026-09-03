import XCTest
@testable import Trace

/// Covers `QuickAddModel` — the field-independence contract for Expense/Income
/// (the "What" input, Amount and Description are separate states, none written
/// from another or from the parser) and the pre-existing Activity duration
/// regression coverage.
final class QuickAddModelTests: XCTestCase {

    // MARK: - Expense / Income: explicit, independent fields

    func testMainInputDoesNotBecomeTheDescription() {
        let model = QuickAddModel()
        model.text = "lunch 150"          // typed into "What"
        model.manualAmount = 150          // entered explicitly in the Amount field

        // Description (effectiveTitle) stays empty — never seeded from "What".
        XCTAssertEqual(model.effectiveTitle, "")

        let draft = model.makeDraft()
        XCTAssertEqual(draft?.kind, .expense)
        XCTAssertEqual(draft?.amount, 150)
        XCTAssertEqual(draft?.title, "Expense")   // generic label, not "lunch"
    }

    func testAmountAndDescriptionAreIndependent() {
        let model = QuickAddModel()
        model.text = "Lunch"
        model.manualAmount = 300
        model.manualTitle = "with Sarah"

        XCTAssertEqual(model.effectiveAmount, 300)
        XCTAssertEqual(model.effectiveTitle, "with Sarah")

        let draft = model.makeDraft()
        XCTAssertEqual(draft?.amount, 300)
        XCTAssertEqual(draft?.title, "with Sarah")
    }

    func testEditingAmountDoesNotModifyDescription() {
        let model = QuickAddModel()
        model.text = "Dinner"
        model.manualTitle = "team dinner"
        model.manualAmount = 100
        model.manualAmount = 250          // "editing" the Amount field
        model.manualAmount = 250.75

        XCTAssertEqual(model.effectiveTitle, "team dinner")
        XCTAssertEqual(model.makeDraft()?.title, "team dinner")
    }

    func testEditingDescriptionDoesNotModifyAmountOrMainInput() {
        let model = QuickAddModel()
        model.text = "Coffee"
        model.manualAmount = 90
        model.manualTitle = "a"
        model.manualTitle = "at the airport"   // "editing" the Description field

        XCTAssertEqual(model.effectiveAmount, 90)
        XCTAssertEqual(model.text, "Coffee")
        XCTAssertEqual(model.makeDraft()?.amount, 90)
    }

    // MARK: - Amount is entirely manual — never pre-filled from "What"

    func testWhatInputNeverPreFillsTheAmount() {
        for what in ["Lunch", "Lunch 1", "Uber 180", "I ate 300 sandwiches"] {
            let model = QuickAddModel()
            model.text = what
            XCTAssertNil(model.effectiveAmount, "\"\(what)\" must not pre-fill Amount")
        }
    }

    func testParserStillExtractsAnAmountInternallyButTheFormIgnoresIt() {
        let model = QuickAddModel()
        model.text = "Uber 180"
        XCTAssertEqual(model.parsed?.amount, 180, "parser still reads it")
        XCTAssertNil(model.effectiveAmount, "…but the Quick Add form ignores parser amount")
    }

    func testManuallyEnteringAmountSavesCorrectly() {
        let model = QuickAddModel()
        model.manualKind = .expense
        model.text = "Uber"
        model.manualAmount = 180

        let draft = model.makeDraft()
        XCTAssertEqual(draft?.kind, .expense)
        XCTAssertEqual(draft?.amount, 180)
    }

    func testChangingWhatAfterEnteringAmountDoesNotChangeAmount() {
        let model = QuickAddModel()
        model.text = "Lunch"
        model.manualAmount = 300          // explicit
        XCTAssertEqual(model.effectiveAmount, 300)

        model.text = "Lunch 999"          // keep editing "What" — parser reads 999
        XCTAssertEqual(model.effectiveAmount, 300)

        model.text = "Uber 180"
        XCTAssertEqual(model.effectiveAmount, 300)
    }

    func testFormWorksWithManualMainInputPlusManualAmount() {
        let model = QuickAddModel()
        model.manualKind = .expense
        model.text = "Lunch"
        model.manualAmount = 300

        let draft = model.makeDraft()
        XCTAssertEqual(draft?.kind, .expense)
        XCTAssertEqual(draft?.amount, 300)
        XCTAssertEqual(draft?.title, "Expense")   // no description entered
    }

    func testDescriptionIsNeverSeededForIncomeEither() {
        let model = QuickAddModel()
        model.text = "salary 20k"
        model.manualAmount = 20000        // still entered explicitly

        XCTAssertEqual(model.effectiveTitle, "")
        let draft = model.makeDraft()
        XCTAssertEqual(draft?.kind, .income)
        XCTAssertEqual(draft?.amount, 20000)
        XCTAssertEqual(draft?.title, "Income")
    }

    func testExpenseStillNeedsAnAmountToBeSaveable() {
        let model = QuickAddModel()
        model.manualKind = .expense
        model.text = "Lunch"
        XCTAssertNil(model.makeDraft(), "no amount → not saveable")

        model.manualAmount = 42
        XCTAssertNotNil(model.makeDraft())
    }

    // MARK: - Add-button validity (`canSave`) — the sole driver of its colour

    func testAddValidityIsFalseWhenRequiredFieldsAreMissing() {
        let expense = QuickAddModel()
        expense.manualKind = .expense
        XCTAssertFalse(expense.canSave, "no What, no Amount")
        expense.text = "Lunch"
        XCTAssertFalse(expense.canSave, "What only, no Amount")

        let income = QuickAddModel()
        income.manualKind = .income
        income.text = "Salary"
        XCTAssertFalse(income.canSave, "What only, no Amount")
    }

    func testAddValidityIsTrueWhenRequiredFieldsArePresent() {
        let expense = QuickAddModel()
        expense.manualKind = .expense
        expense.text = "Lunch"
        expense.manualAmount = 300
        XCTAssertTrue(expense.canSave)
        // Description is optional — presence or absence doesn't matter.
        expense.manualTitle = "with team"
        XCTAssertTrue(expense.canSave)

        let income = QuickAddModel()
        income.manualKind = .income
        income.text = "Bonus"
        income.manualAmount = 5000
        XCTAssertTrue(income.canSave)
    }

    func testAddValidityDependsOnlyOnFieldValuesNotOnAnyExternalState() {
        // `canSave` reads only the model's field state — it takes no
        // keyboard/focus input and is deterministic for identical values.
        let a = QuickAddModel()
        a.manualKind = .expense
        a.text = "Lunch"
        a.manualAmount = 300

        let b = QuickAddModel()
        b.manualKind = .expense
        b.text = "Lunch"
        b.manualAmount = 300

        XCTAssertEqual(a.canSave, b.canSave)
        XCTAssertTrue(a.canSave)
        // Repeated reads are stable.
        XCTAssertEqual(a.canSave, a.canSave)
    }

    func testActivityValidityIsUnchanged() {
        // Activity keeps its existing rule: a name is enough, duration optional.
        let model = QuickAddModel()
        model.manualKind = .activity
        model.text = "Gym"
        XCTAssertTrue(model.canSave)
        XCTAssertNil(model.makeDraft()?.durationSeconds)
    }

    // MARK: - Description isolation (regression)

    func testExpenseDescriptionIsIndependentOfWhatAndAmount() {
        let model = QuickAddModel()
        model.manualKind = .expense
        model.text = "lunch 150"            // "What" — parser reads 150
        model.manualAmount = 150
        XCTAssertEqual(model.effectiveTitle, "")

        model.manualTitle = "with the team" // user types a Description
        XCTAssertEqual(model.effectiveTitle, "with the team")
        XCTAssertEqual(model.text, "lunch 150")       // "What" untouched
        XCTAssertEqual(model.effectiveAmount, 150)    // Amount untouched

        let draft = model.makeDraft()
        XCTAssertEqual(draft?.title, "with the team")
        XCTAssertEqual(draft?.amount, 150)
    }

    func testIncomeDescriptionIsIndependentOfWhatAndAmount() {
        let model = QuickAddModel()
        model.manualKind = .income
        model.text = "bonus 5000"
        model.manualAmount = 5000
        XCTAssertEqual(model.effectiveTitle, "")

        model.manualTitle = "year-end"
        XCTAssertEqual(model.effectiveTitle, "year-end")
        XCTAssertEqual(model.effectiveAmount, 5000)
        XCTAssertEqual(model.makeDraft()?.title, "year-end")
    }

    func testDescriptionIsEmptyUntilManuallyEntered() {
        let model = QuickAddModel()
        XCTAssertEqual(model.effectiveTitle, "")            // fresh
        model.text = "coffee 90"
        XCTAssertEqual(model.effectiveTitle, "")            // after parsing
        model.manualAmount = 90
        XCTAssertEqual(model.effectiveTitle, "")            // after Amount
        model.manualTitle = "flat white"
        XCTAssertEqual(model.effectiveTitle, "flat white")  // only now
    }

    // MARK: - Activity uses no Description field at all

    func testTypingAnActivityNameNeverTouchesTheDescriptionState() {
        let model = QuickAddModel()
        model.manualKind = .activity
        model.text = "Gym"                 // the activity name goes in "What"

        XCTAssertNil(model.manualTitle, "activity name must not land in manualTitle")
        XCTAssertEqual(model.effectiveTitle, "")   // Expense/Income Description stays empty
        XCTAssertNil(model.effectiveAmount)
        XCTAssertNil(model.effectiveDurationSeconds)
    }

    func testActivityNameComesFromTheWhatInputNotManualTitle() {
        let model = QuickAddModel()
        model.manualKind = .activity
        model.text = "Gym 1h"
        XCTAssertEqual(model.makeDraft()?.title, "Gym")
        XCTAssertEqual(model.makeDraft()?.durationSeconds, 3_600)

        // A stale Expense Description in manualTitle must not become the name.
        let stale = QuickAddModel()
        stale.manualTitle = "coffee run"
        stale.manualKind = .activity
        stale.text = "Meditation"
        XCTAssertEqual(stale.makeDraft()?.title, "Meditation")
    }

    func testSwitchingFromExpenseToActivityDoesNotLeakTheDescriptionIntoTheName() {
        let model = QuickAddModel()
        model.manualKind = .expense
        model.text = "Lunch"
        model.manualAmount = 200
        model.manualTitle = "quick bite"          // an Expense Description

        model.manualKind = .activity              // user switches kind
        model.text = "Run"
        XCTAssertEqual(model.makeDraft()?.title, "Run")   // not "quick bite"
    }

    // MARK: - Activity duration regression coverage (unchanged behaviour)

    func testManuallyPickedDurationSurvivesIntoDraft_45Minutes() {
        let model = QuickAddModel()
        model.text = "Study"
        model.manualKind = .activity
        model.manualDurationSeconds = 2_700 // 45 min, as DurationEditor would set it

        let draft = model.makeDraft()
        XCTAssertEqual(draft?.kind, .activity)
        XCTAssertEqual(draft?.durationSeconds, 2_700)
    }

    func testManuallyPickedDurationSurvivesIntoDraft_1h30m() {
        let model = QuickAddModel()
        model.text = "Study"
        model.manualKind = .activity
        model.manualDurationSeconds = 5_400 // 1h 30m

        let draft = model.makeDraft()
        XCTAssertEqual(draft?.durationSeconds, 5_400)
    }

    func testManuallyPickedDurationSurvivesIntoDraft_1h1m() {
        let model = QuickAddModel()
        model.text = "Study"
        model.manualKind = .activity
        model.manualDurationSeconds = 3_660 // 1h 1m — only reachable with a 1-minute step

        let draft = model.makeDraft()
        XCTAssertEqual(draft?.durationSeconds, 3_660)
    }

    func testParsedDurationSurvivesIntoDraftWithoutManualOverride() {
        // "Study 45m" is confidently parsed as an activity already — the
        // duration should carry through even if the user never touches the
        // duration editor at all.
        let model = QuickAddModel()
        model.text = "Study 45m"

        let draft = model.makeDraft()
        XCTAssertEqual(draft?.kind, .activity)
        XCTAssertEqual(draft?.durationSeconds, 2_700)
    }

    func testManualDurationOverridesParsedDuration() {
        let model = QuickAddModel()
        model.text = "Study 45m" // parses to 2700s
        model.manualDurationSeconds = 5_400 // user adjusts the wheel afterward

        let draft = model.makeDraft()
        XCTAssertEqual(draft?.durationSeconds, 5_400)
    }

    func testActivityWithNoDurationStillProducesADraft() {
        // Leaving the duration editor untouched (0h 0m) is a valid "no
        // duration" activity, not a blocked save.
        let model = QuickAddModel()
        model.text = "Gym"
        model.manualKind = .activity

        let draft = model.makeDraft()
        XCTAssertEqual(draft?.kind, .activity)
        XCTAssertNil(draft?.durationSeconds)
    }
}
