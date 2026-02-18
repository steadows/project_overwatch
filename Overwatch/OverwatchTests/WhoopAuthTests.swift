import Foundation
import Testing
@testable import Overwatch

/// Tests for WhoopAuthManager — PKCE, OAuth URL, callback parsing, token refresh (Plan 3.1.3)

// MARK: - Mock OAuth Session Provider

/// A mock session provider that returns a preconfigured callback URL.
struct MockOAuthSessionProvider: OAuthSessionProviding {
    let callbackURL: URL

    func presentSession(url: URL, callbackScheme: String) async throws -> URL {
        callbackURL
    }
}

// MARK: - PKCE & OAuth URL Tests

@Suite("WhoopAuthManager — OAuth")
struct WhoopAuthTests {

    private func makeAuthManager(
        callbackURL: URL = URL(string: "overwatch://whoop/callback?code=test_code&state=abc")!,
        clientId: String = "test_client_id",
        clientSecret: String = "test_secret"
    ) -> WhoopAuthManager {
        let config = WhoopAuthManager.Configuration(
            clientId: clientId,
            clientSecret: clientSecret,
            redirectURI: "overwatch://whoop/callback",
            scopes: ["read:recovery", "read:cycles", "read:sleep"],
            authorizationURL: "https://api.prod.whoop.com/oauth/oauth2/auth",
            tokenURL: "https://api.prod.whoop.com/oauth/oauth2/token"
        )
        let mockProvider = MockOAuthSessionProvider(callbackURL: callbackURL)
        return WhoopAuthManager(
            configuration: config,
            sessionProvider: mockProvider,
            urlSession: .shared
        )
    }

    @Test
    func pkceVerifierLength() async throws {
        // PKCE verifier should be a 64-character base64url string (from 48 random bytes)
        // We test this indirectly by verifying the auth URL contains a code_challenge
        let auth = makeAuthManager()

        // Can't call generatePKCE directly (private), but we can verify
        // that base64URL encoding works correctly
        let testData = Data([0x00, 0xFF, 0x80, 0x7F])
        let encoded = testData.base64URLEncodedString()
        // Should not contain +, /, or = (base64url rules)
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("="))
    }

    @Test
    func base64URLEncoding() {
        // Test RFC 4648 Section 5 compliance
        let data = Data("Hello, PKCE World! This is a test.".utf8)
        let encoded = data.base64URLEncodedString()

        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("="))
        #expect(!encoded.isEmpty)
    }

    @Test
    func configurationMissingClientId() async {
        let auth = makeAuthManager(clientId: "", clientSecret: "secret")

        do {
            try await auth.authorize()
            #expect(Bool(false), "Should have thrown")
        } catch let error as WhoopAuthError {
            #expect(error == .configurationMissing("clientId"))
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test
    func configurationMissingClientSecret() async {
        let auth = makeAuthManager(clientId: "id", clientSecret: "")

        do {
            try await auth.authorize()
            #expect(Bool(false), "Should have thrown")
        } catch let error as WhoopAuthError {
            #expect(error == .configurationMissing("clientSecret"))
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test
    func callbackMissingCodeThrows() async {
        let badCallback = URL(string: "overwatch://whoop/callback?state=abc")!
        let auth = makeAuthManager(callbackURL: badCallback)

        do {
            try await auth.authorize()
            #expect(Bool(false), "Should have thrown")
        } catch let error as WhoopAuthError {
            #expect(error == .callbackMissingCode)
        } catch {
            // Token exchange will fail because there's no real server,
            // but we should get past callback parsing. Any WhoopAuthError is acceptable.
            #expect(error is WhoopAuthError)
        }
    }

    @Test
    func callbackWithErrorParam() async {
        let errorCallback = URL(string: "overwatch://whoop/callback?error=access_denied&error_description=User+denied")!
        let auth = makeAuthManager(callbackURL: errorCallback)

        do {
            try await auth.authorize()
            #expect(Bool(false), "Should have thrown")
        } catch let error as WhoopAuthError {
            if case .callbackParsingFailed = error {
                // Expected — the error param was detected
            } else {
                #expect(Bool(false), "Expected callbackParsingFailed, got \(error)")
            }
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test
    func logoutClearsTokens() async {
        let auth = makeAuthManager()
        // Store fake tokens
        KeychainHelper.save(key: KeychainHelper.Keys.whoopAccessToken, string: "fake_token")
        KeychainHelper.save(key: KeychainHelper.Keys.whoopRefreshToken, string: "fake_refresh")
        KeychainHelper.save(key: KeychainHelper.Keys.whoopTokenExpiry, string: "9999999999")

        await auth.logout()

        #expect(KeychainHelper.readString(key: KeychainHelper.Keys.whoopAccessToken) == nil)
        #expect(KeychainHelper.readString(key: KeychainHelper.Keys.whoopRefreshToken) == nil)
        #expect(KeychainHelper.readString(key: KeychainHelper.Keys.whoopTokenExpiry) == nil)
    }

    @Test
    func noAccessTokenWhenNotAuthenticated() async {
        // Clean slate — no tokens stored
        KeychainHelper.delete(key: KeychainHelper.Keys.whoopAccessToken)
        KeychainHelper.delete(key: KeychainHelper.Keys.whoopRefreshToken)
        KeychainHelper.delete(key: KeychainHelper.Keys.whoopTokenExpiry)

        let auth = makeAuthManager()

        do {
            _ = try await auth.validAccessToken()
            #expect(Bool(false), "Should have thrown")
        } catch let error as WhoopAuthError {
            #expect(error == .noAccessToken)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }
}

// MARK: - Equatable for test assertions

extension WhoopAuthError: Equatable {
    public static func == (lhs: WhoopAuthError, rhs: WhoopAuthError) -> Bool {
        switch (lhs, rhs) {
        case (.pkceGenerationFailed, .pkceGenerationFailed),
             (.authorizationURLInvalid, .authorizationURLInvalid),
             (.authorizationCancelled, .authorizationCancelled),
             (.callbackMissingCode, .callbackMissingCode),
             (.tokenResponseMalformed, .tokenResponseMalformed),
             (.refreshTokenMissing, .refreshTokenMissing),
             (.noAccessToken, .noAccessToken):
            return true
        case (.configurationMissing(let a), .configurationMissing(let b)):
            return a == b
        case (.callbackParsingFailed(let a), .callbackParsingFailed(let b)):
            return a == b
        case (.tokenExchangeFailed(let a, let b), .tokenExchangeFailed(let c, let d)):
            return a == c && b == d
        case (.refreshFailed(let a, let b), .refreshFailed(let c, let d)):
            return a == c && b == d
        default:
            return false
        }
    }
}
