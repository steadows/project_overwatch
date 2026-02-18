import Foundation

struct WhoopStrainResponse: Codable, Sendable {
    let records: [Record]
    let nextToken: String?

    struct Record: Codable, Sendable {
        let id: Int
        let userId: Int
        let createdAt: String
        let updatedAt: String
        let start: String
        let end: String?
        let timezoneOffset: String?
        let scoreState: String
        let score: Score?

        struct Score: Codable, Sendable {
            let strain: Double
            let kilojoule: Double
            let averageHeartRate: Int
            let maxHeartRate: Int

            enum CodingKeys: String, CodingKey {
                case strain, kilojoule
                case averageHeartRate = "average_heart_rate"
                case maxHeartRate = "max_heart_rate"
            }
        }

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case start, end
            case timezoneOffset = "timezone_offset"
            case scoreState = "score_state"
            case score
        }
    }

    enum CodingKeys: String, CodingKey {
        case records
        case nextToken = "next_token"
    }
}
