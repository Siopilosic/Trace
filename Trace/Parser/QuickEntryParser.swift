import Foundation

/// Turns a Quick Add string into a structured ``ParsedDraft``.
///
/// The parser is intentionally deterministic (no AI) and small. It recognises,
/// in priority order:
///
/// 1. **Duration** — `"Gym 1h"`, `"Python 45m"`, `"Run 1h30m"` → activity
/// 2. **Amount** — `"McDonald's 320"`, `"Coffee 90"` → expense,
///    or income when an income cue is present (`"Got paid 20000"`)
/// 3. **Neither** — `"Today was a really good day"` → note
///
/// Everything here is pure Foundation so it can be unit-tested directly.
struct QuickEntryParser {

    /// Injectable clock so tests are deterministic.
    var now: () -> Date = { Date() }

    var categoryInferencer = CategoryInferencer()

    // MARK: Public

    func parse(_ raw: String) -> ParsedDraft? {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }

        if let duration = Self.firstDuration(in: input) {
            let title = Self.clean(input, removing: [duration.range])
            return ParsedDraft(
                kind: .activity,
                title: Self.titleOrFallback(title, "Activity"),
                durationSeconds: duration.seconds,
                date: now(),
                isConfident: !title.isEmpty
            )
        }

        if let money = Self.trailingAmount(in: input) {
            let incomeCue = Self.incomeCue(in: input)
            var title = Self.clean(input, removing: [money.range] + (incomeCue.map { [$0] } ?? []))
            title = Self.stripCurrencyWords(title)

            if incomeCue != nil {
                return ParsedDraft(
                    kind: .income,
                    title: Self.titleOrFallback(title, "Income"),
                    amount: money.value,
                    date: now(),
                    isConfident: true
                )
            } else {
                let category = title.isEmpty ? nil : categoryInferencer.category(for: title)
                return ParsedDraft(
                    kind: .expense,
                    title: Self.titleOrFallback(title, "Expense"),
                    amount: money.value,
                    category: category,
                    date: now(),
                    isConfident: !title.isEmpty
                )
            }
        }

        // No number anywhere — treat as a note. A short fragment ("Gym") is
        // ambiguous (activity? note?), so mark it unconfident and let the UI ask.
        let wordCount = input.split(separator: " ").count
        return ParsedDraft(
            kind: .note,
            title: input,
            note: input,
            date: now(),
            isConfident: wordCount >= 3
        )
    }

    // MARK: - Duration

    struct DurationMatch { var seconds: Double; var range: Range<String.Index> }

    private static let durationRegex = try! NSRegularExpression(
        pattern: #"(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m)(?![a-z])"#,
        options: [.caseInsensitive]
    )

    /// Matches one or two adjacent `<number><unit>` tokens (e.g. `1h`, `1h30m`,
    /// `45 min`) and returns their combined duration plus the full span to remove.
    static func firstDuration(in input: String) -> DurationMatch? {
        let ns = input as NSString
        let matches = durationRegex.matches(in: input, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return nil }

        // Collect matches that chain together (touching or separated only by
        // whitespace) so "1h 30m" reads as a single duration.
        var seconds = 0.0
        var upper = matches[0].range.location + matches[0].range.length

        for (index, match) in matches.enumerated() {
            if index > 0 {
                let gap = ns.substring(with: NSRange(location: upper, length: match.range.location - upper))
                if !gap.trimmingCharacters(in: .whitespaces).isEmpty { break }
            }
            let value = Double(ns.substring(with: match.range(at: 1))) ?? 0
            let unit = ns.substring(with: match.range(at: 2)).lowercased()
            seconds += unit.hasPrefix("h") ? value * 3600 : value * 60
            upper = match.range.location + match.range.length
        }

        guard seconds > 0 else { return nil }
        let nsRange = NSRange(location: matches[0].range.location, length: upper - matches[0].range.location)
        guard let range = Range(nsRange, in: input) else { return nil }
        return DurationMatch(seconds: seconds, range: range)
    }

    // MARK: - Amount

    struct AmountMatch { var value: Double; var range: Range<String.Index> }

    private static let amountRegex = try! NSRegularExpression(
        pattern: #"(?:egp|le|usd|eur|\$|£|€)?\s*(\d[\d,]*(?:\.\d+)?)\s*(k|m)?\s*(?:egp|le|pounds?|usd|eur)?"#,
        options: [.caseInsensitive]
    )

    /// Returns the last money-like number in the string. Handles thousands
    /// separators, a `k`/`m` multiplier, and surrounding currency tokens.
    static func trailingAmount(in input: String) -> AmountMatch? {
        let ns = input as NSString
        let matches = amountRegex.matches(in: input, range: NSRange(location: 0, length: ns.length))
            .filter { $0.range(at: 1).location != NSNotFound }
        guard let match = matches.last else { return nil }

        let digits = ns.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
        guard var value = Double(digits) else { return nil }

        if match.range(at: 2).location != NSNotFound {
            switch ns.substring(with: match.range(at: 2)).lowercased() {
            case "k": value *= 1_000
            case "m": value *= 1_000_000
            default: break
            }
        }

        guard let range = Range(match.range, in: input) else { return nil }
        return AmountMatch(value: value, range: range)
    }

    // MARK: - Income cue

    static let incomeCues = [
        "got paid", "get paid", "paycheck", "pay check", "salary", "income",
        "refund", "refunded", "reimbursed", "reimbursement", "bonus",
        "cashback", "cash back", "deposit", "dividend", "received", "sold",
    ]

    static func incomeCue(in input: String) -> Range<String.Index>? {
        let lower = input.lowercased()
        for cue in incomeCues {
            if let range = lower.range(of: cue) {
                // Map the lowercase range back onto the original string (same length).
                let start = input.index(input.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))
                let end = input.index(input.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.upperBound))
                return start..<end
            }
        }
        return nil
    }

    // MARK: - Cleanup helpers

    private static func clean(_ input: String, removing ranges: [Range<String.Index>]) -> String {
        var result = input
        for range in ranges.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            guard range.lowerBound >= result.startIndex, range.upperBound <= result.endIndex else { continue }
            result.removeSubrange(range)
        }
        return normalise(result)
    }

    private static func stripCurrencyWords(_ text: String) -> String {
        var s = text.replacingOccurrences(
            of: #"(?i)\b(egp|le|pounds?|usd|eur|dollars?|euros?)\b"#,
            with: " ", options: .regularExpression
        )
        s = s.replacingOccurrences(of: #"[£$€]"#, with: " ", options: .regularExpression)
        return normalise(s)
    }

    private static func normalise(_ text: String) -> String {
        var s = text
        // Drop dangling connector words at either end ("… on", "for …").
        s = s.replacingOccurrences(of: #"(?i)^\s*(on|for|at|to|-|–|—)\b\s*"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(?i)\s*\b(on|for|at)\s*$"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " -–—:,.").union(.whitespacesAndNewlines))
        return s
    }

    private static func titleOrFallback(_ title: String, _ fallback: String) -> String {
        guard !title.isEmpty else { return fallback }
        // Gently capitalise a fully-lowercase entry ("mcdonald's" → "Mcdonald's").
        if title == title.lowercased(), let first = title.first {
            return first.uppercased() + title.dropFirst()
        }
        return title
    }
}
