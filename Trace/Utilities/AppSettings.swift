import SwiftUI
import Observation

/// Lightweight, observable wrapper over `UserDefaults` for the handful of
/// preferences Trace exposes. Stored properties (so `@Observable` tracks them)
/// that persist to `UserDefaults` on change.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    @ObservationIgnored private let defaults: UserDefaults

    var currencyCode: String {
        didSet { defaults.set(currencyCode, forKey: Key.currencyCode) }
    }
    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }
    var weekStartsOnMonday: Bool {
        didSet { defaults.set(weekStartsOnMonday, forKey: Key.weekStartsOnMonday) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.currencyCode = defaults.string(forKey: Key.currencyCode) ?? "EGP"
        self.appearance = Appearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        self.weekStartsOnMonday = defaults.object(forKey: Key.weekStartsOnMonday) as? Bool ?? false
    }

    private enum Key {
        static let currencyCode = "settings.currencyCode"
        static let appearance = "settings.appearance"
        static let weekStartsOnMonday = "settings.weekStartsOnMonday"
    }

    /// Calendar honouring the user's week-start choice — used for all stats.
    var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = weekStartsOnMonday ? 2 : 1
        return calendar
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var title: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }
}
