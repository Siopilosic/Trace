import SwiftUI

/// The one prominent control in Trace. A soft circular `+` that floats above
/// the Home content.
struct QuickAddButton: View {
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.traceAccent, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Quick Add")
    }
}

/// Subtle press-scale used on tappable surfaces.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
