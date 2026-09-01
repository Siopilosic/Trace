import SwiftUI
import SwiftData

/// The fastest path in the app: open, type `"lunch 150"`, hit return, done.
/// Everything below the text field is optional refinement.
struct QuickAddView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var model = QuickAddModel()
    @State private var amountText = ""
    @State private var durationText = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                TextField("What happened?", text: $model.text, axis: .vertical)
                    .font(.title2)
                    .focused($fieldFocused)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .lineLimit(1...3)

                if model.parsed != nil {
                    interpretation
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer(minLength: 0)

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
            .padding(Theme.Space.l)
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .animation(.snappy(duration: 0.2), value: model.parsed)
            .onAppear { fieldFocused = true }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Interpretation

    private var interpretation: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            if model.needsKindConfirmation {
                Text("Not sure what this is — pick one.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Picker("Kind", selection: kindBinding) {
                ForEach(EntryKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)

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
                HStack {
                    Text("Duration")
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("e.g. 45m", text: $durationText)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: durationText) { _, new in
                            model.manualDurationSeconds = QuickEntryParser.firstDuration(in: new)?.seconds
                        }
                }

            case .note:
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

    private var kindBinding: Binding<EntryKind> {
        Binding(
            get: { model.effectiveKind },
            set: { Haptics.selection(); model.manualKind = $0 }
        )
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { model.effectiveTitle },
            set: { model.manualTitle = $0 }
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
        if durationText.isEmpty, let seconds = model.effectiveDurationSeconds {
            durationText = Format.duration(seconds)
        }
    }

    private func save() {
        guard let draft = model.makeDraft() else { return }
        EntryActions.add(draft, in: context)
        Haptics.logged()
        dismiss()
    }
}

#Preview {
    QuickAddView()
        .modelContainer(PreviewData.emptyContainer)
}
