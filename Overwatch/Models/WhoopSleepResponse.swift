import Foundation

struct WhoopSleepResponse: Codable, Sendable {
    let records: [Record]
    let nextToken: String?

    struct Record: Codable, Sendable {
        let id: Int
        let userId: Int
        let createdAt: String
        let updatedAt: String
        let start: String
        let end: String
        let timezoneOffset: String?
        let nap: Bool
        let scoreState: String
        let score: Score?

        struct Score: Codable, Sendable {
            let stageSummary: StageSummary
            let sleepNeeded: SleepNeeded?
            let respiratoryRate: Double?
            let sleepPerformancePercentage: Double?
            let sleepConsistencyPercentage: Double?
            let sleepEfficiencyPercentage: Double?

            struct StageSummary: Codable, Sendable {
                let totalInBedTimeMilli: Int
                let totalAwakeTimeMilli: Int
                let totalNoDataTimeMilli: Int
                let totalLightSleepTimeMilli: Int
                let totalSlowWaveSleepTimeMilli: Int
                let totalRemSleepTimeMilli: Int
                let sleepCycleCount: Int
                let disturbanceCount: Int

                enum CodingKeys: String, CodingKey {
                    case totalInBedTimeMilli = "total_in_bed_time_milli"
                    case totalAwakeTimeMilli = "total_awake_time_milli"
                    case totalNoDataTimeMilli = "total_no_data_time_milli"
                    case totalLightSleepTimeMilli = "total_light_sleep_time_milli"
                    case totalSlowWaveSleepTimeMilli = "total_slow_wave_sleep_time_milli"
                    case totalRemSleepTimeMilli = "total_rem_sleep_time_milli"
                    case sleepCycleCount = "sleep_cycle_count"
                    case disturbanceCount = "disturbance_count"
                }
            }

            struct SleepNeeded: Codable, Sendable {
                let baselineMilli: Int
                let needFromSleepDebtMilli: Int
                let needFromRecentStrainMilli: Int
                let needFromRecentNapMilli: Int

                enum CodingKeys: String, CodingKey {
                    case baselineMilli = "baseline_milli"
                    case needFromSleepDebtMilli = "need_from_sleep_debt_milli"
                    case needFromRecentStrainMilli = "need_from_recent_strain_milli"
                    case needFromRecentNapMilli = "need_from_recent_nap_milli"
                }
            }

            enum CodingKeys: String, CodingKey {
                case stageSummary = "stage_summary"
                case sleepNeeded = "sleep_needed"
                case respiratoryRate = "respiratory_rate"
                case sleepPerformancePercentage = "sleep_performance_percentage"
                case sleepConsistencyPercentage = "sleep_consistency_percentage"
                case sleepEfficiencyPercentage = "sleep_efficiency_percentage"
            }
        }

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case start, end
            case timezoneOffset = "timezone_offset"
            case nap
            case scoreState = "score_state"
            case score
        }
    }

    enum CodingKeys: String, CodingKey {
        case records
        case nextToken = "next_token"
    }
}
