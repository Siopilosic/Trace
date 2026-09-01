import Foundation

/// Infers a money category from a free-text description using simple,
/// deterministic keyword matching. Returns `nil` when nothing matches so the
/// caller can leave the entry uncategorised rather than guessing.
///
/// Keep this list easy to grow — order matters only in that longer, more
/// specific phrases are checked before shorter ones.
struct CategoryInferencer {

    /// `(keyword, category)` pairs, checked in order. Longer phrases first.
    static let keywords: [(String, ExpenseCategory)] = [
        // Bills (specific multi-word phrases first)
        ("gym membership", .bills),
        ("phone bill", .bills),
        ("electricity", .bills), ("internet", .bills), ("wifi", .bills),
        ("rent", .bills), ("water bill", .bills), ("subscription", .bills),
        ("vodafone", .bills), ("orange", .bills), ("etisalat", .bills),
        ("insurance", .bills), ("utilities", .bills),

        // Transport
        ("uber", .transport), ("careem", .transport), ("didi", .transport),
        ("bolt", .transport), ("swvl", .transport), ("taxi", .transport),
        ("metro", .transport), ("tram", .transport), ("train", .transport),
        ("bus", .transport), ("flight", .transport), ("petrol", .transport),
        ("gasoline", .transport), ("fuel", .transport), ("parking", .transport),
        ("gas station", .transport),

        // Food
        ("mcdonald", .food), ("kfc", .food), ("burger king", .food),
        ("pizza", .food), ("starbucks", .food), ("costa", .food),
        ("cilantro", .food), ("restaurant", .food), ("cafe", .food),
        ("coffee", .food), ("lunch", .food), ("dinner", .food),
        ("breakfast", .food), ("brunch", .food), ("groceries", .food),
        ("grocery", .food), ("supermarket", .food), ("carrefour", .food),
        ("seoudi", .food), ("gourmet", .food), ("bakery", .food),
        ("snack", .food), ("shawarma", .food), ("koshari", .food),
        ("food", .food), ("meal", .food),

        // Entertainment
        ("netflix", .entertainment), ("spotify", .entertainment),
        ("youtube premium", .entertainment), ("disney", .entertainment),
        ("cinema", .entertainment), ("movie", .entertainment),
        ("concert", .entertainment), ("steam", .entertainment),
        ("playstation", .entertainment), ("xbox", .entertainment),
        ("game", .entertainment), ("theatre", .entertainment),

        // Health
        ("pharmacy", .health), ("doctor", .health), ("dentist", .health),
        ("hospital", .health), ("clinic", .health), ("medicine", .health),
        ("therapy", .health), ("gym", .health), ("supplements", .health),

        // Shopping
        ("amazon", .shopping), ("noon", .shopping), ("zara", .shopping),
        ("h&m", .shopping), ("ikea", .shopping), ("clothes", .shopping),
        ("shoes", .shopping), ("mall", .shopping), ("shopping", .shopping),
    ]

    func category(for text: String) -> ExpenseCategory? {
        let haystack = text.lowercased()
        for (keyword, category) in Self.keywords where haystack.contains(keyword) {
            return category
        }
        return nil
    }
}
