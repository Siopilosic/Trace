import SwiftUI
import SwiftData

/// Edit or delete a single entry. Changes are written straight back to the
/// model (SwiftData autosaves; we also save explicitly on disappear).
struct EntryDetailView: View {
    @Bindable var entry: Entry
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $entry.kind) {
                    ForEach(EntryKind.allCases) { Text($0.displayName).tag($0) }
                }
                if entry.kind == .note {
                    TextField("Note", text: $entry.title, axis: .vertical)
                        .lineLimit(1...6)
                } else {
                    TextField("Description", text: $entry.title)
                }
            }

            if entry.kind.isMoney {
                Section("Amount") {
                    HStack {
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                            .onChange(of: amountText) { _, new in
                                entry.amount = Double(new.replacingOccurrences(of: ",", with: ""))
                            }
                        Text(AppSettings.shared.currencyCode).foregroundStyle(.secondary)
                    }
                }
            }

            if entry.kind == .expense {
                Section("Category") {
                    Picker("Category", selection: categoryBinding) {
                        Text("None").tag(ExpenseCategory?.none)
                        ForEach(ExpenseCategory.allCases) { category in
                            Text(category.displayName).tag(ExpenseCategory?.some(category))
                        }
                    }
                }
            }

            if entry.kind == .activity {
                Section("Duration") {
                    DurationEditor(seconds: Binding(
                        get: { entry.durationSeconds ?? 0 },
                        set: { entry.durationSeconds = $0 == 0 ? nil : $0 }
                    ))
                }
            }

            Section("When") {
                DatePicker("Date", selection: $entry.date)
            }

            if entry.kind != .note {
                Section("Note") {
                    TextField("Add a note", text: noteBinding, axis: .vertical)
                        .lineLimit(1...5)
                }
            }

            Section {
                Button("Delete Entry", role: .destructive) { showDeleteConfirm = true }
            }
        }
        .navigationTitle(entry.kind.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let amount = entry.amount {
                amountText = amount == amount.rounded() ? String(Int(amount)) : String(amount)
            }
        }
        .onDisappear { EntryActions.save(context) }
        .confirmationDialog("Delete this entry?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                EntryActions.delete(entry, in: context)
                dismiss()
            }
        }
    }

    private var categoryBinding: Binding<ExpenseCategory?> {
        Binding(get: { entry.category }, set: { entry.category = $0 })
    }

    private var noteBinding: Binding<String> {
        Binding(get: { entry.noteText ?? "" }, set: { entry.noteText = $0.isEmpty ? nil : $0 })
    }
}

/// Hours + minutes wheels for editing an activity's length.
private struct DurationEditor: View {
    @Binding var seconds: Double

    private var hours: Int { Int(seconds) / 3600 }
    private var minutes: Int { (Int(seconds) % 3600) / 60 }

    var body: some View {
        HStack {
            Picker("Hours", selection: Binding(
                get: { hours },
                set: { seconds = Double($0 * 3600 + minutes * 60) }
            )) {
                ForEach(0..<13) { Text("\($0)h").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Picker("Minutes", selection: Binding(
                get: { minutes },
                set: { seconds = Double(hours * 3600 + $0 * 60) }
            )) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0)m").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 120)
    }
}

#Preview {
    NavigationStack {
        EntryDetailView(entry: Entry(kind: .expense, title: "McDonald's", amount: 320, category: .food))
    }
    .modelContainer(PreviewData.emptyContainer)
}
