import Foundation

/// Secure-ish storage for OAuth tokens and API keys.
///
/// Uses a JSON file in Application Support instead of Keychain.
/// This avoids macOS Keychain authorization prompts that break with
/// ad-hoc ("Sign to Run Locally") code signing.
///
/// Same API as the original Keychain-based implementation — callers don't need to change.
///
/// TODO: Switch back to real Keychain when the app ships with a proper signing identity.
enum KeychainHelper {

    private static let storeName = "com.overwatch.app"

    /// Path: ~/Library/Application Support/com.overwatch.app/secure_store.json
    private static var storeURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(storeName, isDirectory: true)
        return dir.appendingPathComponent("secure_store.json")
    }

    // MARK: - Save

    /// Saves data for the given key. Overwrites if the key already exists.
    @discardableResult
    static func save(key: String, data: Data) -> Bool {
        var store = loadStore()
        store[key] = data.base64EncodedString()
        return writeStore(store)
    }

    /// Convenience: save a string value
    @discardableResult
    static func save(key: String, string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(key: key, data: data)
    }

    // MARK: - Read

    /// Reads raw data for the given key.
    static func read(key: String) -> Data? {
        let store = loadStore()
        guard let base64 = store[key] else { return nil }
        return Data(base64Encoded: base64)
    }

    /// Convenience: read a string value
    static func readString(key: String) -> String? {
        guard let data = read(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete

    /// Deletes the value for the given key.
    @discardableResult
    static func delete(key: String) -> Bool {
        var store = loadStore()
        store.removeValue(forKey: key)
        return writeStore(store)
    }

    // MARK: - Keys

    /// Well-known keys used across the app
    enum Keys {
        static let whoopAccessToken = "whoop_access_token"
        static let whoopRefreshToken = "whoop_refresh_token"
        static let whoopTokenExpiry = "whoop_token_expiry"
        static let whoopClientId = "whoop_client_id"
        static let whoopClientSecret = "whoop_client_secret"
        static let geminiAPIKey = "gemini_api_key"
    }

    // MARK: - Private

    private static func loadStore() -> [String: String] {
        guard let data = try? Data(contentsOf: storeURL),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }

    private static func writeStore(_ store: [String: String]) -> Bool {
        do {
            let dir = storeURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(store)
            try data.write(to: storeURL, options: .atomic)

            // Restrict file permissions to owner only (rw-------)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: storeURL.path
            )
            return true
        } catch {
            print("[SecureStore] Write FAILED: \(error.localizedDescription)")
            return false
        }
    }
}
