import Foundation
import SwiftData

/// A temporary, right-now note — deliberately separate from `JournalEntry`.
/// A Journal entry is permanent, dated, diary writing; a Live Note is
/// something you want visible for a little while (on the Lock Screen / in
/// the Dynamic Island via a Live Activity) and then either archived or
/// thrown away. No mood, tags, priorities, due dates, or reminders — just text.
///
/// Additive to the schema: a fourth, fully independent model alongside
/// `Entry`, `Goal`, and `JournalEntry`.
@Model
final class LiveNote {
    var uuid: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date()

    /// The running Live Activity's id while this note is live — `nil` when
    /// it's never been activated, or once it's been archived/deleted (the
    /// activity is always ended at the same time this is cleared).
    var activityID: String?

    /// Non-nil once archived. Archiving never deletes anything and never
    /// touches `text`/`createdAt` — it's purely a visibility flag.
    var archivedAt: Date?

    var isLive: Bool { activityID != nil }
    var isArchived: Bool { archivedAt != nil }

    init(text: String, createdAt: Date = Date()) {
        self.uuid = UUID()
        self.text = text
        self.createdAt = createdAt
    }
}
