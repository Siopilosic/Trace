import SwiftUI
import SwiftData

struct HistoryView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case list = "List"
        case calendar = "Calendar"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @State private var search = ""
    @State private var typeFilter: HistoryTypeFilter = .all
    @State private var mode: Mode = .list

    private var calendar: Calendar { settings.calendar }

    private var filtered: [Entry] {
        entries.filter { HistoryFilter.matches($0, search: search, type: typeFilter) }
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
                } else {
                    VStack(spacing: 0) {
                        Picker("Mode", selection: $mode) {
                            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, Theme.Space.s)
                        .padding(.bottom, Theme.Space.xs)

                        switch mode {
                        case .list:
                            listContent
                                // Same treatment as Journal's search bar —
                                // shares `GlassSearchField`, floats above the
                                // tab bar via `.safeAreaInset` instead of the
                                // system's top-integrated `.searchable()` —
                                // just without Journal's "+" beside it.
                                .safeAreaInset(edge: .bottom) {
                                    GlassSearchField(text: $search, placeholder: "Search history")
                                        .padding(.horizontal, Theme.Space.l)
                                        .padding(.top, Theme.Space.s)
                                        .padding(.bottom, Theme.Space.m)
                                }
                                .toolbar { filterToolbarItem }
                        case .calendar:
                            CalendarView(entries: entries, calendar: calendar)
                        }
                    }
                }
            }
            .traceBackground()
            .navigationTitle("History")
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if filtered.isEmpty {
            EmptyStateView(
                title: "No matches.",
                message: emptyFilterMessage,
                systemImage: "magnifyingglass"
            )
        } else {
            list
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
                        // `.scrollContentBackground(.hidden)` below only clears
                        // the List's own container background — each row still
                        // paints its own opaque `.systemBackground` (pure black
                        // in dark mode) unless told otherwise. Clearing it here
                        // lets TraceBackground show through, matching how
                        // `EntryRow` already sits directly on it in Today's
                        // Recent list.
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text(Format.relativeDay(section.day, calendar: calendar))
                        .traceSectionLabelStyle()
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ToolbarContentBuilder
    private var filterToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Filter", selection: $typeFilter) {
                    ForEach(HistoryTypeFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
            } label: {
                Image(systemName: typeFilter == .all
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
            }
            .accessibilityLabel("Filter: \(typeFilter.title)")
        }
    }

    private var emptyFilterMessage: String {
        switch (search.isEmpty, typeFilter) {
        case (true, .all):
            return "Nothing logged matches your filters."
        case (true, _):
            return "No \(typeFilter.title.lowercased()) logged yet."
        case (false, .all):
            return "Nothing logged matches “\(search)”."
        case (false, _):
            return "Nothing in \(typeFilter.title.lowercased()) matches “\(search)”."
        }
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
