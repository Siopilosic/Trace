import SwiftUI
import SwiftData

/// Archived Journal entries — a quiet storage/recovery screen, not a second
/// timeline. Flat, newest-first list (no day-grouping — that richer
/// treatment belongs to the active Journal, not its attic); each entry can
/// be restored (back to its exact original chronological position, since
/// `archive`/`restore` never touch `createdAt`) or permanently deleted.
struct JournalArchiveView: View {
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<JournalEntry> { $0.archivedAt != nil },
        sort: \JournalEntry.createdAt, order: .reverse
    ) private var archivedEntries: [JournalEntry]

    @State private var showDeleteConfirm: JournalEntry?

    var body: some View {
        Group {
            if archivedEntries.isEmpty {
                EmptyStateView(
                    title: "No archived entries.",
                    message: "Entries you archive from the Journal show up here.",
                    systemImage: "archivebox"
                )
            } else {
                List {
                    ForEach(archivedEntries) { entry in
                        JournalEntryRow(entry: entry)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    showDeleteConfirm = entry
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    restore(entry)
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(Color.traceAccent)
                            }
                            .listRowBackground(Color.traceSurface)
                            .listRowSeparatorTint(Color.traceSeparator.opacity(0.5))
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .traceBackground()
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Permanently delete this entry?", isPresented: Binding(
                get: { showDeleteConfirm != nil },
                set: { if !$0 { showDeleteConfirm = nil } }
            ), titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let entry = showDeleteConfirm {
                    delete(entry)
                }
            }
        }
    }

    private func restore(_ entry: JournalEntry) {
        Haptics.tap()
        withAnimation { JournalActions.restore(entry, in: context) }
    }

    private func delete(_ entry: JournalEntry) {
        Haptics.tap()
        withAnimation { JournalActions.delete(entry, in: context) }
    }
}

#Preview {
    NavigationStack { JournalArchiveView() }
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.container)
}
