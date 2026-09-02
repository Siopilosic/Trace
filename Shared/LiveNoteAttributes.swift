import ActivityKit
import Foundation

/// The shared contract between Trace and its Live Activity widget extension.
/// This exact file is compiled into BOTH targets (the app, which starts/ends
/// the activity, and the extension, which renders it) — `ActivityAttributes`
/// requires the same concrete type on both sides. Deliberately tiny: a Live
/// Note is just its text, nothing else crosses the app/extension boundary.
struct LiveNoteAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var text: String
    }

    var startedAt: Date
}
