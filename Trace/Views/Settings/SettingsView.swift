import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query private var entries: [Entry]

    @State private var showDeleteAll = false

    private let currencies = ["EGP", "USD", "EUR", "GBP", "SAR", "AED"]

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
                    Button("Delete All Data", role: .destructive) { showDeleteAll = true }
                        .disabled(entries.isEmpty)
                } footer: {
                    Text("\(entries.count) \(entries.count == 1 ? "entry" : "entries") stored locally on this device.")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                } footer: {
                    Text("Trace keeps everything on your device. No account, no sync, no servers.")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Delete all data?", isPresented: $showDeleteAll, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) {
                    withAnimation { EntryActions.deleteAll(in: context) }
                    Haptics.logged()
                }
            } message: {
                Text("This permanently removes every entry. It can't be undone.")
            }
        }
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

#Preview {
    SettingsView()
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.container)
}
