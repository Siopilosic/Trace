import Foundation

/// Turns a Quick Add string into a structured ``ParsedDraft``.
///
/// The parser is intentionally deterministic (no AI) and small. It recognises,
/// in priority order:
///
/// 1. **Duration** — `"Gym 1h"`, `"Python 45m"`, `"Run 1h30m"` → activity
/// 2. **Amount** — a number that is *clearly meant as money* (see
///    ``moneyAmount(in:)``): `"lunch 300"`, `"300 EGP"`, `"salary 20k"`,
///    `"spent 300 on lunch"`. Digits that are merely part of a sentence
///    (`"I ate 300 sandwiches"`) do **not** count. A parsed expense's
///    description starts empty — only the amount and inferred category carry
///    over; the user types a description if they want one.
/// 3. **Neither** — no confident guess. There's no generic "note" kind to
///    fall back to anymore (Live Note replaces that); the UI asks the user
///    to pick explicitly among Expense/Income/Activity/Journal/Live Note.
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

        if let money = Self.moneyAmount(in: input) {
            let incomeCue = Self.incomeCue(in: input)
            var descriptionCandidate = Self.clean(input, removing: [money.range] + (incomeCue.map { [$0] } ?? []))
            descriptionCandidate = Self.stripCurrencyWords(descriptionCandidate)

            if incomeCue != nil {
                return ParsedDraft(
                    kind: .income,
                    title: Self.titleOrFallback(descriptionCandidate, "Income"),
                    amount: money.value,
                    date: now(),
                    isConfident: true
                )
            } else {
                // The description candidate is still used to infer a category
                // and to gauge confidence — but a parsed expense's own
                // description starts empty, never pre-filled with the input.
                let category = descriptionCandidate.isEmpty ? nil : categoryInferencer.category(for: descriptionCandidate)
                return ParsedDraft(
                    kind: .expense,
                    title: "",
                    amount: money.value,
                    category: category,
                    date: now(),
                    isConfident: !descriptionCandidate.isEmpty
                )
            }
        }

        // No number, or only numbers that read as ordinary prose — genuinely
        // ambiguous (expense? activity? a thought for Journal / Live Note?).
        // Default to expense as a starting point but mark it unconfident so
        // the UI nudges the user to actually pick.
        return ParsedDraft(
            kind: .expense,
            title: input,
            date: now(),
            isConfident: false
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

    /// A plain number token: `300`, `4,500`, `12.50` (thousands-grouped form
    /// tried first so `4,500` isn't read as `4`).
    private static let numberRegex = try! NSRegularExpression(
        pattern: #"\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?"#
    )
    /// The text *before* a number ends with a currency token / symbol.
    private static let currencyBeforeRegex = try! NSRegularExpression(
        pattern: #"(?:\begp|\ble|\busd|\beur|\bgbp|\bpounds?|\bdollars?|\beuros?|[$£€])\s*$"#,
        options: [.caseInsensitive]
    )
    /// The text *after* a number begins with a currency token / symbol.
    private static let currencyAfterRegex = try! NSRegularExpression(
        pattern: #"^\s*(?:egp\b|le\b|usd\b|eur\b|gbp\b|pounds?\b|dollars?\b|euros?\b|[$£€])"#,
        options: [.caseInsensitive]
    )
    /// The text *after* a number is only whitespace, plus at most a lone
    /// trailing currency token — i.e. the number is the last real token.
    private static let trailingRegex = try! NSRegularExpression(
        pattern: #"^\s*(?:(?:egp|le|usd|eur|gbp|pounds?|dollars?|euros?|[$£€])\s*)?$"#,
        options: [.caseInsensitive]
    )

    /// Verbs that make a nearby number read as money even mid-sentence
    /// (`"spent 300 on lunch"`).
    static let spendingCues = [
        "spent", "spend", "spending", "paid", "pay", "paying",
        "bought", "buy", "buying", "cost", "costs", "charged", "priced",
    ]

    /// The number in `input` that is clearly meant as a monetary amount — or
    /// `nil` when every number is just part of natural-language text
    /// (`"I ate 300 sandwiches"`, `"I did 45 pushups"`, `"I watched 3 movies"`).
    ///
    /// A number qualifies when: a currency token sits directly beside it
    /// (`"300 EGP"`, `"EGP 300"`, `"$5"`); it carries a directly-attached
    /// `k`/`m` multiplier (`"20k"` — a letter cannot follow, so `"3 movies"`
    /// never multiplies); it is the trailing token of the input (`"lunch 300"`,
    /// `"Uber 180"`, `"300"`); or the input contains a spending / income cue
    /// (`"spent 300 on lunch"`). The last qualifying number wins.
    static func moneyAmount(in input: String) -> AmountMatch? {
        let ns = input as NSString
        let numbers = numberRegex.matches(in: input, range: NSRange(location: 0, length: ns.length))
        guard !numbers.isEmpty else { return nil }

        let lower = input.lowercased()
        let hasCue = incomeCue(in: input) != nil
            || spendingCues.contains { lower.range(of: "\\b\($0)\\b", options: .regularExpression) != nil }

        for match in numbers.reversed() {
            guard let numberRange = Range(match.range, in: input) else { continue }

            // Optional directly-attached k / m multiplier (no space before it,
            // no letter after it — so "20k" multiplies but "3 movies" doesn't).
            var tokenEnd = numberRange.upperBound
            var multiplier = 1.0
            if tokenEnd < input.endIndex {
                let unit = input[tokenEnd].lowercased()
                let afterUnit = input.index(after: tokenEnd)
                let unitInsideWord = afterUnit < input.endIndex && input[afterUnit].isLetter
                if (unit == "k" || unit == "m") && !unitInsideWord {
                    multiplier = unit == "k" ? 1_000 : 1_000_000
                    tokenEnd = afterUnit
                }
            }

            let before = String(input[input.startIndex..<numberRange.lowerBound])
            let after = String(input[tokenEnd...])

            let qualifies = Self.matches(currencyBeforeRegex, before)
                || Self.matches(currencyAfterRegex, after)
                || Self.matches(trailingRegex, after)
                || multiplier != 1.0
                || hasCue
            guard qualifies else { continue }

            let digits = input[numberRange].replacingOccurrences(of: ",", with: "")
            guard let magnitude = Double(digits) else { continue }
            return AmountMatch(value: magnitude * multiplier, range: numberRange.lowerBound..<tokenEnd)
        }
        return nil
    }

    private static func matches(_ regex: NSRegularExpression, _ string: String) -> Bool {
        regex.firstMatch(in: string, range: NSRange(location: 0, length: (string as NSString).length)) != nil
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
