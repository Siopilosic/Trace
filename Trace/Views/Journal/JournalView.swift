import SwiftUI
import SwiftData

/// Personal diary entries, reverse-chronological and grouped by calendar
/// day — separate from Entry's quick-logged timeline (History). Reached from
/// its own tab: open, tap +, write, save.
struct JournalView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    // Active entries only — archived entries are hidden from the normal
    // timeline and search by construction, not by an extra filter step.
    @Query(
        filter: #Predicate<JournalEntry> { $0.archivedAt == nil },
        sort: \JournalEntry.createdAt, order: .reverse
    ) private var entries: [JournalEntry]
    @State private var search = ""
    @State private var showNewEntry = false
    @State private var editingEntry: JournalEntry?
    @State private var showSettings = false

    /// Whether the search field is focused (keyboard up). Drives the trailing
    /// bar button between "+" (new entry) and "×" (exit search).
    @State private var searchActive = false

    /// Date constraint, independent of text search. View state only — survives
    /// navigation within Journal, resets on relaunch.
    @State private var dateFilter: JournalDateFilter = .all
    @State private var showDateFilter = false

    /// The current calendar day, used to resolve `Today` / `Yesterday` in the
    /// day headers. Refreshed on the day-change notification and when the app
    /// returns to the foreground so the labels never go stale.
    @State private var today = Date()
    @Environment(\.scenePhase) private var scenePhase

    private var calendar: Calendar { settings.calendar }

    /// Date filter and text search are independent and combine with AND.
    private var filteredEntries: [JournalEntry] {
        entries.filter {
            dateFilter.contains($0.createdAt, calendar: calendar)
                && JournalFilter.matches($0, search: search)
        }
    }

    private var emptyMatchMessage: String {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = dateFilter.label(calendar: calendar)
        switch (query.isEmpty, range) {
        case (false, .some(let range)):
            return "Nothing from \(range) matches “\(query)”."
        case (false, .none):
            return "Nothing in your journal matches “\(query)”."
        case (true, .some(let range)):
            return "No journal entries from \(range)."
        case (true, .none):
            return "Nothing here yet."
        }
    }

    private var sections: [(day: Date, entries: [JournalEntry])] {
        let groups = Dictionary(grouping: filteredEntries) { calendar.startOfDay(for: $0.createdAt) }
        return groups.map { (day: $0.key, entries: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    EmptyStateView(
                        title: "Your journal is empty",
                        message: "Write something about your day.",
                        systemImage: "book.closed",
                        actionTitle: "Write",
                        action: { showNewEntry = true }
                    )
                } else {
                    content
                }
            }
            .traceBackground()
            .navigationTitle("Journal")
            .toolbar {
                // Date filter — a concept separate from text search. Filled +
                // tinted icon whenever a constraint is active.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showDateFilter = true
                    } label: {
                        Image(systemName: dateFilter.isActive
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle")
                    }
                    .tint(Color.traceAccent)
                    .accessibilityLabel(dateFilter.isActive ? "Date filter active" : "Filter by Date")
                }

                // Journal's own settings entry point — jumps straight to the
                // Journal section of Settings, the same destination reached
                // via Settings › Journal (mirrors how Goals is reachable
                // identically from both Today and Settings › Manage Goals).
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "slider.vertical.3")
                    }
                    .accessibilityLabel("Journal Settings")
                }
            }
        }
        .sheet(isPresented: $showNewEntry) {
            NavigationStack {
                JournalEditorView(existingEntry: nil)
            }
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                JournalEditorView(existingEntry: entry)
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                JournalSettingsView()
            }
        }
        .sheet(isPresented: $showDateFilter) {
            JournalDateFilterSheet(filter: $dateFilter, calendar: calendar)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            today = Date()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { today = Date() }
        }
    }

    /// The populated state: the list (or a "no matches" empty state while
    /// searching), with the search + add bar floating above the tab bar —
    /// present in both cases so search stays editable/clearable even when
    /// it currently matches nothing.
    private var content: some View {
        Group {
            if filteredEntries.isEmpty {
                EmptyStateView(
                    title: "No matches.",
                    message: emptyMatchMessage,
                    systemImage: "magnifyingglass"
                )
            } else {
                list
            }
        }
        .safeAreaInset(edge: .bottom) {
            searchAndAddBar
        }
    }

    private var list: some View {
        List {
            ForEach(sections, id: \.day) { section in
                Section {
                    ForEach(section.entries) { entry in
                        Button {
                            editingEntry = entry
                        } label: {
                            JournalEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                archive(entry)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(Color.traceAccent)
                        }
                        // Same reason as History/Goals' `.scrollContentBackground(.hidden)`
                        // fix, applied the other direction: `.insetGrouped`'s
                        // own row material is a system gray, not a Trace
                        // token — set it explicitly so entries within a day
                        // read as one continuous `traceSurface` card, exactly
                        // like a native grouped list, in Trace's own palette.
                        .listRowBackground(Color.traceSurface)
                        .listRowSeparatorTint(Color.traceSeparator.opacity(0.5))
                    }
                } header: {
                    Text(JournalDate.sectionTitle(for: section.day, calendar: calendar, reference: today))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listSectionSpacing(.compact)
    }

    // MARK: Search + add bar

    /// Floats above the tab bar. Shares `GlassSearchField` with History so
    /// both search bars look and behave identically; the "+" alongside it is
    /// Journal-only.
    private var searchAndAddBar: some View {
        HStack(spacing: Theme.Space.s) {
            GlassSearchField(text: $search, placeholder: "Search entries", isActive: $searchActive)

            Button {
                if searchActive { exitSearch() } else { showNewEntry = true }
            } label: {
                Image(systemName: searchActive ? "xmark" : "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.bar, in: Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(searchActive ? "Close Search" : "New Entry")
            .animation(.snappy(duration: 0.2), value: searchActive)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.s)
        .padding(.bottom, Theme.Space.m)
    }

    /// Tapping "×": drop focus (which dismisses the keyboard via
    /// `GlassSearchField`), leave search mode, and clear the query.
    private func exitSearch() {
        search = ""
        searchActive = false
    }

    private func delete(_ entry: JournalEntry) {
        Haptics.tap()
        withAnimation { JournalActions.delete(entry, in: context) }
    }

    private func archive(_ entry: JournalEntry) {
        Haptics.tap()
        withAnimation { JournalActions.archive(entry, in: context) }
    }
}

#Preview("With data") {
    JournalView()
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.container)
}

#Preview("Empty") {
    JournalView()
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.emptyContainer)
}
