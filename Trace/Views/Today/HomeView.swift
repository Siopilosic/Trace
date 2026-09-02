import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @State private var showQuickAdd = false

    private var calendar: Calendar { settings.calendar }
    private var now: Date { Date() }

    private var todayEntries: [Entry] {
        entries.filter { calendar.isDateInToday($0.date) }
    }
    private var recent: [Entry] { Array(todayEntries.prefix(6)) }

    private var engine: StatisticsEngine { StatisticsEngine(calendar: calendar) }

    /// All-time income minus all-time expenses — never today-scoped, never
    /// reset by a period. See `StatisticsEngine.balance(for:)`.
    private var balance: Double { engine.balance(for: entries) }

    /// Today's money numbers, computed the same way Stats computes a Day
    /// period — one definition of "today's totals" for the whole app.
    private var todayStats: Statistics {
        engine.statistics(for: entries, period: .day)
    }

    /// This calendar month's income/expense — reuses the same Month period
    /// Stats uses, so it's never a second, hand-rolled date filter. Deliberately
    /// separate from `balance`, which is never period-scoped.
    private var monthStats: Statistics {
        engine.statistics(for: entries, period: .month)
    }

    private var goalsEngine: GoalsEngine { GoalsEngine(calendar: calendar) }

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
            .traceBackground()
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showQuickAdd) {
                QuickAddView()
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                header
                balanceSection
                todaySection

                if !goals.isEmpty {
                    goalsSection
                }

                if !recent.isEmpty {
                    recentSection
                }
            }
            .traceScreenPadding()
            .padding(.top, Theme.Space.l)
            .padding(.bottom, Theme.Space.l)
        }
        // Reserves real space for the floating button instead of overlaying
        // it on top of scroll content — Recent's rows are laid out to never
        // sit underneath it, at rest or at the end of the scroll.
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                QuickAddButton { showQuickAdd = true }
            }
            .padding(.trailing, Theme.Space.l)
            .padding(.bottom, Theme.Space.m)
        }
    }

    // MARK: Balance — the primary financial figure, all-time, never period-scoped

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            StatFigure(label: "Balance", value: Format.money(balance), size: 44)
            monthSummary
        }
    }

    /// The small "↑ income ↓ expenses" line directly under Balance — this
    /// month only, reusing `monthStats`. Never confused with all-time Balance
    /// (above) or today's Net (below): three different scopes, three places.
    @ViewBuilder
    private var monthSummary: some View {
        if monthStats.totalIncome > 0 || monthStats.totalSpent > 0 {
            HStack(spacing: Theme.Space.l) {
                if monthStats.totalIncome > 0 {
                    monthFigure(systemImage: "arrow.up", value: monthStats.totalIncome, suffix: "income", tint: .tracePositive)
                }
                if monthStats.totalSpent > 0 {
                    monthFigure(systemImage: "arrow.down", value: monthStats.totalSpent, suffix: "expenses", tint: .traceNegative)
                }
            }
        } else if balance != 0 {
            // Balance has history, but nothing happened this specific month —
            // say so quietly rather than leaving an unexplained gap under Balance.
            Text("This month · No financial activity")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        // Both zero and no all-time history either: nothing to show here at
        // all — the "0 EGP" Balance above already says everything needed.
    }

    private func monthFigure(systemImage: String, value: Double, suffix: String, tint: Color) -> some View {
        HStack(spacing: Theme.Space.xs) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text("\(Format.money(value)) \(suffix)")
                .font(.caption.weight(.medium))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
    }

    // MARK: Today figures — today's movement, then today's other metrics

    private struct Figure {
        var label: String
        var value: String
        var caption: String?
        var tint: Color
    }

    /// Only the figures that mean something today — an income-free day shows
    /// no "Income 0 EGP" row at all. Activity time and an entries count used
    /// to live here too; they were dropped as redundant dashboard noise —
    /// activity logging, its stats (on Stats), and Recent are all untouched.
    private var todayFigures: [Figure] {
        let stats = todayStats
        var figures: [Figure] = []

        if stats.totalIncome > 0 {
            figures.append(Figure(label: "Income", value: Format.money(stats.totalIncome), tint: .tracePositive))
        }
        if stats.totalSpent > 0 {
            figures.append(Figure(label: "Spent", value: Format.money(stats.totalSpent), tint: .traceNegative))
        }
        if stats.totalSpent > 0 || stats.totalIncome > 0 {
            figures.append(Figure(
                label: "Net", value: Format.signedMoney(stats.net),
                tint: stats.net >= 0 ? .tracePositive : .traceNegative
            ))
        }
        return figures
    }

    private var todaySection: some View {
        let figures = todayFigures
        return VStack(alignment: .leading, spacing: Theme.Space.l) {
            Text("Today").traceSectionLabelStyle()

            if figures.isEmpty {
                Text("Nothing logged yet today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading),
                    ],
                    alignment: .leading, spacing: Theme.Space.l
                ) {
                    ForEach(figures, id: \.label) { figure in
                        StatFigure(label: figure.label, value: figure.value, size: 24, tint: figure.tint)
                    }
                }
            }
        }
    }

    // MARK: Goals

    private var goalsSection: some View {
        NavigationLink {
            GoalsView()
        } label: {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack {
                    Text("Goals").traceSectionLabelStyle()
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                VStack(spacing: 0) {
                    ForEach(goals) { goal in
                        GoalRow(goal: goal, progress: goalsEngine.progress(for: goal, entries: entries))
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Recent

    private var recentSection: some View {
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
