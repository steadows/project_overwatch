import Foundation

struct HabitCoefficient: Codable, Sendable, Identifiable, Equatable {
    var id: String { habitName }

    let habitName: String
    let habitEmoji: String
    let coefficient: Double
    let pValue: Double
    let completionRate: Double
    let direction: Direction

    enum Direction: String, Codable, Sendable {
        case positive
        case negative
        case neutral
    }
}
