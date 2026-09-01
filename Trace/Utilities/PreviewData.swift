import Foundation
import SwiftData

/// In-memory sample data for SwiftUI previews only. Never used by the running
/// app — the real container in `TraceApp` is a separate on-disk store.
enum PreviewData {
    @MainActor static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: Entry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let calendar = Calendar.current
        let now = Date()
        func at(_ dayOffset: Int, _ hour: Int) -> Date {
            calendar.date(byAdding: .day, value: dayOffset,
                          to: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now) ?? now
        }
        let samples: [Entry] = [
            Entry(kind: .expense, title: "McDonald's", amount: 320, category: .food, date: at(0, 13)),
            Entry(kind: .expense, title: "Uber", amount: 100, category: .transport, date: at(0, 18)),
            Entry(kind: .activity, title: "Gym", durationSeconds: 3600, date: at(0, 8)),
            Entry(kind: .expense, title: "Coffee", amount: 90, category: .food, date: at(-1, 10)),
            Entry(kind: .activity, title: "Python", durationSeconds: 2700, date: at(-1, 21)),
            Entry(kind: .income, title: "Got paid", amount: 20000, date: at(-2, 12)),
            Entry(kind: .note, title: "Today was actually a really good day",
                  noteText: "Today was actually a really good day", date: at(-2, 22)),
            Entry(kind: .expense, title: "Netflix", amount: 165, category: .entertainment, date: at(-4, 20)),
        ]
        samples.forEach(container.mainContext.insert)
        return container
    }()

    @MainActor static let emptyContainer: ModelContainer = {
        try! ModelContainer(
            for: Entry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }()
}
