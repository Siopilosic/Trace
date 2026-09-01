import SwiftUI

/// One line in a list of entries. Title on the left, a single trailing value
/// (signed amount, duration, or a quiet "Note"). No cards, no icons shouting.
struct EntryRow: View {
    let entry: Entry
    var showsTime = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if showsTime {
                    Text(Format.time(entry.date))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: Theme.Space.m)

            trailingValue
        }
        .padding(.vertical, Theme.Space.s)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var trailingValue: some View {
        switch entry.kind {
        case .expense, .income:
            if let signed = entry.signedAmount {
                Text(Format.signedMoney(signed))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(entry.kind == .income ? Color.tracePositive : .primary)
            }
        case .activity:
            Text(Format.activityValue(seconds: entry.durationSeconds))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        case .note:
            Text("Note")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }
}
