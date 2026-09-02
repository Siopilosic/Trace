import ActivityKit
import WidgetKit
import SwiftUI

/// Renders `LiveNoteAttributes` on the Lock Screen and in the Dynamic
/// Island. Deliberately display-only, deliberately minimal — the note's
/// text is the entire point; there's no branding, no icon on the Lock
/// Screen, no metadata anywhere. Archive/Delete/End all happen inside
/// Trace itself, never from here.
struct TraceLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveNoteAttributes.self) { context in
            // Lock Screen / banner — just the note, nothing else. No
            // background tint override: the system's own native Live
            // Activity material renders this correctly in light and dark.
            Text(context.state.text)
                .font(.body)
                .lineLimit(3)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        } dynamicIsland: { context in
            DynamicIsland {
                // The "📝 Note" header lives entirely in `.leading` as one
                // `Label` — icon and text stay visually together as a single
                // unit instead of being split to opposite sides of the
                // island. The actual note gets its own full-width region
                // below (`.bottom`) instead of sharing space with the
                // header, so it's never squeezed by it.
                DynamicIslandExpandedRegion(.leading) {
                    Label("Note", systemImage: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.text)
                        .font(.body)
                        .lineLimit(3)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "note.text")
            } compactTrailing: {
                // Compact regions are extremely narrow — never the actual
                // note text here, just this fixed, short label, and still
                // guarded against clipping on the tightest real devices.
                Text("Note")
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } minimal: {
                Image(systemName: "note.text")
            }
        }
    }
}

@main
struct TraceLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        TraceLiveActivityLiveActivity()
    }
}
