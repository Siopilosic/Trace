import Foundation

/// Parses a **Quick Journal** plain-text export into structured entries ready
/// to become Trace `JournalEntry` records.
///
/// A Quick Journal export is a sequence of:
///
/// ```
/// <timestamp>  <journal text>  ---
/// ```
///
/// repeated once per entry. In real exports the whole thing can be a single
/// physical line — the timestamps and the `---` separators are **not**
/// guaranteed to sit on their own lines:
///
/// ```
/// Sep 01, 2026 - 4:06 PM entry one --- Sep 01, 2026 - 7:21 PM entry two ---
/// ```
///
/// ### How the split works
///
/// The parser is **timestamp-anchored**, not line- or dash-anchored:
///
/// 1. Every substring matching `MMM dd, yyyy - h:mm a` (validated by
///    `DateFormatter`) is a candidate entry start.
/// 2. The **first** valid timestamp starts entry 1. Each later timestamp starts
///    a new entry only when the text since the current entry's start ends with
///    a `---` separator (a run of 2+ hyphens after whitespace / a line break).
///    A timestamp-shaped string sitting in the middle of an entry — not
///    preceded by a separator — stays part of that entry's text.
/// 3. An entry's text is everything between its timestamp and the next entry's
///    timestamp (or end of file), with the single delimiter after the
///    timestamp and the trailing `---` separator removed. Nothing else is
///    touched — interior `---`, `-----`, Markdown rules and dash art are all
///    preserved.
///
/// Text before the first timestamp, and any timestamp with no text, are
/// returned as ``Failure``s rather than silently dropped.
///
/// Pure Foundation, no SwiftData — unit-tested directly.
enum QuickJournalImport {

    /// One successfully parsed Quick Journal entry.
    struct ParsedEntry: Equatable {
        /// The entry's original timestamp — becomes `JournalEntry.createdAt`.
        var timestamp: Date
        /// The journal text, preserved as-is between the timestamp and the
        /// separator. Internal line breaks, blank lines, indentation and dash
        /// runs are all kept exactly.
        var text: String
    }

    /// Part of the file that could not be turned into an entry. Never silently
    /// discarded — surfaced to the user.
    struct Failure: Equatable {
        /// 1-based line number where the problem text starts.
        var line: Int
        /// A short excerpt of the offending text, for the report.
        var snippet: String
        var reason: String
    }

    struct Outcome: Equatable {
        /// Entries in the order they appeared in the file.
        var entries: [ParsedEntry]
        var failures: [Failure]
    }

    /// Quick Journal's timestamp format, e.g. `Sep 01, 2026 - 4:06 PM`.
    static let headerDateFormat = "MMM dd, yyyy - h:mm a"

    /// Finds timestamp-shaped substrings anywhere in the text (month name,
    /// day, year, 12-hour time, AM/PM). Deliberately loose — every hit is then
    /// validated by `DateFormatter`, and a hit that fails validation is left
    /// as ordinary text.
    private static let timestampPattern =
        #"(?i)\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[ \t]+\d{1,2},[ \t]+\d{4}[ \t]+-[ \t]+\d{1,2}:\d{2}[ \t]+[ap]m\b"#

    /// A trailing entry separator: a run of 2+ hyphens at the end of the span,
    /// introduced by a line break or a single space, with optional trailing
    /// whitespace. Anchored to the end so interior dash runs never match.
    private static let trailingSeparatorPattern = #"(?:\A|\n|[ \t])[ \t]*-{2,}[ \t\n]*\z"#

    // MARK: Parsing

