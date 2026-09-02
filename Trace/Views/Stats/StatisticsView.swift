import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]

    @State private var period: StatisticsPeriod = .month

    private var engine: StatisticsEngine {
        StatisticsEngine(calendar: settings.calendar)
    }

    private var stats: Statistics {
        engine.statistics(for: entries, period: period)
    }

    /// Current vs. the same period a period ago — `nil` for Day, where a
    /// one-day-to-the-next delta isn't a meaningful comparison.
    private var comparison: (current: Statistics, previous: Statistics)? {
        engine.comparison(for: entries, period: period)
    }

    private var maxCategory: Double {
        stats.categoryTotals.map(\.amount).max() ?? 0
    }
    private var maxActivity: Double {
        stats.activityTotals.map(\.totalSeconds).max() ?? 0
    }

    private var periodNoun: String { period.title.lowercased() }

    private var spentCaption: String? {
        guard let comparison else { return nil }
        return Format.periodComparisonCaption(
            current: comparison.current.totalSpent,
            previous: comparison.previous.totalSpent,
            periodNoun: periodNoun,
            formatDelta: { Format.money($0) }
        )
    }

    private var activityCaption: String? {
        guard let comparison else { return nil }
        return Format.periodComparisonCaption(
            current: comparison.current.totalActivityDuration,
            previous: comparison.previous.totalActivityDuration,
            periodNoun: periodNoun,
            formatDelta: { Format.duration($0) }
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    EmptyStateView(
                        title: "No numbers yet.",
                        message: "Log a few things and your patterns will show up here.",
                        systemImage: "chart.bar"
                    )
                } else {
                    content
                }
            }
            .traceBackground()
            .navigationTitle("Stats")
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                Picker("Period", selection: $period) {
                    ForEach(StatisticsPeriod.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.top, Theme.Space.s)

                Text(stats.interval.periodLabel(for: period, calendar: settings.calendar))
                    .font(.title3.weight(.semibold))

                moneySection

                if stats.activityCount > 0 {
                    Divider().overlay(Color.traceSeparator.opacity(0.5))
                    activitySection
                }
            }
            .traceScreenPadding()
            .padding(.bottom, Theme.Space.xxl)
        }
        .animation(.snappy, value: period)
    }

    // MARK: Money — "where is it going, how does it compare"

    private var moneySection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            StatFigure(label: "Spent", value: Format.money(stats.totalSpent), caption: spentCaption, size: 44,
                       tint: stats.totalSpent > 0 ? .traceNegative : .primary)

            HStack(alignment: .top, spacing: Theme.Space.l) {
                StatFigure(label: "Income", value: Format.money(stats.totalIncome), size: 24,
                           tint: .tracePositive)
                StatFigure(label: "Net", value: Format.signedMoney(stats.net), size: 24,
                           tint: stats.net >= 0 ? .tracePositive : .traceNegative)
            }

            HStack(alignment: .top, spacing: Theme.Space.l) {
                StatFigure(label: "Average", value: Format.money(stats.averageDailySpending),
                           caption: "per day", size: 24)
                StatFigure(label: "Transactions", value: "\(stats.transactionCount)", size: 24)
            }

            // "Where is my money going" is the first question this screen should
            // answer, so the breakdown leads; the trend (a secondary "and how has
            // that looked over time") follows it.
            if !stats.categoryTotals.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text("Where it went").traceSectionLabelStyle()
                        .padding(.bottom, Theme.Space.xs)
                    ForEach(stats.categoryTotals) { total in
                        ProportionalBarRow(
                            label: total.category.displayName,
                            valueText: Format.money(total.amount),
                            fraction: maxCategory > 0 ? total.amount / maxCategory : 0
                        )
                    }
                }
            }

            // A trend only reads as a trend with a handful of comparable
            // buckets — an hour-by-hour chart of a single day, or an empty
            // chart when nothing was spent, is decoration, not information.
            if period != .day && stats.totalSpent > 0 {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Text("Trend").traceSectionLabelStyle()
                    TrendChart(points: stats.trend, period: period)
                }
            }
        }
    }

    // MARK: Activity — "what am I spending time on, and how much"

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            Text("Activity")
                .font(.title3.weight(.semibold))

            StatFigure(
                label: "Time",
                value: Format.activityTotal(seconds: stats.totalActivityDuration, count: stats.activityCount),
                caption: activityCaption,
                size: 44
            )

            StatFigure(label: "Sessions", value: "\(stats.activityCount)", size: 24)

            if !stats.activityTotals.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text("Where your time went").traceSectionLabelStyle()
                        .padding(.bottom, Theme.Space.xs)
                    ForEach(stats.activityTotals.prefix(8)) { total in
                        ProportionalBarRow(
                            label: total.name,
                            valueText: Format.duration(total.totalSeconds),
                            fraction: maxActivity > 0 ? total.totalSeconds / maxActivity : 0
                        )
                    }
                }
            }

            if period != .day && stats.totalActivityDuration > 0 {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Text("Trend").traceSectionLabelStyle()
                    TrendChart(points: stats.activityTrend, period: period)
                }
            }
        }
    }
}

#Preview {
    StatisticsView()
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.container)
}
