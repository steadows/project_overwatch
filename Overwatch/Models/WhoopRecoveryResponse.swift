import Foundation

struct WhoopRecoveryResponse: Codable, Sendable {
    let records: [Record]
    let nextToken: String?

    struct Record: Codable, Sendable {
        let cycleId: Int
        let sleepId: Int
        let userId: Int
        let createdAt: String
        let updatedAt: String
        let scoreState: String
        let score: Score?

        struct Score: Codable, Sendable {
            let userCalibrating: Bool
            let recoveryScore: Double
            let restingHeartRate: Double
            let hrvRmssdMilli: Double
            let spo2Percentage: Double?
            let skinTempCelsius: Double?

            enum CodingKeys: String, CodingKey {
                case userCalibrating = "user_calibrating"
                case recoveryScore = "recovery_score"
                case restingHeartRate = "resting_heart_rate"
                case hrvRmssdMilli = "hrv_rmssd_milli"
                case spo2Percentage = "spo2_percentage"
                case skinTempCelsius = "skin_temp_celsius"
            }
        }

        enum CodingKeys: String, CodingKey {
            case cycleId = "cycle_id"
            case sleepId = "sleep_id"
            case userId = "user_id"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case scoreState = "score_state"
            case score
        }
    }

    enum CodingKeys: String, CodingKey {
        case records
        case nextToken = "next_token"
    }
}
