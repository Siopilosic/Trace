import SwiftUI
import SwiftData

/// Archived Live Notes — reached from the composer's own menu, not a
/// separate settings destination. Mirrors `JournalArchiveView`'s shape:
/// a quiet recovery list, not a second timeline. Restoring never
/// reactivates the Live Activity — that's always a fresh, explicit
/// "Go Live" from the composer.
struct LiveNoteArchiveView: View {
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<LiveNote> { $0.archivedAt != nil },
        sort: \LiveNote.createdAt, order: .reverse
    ) private var archivedNotes: [LiveNote]

    @State private var showDeleteConfirm: LiveNote?

    var body: some View {
        Group {
            if archivedNotes.isEmpty {
                EmptyStateView(
                    title: "No archived notes.",
                    message: "Notes you archive from the composer show up here.",
                    systemImage: "archivebox"
                )
            } else {
                List {
                    ForEach(archivedNotes) { note in
                        Text(note.text)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .padding(.vertical, Theme.Space.xs)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    showDeleteConfirm = note
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    restore(note)
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
            "Permanently delete this note?", isPresented: Binding(
                get: { showDeleteConfirm != nil },
                set: { if !$0 { showDeleteConfirm = nil } }
            ), titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let note = showDeleteConfirm {
                    delete(note)
                }
            }
        }
    }

    private func restore(_ note: LiveNote) {
        Haptics.tap()
        withAnimation { LiveNoteActions.restore(note, in: context) }
    }

    private func delete(_ note: LiveNote) {
        Haptics.tap()
        withAnimation { LiveNoteActions.delete(note, in: context) }
    }
}

#Preview {
    NavigationStack { LiveNoteArchiveView() }
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.container)
}
