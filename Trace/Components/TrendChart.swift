import SwiftUI
import Charts

/// A single, quiet bar chart of spending across the current period. No y-axis
/// clutter, a light x-axis for orientation only.
struct TrendChart: View {
    let points: [TrendPoint]
    let period: StatisticsPeriod

    private var hasData: Bool { points.contains { $0.amount > 0 } }

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Date", point.date, unit: period.bucket),
                y: .value("Spent", point.amount),
                width: .fixed(barWidth)
            )
            .cornerRadius(3)
            .foregroundStyle(Color.traceAccent.opacity(hasData ? 0.85 : 0.2))
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4))
        }
        .frame(height: 140)
    }

    private var barWidth: CGFloat {
        switch period {
        case .day: return 6
        case .week: return 22
        case .month: return 6
        case .year: return 16
        }
    }
}
