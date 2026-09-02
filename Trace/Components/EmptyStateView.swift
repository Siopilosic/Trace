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
        // maxHeight too, not just maxWidth: without it this VStack only
        // hugs its own content height, so a screen's `.traceBackground()`
        // (sized to whatever it's attached to) only ever painted a small
        // content-sized rectangle behind it — everywhere else fell through
        // to the system's own default background (pure white in light
        // mode, which is what actually made empty screens read as "still
        // white"; less visible in dark mode since Jet Black and system
        // black are close in tone). Centering here, filling the screen, is
        // what makes every empty state show the real Trace background.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Space.xl)
    }
}
