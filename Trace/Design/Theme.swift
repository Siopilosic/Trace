import SwiftUI
import UIKit

/// Trace's visual language: a small, restrained set of tokens. Calm, premium,
/// mostly monochrome with one quiet accent.
enum Theme {

    // MARK: Spacing scale

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 40
        static let xxl: CGFloat = 64
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let pill: CGFloat = 999
    }
}

extension Color {
    /// App background — a soft, tinted surface. Deliberately never pure
    /// black or pure white; see `TraceBackground` for the atmospheric wash
    /// built on top of this base.
    static let traceBackground = Color(
        light: Color(hex: 0xF5F4F2),
        dark: Color(hex: 0x1D1D1D)   // Jet Black
    )
    /// Primary raised surface — cards, the Quick Add interpretation panel,
    /// List/Form rows.
    static let traceSurface = Color(
        light: Color(hex: 0xFFFFFF),
        dark: Color(hex: 0x23212C)   // Cosmic
    )
    /// A second, warmer surface tone used sparingly — the rare element that
    /// wants to sit apart from `traceSurface`, and one of the two washes
    /// `TraceBackground` blends in.
    static let traceSurfaceSecondary = Color(
        light: Color(hex: 0xECE9EA),
        dark: Color(hex: 0x32292F)   // Wine Ash
    )
    /// Hairline separators.
    static let traceSeparator = Color(.separator)
    /// The single accent — Violet. The dark variant is lifted a little from
    /// the base palette's #36255C so it still reads clearly against Jet
    /// Black; the light variant is the palette's Violet as specified.
    static let traceAccent = Color(
        light: Color(hex: 0x36255C),
        dark: Color(red: 0.58, green: 0.45, blue: 0.85)
    )
    /// Positive figures (income / net up / goal achieved).
    static let tracePositive = Color(
        light: Color(red: 0.15, green: 0.52, blue: 0.34),
        dark: Color(red: 0.36, green: 0.78, blue: 0.55)
    )
    /// Negative figures (expense / net down / an over-target spending goal).
    /// A muted, restrained red — clearly "negative" without reading alarmist.
    static let traceNegative = Color(
        light: Color(red: 0.72, green: 0.20, blue: 0.18),
        dark: Color(red: 0.95, green: 0.42, blue: 0.40)
    )

    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    /// `0xRRGGBB` convenience for the fixed palette hex values above — never
    /// used for the semantic dynamic colors themselves, only to define them.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension LinearGradient {
    /// Primary-action fill — a restrained violet gradient, not a loud one.
    /// Used on the one most prominent control (Quick Add); ordinary
    /// bordered-prominent buttons stay flat `traceAccent` via `.tint`.
    static let traceAccentGradient = LinearGradient(
        colors: [Color.traceAccent, Color.traceAccent.opacity(0.8)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Typography

extension Font {
    /// Big number readout (Today's spend, stat headline).
    static func traceFigure(_ size: CGFloat = 40) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static let traceSectionLabel = Font.system(.footnote, weight: .semibold)
    static let traceGreeting = Font.system(.title, design: .serif)
}

extension View {
    /// Uppercase, tracked-out section label ("TODAY", "RECENT").
    func traceSectionLabelStyle() -> some View {
        self.font(.traceSectionLabel)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }

    /// Standard screen horizontal padding.
    func traceScreenPadding() -> some View {
        self.padding(.horizontal, Theme.Space.l)
    }
}
