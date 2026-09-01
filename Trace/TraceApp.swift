import SwiftUI
import SwiftData

@main
struct TraceApp: App {
    /// One local-first SwiftData container for the whole app.
    /// `isStoredInMemoryOnly: false` → persists between launches.
    /// Swapping in a `cloudKitDatabase:` option later needs no model changes.
    let container: ModelContainer = {
        do {
            return try ModelContainer(
                for: Entry.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .tint(.traceAccent)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
        .modelContainer(container)
    }
}
