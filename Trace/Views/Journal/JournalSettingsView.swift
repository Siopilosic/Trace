import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Journal-specific preferences — reached both from Settings › Journal and
/// directly from Journal's own toolbar, mirroring how `GoalsView` is reached
/// identically from both Today and Settings › Manage Goals.
///
/// Local-only data portability (export/import a file, storage counts) — no
/// account, no sync, no server. See `SettingsView`'s "Data" section for the
/// equivalent covering the whole app.
struct JournalSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.createdAt) private var entries: [JournalEntry]

    /// One import action, one presentation state. It accepts both Trace's own
    /// JSON journal export and a Quick Journal `.txt` export and routes on the
    /// selected file's type — the user never picks an importer.
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
            } header: {
                Text("Data")
            } footer: {
                Text("Export saves every journal entry as a JSON file. Import accepts a Trace journal export (.json) or a Quick Journal export (.txt) — it adds entries and never removes or replaces what's already here. Importing the same file twice won't create duplicates.")
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
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json, .plainText]
        ) { result in
            importEntries(from: result)
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

    // MARK: Routing

    enum ImportFileKind: Equatable { case traceJSON, quickJournalText, unknown }

    /// Picks the importer from the file's type: extension first (most reliable
    /// for user-chosen files), then its declared UTI. Never guesses — an
    /// undetermined type routes to `.unknown` and a clear error, not to a
    /// best-effort format.
    static func fileKind(of url: URL) -> ImportFileKind {
        switch url.pathExtension.lowercased() {
        case "json": return .traceJSON
        case "txt": return .quickJournalText
        default: break
        }
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            if type.conforms(to: .json) { return .traceJSON }
            if type.conforms(to: .plainText) { return .quickJournalText }
        }
        return .unknown
    }

    private func importEntries(from result: Result<URL, Error>) {
        // Cancelling the picker doesn't call this; a rare picker error just
        // leaves the screen untouched.
        guard case .success(let url) = result else { return }

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        switch Self.fileKind(of: url) {
        case .traceJSON:
            importTraceJSON(from: url)
        case .quickJournalText:
            importQuickJournal(from: url)
        case .unknown:
            importResult = "That file isn't a supported type. Choose a Trace export (.json) or a Quick Journal export (.txt)."
        }
    }

    // MARK: Trace JSON — unchanged decode/import path, now fed a resolved URL

    private func importTraceJSON(from url: URL) {
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

    // MARK: Quick Journal — unchanged parse/import path, now fed a resolved URL

    private func importQuickJournal(from url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            importResult = "Couldn't read that file."
            return
        }
        let contents = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(decoding: data, as: UTF8.self)

        let outcome = QuickJournalImport.parse(contents)
        let imported = JournalActions.importQuickJournal(outcome.entries, in: context)
        if imported.imported > 0 { Haptics.logged() }
        importResult = Self.quickJournalMessage(result: imported, failures: outcome.failures)
    }

    /// Builds the alert text: how many imported, how many were duplicates, and
    /// — never silently — which blocks could not be parsed.
    static func quickJournalMessage(
        result: JournalActions.QuickJournalImportResult,
        failures: [QuickJournalImport.Failure]
    ) -> String {
        if result.imported == 0, result.duplicatesSkipped == 0, failures.isEmpty {
            return "No Quick Journal entries were found in that file."
        }

        var lines: [String] = [
            "Imported \(result.imported) \(result.imported == 1 ? "entry" : "entries")."
        ]
        if result.duplicatesSkipped > 0 {
            lines.append("\(result.duplicatesSkipped) already in your journal — skipped.")
        }
        if !failures.isEmpty {
            lines.append("")
            lines.append("\(failures.count) \(failures.count == 1 ? "block" : "blocks") couldn't be read:")
            for failure in failures.prefix(5) {
                lines.append("• Line \(failure.line): \(failure.reason)")
            }
            if failures.count > 5 {
                lines.append("• …and \(failures.count - 5) more.")
            }
        }
        return lines.joined(separator: "\n")
    }
}

#Preview {
    NavigationStack { JournalSettingsView() }
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.container)
}
