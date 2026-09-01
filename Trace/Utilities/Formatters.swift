import Foundation

/// Formatting helpers. All display strings for money, duration and dates flow
/// through here so the app stays visually consistent.
enum Format {

    // MARK: Money

    /// `"320 EGP"` — amount then code, no decimals for whole numbers.
    static func money(_ amount: Double, code: String = AppSettings.shared.currencyCode) -> String {
        let rounded = amount.rounded()
        let hasFraction = abs(amount - rounded) > 0.005
        let number: String
        if hasFraction {
            number = decimalFormatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        } else {
            number = wholeFormatter.string(from: NSNumber(value: rounded)) ?? "\(Int(rounded))"
        }
        return "\(number) \(code)"
    }

    /// Signed money for history rows: `"−320 EGP"` / `"+20,000 EGP"`.
    static func signedMoney(_ amount: Double, code: String = AppSettings.shared.currencyCode) -> String {
        let sign = amount < 0 ? "\u{2212}" : "+"
        return sign + money(abs(amount), code: code)
    }

    private static let wholeFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    private static let decimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    // MARK: Duration

    /// `3600 → "1h"`, `2700 → "45 min"`, `5400 → "1h 30m"`.
    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        switch (hours, minutes) {
        case (0, 0): return "0 min"
        case (0, _): return "\(minutes) min"
        case (_, 0): return "\(hours)h"
        default: return "\(hours)h \(minutes)m"
        }
    }

    /// A short, human phrase for activity rows: `"1 session"` when no useful
    /// duration, otherwise the duration.
    static func activityValue(seconds: Double?) -> String {
        guard let seconds, seconds > 0 else { return "1 session" }
        return duration(seconds)
    }

    // MARK: Dates

    static func headerDate(_ date: Date) -> String {
        headerFormatter.string(from: date)
    }

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// Section title for History: `"Today"`, `"Yesterday"`, else `"Monday, 25 Aug"`.
    static func relativeDay(_ date: Date, calendar: Calendar = .current, now: Date = .now) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let daysAgo = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if daysAgo > 1 && daysAgo < 7 { return weekdayFormatter.string(from: date) }
        return sectionFormatter.string(from: date)
    }

    private static let headerFormatter: DateFormatter = {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("MMMMd"); return f
    }()
    private static let sectionFormatter: DateFormatter = {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("EEEEdMMM"); return f
    }()
    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f
    }()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f
    }()
}
