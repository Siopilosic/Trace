import Foundation

/// Pure, testable date logic for the Journal timeline's day-group headers.
/// No SwiftUI, no SwiftData; takes an explicit `calendar` and reference `Date`
/// so behaviour is deterministic and midnight-relative rather than a rolling
/// 24-hour window.
///
/// Nothing here is persisted — `Today` / `Yesterday` are derived from
/// `JournalEntry.createdAt` on the fly, so they follow the calendar day
/// automatically and never diverge from the stored timestamp.
enum JournalDate {

    /// The header shown above a day's entries:
    ///
    /// - the reference calendar day  → `"Today"`
    /// - the day before it           → `"Yesterday"`
    /// - anything older              → `"Tuesday, September 1"` (`EEEE, MMMM d`,
    ///   localised, no year)
    ///
    /// Comparison is by calendar day in `calendar` (its time zone), never by
    /// elapsed hours.
    static func sectionTitle(for date: Date, calendar: Calendar, reference: Date) -> String {
        switch dayOffset(of: date, from: reference, calendar: calendar) {
        case 0: return "Today"
        case 1: return "Yesterday"
        default: return formatter(for: "EEEEMMMMd", calendar: calendar).string(from: date)
        }
    }

    // MARK: Internal helpers

    /// Whole calendar days from `date`'s day to `reference`'s day (0 = same day,
    /// 1 = the day before, negative = in the future).
    private static func dayOffset(of date: Date, from reference: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: reference)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    // DateFormatter creation is comparatively costly and the header re-renders
    // often — cache one per (template, locale, zone).
    private static var formatterCache: [String: DateFormatter] = [:]

    private static func formatter(for template: String, calendar: Calendar) -> DateFormatter {
        let locale = calendar.locale ?? Locale(identifier: "en_US_POSIX")
        let key = "\(template)|\(locale.identifier)|\(calendar.timeZone.identifier)"
        if let cached = formatterCache[key] { return cached }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        formatterCache[key] = formatter
        return formatter
    }
}
