import UIKit

/// Thin wrapper around UIKit feedback generators. Used sparingly — a soft tap
/// when something is logged, a gentle selection tick when changing kind.
enum Haptics {
    static func logged() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Distinct feedback for "that didn't work" — e.g. Go Live failing
    /// because Live Activities aren't authorized. A silent no-op is
    /// indistinguishable from a hang; this makes the failure felt.
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
