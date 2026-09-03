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

    /// The Description / name field — **entirely manual**. The parser never
    /// seeds it or overwrites it; `parsed.title` is used only as a save-time
    /// fallback for an activity's name (see ``makeDraft()``), never shown in
    /// the field.
    var effectiveTitle: String {
        manualTitle ?? ""
    }

    /// The amount is **entirely manual** for Quick Add's Expense/Income form —
    /// the parser's read of the "What" text (`parsed?.amount`) is deliberately
    /// ignored so numbers in prose ("Uber 180", "Lunch 1") never pre-fill it.
    var effectiveAmount: Double? {
        manualAmount
    }

    var effectiveCategory: ExpenseCategory? {
        manualCategory ?? parsed?.category
    }

    var effectiveDurationSeconds: Double? {
        manualDurationSeconds ?? parsed?.durationSeconds
    }

    /// Whether the current fields form a saveable entry — the **sole** input to
    /// the Add button's enabled/colour state. A pure function of the field
    /// values; keyboard and focus have no part in it.
    var canSave: Bool { makeDraft() != nil }

    /// The entry to persist, or `nil` if there's nothing usable yet.
    func makeDraft() -> ParsedDraft? {
        guard parsed != nil else { return nil }
        let kind = effectiveKind
        let typed = effectiveTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        switch kind {
        case .expense:
            guard let amount = effectiveAmount, amount > 0 else { return nil }
            return ParsedDraft(kind: .expense, title: typed.isEmpty ? kind.displayName : typed,
                               amount: amount, category: effectiveCategory, date: Date())
        case .income:
            guard let amount = effectiveAmount, amount > 0 else { return nil }
            return ParsedDraft(kind: .income, title: typed.isEmpty ? kind.displayName : typed,
                               amount: amount, date: Date())
        case .activity:
            // An activity's name comes only from the "What" input — the
            // parser's read of it ("Gym" from "Gym 1h"), else the raw text,
            // else the generic label. Never `manualTitle` (that's the
            // Expense/Income Description field, which Activity doesn't use).
            var name = parsed?.title ?? ""
            if name.isEmpty {
                name = text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if name.isEmpty { name = kind.displayName }
            return ParsedDraft(kind: .activity, title: name,
                               durationSeconds: effectiveDurationSeconds, date: Date())
        case .note:
            // Unreachable via the current UI: the parser never guesses
            // `.note` anymore and Quick Add's kind picker never offers it
            // (Live Note replaces it, and isn't an `EntryKind` at all). Kept
            // only so this switch stays exhaustive over the legacy case.
            return nil
        }
    }
}
