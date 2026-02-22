import Foundation
import Security

/// Lightweight Keychain wrapper for storing OAuth tokens and API keys securely.
/// Uses kSecClassGenericPassword items with a service prefix for namespacing.
enum KeychainHelper {

    private static let service = "com.overwatch.app"

    // MARK: - Save

    /// Saves data to the Keychain. Overwrites if the key already exists.
    @discardableResult
    static func save(key: String, data: Data) -> Bool {
        // Delete any existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecUseDataProtectionKeychain as String: true,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Convenience: save a string value
    @discardableResult
    static func save(key: String, string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(key: key, data: data)
    }

    // MARK: - Read

    /// Reads raw data from the Keychain for the given key.
    static func read(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Convenience: read a string value
    static func readString(key: String) -> String? {
        guard let data = read(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete

    /// Deletes the item for the given key from the Keychain.
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true,
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Keys

    /// Well-known Keychain keys used across the app
    enum Keys {
        static let whoopAccessToken = "whoop_access_token"
        static let whoopRefreshToken = "whoop_refresh_token"
        static let whoopTokenExpiry = "whoop_token_expiry"
        static let whoopClientId = "whoop_client_id"
        static let whoopClientSecret = "whoop_client_secret"
        static let geminiAPIKey = "gemini_api_key"
    }
}
