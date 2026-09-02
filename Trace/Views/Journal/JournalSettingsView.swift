import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Journal-specific preferences — reached both from Settings › Journal and
/// directly from Journal's own toolbar, mirroring how `GoalsView` is reached
/// identically from both Today and Settings › Manage Goals.
///
/// Local-only data portability (export/import a JSON file, storage counts) —
/// no account, no sync, no server. See `SettingsView`'s "Data" section for
/// the equivalent covering the whole app.
struct JournalSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.createdAt) private var entries: [JournalEntry]

    @State private var showImporter = false
    @State private var importResult: String?

    private var exportURL: URL? {
        guard !entries.isEmpty else { return nil }
        return JSONExport.writeTempFile(
            JournalActions.exportPayload(entries),
            filename: "trace-journal-export.json"
        )
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    JournalArchiveView()
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            }

            Section {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Export All Entries", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Label("Export All Entries", systemImage: "square.and.arrow.up")
                        .foregroundStyle(.secondary)
                }

                Button {
                    showImporter = true
                } label: {
                    Label("Import Entries", systemImage: "square.and.arrow.down")
                }
            } footer: {
                Text("Export saves every journal entry as a JSON file you can keep or move to another device. Import adds entries from a previously exported file — it never removes or replaces what's already here.")
            }

            Section {
                LabeledContent("Entries", value: "\(entries.count)")
                if let oldest = entries.first {
                    LabeledContent("Since", value: Format.journalDayHeader(oldest.createdAt))
                }
            } header: {
                Text("Storage")
            }
        }
        .scrollContentBackground(.hidden)
        .traceBackground()
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            importFile(from: result)
        }
        .alert("Import", isPresented: Binding(
            get: { importResult != nil },
            set: { if !$0 { importResult = nil } }
        )) {
            Button("OK") { importResult = nil }
        } message: {
            Text(importResult ?? "")
        }
    }

    private func importFile(from result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            importResult = "Couldn't read that file."
            return
        }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard
            let data = try? Data(contentsOf: url),
            let payload = try? JSONExport.decoder.decode([JournalActions.ExportEntry].self, from: data)
        else {
            importResult = "That file doesn't look like a Trace journal export."
            return
        }

        let count = JournalActions.importPayload(payload, in: context)
        Haptics.logged()
        importResult = count == 0
            ? "Nothing to import."
            : "Imported \(count) \(count == 1 ? "entry" : "entries")."
    }
}

#Preview {
    NavigationStack { JournalSettingsView() }
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.container)
}
