import SwiftUI

/// One day in the calendar grid — the day number plus up to three small dots
/// for money / activity / note. Selected gets a filled accent circle; today
/// (when not selected) gets a quiet outline so it's still easy to find.
struct CalendarDayCell: View {
    let day: CalendarGridDay
    let calendar: Calendar
    let summary: DaySummary?
    let isSelected: Bool
    let isToday: Bool

    private var dayNumber: Int { calendar.component(.day, from: day.date) }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(dayNumber)")
                .font(.subheadline.weight(isToday ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(width: 30, height: 30)
                .background {
                    if isSelected {
                        Circle().fill(Color.traceAccent)
                    } else if isToday {
                        Circle().strokeBorder(Color.traceAccent, lineWidth: 1.5)
                    }
                }

            HStack(spacing: 3) {
                dot(summary?.hasMoney == true, .traceAccent)
                dot(summary?.hasActivity == true, .secondary)
                dot(summary?.hasNote == true, Color.traceSeparator)
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        // Selection must stay unambiguous even for a leading/trailing day
        // borrowed from an adjacent month — only dim when it's neither.
        .opacity(day.isCurrentMonth || isSelected ? 1 : 0.35)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func dot(_ show: Bool, _ color: Color) -> some View {
        Circle()
            .fill(show ? color : Color.clear)
            .frame(width: 4, height: 4)
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if summary?.hasMoney == true { parts.append("money logged") }
        if summary?.hasActivity == true { parts.append("activity logged") }
        if summary?.hasNote == true { parts.append("note logged") }
        let base = DateFormatter.localizedString(from: day.date, dateStyle: .long, timeStyle: .none)
        return parts.isEmpty ? base : "\(base), \(parts.joined(separator: ", "))"
    }
}
