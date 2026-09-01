import Foundation

/// Minimal shape the statistics engine needs from an entry.
///
/// Both the SwiftData `Entry` model and lightweight test fixtures conform to
/// this, keeping `StatisticsEngine` free of any persistence dependency.
protocol StatEntry {
    var kind: EntryKind { get }
    var amount: Double? { get }
    var durationSeconds: Double? { get }
    var category: ExpenseCategory? { get }
    var date: Date { get }
}
