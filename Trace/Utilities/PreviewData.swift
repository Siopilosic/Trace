import Foundation
import SwiftData

/// In-memory sample data for SwiftUI previews only. Never used by the running
/// app — the real container in `TraceApp` is a separate on-disk store.
enum PreviewData {
    @MainActor static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: Entry.self, Goal.self, JournalEntry.self, LiveNote.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let calendar = Calendar.current
        let now = Date()
        func at(_ dayOffset: Int, _ hour: Int) -> Date {
            calendar.date(byAdding: .day, value: dayOffset,
                          to: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now) ?? now
        }
        let samples: [Entry] = [
            // This week
            Entry(kind: .expense, title: "McDonald's", amount: 320, category: .food, date: at(0, 13)),
            Entry(kind: .expense, title: "Uber", amount: 100, category: .transport, date: at(0, 18)),
            Entry(kind: .activity, title: "Gym", durationSeconds: 3600, date: at(0, 8)),
            Entry(kind: .expense, title: "Coffee", amount: 90, category: .food, date: at(-1, 10)),
            Entry(kind: .activity, title: "Python", durationSeconds: 2700, date: at(-1, 21)),
            Entry(kind: .income, title: "Got paid", amount: 20000, date: at(-2, 12)),
            Entry(kind: .note, title: "Today was actually a really good day",
                  noteText: "Today was actually a really good day", date: at(-2, 22)),
            Entry(kind: .expense, title: "Netflix", amount: 165, category: .entertainment, date: at(-4, 20)),

            // Earlier this month — repeated activity titles for breakdown, a
            // spread of categories for the chart.
            Entry(kind: .activity, title: "Python", durationSeconds: 3600, date: at(-8, 20)),
            Entry(kind: .activity, title: "Gym", durationSeconds: 2700, date: at(-9, 8)),
            Entry(kind: .expense, title: "Groceries", amount: 540, category: .food, date: at(-10, 17)),
            Entry(kind: .activity, title: "Python", durationSeconds: 1800, date: at(-12, 19)),
            Entry(kind: .expense, title: "Pharmacy", amount: 210, category: .health, date: at(-14, 11)),

            // Last month — enough for period-over-period comparison.
            Entry(kind: .expense, title: "Rent", amount: 4500, category: .bills, date: at(-33, 9)),
            Entry(kind: .expense, title: "Zara", amount: 980, category: .shopping, date: at(-36, 16)),
            Entry(kind: .income, title: "Got paid", amount: 18000, date: at(-40, 12)),
            Entry(kind: .activity, title: "Gym", durationSeconds: 5400, date: at(-38, 8)),
        ]
        samples.forEach(container.mainContext.insert)

        let goals: [Goal] = [
            Goal(metric: .spendingLimit, targetValue: 10000),
            Goal(metric: .activityTime, targetValue: 36000, activityName: "Python"), // 10h
        ]
        goals.forEach(container.mainContext.insert)

        // Two dates with multiple entries and one lone older entry, so the
        // Journal preview exercises both same-day ordering and day-grouping.
        let journalEntries: [JournalEntry] = [
            JournalEntry(text: "Today was actually a really good day. I got a lot done and finally started using Trace properly.", createdAt: at(0, 21)),
            JournalEntry(text: "Went out today and talked for hours. It was honestly great.", createdAt: at(0, 15)),
            JournalEntry(text: "Started working on the new Trace design.", createdAt: at(-1, 23)),
            JournalEntry(text: "Quiet day. Read a bit, didn't do much else — and that was fine.", createdAt: at(-5, 20)),
        ]
        journalEntries.forEach(container.mainContext.insert)

        let liveNotes: [LiveNote] = [
            LiveNote(text: "Buy groceries after class", createdAt: at(0, 12)),
            LiveNote(text: "Ask Sara about the trip dates", createdAt: at(-1, 9)),
        ]
        liveNotes[1].archivedAt = at(-1, 20)
        liveNotes.forEach(container.mainContext.insert)

        return container
    }()

    @MainActor static let emptyContainer: ModelContainer = {
        try! ModelContainer(
            for: Entry.self, Goal.self, JournalEntry.self, LiveNote.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }()
}
