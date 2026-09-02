import SwiftUI

/// A label, a trailing value, and a thin proportional capsule bar underneath —
/// the one shared "how full is this" visual in Trace. Used for goal progress,
/// and shares its visual language with the category/activity breakdown rows.
struct ProportionalBarRow: View {
    let label: String
    let valueText: String
    /// 0...1 — the bar's fill. Callers clamp this themselves (see
    /// `GoalProgress.fraction`); the label/value text is free to show real,
    /// uncapped numbers even when this is pinned at 1.
    let fraction: Double
    var valueTint: Color = .secondary
    var barTint: Color = .traceAccent

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(valueText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(valueTint)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.traceSeparator.opacity(0.4))
                    Capsule()
                        .fill(barTint.opacity(0.85))
                        .frame(width: max(4, proxy.size.width * fraction))
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, Theme.Space.xs)
    }
}
