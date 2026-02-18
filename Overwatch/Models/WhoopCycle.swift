import Foundation
import SwiftData

@Model
final class WhoopCycle {
    #Unique<WhoopCycle>([\.cycleId])

    var id: UUID
    var cycleId: Int
    var date: Date

    // Strain
    var strain: Double
    var kilojoules: Double
    var averageHeartRate: Int
    var maxHeartRate: Int

    // Recovery
    var recoveryScore: Double
    var hrvRmssdMilli: Double
    var restingHeartRate: Double

    // Sleep
    var sleepPerformance: Double
    var sleepSWSMilli: Int
    var sleepREMMilli: Int

    var fetchedAt: Date

    init(
        id: UUID = UUID(),
        cycleId: Int,
        date: Date,
        strain: Double = 0,
        kilojoules: Double = 0,
        averageHeartRate: Int = 0,
        maxHeartRate: Int = 0,
        recoveryScore: Double = 0,
        hrvRmssdMilli: Double = 0,
        restingHeartRate: Double = 0,
        sleepPerformance: Double = 0,
        sleepSWSMilli: Int = 0,
        sleepREMMilli: Int = 0,
        fetchedAt: Date = .now
    ) {
        self.id = id
        self.cycleId = cycleId
        self.date = date
        self.strain = strain
        self.kilojoules = kilojoules
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.recoveryScore = recoveryScore
        self.hrvRmssdMilli = hrvRmssdMilli
        self.restingHeartRate = restingHeartRate
        self.sleepPerformance = sleepPerformance
        self.sleepSWSMilli = sleepSWSMilli
        self.sleepREMMilli = sleepREMMilli
        self.fetchedAt = fetchedAt
    }

    // MARK: - Transforms

    /// Applies recovery data from a WHOOP API recovery record
    func applyRecovery(_ record: WhoopRecoveryResponse.Record) {
        guard let score = record.score else { return }
        self.recoveryScore = score.recoveryScore
        self.hrvRmssdMilli = score.hrvRmssdMilli
        self.restingHeartRate = score.restingHeartRate
    }

    /// Applies sleep data from a WHOOP API sleep record
    func applySleep(_ record: WhoopSleepResponse.Record) {
        guard let score = record.score else { return }
        self.sleepPerformance = score.sleepPerformancePercentage ?? 0
        self.sleepSWSMilli = score.stageSummary.totalSlowWaveSleepTimeMilli
        self.sleepREMMilli = score.stageSummary.totalRemSleepTimeMilli
    }

    /// Applies strain data from a WHOOP API cycle record
    func applyStrain(_ record: WhoopStrainResponse.Record) {
        guard let score = record.score else { return }
        self.strain = score.strain
        self.kilojoules = score.kilojoule
        self.averageHeartRate = score.averageHeartRate
        self.maxHeartRate = score.maxHeartRate
    }
}
