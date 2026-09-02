import SwiftUI
import SwiftData

/// A blank page, not a form: one large text field, an automatic timestamp,
/// Save/Cancel. No title, no date/time picker — those are exactly what this
/// screen deliberately omits.
struct JournalEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    /// `nil` when writing a new entry.
    var existingEntry: JournalEntry?

    @State private var text = ""
    @State private var showDeleteConfirm = false
    @FocusState private var focused: Bool

    /// The moment shown above the editor — captured once, not live-updating.
    /// The existing entry's original `createdAt` when editing (proving it
    /// isn't changing), or "now" for a new entry.
    private let displayedDate: Date

    init(existingEntry: JournalEntry?) {
        self.existingEntry = existingEntry
        self.displayedDate = existingEntry?.createdAt ?? Date()
    }

    private var calendar: Calendar { settings.calendar }
    private var isValid: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("\(Format.journalDayHeader(displayedDate, calendar: calendar)) · \(Format.time(displayedDate))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, Theme.Space.m)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Write something…")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(.body, design: .serif))
                    .scrollContentBackground(.hidden)
                    .focused($focused)
            }
            .padding(.horizontal, Theme.Space.l - 5)
        }
        .traceBackground()
        .navigationTitle(existingEntry == nil ? "New Entry" : "Edit Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if existingEntry == nil {
                // New entry: unchanged — Cancel leading, Save trailing.
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!isValid)
                }
            } else {
                // Editing: Delete leading (quiet text button, Trace's own
                // negative color rather than plain system red) — Save then
                // Cancel trailing.
                ToolbarItem(placement: .topBarLeading) {
                    Button("Delete", role: .destructive) { showDeleteConfirm = true }
                        .foregroundStyle(Color.traceNegative)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.disabled(!isValid)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            if let existingEntry { text = existingEntry.text }
            focused = true
        }
        .confirmationDialog("Delete this entry?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let existingEntry {
                    JournalActions.delete(existingEntry, in: context)
                }
                dismiss()
            }
        }
    }

    private func save() {
        guard isValid else { return }
        if let existingEntry {
            JournalActions.update(existingEntry, text: text, in: context)
        } else {
            JournalActions.add(text: text, in: context)
        }
        Haptics.logged()
        dismiss()
    }
}

#Preview("New") {
    NavigationStack { JournalEditorView(existingEntry: nil) }
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.emptyContainer)
}

#Preview("Edit") {
    NavigationStack {
        JournalEditorView(existingEntry: JournalEntry(text: "Today was actually a really good day."))
    }
    .environment(AppSettings.shared)
    .modelContainer(PreviewData.emptyContainer)
}
