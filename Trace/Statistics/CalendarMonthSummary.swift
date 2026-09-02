import Foundation

/// What kinds of things were logged on one calendar day — powers the small
/// per-day dots in the Calendar view. Deliberately just three booleans (not
/// amounts) — the calendar is an at-a-glance map of *which* days have
/// activity, not another place to read numbers.
struct DaySummary: Equatable, Sendable {
    var day: Date
    var hasMoney: Bool
    var hasActivity: Bool
    var hasNote: Bool

    var isEmpty: Bool { !hasMoney && !hasActivity && !hasNote }
}

/// One cell in a calendar month grid — a real calendar day, flagged with
/// whether it belongs to the displayed month or is a leading/trailing day
/// borrowed from an adjacent month to complete a whole week.
struct CalendarGridDay: Identifiable, Equatable, Sendable {
    var date: Date
    var isCurrentMonth: Bool
    var id: Date { date }
}

/// Pure day-level rollup for a calendar month. No SwiftUI, no SwiftData.
enum CalendarMonthSummary {

    /// One `DaySummary` per calendar day that has at least one entry, keyed by
    /// the start-of-day `Date` (via `calendar.startOfDay`). Days with nothing
    /// logged simply have no entry in the dictionary. Entries from any month
    /// can be passed in — a day's summary only ever reflects entries whose
    /// `date` falls on that exact calendar day, so nothing leaks between,
    /// say, the 15th of one month and the 15th of another.
    static func summaries<E: StatEntry>(
        for entries: [E],
        calendar: Calendar
    ) -> [Date: DaySummary] {
        var result: [Date: DaySummary] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            var summary = result[day] ?? DaySummary(day: day, hasMoney: false, hasActivity: false, hasNote: false)
            switch entry.kind {
            case .expense, .income: summary.hasMoney = true
            case .activity: summary.hasActivity = true
            case .note: summary.hasNote = true
            }
            result[day] = summary
        }
        return result
    }

    /// The full grid of days for the month containing `date` — the month's
    /// own days plus whatever leading/trailing days from adjacent months are
    /// needed to fill out whole weeks, respecting `calendar.firstWeekday`.
    static func gridDays(for date: Date, calendar: Calendar) -> [CalendarGridDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let monthStart = monthInterval.start

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leadingCount, to: monthStart) else { return [] }

        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        let totalCells = Int((Double(leadingCount + daysInMonth) / 7).rounded(.up)) * 7

        return (0..<totalCells).compactMap { offset in
            guard let cellDate = calendar.date(byAdding: .day, value: offset, to: gridStart) else { return nil }
            let isCurrentMonth = calendar.isDate(cellDate, equalTo: monthStart, toGranularity: .month)
            return CalendarGridDay(date: cellDate, isCurrentMonth: isCurrentMonth)
        }
    }

    /// Weekday header symbols ("S M T W T F S" or the locale's equivalent),
    /// starting from `calendar.firstWeekday`.
    static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        guard symbols.count == 7, (1...7).contains(calendar.firstWeekday) else { return symbols }
        let startIndex = calendar.firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }
}
