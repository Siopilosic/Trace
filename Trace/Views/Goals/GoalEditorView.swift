import SwiftUI
import SwiftData

/// Create or edit a goal — one small Form, same shape for both. Reuses the
/// conditional-section pattern already established in `EntryDetailView`:
/// which fields show depends on the selected metric.
struct GoalEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// `nil` when creating a new goal.
    var existingGoal: Goal?

    @State private var metric: GoalMetric = .spendingLimit
    @State private var amountText = ""
    @State private var targetSeconds: Double = 3600
    @State private var activityName = ""
    @State private var showDeleteConfirm = false

    private var isMoney: Bool { metric.isMoney }

    private var isValid: Bool {
        if isMoney {
            return (Double(amountText) ?? 0) > 0
        }
        return targetSeconds > 0 && !activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $metric) {
                    ForEach(GoalMetric.allCases) { Text($0.shortTitle).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if isMoney {
                Section("Target Amount") {
                    HStack {
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                        Text(AppSettings.shared.currencyCode).foregroundStyle(.secondary)
                    }
                }
            } else {
                Section("Target Duration") {
                    DurationEditor(seconds: $targetSeconds)
                }
                Section("Activity") {
                    TextField("Activity name (e.g. Python)", text: $activityName)
                }
            }

            if existingGoal != nil {
                Section {
                    Button("Delete Goal", role: .destructive) { showDeleteConfirm = true }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .traceBackground()
        .navigationTitle(existingGoal == nil ? "New Goal" : "Edit Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }.disabled(!isValid)
            }
        }
        .onAppear(perform: populate)
        .confirmationDialog("Delete this goal?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let existingGoal { GoalActions.delete(existingGoal, in: context) }
                dismiss()
            }
        }
    }

    private func populate() {
        guard let existingGoal else { return }
        metric = existingGoal.metric
        if existingGoal.metric.isMoney {
            let value = existingGoal.targetValue
            amountText = value == value.rounded() ? String(Int(value)) : String(value)
        } else {
            targetSeconds = existingGoal.targetValue
            activityName = existingGoal.activityName ?? ""
        }
    }

    private func save() {
        let target = isMoney ? (Double(amountText) ?? 0) : targetSeconds
        let name = isMoney ? nil : activityName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingGoal {
            existingGoal.metric = metric
            existingGoal.targetValue = target
            existingGoal.activityName = name
            GoalActions.save(context)
        } else {
            GoalActions.add(metric: metric, targetValue: target, activityName: name, in: context)
        }
        Haptics.logged()
        dismiss()
    }
}

#Preview("New") {
    NavigationStack { GoalEditorView(existingGoal: nil) }
        .modelContainer(PreviewData.emptyContainer)
}

#Preview("Edit") {
    NavigationStack {
        GoalEditorView(existingGoal: Goal(metric: .activityTime, targetValue: 36_000, activityName: "Python"))
    }
    .modelContainer(PreviewData.emptyContainer)
}
