import Foundation

/// Centralized SF Symbol icon catalog for habits.
/// Maps habit names/categories to SF Symbol names for the tactical HUD aesthetic.
enum HabitIcons {
    static let catalog: [String: String] = [
        "meditation": "brain.head.profile",
        "exercise": "figure.run",
        "water": "drop",
        "sleep": "moon.zzz",
        "reading": "book",
        "nutrition": "fork.knife",
        "supplements": "pill",
        "journaling": "pencil.line",
        "stretching": "figure.flexibility",
        "walking": "figure.walk",
        "alcohol": "wineglass",
        "breathing": "wind",
        "cold exposure": "snowflake",
        "strength": "dumbbell",
        "yoga": "figure.yoga",
        "cardio": "figure.run",
        "hydration": "drop",
        "vitamins": "pill",
        "morning routine": "sunrise",
        "evening routine": "moon",
        "deep work": "brain",
        "focus": "scope",
        "gratitude": "heart",
        "prayer": "hands.sparkles",
        "fasting": "clock",
        "sauna": "flame",
        "skincare": "face.smiling",
        "no caffeine": "cup.and.saucer",
        "caffeine": "cup.and.saucer",
        "no sugar": "xmark.circle",
        "protein": "fork.knife",
        "steps": "figure.walk",
        "run": "figure.run",
        "swim": "figure.pool.swim",
        "bike": "bicycle",
        "hike": "figure.hiking",
        "climb": "figure.climbing",
        "gym": "dumbbell",
        "martial arts": "figure.martial.arts",
        "dance": "figure.dance",
        "flossing": "mouth",
        "posture": "figure.stand",
        "screen time": "iphone",
        "no phone": "iphone.slash",
        "social": "person.2",
        "clean": "sparkles",
        "cook": "frying.pan",
        "music": "music.note",
        "creative": "paintbrush",
        "writing": "pencil.line",
        "learn": "graduationcap",
        "study": "book",
        "therapy": "brain.head.profile",
    ]

    /// Resolves an SF Symbol name from a habit name or category.
    /// Uses fuzzy matching (lowercased substring containment) with fallback to default.
    static func icon(for name: String, category: String = "") -> String {
        let lowName = name.lowercased()
        let lowCat = category.lowercased()

        // Exact match on name
        if let exact = catalog[lowName] {
            return exact
        }

        // Substring match on name
        for (key, symbol) in catalog {
            if lowName.contains(key) || key.contains(lowName) {
                return symbol
            }
        }

        // Try category
        if !lowCat.isEmpty {
            if let catMatch = catalog[lowCat] {
                return catMatch
            }
            for (key, symbol) in catalog {
                if lowCat.contains(key) || key.contains(lowCat) {
                    return symbol
                }
            }
        }

        return "circle.fill"
    }
}
