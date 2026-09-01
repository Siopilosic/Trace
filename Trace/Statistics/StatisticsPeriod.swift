import Foundation

/// The time window the Statistics screen is showing.
enum StatisticsPeriod: String, CaseIterable, Identifiable, Sendable {
    case day, week, month, year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }

    /// Calendar component that defines this period's boundaries.
    var component: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }

    /// Component used to bucket the spending trend series within the period.
    var bucket: Calendar.Component {
        switch self {
        case .day: return .hour
        case .week: return .day
        case .month: return .day
        case .year: return .month
        }
    }

    /// The `dateInterval` for this period containing `date`.
    func interval(containing date: Date, calendar: Calendar) -> DateInterval {
        calendar.dateInterval(of: component, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 86_400)
    }
}
