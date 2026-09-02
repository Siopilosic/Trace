import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query private var entries: [Entry]
    @Query private var goals: [Goal]
    @Query private var journalEntries: [JournalEntry]
    @Query private var liveNotes: [LiveNote]

    @State private var showDeleteAll = false
    @State private var showImporter = false
    @State private var importResult: String?

    private let currencies = ["EGP", "USD", "EUR", "GBP", "SAR", "AED"]

    private var hasAnyData: Bool {
        !entries.isEmpty || !goals.isEmpty || !journalEntries.isEmpty || !liveNotes.isEmpty
    }

    private var exportURL: URL? {
        guard hasAnyData else { return nil }
        return JSONExport.writeTempFile(
            AppExportPayload(
                entries: EntryActions.exportPayload(entries),
                goals: GoalActions.exportPayload(goals),
                journalEntries: JournalActions.exportPayload(journalEntries),
                liveNotes: LiveNoteActions.exportPayload(liveNotes)
            ),
            filename: "trace-export.json"
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Currency") {
                    Picker("Currency", selection: currencyBinding) {
                        ForEach(currencies, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: appearanceBinding) {
                        ForEach(AppSettings.Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Start week on Monday", isOn: weekStartBinding)
                } footer: {
                    Text("Affects how weekly statistics are grouped.")
                }

                Section {
                    NavigationLink("Manage Goals") {
                        GoalsView()
                    }
                    NavigationLink("Journal") {
                        JournalSettingsView()
                    }
                    NavigationLink("Live Note Archive") {
                        LiveNoteArchiveView()
                    }
                }

                Section {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Export All Data", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Label("Export All Data", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showImporter = true
                    } label: {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }
                } footer: {
                    Text("Export saves everything — entries, goals, and journal entries — as a JSON file you can keep or move to another device. Import adds records from a previously exported file — it never removes or replaces what's already here.")
                }

                Section {
                    LabeledContent("Entries", value: "\(entries.count)")
                    LabeledContent("Goals", value: "\(goals.count)")
                    LabeledContent("Journal Entries", value: "\(journalEntries.count)")
                    LabeledContent("Live Notes", value: "\(liveNotes.count)")
                } header: {
                    Text("Storage")
                }

                Section {
                    Button("Delete All Data", role: .destructive) { showDeleteAll = true }
                        .disabled(!hasAnyData)
                } footer: {
                    Text("\(entries.count) \(entries.count == 1 ? "entry" : "entries") stored locally on this device.")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                } footer: {
                    Text("Trace keeps everything on your device. No account, no sync, no servers.")
                }
            }
            .scrollContentBackground(.hidden)
            .traceBackground()
            .navigationTitle("Settings")
            .confirmationDialog("Delete all data?", isPresented: $showDeleteAll, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) {
                    withAnimation {
                        EntryActions.deleteAll(in: context)
                        GoalActions.deleteAll(in: context)
                        JournalActions.deleteAll(in: context)
                        LiveNoteActions.deleteAll(in: context)
                    }
                    Haptics.logged()
                }
            } message: {
                Text("This permanently removes every entry, goal, journal entry, and live note. It can't be undone.")
            }
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
            let payload = try? JSONExport.decoder.decode(AppExportPayload.self, from: data)
        else {
            importResult = "That file doesn't look like a Trace export."
            return
        }

        let entryCount = EntryActions.importPayload(payload.entries, in: context)
        let goalCount = GoalActions.importPayload(payload.goals, in: context)
        let journalCount = JournalActions.importPayload(payload.journalEntries, in: context)
        let liveNoteCount = LiveNoteActions.importPayload(payload.liveNotes, in: context)
        Haptics.logged()

        let total = entryCount + goalCount + journalCount + liveNoteCount
        importResult = total == 0
            ? "Nothing to import."
            : "Imported \(entryCount) \(entryCount == 1 ? "entry" : "entries"), \(goalCount) \(goalCount == 1 ? "goal" : "goals"), \(journalCount) journal \(journalCount == 1 ? "entry" : "entries"), and \(liveNoteCount) live \(liveNoteCount == 1 ? "note" : "notes")."
    }

    private var currencyBinding: Binding<String> {
        Binding(get: { settings.currencyCode }, set: { settings.currencyCode = $0 })
    }
    private var appearanceBinding: Binding<AppSettings.Appearance> {
        Binding(get: { settings.appearance }, set: { settings.appearance = $0 })
    }
    private var weekStartBinding: Binding<Bool> {
        Binding(get: { settings.weekStartsOnMonday }, set: { settings.weekStartsOnMonday = $0 })
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

/// The whole-app export format — one JSON file covering every model, so a
/// single export/import round-trips everything. Each model's own facade owns
/// its slice's shape (`EntryActions.ExportEntry`, etc.); this just bundles them.
private struct AppExportPayload: Codable {
    var entries: [EntryActions.ExportEntry]
    var goals: [GoalActions.ExportGoal]
    var journalEntries: [JournalActions.ExportEntry]
    var liveNotes: [LiveNoteActions.ExportNote]
}

#Preview {
    SettingsView()
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.container)
}
