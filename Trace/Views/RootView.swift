import SwiftUI
import SwiftData

struct RootView: View {
    enum Tab: Hashable { case today, history, journal, stats, settings }
    @State private var selection: Tab = .today

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(Tab.today)

            HistoryView()
                .tabItem { Label("History", systemImage: "list.bullet") }
                .tag(Tab.history)

            JournalView()
                .tabItem { Label("Journal", systemImage: "book.closed") }
                .tag(Tab.journal)

            StatisticsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(Tab.stats)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
    }
}

#Preview {
    RootView()
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.container)
}
