import Foundation
import Testing
import SwiftData
@testable import Overwatch

/// Tests for WHOOP Codable structs and WhoopCycle cache model (Plan 2.2.3)

// MARK: - JSON Decoding

@Suite("WHOOP Codable Structs")
struct WhoopCodableTests {

    @Test
    func decodeRecoveryResponse() throws {
        let json = """
        {
            "records": [{
                "cycle_id": 12345,
                "sleep_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                "user_id": 1,
                "created_at": "2026-02-17T08:00:00.000Z",
                "updated_at": "2026-02-17T08:00:00.000Z",
                "score_state": "SCORED",
                "score": {
                    "user_calibrating": false,
                    "recovery_score": 87.0,
                    "resting_heart_rate": 52.0,
                    "hrv_rmssd_milli": 65.3,
                    "spo2_percentage": 97.5,
                    "skin_temp_celsius": 33.2
                }
            }],
            "next_token": null
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WhoopRecoveryResponse.self, from: json)
        #expect(response.records.count == 1)

        let record = response.records[0]
        #expect(record.cycleId == 12345)
        #expect(record.scoreState == "SCORED")
        #expect(record.score?.recoveryScore == 87.0)
        #expect(record.score?.hrvRmssdMilli == 65.3)
        #expect(record.score?.restingHeartRate == 52.0)
        #expect(record.score?.spo2Percentage == 97.5)
    }

    @Test
    func decodeSleepResponse() throws {
        let json = """
        {
            "records": [{
                "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
                "user_id": 1,
                "cycle_id": 12345,
                "created_at": "2026-02-17T06:00:00.000Z",
                "updated_at": "2026-02-17T06:00:00.000Z",
                "start": "2026-02-16T22:30:00.000Z",
                "end": "2026-02-17T06:00:00.000Z",
                "timezone_offset": "-06:00",
                "nap": false,
                "score_state": "SCORED",
                "score": {
                    "stage_summary": {
                        "total_in_bed_time_milli": 27000000,
                        "total_awake_time_milli": 3600000,
                        "total_no_data_time_milli": 0,
                        "total_light_sleep_time_milli": 10800000,
                        "total_slow_wave_sleep_time_milli": 5400000,
                        "total_rem_sleep_time_milli": 7200000,
                        "sleep_cycle_count": 5,
                        "disturbance_count": 2
                    },
                    "sleep_needed": {
                        "baseline_milli": 28800000,
                        "need_from_sleep_debt_milli": 0,
                        "need_from_recent_strain_milli": 1800000,
                        "need_from_recent_nap_milli": 0
                    },
                    "respiratory_rate": 15.2,
                    "sleep_performance_percentage": 85.0,
                    "sleep_consistency_percentage": 90.0,
                    "sleep_efficiency_percentage": 87.0
                }
            }],
            "next_token": null
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WhoopSleepResponse.self, from: json)
        #expect(response.records.count == 1)

        let record = response.records[0]
        #expect(record.nap == false)
        #expect(record.score?.sleepPerformancePercentage == 85.0)
        #expect(record.score?.stageSummary.totalSlowWaveSleepTimeMilli == 5400000)
        #expect(record.score?.stageSummary.totalRemSleepTimeMilli == 7200000)
        #expect(record.score?.stageSummary.sleepCycleCount == 5)
    }

