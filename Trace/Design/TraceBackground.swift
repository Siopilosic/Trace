import SwiftUI

/// Trace's atmospheric backdrop: a soft base tone with two barely-there
/// surface washes and a restrained accent glow toward one corner. This is
/// the one place the "richer, not louder" background is defined — every
/// top-level screen applies it with `.traceBackground()` instead of hand
/// -rolling a gradient, so the whole app can be re-tuned from here.
///
/// Deliberately quiet: the base color alone already reads as "not pure
/// black/white", the washes are low-opacity radial fades that never reach
/// full strength, and nothing here animates or repaints.
struct TraceBackground: View {
    var body: some View {
        ZStack {
            Color.traceBackground

            // A faint secondary-surface wash toward the top-trailing corner
            // — this is what makes the surface feel "richer" without
            // reading as an obvious gradient. Kept tight to the corner (not
            // reaching the far side of the screen) so the base color stays
            // dominant everywhere else.
            RadialGradient(
                colors: [Color.traceSurfaceSecondary.opacity(0.4), .clear],
                center: .topTrailing, startRadius: 0, endRadius: 260
            )

            // A restrained violet glow, opposite corner, kept subtle enough
            // that it reads as atmosphere rather than a colored panel.
            RadialGradient(
                colors: [Color.traceAccent.opacity(0.11), .clear],
                center: .bottomLeading, startRadius: 0, endRadius: 240
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Applies Trace's atmospheric background behind this screen, replacing
    /// the implicit system background every top-level screen used to
    /// inherit (pure black in dark mode, pure white in light). Call once per
    /// screen, behind its content.
    func traceBackground() -> some View {
        background(TraceBackground())
    }
}
