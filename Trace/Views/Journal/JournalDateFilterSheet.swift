import SwiftUI

/// Compact native sheet for choosing a ``JournalDateFilter`` — All / Day /
/// Month / Range. Applies live: every change writes straight back to the
/// bound filter so the timeline updates behind the sheet. No "Apply" step,
/// just "Done" to dismiss.
struct JournalDateFilterSheet: View {
    @Binding var filter: JournalDateFilter
    let calendar: Calendar

    @Environment(\.dismiss) private var dismiss

    private enum Mode: Int, CaseIterable, Identifiable {
        case all, day, month, range
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .all: return "All"
            case .day: return "Day"
            case .month: return "Month"
            case .range: return "Range"
            }
        }
    }

    @State private var mode: Mode = .all
    @State private var day = Date()
    @State private var monthIndex = 1
    @State private var year = 2025
    @State private var rangeStart = Date()
    @State private var rangeEnd = Date()

    private var years: [Int] {
        let current = calendar.component(.year, from: Date())
        return Array(((current - 20)...(current + 1)).reversed())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Filter by date", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } footer: {
                    Text(filter.label(calendar: calendar) ?? "Showing entries from every date.")
                }

                switch mode {
                case .all:
                    EmptyView()
                case .day:
                    Section {
                        DatePicker("Day", selection: $day, displayedComponents: [.date])
                    }
                case .month:
                    Section {
                        Picker("Month", selection: $monthIndex) {
                            ForEach(1...12, id: \.self) { Text(calendar.monthSymbols[$0 - 1]).tag($0) }
                        }
                        Picker("Year", selection: $year) {
                            ForEach(years, id: \.self) { Text(verbatim: "\($0)").tag($0) }
                        }
                    }
                case .range:
                    Section {
                        DatePicker("From", selection: $rangeStart, displayedComponents: [.date])
                        DatePicker("To", selection: $rangeEnd, in: rangeStart..., displayedComponents: [.date])
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .traceBackground()
            .navigationTitle("Filter by Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: loadFromFilter)
            .onChange(of: mode) { _, _ in apply() }
            .onChange(of: day) { _, _ in apply() }
            .onChange(of: monthIndex) { _, _ in apply() }
            .onChange(of: year) { _, _ in apply() }
            .onChange(of: rangeStart) { _, _ in apply() }
            .onChange(of: rangeEnd) { _, _ in apply() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func loadFromFilter() {
        let now = Date()
        year = calendar.component(.year, from: now)
        monthIndex = calendar.component(.month, from: now)

        switch filter {
        case .all:
            mode = .all
        case .day(let value):
            mode = .day
            day = value
        case .month(let anchor):
            mode = .month
            year = calendar.component(.year, from: anchor)
            monthIndex = calendar.component(.month, from: anchor)
        case .range(let from, let to):
            mode = .range
            rangeStart = min(from, to)
            rangeEnd = max(from, to)
        }
    }

    private func apply() {
        switch mode {
        case .all:
            filter = .all
        case .day:
            filter = .day(calendar.startOfDay(for: day))
        case .month:
            let anchor = calendar.date(from: DateComponents(year: year, month: monthIndex, day: 1)) ?? Date()
            filter = .month(anchor)
        case .range:
            let lo = min(rangeStart, rangeEnd)
            let hi = max(rangeStart, rangeEnd)
            filter = .range(from: calendar.startOfDay(for: lo), to: calendar.startOfDay(for: hi))
        }
    }
}

#Preview {
    JournalDateFilterSheet(filter: .constant(.month(Date())), calendar: .current)
}
