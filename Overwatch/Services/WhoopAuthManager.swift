import AuthenticationServices
import CryptoKit
import Foundation

// MARK: - Errors

/// Errors that can occur during WHOOP OAuth authentication.
enum WhoopAuthError: LocalizedError, Sendable {
    case pkceGenerationFailed
    case authorizationURLInvalid
    case authorizationCancelled
    case callbackMissingCode
    case callbackParsingFailed(String)
    case tokenExchangeFailed(statusCode: Int, body: String)
    case tokenResponseMalformed
    case refreshTokenMissing
    case refreshFailed(statusCode: Int, body: String)
    case noAccessToken
    case configurationMissing(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .pkceGenerationFailed:
            "Failed to generate PKCE code verifier and challenge."
        case .authorizationURLInvalid:
            "The constructed authorization URL is invalid."
        case .authorizationCancelled:
            "The user cancelled the authorization flow."
        case .callbackMissingCode:
            "The callback URL did not contain an authorization code."
        case .callbackParsingFailed(let detail):
            "Failed to parse the callback URL: \(detail)"
        case .tokenExchangeFailed(let statusCode, let body):
            "Token exchange failed (HTTP \(statusCode)): \(body)"
        case .tokenResponseMalformed:
            "The token response could not be decoded."
        case .refreshTokenMissing:
            "No refresh token is stored. Re-authorization is required."
        case .refreshFailed(let statusCode, let body):
            "Token refresh failed (HTTP \(statusCode)): \(body)"
        case .noAccessToken:
            "No access token is available. Authorization is required."
        case .configurationMissing(let field):
            "Missing configuration: \(field). Set the value in Keychain or Configuration."
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - OAuth Session Protocol

/// Protocol for presenting OAuth browser sessions. Injected into
/// `WhoopAuthManager` so the auth flow can be tested without a real browser.
protocol OAuthSessionProviding: Sendable {
    /// Present an OAuth session in the system browser and return the callback URL.
    /// - Parameters:
    ///   - url: The authorization URL to open.
    ///   - callbackScheme: The custom URL scheme to listen for (e.g. "overwatch").
    /// - Returns: The full callback URL containing the authorization code.
    func presentSession(url: URL, callbackScheme: String) async throws -> URL
}

// MARK: - Production OAuth Session Provider

/// Production implementation using `ASWebAuthenticationSession`.
/// Conforms to `ASWebAuthenticationPresentationContextProviding` to anchor the
/// authentication sheet to the key window on macOS.
final class WebAuthSessionProvider: NSObject, OAuthSessionProviding,
    ASWebAuthenticationPresentationContextProviding, @unchecked Sendable
{
    /// Retained to prevent deallocation while the browser session is active.
    /// `nonisolated(unsafe)` because it's written on main (start) and cleared
    /// from the XPC callback thread — both single-writer, non-concurrent.
    nonisolated(unsafe) private var activeSession: ASWebAuthenticationSession?

    nonisolated func presentSession(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            // The completion handler is defined here — OUTSIDE DispatchQueue.main.async
            // and marked @Sendable — so it does NOT inherit MainActor isolation.
            // ASWebAuthenticationSession fires this on a background XPC thread;
            // if the closure were MainActor-isolated, Swift 6's runtime would trap.
            let handler: @Sendable (URL?, (any Error)?) -> Void = { [weak self] callbackURL, error in
                self?.activeSession = nil

                if let error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: WhoopAuthError.authorizationCancelled)
                    } else {
                        continuation.resume(throwing: WhoopAuthError.networkError(error))
                    }
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: WhoopAuthError.callbackMissingCode)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            // ASWebAuthenticationSession must be created and started on the main
            // thread. The handler above runs on whatever thread the system chooses.
            DispatchQueue.main.async { [self] in
                let session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: callbackScheme,
                    completionHandler: handler
                )
                self.activeSession = session
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                session.start()
            }
        }
    }

    // MARK: ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // On macOS, return the key window or create a fallback window.
        #if os(macOS)
        return NSApplication.shared.keyWindow ?? NSWindow()
        #else
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? UIWindow()
        #endif
    }
}

// MARK: - Token Response

/// Maps the JSON response from WHOOP's `/oauth/oauth2/token` endpoint.
struct WhoopTokenResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

