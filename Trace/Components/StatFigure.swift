import SwiftUI

/// A label above a large number. The core building block of Home and Stats —
/// used instead of boxing everything in cards.
struct StatFigure: View {
    let label: String
    let value: String
    var caption: String? = nil
    var size: CGFloat = 40
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(label)
                .traceSectionLabelStyle()
            Text(value)
                .font(.traceFigure(size))
                .foregroundStyle(tint)
                .monospacedDigit()
                .contentTransition(.numericText())
            if let caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
