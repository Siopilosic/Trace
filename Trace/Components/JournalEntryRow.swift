import SwiftUI

/// One journal entry in the timeline — the exact time it was written, then a
/// single-line preview of the text, with a trailing disclosure chevron.
/// Rows within the same day sit inside one continuous grouped card
/// (`JournalView`'s `.insetGrouped` list style provides that, not this row
/// itself) — matching a native iOS grouped-list entry, not a bespoke card.
struct JournalEntryRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(Format.time(entry.createdAt))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(entry.text)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, Theme.Space.xs)
        .contentShape(Rectangle())
    }
}
