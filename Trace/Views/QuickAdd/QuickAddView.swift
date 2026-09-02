import SwiftUI
import SwiftData

/// The four things you can log from here: Expense, Income, Activity — all
/// three parsed from free text exactly as before — and Live Note, which
/// isn't part of that parsing pipeline at all (it's a separate persistent
/// scratchpad). Picking it switches `QuickAddView` itself into Live Note
/// mode — there's no hand-off to another screen.
private enum QuickAddKind: Hashable, Identifiable, CaseIterable {
    case expense, income, activity, liveNote

    var id: Self { self }

    var displayName: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        case .activity: return "Activity"
        case .liveNote: return "Live Note"
        }
    }

    /// `nil` for `.liveNote` — it has no `EntryKind` counterpart.
    var entryKind: EntryKind? {
        switch self {
        case .expense: return .expense
        case .income: return .income
        case .activity: return .activity
        case .liveNote: return nil
        }
    }

    init(_ entryKind: EntryKind) {
        switch entryKind {
        case .expense: self = .expense
        case .income: self = .income
        case .activity: self = .activity
        case .note: self = .expense // unreachable in practice — see QuickAddModel
        }
    }
}

/// The fastest path in the app: open, type `"lunch 150"`, hit return, done.
/// Everything below the text field is optional refinement.
struct QuickAddView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<LiveNote> { $0.archivedAt == nil },
        sort: \LiveNote.createdAt, order: .reverse
    ) private var draftNotes: [LiveNote]

    @State private var model = QuickAddModel()
    @State private var amountText = ""
    /// Explicit source of truth for which of the four modes is showing.
    /// `model.effectiveKind` can't carry this on its own — Live Note isn't an
    /// `EntryKind` at all.
    @State private var mode: QuickAddKind = .expense
    @State private var liveNoteText = ""
    @State private var showLiveNoteDeleteConfirm = false
    @FocusState private var fieldFocused: Bool

    private let liveNoteCharacterLimit = 180

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                if mode == .liveNote {
                    liveNoteTextBox
                } else {
                    TextField("What happened?", text: $model.text, axis: .vertical)
                        .font(.title2)
                        .focused($fieldFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                        .lineLimit(1...3)
                }

                // Always visible — Live Note is a first-class option here,
                // reachable the instant the sheet opens, not just after
                // typing something for the parser to react to.
                kindPicker

                if mode != .liveNote, model.parsed != nil {
                    interpretationFields
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer(minLength: 0)

                primaryButton
            }
            .padding(Theme.Space.l)
            .traceBackground()
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(mode == .liveNote ? "Done" : "Cancel") { dismiss() }
                }
                if mode == .liveNote {
                    ToolbarItem(placement: .primaryAction) {
                        liveNoteMenu
                    }
                }
            }
            .animation(.snappy(duration: 0.2), value: model.parsed)
            .animation(.snappy(duration: 0.2), value: mode)
            .onAppear {
                fieldFocused = true
                liveNoteText = draftNotes.first?.text ?? ""
                reconcileLiveActivityState()
            }
            .onChange(of: liveNoteText) { _, newValue in
                if newValue.count > liveNoteCharacterLimit {
                    liveNoteText = String(newValue.prefix(liveNoteCharacterLimit))
                    return // re-fires onChange with the clamped value
                }
                persistLiveNote(newValue)
            }
            .confirmationDialog(
                "Delete this note?", isPresented: $showLiveNoteDeleteConfirm, titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteLiveNote() }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Kind picker — always visible; Live Note lives here as a peer of
    // Expense/Income/Activity, not behind a gesture or a second screen.

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            if mode != .liveNote, model.needsKindConfirmation {
                Text("Not sure what this is — pick one.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Picker("Kind", selection: quickAddKindBinding) {
                ForEach(QuickAddKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Live Note mode — text box, primary button, menu

    private var liveNoteTextBox: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack(alignment: .topLeading) {
                if liveNoteText.isEmpty {
                    Text("Type your note…")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $liveNoteText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .focused($fieldFocused)
            }
            .padding(Theme.Space.m)
            .frame(height: 140)
            .background(Color.traceSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))

            CharacterLimitRing(count: liveNoteText.count, limit: liveNoteCharacterLimit)
                .padding(Theme.Space.s)
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        if mode == .liveNote {
            Button(action: toggleGoLive) {
                HStack(spacing: Theme.Space.xs) {
                    if isLiveNoteLive {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.white)
                            .symbolEffect(.pulse)
                    }
                    Text(isLiveNoteLive ? "Live" : "Go Live")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            // The one thing that was actually broken visually: this state
            // must be unmistakable at a glance, not just a text swap — Live
            // gets the app's negative/red token so it reads as clearly
            // different from Go Live's ordinary accent-purple, using only
            // existing Theme colors.
            .tint(isLiveNoteLive ? Color.traceNegative : Color.traceAccent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(isLiveNoteEmpty)
        } else {
            Button(action: save) {
                Text("Add")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(model.makeDraft() == nil)
        }
    }

    private var liveNoteMenu: some View {
        Menu {
            // Non-destructive — icon takes the brand accent, text stays the
            // default label color. Inside a native `Menu`, SwiftUI's own
            // `.foregroundStyle`/`.symbolRenderingMode` on a Label's icon are
            // silently ignored — the row is rendered by UIKit as a `UIAction`,
            // which only honors color via `.tint(_:)` on the `Button` itself.
            // `.tint` here colors just the icon (text stays default), which
            // is exactly what's wanted — verified against the real rendered
            // menu, not just the SwiftUI source.
            Button {
                archiveLiveNote()
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(Color.traceAccent)
            .disabled(currentLiveNote == nil)

            // Destructive — same proven fix as Archive: the icon's color
            // has to come from `.tint(_:)` on the `Button`, not from
            // `.foregroundStyle`/`.symbolRenderingMode` on the Label's icon,
            // which the native Menu row ignores. Text keeps its explicit
            // red too, so icon and text land on the exact same red rather
            // than text getting it from `role: .destructive`'s system red
            // and the icon getting it from `.tint` separately. `role:
            // .destructive` is kept for its semantics (confirmation flow,
            // accessibility), not relied on alone for color.
            Button(role: .destructive) {
                showLiveNoteDeleteConfirm = true
            } label: {
                Label {
                    Text("Delete")
                        .foregroundStyle(Color.traceNegative)
                } icon: {
                    Image(systemName: "trash")
                }
            }
            .tint(Color.traceNegative)
            .disabled(currentLiveNote == nil)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Note actions")
    }

    // MARK: Interpretation fields — amount/category/duration/description for
    // whichever of Expense/Income/Activity is currently selected.

    private var interpretationFields: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            switch model.effectiveKind {
            case .expense, .income:
                HStack(spacing: Theme.Space.m) {
                    HStack(spacing: Theme.Space.xs) {
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.body.monospacedDigit())
                            .onChange(of: amountText) { _, new in
                                model.manualAmount = Double(new.replacingOccurrences(of: ",", with: ""))
                            }
                        Text(AppSettings.shared.currencyCode)
                            .foregroundStyle(.secondary)
                    }
                    if model.effectiveKind == .expense {
                        Spacer()
                        categoryMenu
                    }
                }

            case .activity:
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("Duration")
                        .foregroundStyle(.secondary)
                    DurationEditor(seconds: durationBinding)
                }

            case .note:
                // Unreachable — see `QuickAddModel.makeDraft()`.
                EmptyView()
            }

            if model.effectiveKind != .note {
                TextField("Description", text: titleBinding)
                    .foregroundStyle(.primary)
            }
        }
        .padding(Theme.Space.m)
        .background(Color.traceSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .onChange(of: model.parsed) { _, _ in syncEditableFields() }
    }

    private var categoryMenu: some View {
        Menu {
            Button("None") { model.manualCategory = nil }
            ForEach(ExpenseCategory.allCases) { category in
                Button {
                    Haptics.selection()
                    model.manualCategory = category
                } label: {
                    Label(category.displayName, systemImage: category.symbolName)
                }
            }
        } label: {
            HStack(spacing: Theme.Space.xs) {
                Text(model.effectiveCategory?.displayName ?? "Category")
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .font(.subheadline)
            .foregroundStyle(model.effectiveCategory == nil ? .secondary : .primary)
        }
    }

    // MARK: Bindings

    private var quickAddKindBinding: Binding<QuickAddKind> {
        Binding(
            get: { mode },
            set: { newValue in
                Haptics.selection()
                mode = newValue
                if let entryKind = newValue.entryKind {
                    model.manualKind = entryKind
                }
            }
        )
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { model.effectiveTitle },
            set: { model.manualTitle = $0 }
        )
    }

    /// Feeds `DurationEditor` directly — reads whatever's currently in effect
    /// (parsed or manually set) and writes straight back into the model, no
    /// intermediate text representation to fall out of sync.
    private var durationBinding: Binding<Double> {
        Binding(
            get: { model.effectiveDurationSeconds ?? 0 },
            // Deliberately does NOT map 0 back to nil: unlike EntryDetailView
            // (where nil just means "no duration"), nil here specifically
            // means "defer to the parser's guess". Once the user has touched
            // the wheel at all, even landing back on 0h 0m, that's an
            // explicit override and must win outright — same as amount/
            // category once manually touched elsewhere in this view.
            set: { model.manualDurationSeconds = $0 }
        )
    }

    private func syncEditableFields() {
        if let amount = model.effectiveAmount {
            let formatted = amount == amount.rounded() ? String(Int(amount)) : String(amount)
            if Double(amountText.replacingOccurrences(of: ",", with: "")) != amount {
                amountText = formatted
            }
        } else {
            amountText = ""
        }
    }

    private func save() {
        guard let draft = model.makeDraft() else { return }
        EntryActions.add(draft, in: context)
        Haptics.logged()
        dismiss()
    }

    // MARK: Live Note — persistence & lifecycle, ported from the former
    // standalone `LiveNoteComposerView`. There's ever only one draft — the
    // query exists precisely so entering Live Note mode always finds the
    // same one instead of creating a new one.

    private var currentLiveNote: LiveNote? { draftNotes.first }
    private var isLiveNoteEmpty: Bool { liveNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var isLiveNoteLive: Bool { currentLiveNote?.isLive ?? false }

    /// Keeps the draft in sync with every keystroke — the "text must still
    /// be there" requirement covers app termination, not just a clean
    /// dismissal, so this can't wait for `Done`. Creates the draft lazily on
    /// the first real character rather than the moment Live Note mode is
    /// selected, so switching to it and back without typing anything never
    /// leaves an empty row behind.
    private func persistLiveNote(_ newText: String) {
        if let note = currentLiveNote {
            note.text = newText
            LiveNoteActions.save(context)
            if note.isLive {
                LiveActivityController.update(activityID: note.activityID, text: newText)
            }
        } else if !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            LiveNoteActions.add(text: newText, in: context)
        }
    }

    private func toggleGoLive() {
        guard let note = currentLiveNote, !isLiveNoteEmpty else { return }
        if note.isLive {
            Haptics.tap()
            LiveActivityController.end(activityID: note.activityID)
            LiveNoteActions.setActivityID(nil, for: note, in: context)
        } else if let activityID = LiveActivityController.start(for: note) {
            Haptics.tap()
            LiveNoteActions.setActivityID(activityID, for: note, in: context)
        } else {
            // `start` returning nil means ActivityKit itself refused (Live
            // Activities disabled/not authorized) — leave `activityID`
            // untouched (still correctly not-live) but make the failure
            // felt instead of silently doing nothing.
            Haptics.error()
        }
    }

    /// The persisted `activityID` is only ever a record of what we last told
    /// ActivityKit to do — it's not proof the activity is still actually
    /// running. The system can end one behind the app's back (staleness
    /// expiry, or while the app wasn't running to observe it), which would
    /// otherwise leave the UI stuck showing "Live" for a note that isn't.
    /// Called once when entering/reopening Quick Add so the button always
    /// reflects reality rather than a possibly-stale local copy.
    private func reconcileLiveActivityState() {
        guard let note = currentLiveNote, note.isLive,
              !LiveActivityController.isActuallyRunning(activityID: note.activityID)
        else { return }
        LiveNoteActions.setActivityID(nil, for: note, in: context)
    }

    private func archiveLiveNote() {
        guard let note = currentLiveNote else { return }
        Haptics.tap()
        LiveActivityController.end(activityID: note.activityID)
        LiveNoteActions.archive(note, in: context)
        liveNoteText = ""
    }

    private func deleteLiveNote() {
        guard let note = currentLiveNote else { return }
        Haptics.tap()
        LiveActivityController.end(activityID: note.activityID)
        LiveNoteActions.delete(note, in: context)
        liveNoteText = ""
    }
}

#Preview {
    QuickAddView()
        .modelContainer(PreviewData.emptyContainer)
}
