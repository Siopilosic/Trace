import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @State private var search = ""

    private var calendar: Calendar { settings.calendar }

    private var filtered: [Entry] {
        guard !search.isEmpty else { return entries }
        let needle = search.lowercased()
        return entries.filter {
            $0.title.lowercased().contains(needle)
            || ($0.noteText?.lowercased().contains(needle) ?? false)
            || ($0.category?.displayName.lowercased().contains(needle) ?? false)
        }
    }

    private var sections: [(day: Date, entries: [Entry])] {
        let groups = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        return groups.map { (day: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    EmptyStateView(
                        title: "No history yet.",
                        message: "Everything you log will gather here, newest first.",
                        systemImage: "list.bullet"
                    )
                } else if filtered.isEmpty {
                    EmptyStateView(
                        title: "No matches.",
                        message: "Nothing logged matches “\(search)”.",
                        systemImage: "magnifyingglass"
                    )
                } else {
                    list
                }
            }
            .navigationTitle("History")
            .searchable(text: $search, prompt: "Search entries")
        }
    }

    private var list: some View {
        List {
            ForEach(sections, id: \.day) { section in
                Section {
                    ForEach(section.entries) { entry in
                        NavigationLink {
                            EntryDetailView(entry: entry)
                        } label: {
                            EntryRow(entry: entry, showsTime: true)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(Format.relativeDay(section.day, calendar: calendar))
                        .traceSectionLabelStyle()
                }
            }
        }
        .listStyle(.plain)
    }

    private func delete(_ entry: Entry) {
        Haptics.tap()
        withAnimation { EntryActions.delete(entry, in: context) }
    }
}

#Preview {
    HistoryView()
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.container)
}
