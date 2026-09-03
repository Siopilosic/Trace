import Foundation

/// A date constraint on the Journal timeline — a concept entirely separate from
/// text search. Every comparison uses **calendar-day boundaries** in the
/// supplied `Calendar` (and its time zone), never a rolling 24-hour window,
/// and keys only off `JournalEntry.createdAt` — no new stored fields.
///
/// Held in view state, so it survives navigation within Journal but not an app
/// relaunch. Pure and `Equatable`; no SwiftUI, no SwiftData.
enum JournalDateFilter: Equatable {
    /// No constraint — the default.
    case all
    /// Entries whose `createdAt` lands on the same calendar day as this date.
    case day(Date)
    /// Entries whose `createdAt` lands in the same calendar month **and year**.
    case month(Date)
    /// Entries from `from`'s calendar day through `to`'s calendar day,
    /// inclusive at both ends. The order of the two dates doesn't matter.
    case range(from: Date, to: Date)

    var isActive: Bool { self != .all }

    /// Whether `date` satisfies this filter.
    func contains(_ date: Date, calendar: Calendar) -> Bool {
        switch self {
        case .all:
            return true
        case .day(let day):
            return calendar.isDate(date, inSameDayAs: day)
        case .month(let anchor):
            return calendar.isDate(date, equalTo: anchor, toGranularity: .month)
        case .range(let a, let b):
            let lower = calendar.startOfDay(for: min(a, b))
            guard let upper = calendar.date(byAdding: .day, value: 1,
                                            to: calendar.startOfDay(for: max(a, b)))
            else { return false }
            return date >= lower && date < upper
        }
    }

    /// A short label for the active filter, for the toolbar / a chip. `nil`
    /// when `.all`.
    func label(calendar: Calendar) -> String? {
        switch self {
        case .all:
            return nil
        case .day(let day):
            return Self.formatter("MMMMdyyyy", calendar).string(from: day)
        case .month(let anchor):
            return Self.formatter("MMMMyyyy", calendar).string(from: anchor)
        case .range(let a, let b):
            let lo = min(a, b), hi = max(a, b)
            let sameYear = calendar.isDate(lo, equalTo: hi, toGranularity: .year)
            let start = Self.formatter(sameYear ? "MMMd" : "MMMdyyyy", calendar).string(from: lo)
            let end = Self.formatter("MMMdyyyy", calendar).string(from: hi)
            return "\(start) – \(end)"
        }
    }

    private static func formatter(_ template: String, _ calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}
