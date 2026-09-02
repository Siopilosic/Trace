import ActivityKit
import Foundation

/// Thin wrapper around ActivityKit — starts, updates, and ends the Live
/// Activity for a `LiveNote`. The actual on-screen Lock Screen / Dynamic
/// Island presentation is defined by the widget extension's
/// `ActivityConfiguration(for: LiveNoteAttributes.self)`; this only ever
/// talks to the system-level `Activity` API, never renders anything itself.
///
/// Deliberately minimal to match the product intent: the Live Activity is
/// display-only. Archive/Delete happen inside Trace, not from the Lock
/// Screen — so there's no update path here beyond starting and ending.
enum LiveActivityController {

    /// Requests a new Live Activity showing `note`'s text. Returns the new
    /// activity's id (to store on the note) or `nil` if Live Activities
    /// aren't available/enabled (Simulator without the feature turned on,
    /// user has disabled them in Settings, etc.) — callers treat that as
    /// "the note still exists, it just isn't live."
    static func start(for note: LiveNote) -> String? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        let attributes = LiveNoteAttributes(startedAt: note.createdAt)
        let state = LiveNoteAttributes.ContentState(text: note.text)
        do {
            let activity = try Activity<LiveNoteAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
            return activity.id
        } catch {
            return nil
        }
    }

    /// Ends the Live Activity with the given id, if it's still running.
    /// Safe to call with `nil` (a note that was never live) or a stale id
    /// (already ended) — both are no-ops.
    static func end(activityID: String?) {
        guard let activityID else { return }
        Task {
            for activity in Activity<LiveNoteAttributes>.activities where activity.id == activityID {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Pushes new text to an already-running Live Activity — the composer is
    /// a persistent scratchpad, so edits made while a note is live should
    /// show up there too, not just at the moment "Go Live" was tapped. Safe
    /// to call with `nil`/a stale id (no-op).
    static func update(activityID: String?, text: String) {
        guard let activityID else { return }
        Task {
            for activity in Activity<LiveNoteAttributes>.activities where activity.id == activityID {
                await activity.update(.init(state: .init(text: text), staleDate: nil))
            }
        }
    }

    /// Whether an Activity with this id is actually still running, per
    /// ActivityKit itself — a persisted `activityID` alone isn't proof: the
    /// system can end an activity out from under the app (staleness expiry,
    /// or ending while the app wasn't running to observe it). This is the
    /// real source of truth for reconciling `LiveNote.activityID` against
    /// what's actually live, rather than trusting our own stored copy.
    static func isActuallyRunning(activityID: String?) -> Bool {
        guard let activityID else { return false }
        return Activity<LiveNoteAttributes>.activities.contains { $0.id == activityID }
    }
}
