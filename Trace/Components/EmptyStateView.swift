import SwiftUI

/// A calm empty state: a quiet line, a softer line, and an optional action.
struct EmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Space.m) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, Theme.Space.xs)
            }
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .padding(.top, Theme.Space.s)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Space.xl)
    }
}
