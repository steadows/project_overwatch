import Foundation
import SwiftData
import os

/// Orchestrates periodic WHOOP data sync: fetch → transform → persist.
///
/// Fetches recovery, sleep, and strain data from the WHOOP API, transforms
/// them into `WhoopCycle` SwiftData models, and deduplicates by `cycleId`.
///
/// Sync schedule: on launch + every 30 minutes while the app is running.
actor WhoopSyncManager {

    // MARK: - Configuration

    /// Minimum interval between syncs (30 minutes).
    private let syncInterval: TimeInterval = 30 * 60

    // MARK: - Dependencies

    private let client: WhoopClient
    private let modelContainer: ModelContainer
    private let logger: Logger

    /// Recurring sync task handle — cancelled on deinit or stopSync().
    private var syncTask: Task<Void, Never>?

    // MARK: - Init

    init(client: WhoopClient, modelContainer: ModelContainer) {
        self.client = client
        self.modelContainer = modelContainer
        self.logger = Logger(subsystem: "com.overwatch.app", category: "WhoopSync")
    }

    deinit {
        syncTask?.cancel()
    }

    // MARK: - Public API

    /// Start the recurring sync loop: sync immediately, then every 30 minutes.
    func startSync(onStatusChange: @escaping @Sendable (SyncUpdate) -> Void) {
        stopSync()

        syncTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let update = await self.performSync()
                onStatusChange(update)

                do {
                    try await Task.sleep(for: .seconds(self.syncInterval))
                } catch {
                    break // Task was cancelled
                }
            }
        }
    }

    /// Stop the recurring sync loop.
    func stopSync() {
        syncTask?.cancel()
        syncTask = nil
    }

    /// Perform a single sync cycle. Returns the result for status reporting.
    func performSync() async -> SyncUpdate {
        logger.info("Starting WHOOP sync")

        do {
            // Fetch all three endpoints. Run in parallel for speed.
            async let recoveryResult = client.fetchRecovery()
            async let sleepResult = client.fetchSleep()
            async let strainResult = client.fetchStrain()

            let (recovery, sleep, strain) = try await (recoveryResult, sleepResult, strainResult)

            // Transform and persist
            let count = try await persistData(recovery: recovery, sleep: sleep, strain: strain)

            logger.info("WHOOP sync complete — \(count) cycles updated")
            return .synced(Date(), cyclesUpdated: count)
        } catch {
            logger.error("WHOOP sync failed: \(error.localizedDescription)")
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Persistence

    /// Transform API responses into WhoopCycle models and save to SwiftData.
    /// Deduplicates by cycleId — existing cycles are updated, new ones are inserted.
    @MainActor
    private func persistData(
        recovery: WhoopRecoveryResponse,
        sleep: WhoopSleepResponse,
        strain: WhoopStrainResponse
    ) throws -> Int {
        let context = modelContainer.mainContext
        var updatedCount = 0

        // Process strain records first — they define the cycle
        for record in strain.records {
            let cycle = try findOrCreateCycle(cycleId: record.id, in: context)
            cycle.applyStrain(record)

            // Parse the cycle start date for the date field
            if let date = DateFormatters.iso8601.date(from: record.start) {
                cycle.date = date
            }

            cycle.fetchedAt = .now
            updatedCount += 1
        }

        // Overlay recovery data onto matching cycles
        for record in recovery.records {
            let cycle = try findOrCreateCycle(cycleId: record.cycleId, in: context)
            cycle.applyRecovery(record)
            cycle.fetchedAt = .now
        }

        // Overlay sleep data — match by finding the cycle whose date range contains the sleep end
        for record in sleep.records where !record.nap {
            // Sleep records don't have a cycleId directly, so we find the cycle
            // by matching the sleep end date to cycles. For simplicity, apply to
            // the most recent cycle if we can't match exactly.
            if let sleepEnd = DateFormatters.iso8601.date(from: record.end) {
                let calendar = Calendar.current
                let dayStart = calendar.startOfDay(for: sleepEnd)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

                let predicate = #Predicate<WhoopCycle> { cycle in
                    cycle.date >= dayStart && cycle.date < dayEnd
                }
                let descriptor = FetchDescriptor<WhoopCycle>(predicate: predicate)

                if let matchingCycle = try context.fetch(descriptor).first {
                    matchingCycle.applySleep(record)
                    matchingCycle.fetchedAt = .now
                }
            }
        }

        try context.save()
        return updatedCount
    }

    /// Find an existing WhoopCycle by cycleId, or create a new one.
    @MainActor
    private func findOrCreateCycle(cycleId: Int, in context: ModelContext) throws -> WhoopCycle {
        let predicate = #Predicate<WhoopCycle> { cycle in
            cycle.cycleId == cycleId
        }
        let descriptor = FetchDescriptor<WhoopCycle>(predicate: predicate)

        if let existing = try context.fetch(descriptor).first {
            return existing
        }

        let newCycle = WhoopCycle(cycleId: cycleId, date: .now)
        context.insert(newCycle)
        return newCycle
    }
}

// MARK: - Sync Update

extension WhoopSyncManager {
    /// Represents the outcome of a sync operation, used to update AppState.
    enum SyncUpdate: Sendable {
        case syncing
        case synced(Date, cyclesUpdated: Int)
        case error(String)
    }
}
