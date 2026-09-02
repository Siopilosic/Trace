import XCTest
@testable import Trace

/// Regression coverage for the Quick Add duration bug: selecting a duration
/// for an Activity must survive into the draft `makeDraft()` produces — the
/// exact value `QuickAddView` hands to `EntryActions.add`.
final class QuickAddModelTests: XCTestCase {

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
