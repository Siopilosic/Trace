import SwiftUI

/// A category, a slim proportional bar, and its total. Restrained — no pie
/// charts, no colour explosion.
struct CategoryBreakdownRow: View {
    let total: CategoryTotal
    let fraction: Double

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            HStack {
                Text(total.category.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(Format.money(total.amount))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.traceSeparator.opacity(0.4))
                    Capsule()
                        .fill(Color.traceAccent.opacity(0.85))
                        .frame(width: max(4, proxy.size.width * fraction))
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, Theme.Space.xs)
    }
}
