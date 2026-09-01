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

    private var maxCategory: Double {
        stats.categoryTotals.map(\.amount).max() ?? 0
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

                StatFigure(label: "Spent", value: Format.money(stats.totalSpent), size: 44)

                HStack(alignment: .top, spacing: Theme.Space.l) {
                    StatFigure(label: "Income", value: Format.money(stats.totalIncome), size: 24,
                               tint: .tracePositive)
                    StatFigure(label: "Net", value: Format.signedMoney(stats.net), size: 24,
                               tint: stats.net >= 0 ? .tracePositive : .primary)
                }

                HStack(alignment: .top, spacing: Theme.Space.l) {
                    StatFigure(label: "Average", value: Format.money(stats.averageDailySpending),
                               caption: "per day", size: 24)
                    StatFigure(label: "Transactions", value: "\(stats.transactionCount)", size: 24)
                }

                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Text("Trend").traceSectionLabelStyle()
                    TrendChart(points: stats.trend, period: period)
                }

                if !stats.categoryTotals.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Text("By category").traceSectionLabelStyle()
                            .padding(.bottom, Theme.Space.xs)
                        ForEach(stats.categoryTotals) { total in
                            CategoryBreakdownRow(
                                total: total,
                                fraction: maxCategory > 0 ? total.amount / maxCategory : 0
                            )
                        }
                    }
                }
            }
            .traceScreenPadding()
            .padding(.bottom, Theme.Space.xxl)
        }
        .animation(.snappy, value: period)
    }
}

#Preview {
    StatisticsView()
        .environment(AppSettings.shared)
        .modelContainer(PreviewData.container)
}
