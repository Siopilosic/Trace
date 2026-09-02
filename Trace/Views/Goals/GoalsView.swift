import SwiftUI
import SwiftData

/// Reached from Today's Goals section and from Settings. Lists every goal
/// with its live progress, and is where goals are created, edited, and
/// removed — no separate "manage" screen, this is the one Goals screen.
struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @Query private var entries: [Entry]

    @State private var editingGoal: Goal?
    @State private var showNewGoal = false

    private var engine: GoalsEngine { GoalsEngine(calendar: settings.calendar) }

    var body: some View {
        Group {
            if goals.isEmpty {
                EmptyStateView(
                    title: "No goals yet.",
                    message: "Set a simple, optional target — a monthly spending limit, a savings target, or time toward an activity.",
                    systemImage: "target",
                    actionTitle: "Add Goal",
                    action: { showNewGoal = true }
                )
            } else {
                List {
                    ForEach(goals) { goal in
                        Button {
                            editingGoal = goal
                        } label: {
                            GoalRow(goal: goal, progress: engine.progress(for: goal, entries: entries))
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(goal)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        // Same fix as History: `.scrollContentBackground(.hidden)`
                        // only clears the List's own container background, not
                        // each row's own opaque `.systemBackground`. Clear it
                        // per row so TraceBackground shows through.
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .traceBackground()
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewGoal = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Goal")
            }
        }
        .sheet(isPresented: $showNewGoal) {
            NavigationStack {
                GoalEditorView(existingGoal: nil)
            }
        }
        .sheet(item: $editingGoal) { goal in
            NavigationStack {
                GoalEditorView(existingGoal: goal)
            }
        }
    }

    private func delete(_ goal: Goal) {
        Haptics.tap()
        withAnimation { GoalActions.delete(goal, in: context) }
    }
}

#Preview {
    NavigationStack { GoalsView() }
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.container)
}

#Preview("Empty") {
    NavigationStack { GoalsView() }
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.emptyContainer)
}
