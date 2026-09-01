import Foundation

/// Money categories. Never required at entry time — inferred from the
/// description and always editable later.
enum ExpenseCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case food
    case transport
    case shopping
    case entertainment
    case bills
    case health
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food: return "Food"
        case .transport: return "Transport"
        case .shopping: return "Shopping"
        case .entertainment: return "Entertainment"
        case .bills: return "Bills"
        case .health: return "Health"
        case .other: return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .shopping: return "bag.fill"
        case .entertainment: return "play.circle.fill"
        case .bills: return "doc.text.fill"
        case .health: return "heart.fill"
        case .other: return "circle.grid.2x2.fill"
        }
    }
}
