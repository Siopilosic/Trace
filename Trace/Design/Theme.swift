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
    /// App background — pure system background so the app feels native.
    static let traceBackground = Color(.systemBackground)
    /// Subtle raised surface for the rare grouped element.
    static let traceSurface = Color(.secondarySystemBackground)
    /// Hairline separators.
    static let traceSeparator = Color(.separator)
    /// The single accent. A calm ink-indigo that reads well in both schemes.
    static let traceAccent = Color(
        light: Color(red: 0.29, green: 0.33, blue: 0.86),
        dark: Color(red: 0.52, green: 0.56, blue: 0.98)
    )
    /// Positive figures (income / net up).
    static let tracePositive = Color(
        light: Color(red: 0.15, green: 0.52, blue: 0.34),
        dark: Color(red: 0.36, green: 0.78, blue: 0.55)
    )

    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
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
