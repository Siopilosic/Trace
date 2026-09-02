import Foundation

/// Formatting helpers. All display strings for money, duration and dates flow
/// through here so the app stays visually consistent.
enum Format {

    // MARK: Money

    /// `"320 EGP"` — amount then code, no decimals for whole numbers.
    static func money(_ amount: Double, code: String = AppSettings.shared.currencyCode) -> String {
        "\(plainNumber(amount)) \(code)"
    }

    /// Signed money for history rows: `"−320 EGP"` / `"+20,000 EGP"`.
    static func signedMoney(_ amount: Double, code: String = AppSettings.shared.currencyCode) -> String {
        let sign = amount < 0 ? "\u{2212}" : "+"
        return sign + money(abs(amount), code: code)
    }

    /// Just the number, no currency code — for compact "current / target" pairs
    /// where the unit only needs to appear once.
    static func plainNumber(_ amount: Double) -> String {
        let rounded = amount.rounded()
        let hasFraction = abs(amount - rounded) > 0.005
        if hasFraction {
            return decimalFormatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        }
        return wholeFormatter.string(from: NSNumber(value: rounded)) ?? "\(Int(rounded))"
    }

    /// `"7,240 / 10,000 EGP"` or `"4h 20m / 10h"` — the compact goal-progress
    /// line. `isMoney` picks money vs. duration formatting for both sides.
    /// `current` is shown exactly as given — including negative or
    /// over-target values — never clamped or hidden; only the progress bar's
    /// fill fraction clamps.
    static func goalProgress(current: Double, target: Double, isMoney: Bool, code: String = AppSettings.shared.currencyCode) -> String {
        if isMoney {
            return "\(plainNumber(current)) / \(plainNumber(target)) \(code)"
        }
        return "\(duration(max(0, current))) / \(duration(target))"
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

    /// Total activity time across possibly many entries — `count` is only used
    /// as a fallback when there's no useful duration to show.
    static func activityTotal(seconds: Double, count: Int) -> String {
        guard seconds > 0 else { return count == 1 ? "1 session" : "\(count) sessions" }
        return duration(seconds)
    }

    // MARK: Comparison

    /// "12% more than last month" / "8% less than last week" / "About the same
    /// as last year" — `nil` when there's no meaningful baseline (nothing
    /// logged in the previous period).
    ///
    /// A percentage only reads as useful information when the baseline isn't
    /// tiny — "1,692% more than last month" is technically correct and
    /// practically meaningless. Past a threshold this switches to the plain
    /// absolute difference instead ("5,075 EGP more than last month"),
    /// formatted by the caller so the same helper serves money and duration.
    static func periodComparisonCaption(
        current: Double, previous: Double, periodNoun: String,
        formatDelta: (Double) -> String
    ) -> String? {
        guard previous > 0 else { return nil }
        let delta = current - previous
        let percent = Int(((delta / previous) * 100).rounded())
        if percent == 0 { return "About the same as last \(periodNoun)" }
        let direction = percent > 0 ? "more" : "less"
        if abs(percent) > 200 {
            return "\(formatDelta(abs(delta))) \(direction) than last \(periodNoun)"
        }
        return "\(abs(percent))% \(direction) than last \(periodNoun)"
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

    /// Journal's day header: `"Tuesday, September 2"` — always the specific
    /// weekday + month + day, never "Today"/"Yesterday" like `relativeDay`.
    /// A diary's dated-page convention, deliberately different from
    /// History's relative labels.
    static func journalDayHeader(_ date: Date, calendar: Calendar = .current) -> String {
        journalDayFormatter.calendar = calendar
        return journalDayFormatter.string(from: date)
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
    private static let journalDayFormatter: DateFormatter = {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("EEEEMMMMd"); return f
    }()
}