// MARK: - Auth Manager

/// Thread-safe OAuth 2.0 + PKCE authentication manager for the WHOOP API.
///
/// Handles the full lifecycle: authorization, token exchange, automatic refresh,
/// and logout. All token storage goes through `KeychainHelper`.
///
/// Usage:
/// ```swift
/// let auth = WhoopAuthManager()
/// try await auth.authorize()              // opens browser, exchanges code
/// let token = try await auth.validAccessToken() // auto-refreshes if needed
/// auth.logout()                           // clears all stored tokens
/// ```
actor WhoopAuthManager: WhoopAuthProviding {

    // MARK: - Configuration

    /// OAuth client configuration for WHOOP API.
    struct Configuration: Sendable {
        let clientId: String
        let clientSecret: String
        let redirectURI: String
        let scopes: [String]

        /// Authorization endpoint.
        let authorizationURL: String
        /// Token endpoint for exchange and refresh.
        let tokenURL: String

        /// Default configuration reading client ID and secret from Keychain.
        /// Falls back to empty strings — the manager validates before use.
        static let `default` = Configuration(
            clientId: EnvironmentConfig.whoopClientId ?? "",
            clientSecret: EnvironmentConfig.whoopClientSecret ?? "",
            redirectURI: "overwatch://whoop/callback",
            scopes: ["read:recovery", "read:cycles", "read:sleep", "read:profile"],
            authorizationURL: "https://api.prod.whoop.com/oauth/oauth2/auth",
            tokenURL: "https://api.prod.whoop.com/oauth/oauth2/token"
        )
    }

    // MARK: - PKCE Pair

    /// Ephemeral PKCE values used during a single authorization flow.
    private struct PKCEPair: Sendable {
        let codeVerifier: String
        let codeChallenge: String
    }

    // MARK: - Properties

    private let configuration: Configuration
    private let sessionProvider: OAuthSessionProviding
    private let urlSession: URLSession

    /// Cached in-memory access token. Falls back to Keychain on cold start.
    private var cachedAccessToken: String?
    /// Cached in-memory expiry date.
    private var cachedTokenExpiry: Date?
    /// Stored between `authorize()` (generate) and `exchangeCode()` (consume).
    private var currentPKCE: PKCEPair?

    // MARK: - Init

    /// Create an auth manager with explicit dependencies.
    /// - Parameters:
    ///   - configuration: OAuth client configuration. Defaults to `Configuration.default`.
    ///   - sessionProvider: The provider for presenting the browser login. Defaults to
    ///     `WebAuthSessionProvider` for production use.
    ///   - urlSession: The `URLSession` to use for HTTP calls. Defaults to `.shared`.
    init(
        configuration: Configuration = .default,
        sessionProvider: OAuthSessionProviding? = nil,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.sessionProvider = sessionProvider ?? WebAuthSessionProvider()
        self.urlSession = urlSession

        // Hydrate in-memory cache from Keychain on init.
        self.cachedAccessToken = KeychainHelper.readString(key: KeychainHelper.Keys.whoopAccessToken)
        if let expiryString = KeychainHelper.readString(key: KeychainHelper.Keys.whoopTokenExpiry),
           let expiryInterval = TimeInterval(expiryString)
        {
            self.cachedTokenExpiry = Date(timeIntervalSince1970: expiryInterval)
        }
    }

    // MARK: - Public API

    /// Whether the user currently has stored credentials (tokens may still be expired).
    var isAuthenticated: Bool {
        cachedAccessToken != nil
            || KeychainHelper.readString(key: KeychainHelper.Keys.whoopAccessToken) != nil
    }

    /// Run the full OAuth 2.0 + PKCE authorization flow.
    ///
    /// 1. Generates a PKCE code verifier and challenge.
    /// 2. Opens the WHOOP login page in a system browser sheet.
    /// 3. Captures the authorization code from the callback URL.
    /// 4. Exchanges the code for access + refresh tokens.
    ///
    /// - Throws: `WhoopAuthError` if any step fails.
    func authorize() async throws {
        // Validate configuration before starting.
        guard !configuration.clientId.isEmpty else {
            throw WhoopAuthError.configurationMissing("clientId")
        }
        guard !configuration.clientSecret.isEmpty else {
            throw WhoopAuthError.configurationMissing("clientSecret")
        }

        // Step 1: Generate PKCE pair.
        let pkce = try generatePKCE()
        currentPKCE = pkce

        // Step 2: Build authorization URL.
        let authURL = try buildAuthorizationURL(codeChallenge: pkce.codeChallenge)

        // Step 3: Present browser session and capture callback.
        let callbackURL = try await sessionProvider.presentSession(
            url: authURL,
            callbackScheme: "overwatch"
        )

        // Step 4: Extract authorization code from callback.
        let code = try extractAuthorizationCode(from: callbackURL)

        // Step 5: Exchange code for tokens.
        try await exchangeCode(code, codeVerifier: pkce.codeVerifier)

        // Clean up PKCE — it is single-use.
        currentPKCE = nil
    }

    /// Returns a valid access token. If the current token is expired,
    /// automatically refreshes it first.
    ///
    /// - Throws: `WhoopAuthError.noAccessToken` if no token exists,
    ///   or refresh errors if the refresh fails.
    /// - Returns: A valid, non-expired access token string.
    func validAccessToken() async throws -> String {
        // If we have a cached token and it is still valid, return it.
        if let token = cachedAccessToken, let expiry = cachedTokenExpiry {
            // Refresh 60 seconds before actual expiry to avoid race conditions.
            if expiry.timeIntervalSinceNow > 60 {
                return token
            }
        }

        // Try to refresh.
        if KeychainHelper.readString(key: KeychainHelper.Keys.whoopRefreshToken) != nil {
            try await refreshTokens()
            if let token = cachedAccessToken {
                return token
            }
        }

        throw WhoopAuthError.noAccessToken
    }

    /// Refresh the access token using the stored refresh token.
    ///
    /// - Throws: `WhoopAuthError.refreshTokenMissing` if no refresh token is stored,
    ///   or `WhoopAuthError.refreshFailed` if the HTTP call fails.
    func refreshTokens() async throws {
        guard let refreshToken = KeychainHelper.readString(key: KeychainHelper.Keys.whoopRefreshToken) else {
            throw WhoopAuthError.refreshTokenMissing
        }

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": configuration.clientId,
            "client_secret": configuration.clientSecret,
        ]

        let tokenResponse = try await performTokenRequest(body: body)
        storeTokens(tokenResponse)
    }

    /// Clear all stored tokens and reset in-memory state.
    /// The user will need to re-authorize after this call.
    func logout() {
        KeychainHelper.delete(key: KeychainHelper.Keys.whoopAccessToken)
        KeychainHelper.delete(key: KeychainHelper.Keys.whoopRefreshToken)
        KeychainHelper.delete(key: KeychainHelper.Keys.whoopTokenExpiry)
        cachedAccessToken = nil
        cachedTokenExpiry = nil
        currentPKCE = nil
    }

    // MARK: - PKCE Generation

    /// Generate a cryptographically random PKCE code verifier and its SHA-256 challenge.
    ///
    /// The verifier is a 64-character URL-safe Base64 string.
    /// The challenge is `Base64URL(SHA256(verifier))`.
    private func generatePKCE() throws -> PKCEPair {
        // Generate 32 random bytes -> 43+ character base64url string.
        // We use 48 bytes to get a 64-character base64url string.
        var randomBytes = [UInt8](repeating: 0, count: 48)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard status == errSecSuccess else {
            throw WhoopAuthError.pkceGenerationFailed
        }

        let codeVerifier = Data(randomBytes)
            .base64URLEncodedString()

        // SHA-256 hash the verifier, then base64url-encode the digest.
        let challengeData = Data(SHA256.hash(data: Data(codeVerifier.utf8)))
        let codeChallenge = challengeData.base64URLEncodedString()

        return PKCEPair(codeVerifier: codeVerifier, codeChallenge: codeChallenge)
    }

    // MARK: - Authorization URL

    /// Build the full WHOOP authorization URL with PKCE and all required parameters.
    private func buildAuthorizationURL(codeChallenge: String) throws -> URL {
        guard var components = URLComponents(string: configuration.authorizationURL) else {
            throw WhoopAuthError.authorizationURLInvalid
        }

        components.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: UUID().uuidString),
        ]

        guard let url = components.url else {
            throw WhoopAuthError.authorizationURLInvalid
        }

        return url
    }

    // MARK: - Callback Parsing

    /// Extract the authorization code from the OAuth callback URL.
    ///
    /// Expected format: `overwatch://whoop/callback?code=XXXXX&state=YYYYY`
    private func extractAuthorizationCode(from url: URL) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw WhoopAuthError.callbackParsingFailed("Cannot parse URL components from \(url)")
        }

        // Check for an error parameter from the OAuth provider.
        if let errorParam = components.queryItems?.first(where: { $0.name == "error" })?.value {
            let description = components.queryItems?.first(where: { $0.name == "error_description" })?.value
            throw WhoopAuthError.callbackParsingFailed(description ?? errorParam)
        }

        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty
        else {
            throw WhoopAuthError.callbackMissingCode
        }

        return code
    }

    // MARK: - Token Exchange

    /// Exchange an authorization code for access and refresh tokens.
    private func exchangeCode(_ code: String, codeVerifier: String) async throws {
        let body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": configuration.redirectURI,
            "client_id": configuration.clientId,
            "client_secret": configuration.clientSecret,
            "code_verifier": codeVerifier,
        ]

        let tokenResponse = try await performTokenRequest(body: body)
        storeTokens(tokenResponse)
    }

    // MARK: - HTTP Helpers

    /// Perform a POST to the token endpoint with a URL-encoded form body.
    private func performTokenRequest(body: [String: String]) async throws -> WhoopTokenResponse {
        guard let url = URL(string: configuration.tokenURL) else {
            throw WhoopAuthError.authorizationURLInvalid
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let formBody = body
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")

        request.httpBody = formBody.data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw WhoopAuthError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhoopAuthError.tokenResponseMalformed
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "<unreadable>"
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 400 {
                // Distinguish between exchange failures and refresh failures
                // by checking the grant_type in the original body.
                if body["grant_type"] == "refresh_token" {
                    throw WhoopAuthError.refreshFailed(
                        statusCode: httpResponse.statusCode,
                        body: responseBody
                    )
                }
            }
            throw WhoopAuthError.tokenExchangeFailed(
                statusCode: httpResponse.statusCode,
                body: responseBody
            )
        }

        do {
            let tokenResponse = try JSONDecoder().decode(WhoopTokenResponse.self, from: data)
            return tokenResponse
        } catch {
            #if DEBUG
            let bodyString = String(data: data, encoding: .utf8) ?? "<unreadable>"
            print("[WhoopAuth] Token decode failed. Response body:\n\(bodyString)")
            print("[WhoopAuth] Decode error: \(error)")
            #endif
            throw WhoopAuthError.tokenResponseMalformed
        }
    }

    // MARK: - Token Storage

    /// Persist tokens to Keychain and update the in-memory cache.
    private func storeTokens(_ response: WhoopTokenResponse) {
        // Store access token.
        let accessSaved = KeychainHelper.save(key: KeychainHelper.Keys.whoopAccessToken, string: response.accessToken)
        print("[WHOOP] Keychain save access token: \(accessSaved ? "OK" : "FAILED")")

        // Store refresh token (if provided).
        if let refreshToken = response.refreshToken {
            let refreshSaved = KeychainHelper.save(key: KeychainHelper.Keys.whoopRefreshToken, string: refreshToken)
            print("[WHOOP] Keychain save refresh token: \(refreshSaved ? "OK" : "FAILED")")
        }

        // Compute and store the absolute expiry timestamp.
        let expiry = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        let expiryString = String(expiry.timeIntervalSince1970)
        let expirySaved = KeychainHelper.save(key: KeychainHelper.Keys.whoopTokenExpiry, string: expiryString)
        print("[WHOOP] Keychain save expiry: \(expirySaved ? "OK" : "FAILED")")

        // Update in-memory cache.
        cachedAccessToken = response.accessToken
        cachedTokenExpiry = expiry
    }
}

// MARK: - Data + Base64URL

extension Data {
    /// Encodes data as a Base64 URL-safe string (RFC 4648 Section 5).
    ///
    /// Replaces `+` with `-`, `/` with `_`, and strips trailing `=` padding.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
