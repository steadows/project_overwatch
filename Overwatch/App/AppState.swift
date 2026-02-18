import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppState {
    // WHOOP sync status
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case synced(Date)
        case error(String)
    }

    var whoopSyncStatus: SyncStatus = .idle
    var isOnboarded: Bool = false

    // MARK: - Services

    private var syncManager: WhoopSyncManager?

    // MARK: - WHOOP Sync

    /// Initialize and start WHOOP sync with the given model container.
    /// Call this from the app's root view once the container is available.
    func startWhoopSync(modelContainer: ModelContainer) {
        let authManager = WhoopAuthManager()
        let client = WhoopClient(authProvider: authManager)
        let sync = WhoopSyncManager(client: client, modelContainer: modelContainer)
        self.syncManager = sync

        whoopSyncStatus = .syncing

        Task {
            await sync.startSync { [weak self] update in
                Task { @MainActor in
                    guard let self else { return }
                    switch update {
                    case .syncing:
                        self.whoopSyncStatus = .syncing
                    case .synced(let date, _):
                        self.whoopSyncStatus = .synced(date)
                    case .error(let message):
                        self.whoopSyncStatus = .error(message)
                    }
                }
            }
        }
    }

    /// Stop WHOOP sync (e.g., on logout).
    func stopWhoopSync() {
        Task {
            await syncManager?.stopSync()
        }
        syncManager = nil
        whoopSyncStatus = .idle
    }
}
