import SwiftUI

/// A small, quiet progress ring for a hard character limit — meant to feel
/// like part of the text field it sits on, not a standalone progress UI.
/// Stays subtle for most of the range; only once truly close to the limit
/// does it start counting down the exact characters remaining.
struct CharacterLimitRing: View {
    let count: Int
    let limit: Int

    /// The last stretch where the ring starts actually communicating
    /// something ("you're close") rather than just quietly filling.
    private let warningThreshold = 20

    private var remaining: Int { max(0, limit - count) }
    private var fraction: Double { limit > 0 ? min(1, Double(count) / Double(limit)) : 0 }
    private var isNearLimit: Bool { remaining <= warningThreshold }
    private var ringColor: Color { isNearLimit ? .traceNegative : .traceAccent }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.traceSeparator.opacity(0.5), lineWidth: 2)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(ringColor.opacity(isNearLimit ? 1 : 0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if isNearLimit {
                Text("\(remaining)")
                    .font(.system(size: 9, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(ringColor)
            }
        }
        .frame(width: 20, height: 20)
        .animation(.easeInOut(duration: 0.15), value: count)
        .accessibilityLabel("\(remaining) characters remaining")
    }
}
