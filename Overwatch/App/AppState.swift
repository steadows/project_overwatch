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
    /// Safe to call multiple times — subsequent calls are no-ops unless sync is stopped first.
    func startWhoopSync(modelContainer: ModelContainer) {
        // Guard against double-start
        guard syncManager == nil else { return }

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
                    case .sessionExpired:
                        self.handleSessionExpired()
                    }
                }
            }
        }
    }

    /// Session expired — stop sync but preserve tokens so the user can retry.
    private func handleSessionExpired() {
        syncManager = nil
        whoopSyncStatus = .error("SESSION EXPIRED — Reconnect WHOOP")
    }

    /// Stop WHOOP sync (e.g., on logout).
    func stopWhoopSync() {
        Task {
            await syncManager?.stopSync()
        }
        syncManager = nil
        whoopSyncStatus = .idle
    }

    /// Check if sync died (session expired, error) and restart it if tokens still exist.
    /// Called from NavigationShell when the app becomes active or the user navigates.
    /// No-op if sync is already running or no tokens are available.
    func ensureSyncRunning(modelContainer: ModelContainer) {
        // Sync is already alive — nothing to do
        guard syncManager == nil else { return }
        // No tokens — can't sync
        guard KeychainHelper.readString(key: KeychainHelper.Keys.whoopAccessToken) != nil else { return }
        // Tokens exist but sync died — restart it
        startWhoopSync(modelContainer: modelContainer)
    }

    /// Stop the current sync and start a fresh one (e.g., after re-linking in Settings).
    /// Properly awaits the old sync stopping before starting a new one.
    /// - Parameter authProvider: Pass the auth manager from a fresh OAuth flow to reuse its
    ///   in-memory tokens. If nil, creates a new auth manager (reads from Keychain).
    func restartWhoopSync(modelContainer: ModelContainer, authProvider: WhoopAuthProviding? = nil) {
        let oldManager = syncManager
        syncManager = nil
        whoopSyncStatus = .syncing

        Task {
            // Actually stop the old sync loop before starting a new one
            await oldManager?.stopSync()

            let auth: WhoopAuthProviding = authProvider ?? WhoopAuthManager()
            let client = WhoopClient(authProvider: auth)
            let sync = WhoopSyncManager(client: client, modelContainer: modelContainer)

            await MainActor.run {
                self.syncManager = sync
            }

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
                    case .sessionExpired:
                        self.handleSessionExpired()
                    }
                }
            }
        }
    }
}
