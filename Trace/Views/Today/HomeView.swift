import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @State private var showQuickAdd = false

    private var calendar: Calendar { settings.calendar }
    private var now: Date { Date() }

    private var todayEntries: [Entry] {
        entries.filter { calendar.isDateInToday($0.date) }
    }
    private var todaySpent: Double {
        todayEntries.filter { $0.kind == .expense }.compactMap(\.amount).reduce(0, +)
    }
    private var loggedToday: Int { todayEntries.count }
    private var recent: [Entry] { Array(todayEntries.prefix(6)) }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    EmptyStateView(
                        title: "Nothing here yet.",
                        message: "Start by telling Trace what happened today.",
                        systemImage: "circle.dotted",
                        actionTitle: "Quick Add",
                        action: { showQuickAdd = true }
                    )
                } else {
                    content
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                if !entries.isEmpty {
                    QuickAddButton { showQuickAdd = true }
                        .padding(.trailing, Theme.Space.l)
                        .padding(.bottom, Theme.Space.m)
                }
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddView()
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                header

                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    Text("Today").traceSectionLabelStyle()
                    HStack(alignment: .top, spacing: Theme.Space.l) {
                        StatFigure(label: "Spent", value: Format.money(todaySpent))
                        StatFigure(
                            label: "Logged",
                            value: "\(loggedToday)",
                            caption: loggedToday == 1 ? "entry" : "entries"
                        )
                    }
                }

                if !recent.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        Text("Recent").traceSectionLabelStyle()
                            .padding(.bottom, Theme.Space.xs)
                        ForEach(Array(recent.enumerated()), id: \.element.id) { index, entry in
                            EntryRow(entry: entry, showsTime: true)
                            if index < recent.count - 1 {
                                Divider().overlay(Color.traceSeparator.opacity(0.5))
                            }
                        }
                    }
                }
            }
            .traceScreenPadding()
            .padding(.top, Theme.Space.l)
            .padding(.bottom, 120)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text(Format.headerDate(now))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(now.greeting(calendar: calendar))
                .font(.traceGreeting)
                .foregroundStyle(.primary)
        }
    }
}

#Preview("With data") {
    HomeView()
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.container)
}

#Preview("Empty") {
    HomeView()
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.emptyContainer)
}
