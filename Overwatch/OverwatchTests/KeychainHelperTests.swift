import Testing
import Foundation
@testable import Overwatch

/// Tests for KeychainHelper (JSON file-backed secure store)

@Suite("KeychainHelper")
struct KeychainHelperTests {

    // Use unique keys per test to avoid cross-contamination
    private static let testPrefix = "test_keychain_\(UUID().uuidString.prefix(8))_"

    private func testKey(_ suffix: String) -> String {
        Self.testPrefix + suffix
    }

    // MARK: - Save & Read

    @Test
    func saveAndReadString() {
        let key = testKey("string")
        defer { KeychainHelper.delete(key: key) }

        let saved = KeychainHelper.save(key: key, string: "hello_world")
        #expect(saved == true)

        let retrieved = KeychainHelper.readString(key: key)
        #expect(retrieved == "hello_world")
    }

    @Test
    func saveAndReadData() {
        let key = testKey("data")
        defer { KeychainHelper.delete(key: key) }

        let originalData = Data([0x01, 0x02, 0x03, 0xFF])
        let saved = KeychainHelper.save(key: key, data: originalData)
        #expect(saved == true)

        let retrieved = KeychainHelper.read(key: key)
        #expect(retrieved == originalData)
    }

    @Test
    func overwriteExistingValue() {
        let key = testKey("overwrite")
        defer { KeychainHelper.delete(key: key) }

        KeychainHelper.save(key: key, string: "first")
        KeychainHelper.save(key: key, string: "second")

        let retrieved = KeychainHelper.readString(key: key)
        #expect(retrieved == "second")
    }

    // MARK: - Read Non-Existent

    @Test
    func readNonExistentKeyReturnsNil() {
        let result = KeychainHelper.readString(key: testKey("does_not_exist"))
        #expect(result == nil)
    }

    @Test
    func readNonExistentDataReturnsNil() {
        let result = KeychainHelper.read(key: testKey("does_not_exist_data"))
        #expect(result == nil)
    }

    // MARK: - Delete

    @Test
    func deleteExistingKey() {
        let key = testKey("delete")
        KeychainHelper.save(key: key, string: "to_be_deleted")

        let deleted = KeychainHelper.delete(key: key)
        #expect(deleted == true)

        let result = KeychainHelper.readString(key: key)
        #expect(result == nil)
    }

    @Test
    func deleteNonExistentKeySucceeds() {
        let deleted = KeychainHelper.delete(key: testKey("never_existed"))
        #expect(deleted == true) // Removing a non-existent key is not an error
    }

    // MARK: - Edge Cases

    @Test
    func emptyStringValue() {
        let key = testKey("empty")
        defer { KeychainHelper.delete(key: key) }

        KeychainHelper.save(key: key, string: "")
        let result = KeychainHelper.readString(key: key)
        #expect(result == "")
    }

    @Test
    func unicodeStringValue() {
        let key = testKey("unicode")
        defer { KeychainHelper.delete(key: key) }

        let value = "🔐🧘‍♂️ café naïve"
        KeychainHelper.save(key: key, string: value)
        let result = KeychainHelper.readString(key: key)
        #expect(result == value)
    }

    @Test
    func longStringValue() {
        let key = testKey("long")
        defer { KeychainHelper.delete(key: key) }

        let value = String(repeating: "a", count: 10_000)
        KeychainHelper.save(key: key, string: value)
        let result = KeychainHelper.readString(key: key)
        #expect(result == value)
    }

    @Test
    func multipleKeysIndependent() {
        let key1 = testKey("multi_1")
        let key2 = testKey("multi_2")
        defer {
            KeychainHelper.delete(key: key1)
            KeychainHelper.delete(key: key2)
        }

        KeychainHelper.save(key: key1, string: "value1")
        KeychainHelper.save(key: key2, string: "value2")

        #expect(KeychainHelper.readString(key: key1) == "value1")
        #expect(KeychainHelper.readString(key: key2) == "value2")

        // Delete one, other should remain
        KeychainHelper.delete(key: key1)
        #expect(KeychainHelper.readString(key: key1) == nil)
        #expect(KeychainHelper.readString(key: key2) == "value2")
    }

    // MARK: - Well-Known Keys

    @Test
    func keysConstants() {
        // Verify the key constants exist and are distinct
        let keys = [
            KeychainHelper.Keys.whoopAccessToken,
            KeychainHelper.Keys.whoopRefreshToken,
            KeychainHelper.Keys.whoopTokenExpiry,
            KeychainHelper.Keys.whoopClientId,
            KeychainHelper.Keys.whoopClientSecret,
            KeychainHelper.Keys.geminiAPIKey,
        ]
        let uniqueKeys = Set(keys)
        #expect(uniqueKeys.count == keys.count, "All key constants should be unique")
    }
}