    /// - Parameters:
    ///   - raw: the full contents of the exported `.txt` file.
    ///   - timeZone: how to interpret the zone-less timestamps. Defaults to the
    ///     device's current zone (what the user sees in Quick Journal); tests
    ///     pin this explicitly.
    static func parse(_ raw: String, timeZone: TimeZone = .current) -> Outcome {
        let formatter = makeFormatter(timeZone: timeZone)

        // Normalise line endings only — content is otherwise untouched.
        let text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // 1. Every valid timestamp, in order.
        let regex = try! NSRegularExpression(pattern: timestampPattern)
        let ns = text as NSString
        struct Stamp { var range: Range<String.Index>; var date: Date }
        var stamps: [Stamp] = []
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard let range = Range(match.range, in: text),
                  let date = formatter.date(from: String(text[range]))
            else { continue }
            stamps.append(Stamp(range: range, date: date))
        }

        var entries: [ParsedEntry] = []
        var failures: [Failure] = []

        guard let first = stamps.first else {
            let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                failures.append(Failure(
                    line: 1,
                    snippet: Self.snippet(content),
                    reason: "No Quick Journal entries found. Each entry starts with a timestamp like “Sep 01, 2026 - 4:06 PM”."
                ))
            }
            return Outcome(entries: entries, failures: failures)
        }

        // Anything before the first timestamp (ignoring separators/whitespace).
        let preamble = String(text[text.startIndex..<first.range.lowerBound])
            .trimmingCharacters(in: CharacterSet(charactersIn: "-").union(.whitespacesAndNewlines))
        if !preamble.isEmpty {
            failures.append(Failure(
                line: 1,
                snippet: Self.snippet(preamble),
                reason: "Text before the first entry, with no timestamp — not imported."
            ))
        }

        // 2. Walk the timestamps. A later one only opens a new entry when the
        //    text since the current entry's start ends with a `---` separator.
        var entryStart = first.range.upperBound
        var entryDate = first.date
        var entryOrigin = first.range.lowerBound

        func closeEntry(upTo end: String.Index) {
            appendEntry(String(text[entryStart..<end]), date: entryDate, origin: entryOrigin,
                        text: text, into: &entries, failures: &failures)
        }

        for stamp in stamps.dropFirst() {
            let between = text[entryStart..<stamp.range.lowerBound]
            guard endsWithSeparator(between) else { continue }   // timestamp inside body — keep it as text
            closeEntry(upTo: stamp.range.lowerBound)
            entryStart = stamp.range.upperBound
            entryDate = stamp.date
            entryOrigin = stamp.range.lowerBound
        }
        closeEntry(upTo: text.endIndex)

        return Outcome(entries: entries, failures: failures)
    }

    // MARK: Helpers

    private static func appendEntry(
        _ span: String,
        date: Date,
        origin: String.Index,
        text: String,
        into entries: inout [ParsedEntry],
        failures: inout [Failure]
    ) {
        var body = span
        // Drop the single delimiter between the timestamp and the body
        // (a space on one line, or the line break before a multi-line body).
        if body.first == " " { body.removeFirst() }
        if body.first == "\n" { body.removeFirst() }
        // Drop the trailing `---` separator, if this entry has one.
        if let separator = body.range(of: trailingSeparatorPattern, options: .regularExpression) {
            body.removeSubrange(separator)
        }

        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failures.append(Failure(
                line: lineNumber(of: origin, in: text),
                snippet: Self.snippet(String(text[origin...]).trimmingCharacters(in: .whitespaces)),
                reason: "Entry has a timestamp but no text — not imported."
            ))
            return
        }
        entries.append(ParsedEntry(timestamp: date, text: body))
    }

    private static func endsWithSeparator(_ span: Substring) -> Bool {
        span.range(of: trailingSeparatorPattern, options: .regularExpression) != nil
    }

    static func makeFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = headerDateFormat
        formatter.isLenient = false
        return formatter
    }

    private static func lineNumber(of index: String.Index, in text: String) -> Int {
        text[text.startIndex..<index].reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
    }

    private static func snippet(_ text: String, limit: Int = 60) -> String {
        let firstLine = text.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? text
        return firstLine.count > limit ? String(firstLine.prefix(limit)) + "…" : firstLine
    }
}
