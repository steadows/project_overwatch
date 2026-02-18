import Foundation
import os

// MARK: - Auth Provider Protocol

/// Protocol for providing authentication tokens to the WHOOP client.
/// `WhoopAuthManager` will conform to this once OAuth is built (Phase 3.1.x).
/// Using a protocol here keeps the client testable with a mock auth provider.
protocol WhoopAuthProviding: Sendable {
    func validAccessToken() async throws -> String
    func refreshTokens() async throws
}

// MARK: - WhoopClient

/// HTTP client actor for all WHOOP API v1 endpoints.
///
/// Responsibilities:
/// - Builds authenticated requests against the WHOOP Developer API
/// - Handles pagination via `nextToken`
/// - Auto-retries on 401 (token refresh) and 429/5xx (exponential backoff)
///
/// Architecture:
/// - Actor isolation guarantees thread-safe state (no data races on retry counters, etc.)
/// - Dependencies injected via init for testability
/// - No SwiftUI imports — pure Foundation networking
actor WhoopClient {

    // MARK: - Error Types

    enum WhoopClientError: Error, LocalizedError {
        case unauthorized
        case rateLimited
        case serverError(statusCode: Int)
        case networkError(Error)
        case decodingError(Error)
        case invalidResponse
        case maxRetriesExceeded

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "WHOOP authentication failed. Please reconnect your account."
            case .rateLimited:
                return "WHOOP API rate limit exceeded. Please wait and try again."
            case .serverError(let statusCode):
                return "WHOOP server error (HTTP \(statusCode)). Please try again later."
            case .networkError(let error):
                return "Network error communicating with WHOOP: \(error.localizedDescription)"
            case .decodingError(let error):
                return "Failed to parse WHOOP response: \(error.localizedDescription)"
            case .invalidResponse:
                return "Received an invalid response from WHOOP API."
            case .maxRetriesExceeded:
                return "WHOOP API request failed after multiple retry attempts."
            }
        }
    }

    // MARK: - Configuration

    private struct RetryConfig {
        let maxBackoffRetries: Int = 3
        let baseDelay: TimeInterval = 1.0  // 1s, 2s, 4s
        let maxAuthRetries: Int = 1
    }

    // MARK: - Dependencies

    private let authProvider: WhoopAuthProviding
    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let logger: Logger
    private let retryConfig: RetryConfig

    // MARK: - Init

    init(
        authProvider: WhoopAuthProviding,
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.prod.whoop.com/developer")!
    ) {
        self.authProvider = authProvider
        self.session = session
        self.baseURL = baseURL
        self.retryConfig = RetryConfig()
        self.logger = Logger(subsystem: "com.overwatch.app", category: "WhoopClient")

        let decoder = JSONDecoder()
        // WHOOP API uses snake_case — our Codable models handle this via explicit CodingKeys,
        // so we use the default key decoding strategy.
        self.decoder = decoder
    }

    // MARK: - Public API

    /// Fetch recovery data from WHOOP.
    /// - Parameters:
    ///   - start: Optional start date for the query range.
    ///   - end: Optional end date for the query range.
    ///   - nextToken: Pagination token from a previous response.
    /// - Returns: A paginated recovery response.
    func fetchRecovery(
        start: Date? = nil,
        end: Date? = nil,
        nextToken: String? = nil
    ) async throws -> WhoopRecoveryResponse {
        try await performRequest(
            path: "/v1/recovery",
            start: start,
            end: end,
            nextToken: nextToken
        )
    }

    /// Fetch sleep data from WHOOP.
    /// - Parameters:
    ///   - start: Optional start date for the query range.
    ///   - end: Optional end date for the query range.
    ///   - nextToken: Pagination token from a previous response.
    /// - Returns: A paginated sleep response.
    func fetchSleep(
        start: Date? = nil,
        end: Date? = nil,
        nextToken: String? = nil
    ) async throws -> WhoopSleepResponse {
        try await performRequest(
            path: "/v1/activity/sleep",
            start: start,
            end: end,
            nextToken: nextToken
        )
    }

    /// Fetch strain (cycle) data from WHOOP.
    /// - Parameters:
    ///   - start: Optional start date for the query range.
    ///   - end: Optional end date for the query range.
    ///   - nextToken: Pagination token from a previous response.
    /// - Returns: A paginated strain response.
    func fetchStrain(
        start: Date? = nil,
        end: Date? = nil,
        nextToken: String? = nil
    ) async throws -> WhoopStrainResponse {
        try await performRequest(
            path: "/v1/cycle",
            start: start,
            end: end,
            nextToken: nextToken
        )
    }

    // MARK: - Private: Request Execution

    /// Generic request handler that builds the URL, attaches auth, and handles retries.
    ///
    /// Retry strategy:
    /// 1. **401 Unauthorized** — refresh tokens via `authProvider`, retry once.
    /// 2. **429 Rate Limited / 5xx Server Error** — exponential backoff (1s, 2s, 4s), up to 3 retries.
    /// 3. **Other errors** — thrown immediately, no retry.
    private func performRequest<T: Decodable & Sendable>(
        path: String,
        start: Date?,
        end: Date?,
        nextToken: String?
    ) async throws -> T {
        let request = try await buildRequest(path: path, start: start, end: end, nextToken: nextToken)

        // Attempt with 401 retry (token refresh)
        do {
            return try await executeWithBackoff(request: request)
        } catch WhoopClientError.unauthorized {
            logger.info("Received 401 — attempting token refresh and retry")
            try await authProvider.refreshTokens()
            let refreshedRequest = try await buildRequest(
                path: path,
                start: start,
                end: end,
                nextToken: nextToken
            )
            return try await executeWithBackoff(request: refreshedRequest)
        }
    }

    /// Executes a request with exponential backoff for 429 and 5xx responses.
    private func executeWithBackoff<T: Decodable & Sendable>(request: URLRequest) async throws -> T {
        var lastError: WhoopClientError?

        for attempt in 0...retryConfig.maxBackoffRetries {
            // Wait before retrying (skip delay on first attempt)
            if attempt > 0 {
                let delay = retryConfig.baseDelay * pow(2.0, Double(attempt - 1))
                logger.info("Backoff retry \(attempt)/\(self.retryConfig.maxBackoffRetries) — waiting \(delay)s")
                try await Task.sleep(for: .seconds(delay))
            }

            do {
                return try await executeSingleRequest(request: request)
            } catch let error as WhoopClientError {
                switch error {
                case .rateLimited, .serverError:
                    lastError = error
                    // Continue to next retry attempt
                    continue
                default:
                    // Non-retryable error — throw immediately
                    throw error
                }
            }
        }

        // All retries exhausted
        logger.error("All \(self.retryConfig.maxBackoffRetries) backoff retries exhausted")
        throw lastError ?? WhoopClientError.maxRetriesExceeded
    }

    /// Executes a single HTTP request, maps status codes to errors, and decodes the response.
    private func executeSingleRequest<T: Decodable & Sendable>(request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw WhoopClientError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Response is not HTTPURLResponse")
            throw WhoopClientError.invalidResponse
        }

        let statusCode = httpResponse.statusCode
        logger.debug("\(request.httpMethod ?? "GET") \(request.url?.path ?? "") → \(statusCode)")

        switch statusCode {
        case 200...299:
            break // Success — continue to decoding
        case 401:
            throw WhoopClientError.unauthorized
        case 429:
            logger.warning("Rate limited by WHOOP API")
            throw WhoopClientError.rateLimited
        case 500...599:
            logger.warning("WHOOP server error: \(statusCode)")
            throw WhoopClientError.serverError(statusCode: statusCode)
        default:
            logger.error("Unexpected HTTP status: \(statusCode)")
            throw WhoopClientError.serverError(statusCode: statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("Decoding failed: \(error.localizedDescription)")
            throw WhoopClientError.decodingError(error)
        }
    }

    // MARK: - Private: Request Building

    /// Builds an authenticated URLRequest with query parameters for date range and pagination.
    private func buildRequest(
        path: String,
        start: Date?,
        end: Date?,
        nextToken: String?
    ) async throws -> URLRequest {
        let token: String
        do {
            token = try await authProvider.validAccessToken()
        } catch {
            logger.error("Failed to get access token: \(error.localizedDescription)")
            throw WhoopClientError.unauthorized
        }

        let url = baseURL.appendingPathComponent(path)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        var queryItems: [URLQueryItem] = []

        if let start {
            queryItems.append(URLQueryItem(
                name: "start",
                value: DateFormatters.iso8601.string(from: start)
            ))
        }

        if let end {
            queryItems.append(URLQueryItem(
                name: "end",
                value: DateFormatters.iso8601.string(from: end)
            ))
        }

        if let nextToken {
            queryItems.append(URLQueryItem(name: "nextToken", value: nextToken))
        }

        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let finalURL = components?.url else {
            throw WhoopClientError.invalidResponse
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Timeout: 30s connect, 60s resource
        request.timeoutInterval = 60

        return request
    }
}
