import Foundation

extension Date {
    /// A calm, time-aware greeting for the Home header.
    func greeting(calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: self) {
        case 5..<12: return "Good morning."
        case 12..<17: return "Good afternoon."
        case 17..<22: return "Good evening."
        default: return "Working late."
        }
    }
}

extension DateInterval {
    /// A short label for the period being viewed on Statistics.
    func periodLabel(for period: StatisticsPeriod, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        switch period {
        case .day:
            if calendar.isDateInToday(start) { return "Today" }
            f.setLocalizedDateFormatFromTemplate("MMMMd")
        case .week:
            f.setLocalizedDateFormatFromTemplate("MMMd")
            let end = calendar.date(byAdding: .day, value: -1, to: self.end) ?? self.end
            return "\(f.string(from: start)) – \(f.string(from: end))"
        case .month:
            f.setLocalizedDateFormatFromTemplate("MMMM")
        case .year:
            f.setLocalizedDateFormatFromTemplate("yyyy")
        }
        return f.string(from: start)
    }
}
