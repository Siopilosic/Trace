import Foundation
import Observation

/// Backs ``QuickAddView``. Holds the raw text, the parser's interpretation, and
/// any manual corrections, then produces the final ``ParsedDraft`` to save.
///
/// Corrections survive further typing so a quick "actually, this is income" tap
/// isn't undone by the next keystroke.
@Observable
final class QuickAddModel {
    var text = "" {
        didSet { reparse() }
    }

    private(set) var parsed: ParsedDraft?

    // Manual overrides (nil = "use the parser's answer").
    var manualKind: EntryKind?
    var manualTitle: String?
    var manualAmount: Double?
    var manualCategory: ExpenseCategory?
    var manualDurationSeconds: Double?

    private let parser = QuickEntryParser()

    private func reparse() {
        parsed = parser.parse(text)
    }

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var effectiveKind: EntryKind {
        manualKind ?? parsed?.kind ?? .expense
    }

    /// Whether to nudge the user to confirm the kind.
    var needsKindConfirmation: Bool {
        guard let parsed, manualKind == nil else { return false }
        return !parsed.isConfident
    }

    var effectiveTitle: String {
        if let manualTitle, !manualTitle.isEmpty { return manualTitle }
        return parsed?.title ?? ""
    }

    var effectiveAmount: Double? {
        manualAmount ?? parsed?.amount
    }

    var effectiveCategory: ExpenseCategory? {
        manualCategory ?? parsed?.category
    }

    var effectiveDurationSeconds: Double? {
        manualDurationSeconds ?? parsed?.durationSeconds
    }

    /// The entry to persist, or `nil` if there's nothing usable yet.
    func makeDraft() -> ParsedDraft? {
        guard parsed != nil else { return nil }
        let kind = effectiveKind
        var title = effectiveTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { title = kind.displayName }

        switch kind {
        case .expense:
            guard let amount = effectiveAmount, amount > 0 else { return nil }
            return ParsedDraft(kind: .expense, title: title, amount: amount,
                               category: effectiveCategory, date: Date())
        case .income:
            guard let amount = effectiveAmount, amount > 0 else { return nil }
            return ParsedDraft(kind: .income, title: title, amount: amount, date: Date())
        case .activity:
            return ParsedDraft(kind: .activity, title: title,
                               durationSeconds: effectiveDurationSeconds, date: Date())
        case .note:
            let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return ParsedDraft(kind: .note, title: body, note: body, date: Date())
        }
    }
}
