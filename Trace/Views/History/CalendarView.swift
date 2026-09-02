import SwiftUI

/// Calendar lens on History — a month grid with subtle per-day indicators,
/// the tapped day's entries revealed inline below using the same `EntryRow`
/// History's list uses. Editing/deleting still goes through the existing
/// `EntryDetailView` — there's no separate calendar-specific detail screen.
struct CalendarView: View {
    let entries: [Entry]
    let calendar: Calendar

    @State private var displayedMonth: Date
    @State private var selectedDay: Date?

    init(entries: [Entry], calendar: Calendar) {
        self.entries = entries
        self.calendar = calendar
        let today = calendar.startOfDay(for: Date())
        _displayedMonth = State(initialValue: calendar.dateInterval(of: .month, for: today)?.start ?? today)
        _selectedDay = State(initialValue: today)
    }

    private var summaries: [Date: DaySummary] {
        CalendarMonthSummary.summaries(for: entries, calendar: calendar)
    }

    private var gridDays: [CalendarGridDay] {
        CalendarMonthSummary.gridDays(for: displayedMonth, calendar: calendar)
    }

    private var weekdaySymbols: [String] {
        CalendarMonthSummary.weekdaySymbols(calendar: calendar)
    }

    private var isCurrentMonthDisplayed: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private var selectedDayEntries: [Entry] {
        guard let selectedDay else { return [] }
        return entries
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDay) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                monthHeader
                VStack(spacing: Theme.Space.s) {
                    weekdayHeader
                    grid
                }
                dayDetail
            }
            .traceScreenPadding()
            .padding(.top, Theme.Space.m)
            .padding(.bottom, Theme.Space.xxl)
        }
    }

    // MARK: Header

    private var monthHeader: some View {
        HStack(spacing: Theme.Space.m) {
            Text(monthTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            if !isCurrentMonthDisplayed {
                Button("Today") { jumpToToday() }
                    .font(.subheadline)
                    .foregroundStyle(Color.traceAccent)
            }

            HStack(spacing: Theme.Space.m) {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Previous month")

                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Next month")
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        return formatter.string(from: displayedMonth)
    }

    // MARK: Grid

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: Theme.Space.s) {
            ForEach(gridDays) { day in
                Button {
                    Haptics.selection()
                    selectedDay = day.date
                } label: {
                    CalendarDayCell(
                        day: day,
                        calendar: calendar,
                        summary: summaries[calendar.startOfDay(for: day.date)],
                        isSelected: selectedDay.map { calendar.isDate($0, inSameDayAs: day.date) } ?? false,
                        isToday: calendar.isDateInToday(day.date)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Day detail

    @ViewBuilder
    private var dayDetail: some View {
        if let selectedDay {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(Format.relativeDay(selectedDay, calendar: calendar))
                    .traceSectionLabelStyle()
                    .padding(.bottom, Theme.Space.xs)

                if selectedDayEntries.isEmpty {
                    Text("Nothing logged this day.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(selectedDayEntries.enumerated()), id: \.element.id) { index, entry in
                        NavigationLink {
                            EntryDetailView(entry: entry)
                        } label: {
                            EntryRow(entry: entry, showsTime: true)
                        }
                        .buttonStyle(.plain)
                        if index < selectedDayEntries.count - 1 {
                            Divider().overlay(Color.traceSeparator.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    // MARK: Navigation

    private func changeMonth(by delta: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        Haptics.selection()
        displayedMonth = newMonth
        selectedDay = nil
    }

    private func jumpToToday() {
        Haptics.tap()
        let today = calendar.startOfDay(for: Date())
        displayedMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        selectedDay = today
    }
}