    @Test
    func decodeStrainResponse() throws {
        let json = """
        {
            "records": [{
                "id": 99999,
                "user_id": 1,
                "created_at": "2026-02-17T00:00:00.000Z",
                "updated_at": "2026-02-17T18:00:00.000Z",
                "start": "2026-02-17T00:00:00.000Z",
                "end": "2026-02-17T23:59:59.000Z",
                "timezone_offset": "-06:00",
                "score_state": "SCORED",
                "score": {
                    "strain": 14.2,
                    "kilojoule": 8500.0,
                    "average_heart_rate": 72,
                    "max_heart_rate": 185
                }
            }],
            "next_token": "abc123"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WhoopStrainResponse.self, from: json)
        #expect(response.records.count == 1)
        #expect(response.nextToken == "abc123")

        let record = response.records[0]
        #expect(record.score?.strain == 14.2)
        #expect(record.score?.kilojoule == 8500.0)
        #expect(record.score?.averageHeartRate == 72)
        #expect(record.score?.maxHeartRate == 185)
    }
}

// MARK: - WhoopCycle Transforms

@Suite("WhoopCycle Transforms")
struct WhoopCycleTransformTests {

    @Test @MainActor
    func applyRecoveryTransform() throws {
        let cycle = WhoopCycle(cycleId: 1, date: .now)

        let json = """
        {
            "cycle_id": 1, "sleep_id": "sleep-uuid-002", "user_id": 1,
            "created_at": "2026-02-17T08:00:00.000Z",
            "updated_at": "2026-02-17T08:00:00.000Z",
            "score_state": "SCORED",
            "score": {
                "user_calibrating": false,
                "recovery_score": 91.0,
                "resting_heart_rate": 48.0,
                "hrv_rmssd_milli": 72.5,
                "spo2_percentage": 98.0,
                "skin_temp_celsius": null
            }
        }
        """.data(using: .utf8)!

        let record = try JSONDecoder().decode(WhoopRecoveryResponse.Record.self, from: json)
        cycle.applyRecovery(record)

        #expect(cycle.recoveryScore == 91.0)
        #expect(cycle.hrvRmssdMilli == 72.5)
        #expect(cycle.restingHeartRate == 48.0)
    }

    @Test @MainActor
    func applySleepTransform() throws {
        let cycle = WhoopCycle(cycleId: 1, date: .now)

        let json = """
        {
            "id": "sleep-uuid-002", "user_id": 1, "cycle_id": 1,
            "created_at": "2026-02-17T06:00:00.000Z",
            "updated_at": "2026-02-17T06:00:00.000Z",
            "start": "2026-02-16T22:00:00.000Z",
            "end": "2026-02-17T06:00:00.000Z",
            "timezone_offset": "-06:00",
            "nap": false,
            "score_state": "SCORED",
            "score": {
                "stage_summary": {
                    "total_in_bed_time_milli": 28800000,
                    "total_awake_time_milli": 1800000,
                    "total_no_data_time_milli": 0,
                    "total_light_sleep_time_milli": 12600000,
                    "total_slow_wave_sleep_time_milli": 7200000,
                    "total_rem_sleep_time_milli": 7200000,
                    "sleep_cycle_count": 5,
                    "disturbance_count": 1
                },
                "respiratory_rate": 14.5,
                "sleep_performance_percentage": 92.0,
                "sleep_consistency_percentage": 88.0,
                "sleep_efficiency_percentage": 94.0
            }
        }
        """.data(using: .utf8)!

        let record = try JSONDecoder().decode(WhoopSleepResponse.Record.self, from: json)
        cycle.applySleep(record)

        #expect(cycle.sleepPerformance == 92.0)
        #expect(cycle.sleepSWSMilli == 7200000)
        #expect(cycle.sleepREMMilli == 7200000)
    }

    @Test @MainActor
    func applyStrainTransform() throws {
        let cycle = WhoopCycle(cycleId: 1, date: .now)

        let json = """
        {
            "id": 99, "user_id": 1,
            "created_at": "2026-02-17T00:00:00.000Z",
            "updated_at": "2026-02-17T18:00:00.000Z",
            "start": "2026-02-17T00:00:00.000Z",
            "end": null,
            "timezone_offset": "-06:00",
            "score_state": "SCORED",
            "score": {
                "strain": 16.8,
                "kilojoule": 9200.0,
                "average_heart_rate": 75,
                "max_heart_rate": 190
            }
        }
        """.data(using: .utf8)!

        let record = try JSONDecoder().decode(WhoopStrainResponse.Record.self, from: json)
        cycle.applyStrain(record)

        #expect(cycle.strain == 16.8)
        #expect(cycle.kilojoules == 9200.0)
        #expect(cycle.averageHeartRate == 75)
        #expect(cycle.maxHeartRate == 190)
    }
}

// MARK: - WhoopCycle Deduplication

@Suite("WhoopCycle Deduplication")
struct WhoopCycleDeduplicationTests {

    @Test @MainActor
    func deduplicatesByCycleId() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WhoopCycle.self,
            configurations: config
        )
        let context = container.mainContext

        let cycle1 = WhoopCycle(cycleId: 42, date: .now, strain: 10.0)
        context.insert(cycle1)
        try context.save()

        // Insert a second cycle with same cycleId — should fail or replace
        let cycle2 = WhoopCycle(cycleId: 42, date: .now, strain: 15.0)
        context.insert(cycle2)

        // The #Unique constraint means the save should enforce uniqueness.
        // SwiftData handles this via upsert — the duplicate should be merged.
        try context.save()

        let all = try context.fetch(FetchDescriptor<WhoopCycle>())
        #expect(all.count == 1)
    }
}
