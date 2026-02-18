import Foundation
import Testing
@testable import Overwatch

/// Tests for WhoopClient — mock URLProtocol, endpoint routing, 401 retry, backoff (Plan 3.2.3)

// MARK: - Mock Auth Provider

struct MockAuthProvider: WhoopAuthProviding {
    var token: String = "mock_token"
    var refreshCalled: Bool = false

    func validAccessToken() async throws -> String {
        token
    }

    func refreshTokens() async throws {
        // No-op in most tests
    }
}

/// Auth provider that tracks refresh calls and provides a fresh token after refresh.
actor TrackingAuthProvider: WhoopAuthProviding {
    private var token: String
    private let refreshedToken: String
    private(set) var refreshCallCount = 0

    init(initialToken: String = "expired_token", refreshedToken: String = "fresh_token") {
        self.token = initialToken
        self.refreshedToken = refreshedToken
    }

    func validAccessToken() async throws -> String {
        token
    }

    func refreshTokens() async throws {
        refreshCallCount += 1
        token = refreshedToken
    }
}

// MARK: - Mock URL Protocol

/// A URLProtocol subclass that intercepts requests and returns preconfigured responses.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Test Helpers

private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeClient(
    authProvider: WhoopAuthProviding = MockAuthProvider(),
    session: URLSession? = nil
) -> WhoopClient {
    WhoopClient(
        authProvider: authProvider,
        session: session ?? makeMockSession(),
        baseURL: URL(string: "https://mock.whoop.test/developer")!
    )
}

private func mockResponse(statusCode: Int = 200, json: String, for path: String? = nil) {
    MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response, json.data(using: .utf8)!)
    }
}

// MARK: - Endpoint Tests

@Suite("WhoopClient — Endpoints")
struct WhoopClientEndpointTests {

    @Test
    func fetchRecoveryDecodesResponse() async throws {
        let json = """
        {
            "records": [{
                "cycle_id": 100, "sleep_id": 200, "user_id": 1,
                "created_at": "2026-02-17T08:00:00.000Z",
                "updated_at": "2026-02-17T08:00:00.000Z",
                "score_state": "SCORED",
                "score": {
                    "user_calibrating": false,
                    "recovery_score": 85.0,
                    "resting_heart_rate": 50.0,
                    "hrv_rmssd_milli": 60.0
                }
            }],
            "next_token": null
        }
        """
        mockResponse(json: json)

        let client = makeClient()
        let response = try await client.fetchRecovery()

        #expect(response.records.count == 1)
        #expect(response.records[0].score?.recoveryScore == 85.0)
    }

    @Test
    func fetchSleepDecodesResponse() async throws {
        let json = """
        {
            "records": [{
                "id": 200, "user_id": 1,
                "created_at": "2026-02-17T06:00:00.000Z",
                "updated_at": "2026-02-17T06:00:00.000Z",
                "start": "2026-02-16T22:00:00.000Z",
                "end": "2026-02-17T06:00:00.000Z",
                "nap": false, "score_state": "SCORED",
                "score": {
                    "stage_summary": {
                        "total_in_bed_time_milli": 28800000,
                        "total_awake_time_milli": 3600000,
                        "total_no_data_time_milli": 0,
                        "total_light_sleep_time_milli": 10800000,
                        "total_slow_wave_sleep_time_milli": 5400000,
                        "total_rem_sleep_time_milli": 7200000,
                        "sleep_cycle_count": 4,
                        "disturbance_count": 2
                    },
                    "sleep_performance_percentage": 88.0,
                    "sleep_efficiency_percentage": 87.5
                }
            }],
            "next_token": null
        }
        """
        mockResponse(json: json)

        let client = makeClient()
        let response = try await client.fetchSleep()

        #expect(response.records.count == 1)
        #expect(response.records[0].score?.sleepPerformancePercentage == 88.0)
    }

    @Test
    func fetchStrainDecodesResponse() async throws {
        let json = """
        {
            "records": [{
                "id": 300, "user_id": 1,
                "created_at": "2026-02-17T00:00:00.000Z",
                "updated_at": "2026-02-17T18:00:00.000Z",
                "start": "2026-02-17T00:00:00.000Z",
                "end": null,
                "score_state": "SCORED",
                "score": { "strain": 12.5, "kilojoule": 7800.0, "average_heart_rate": 68, "max_heart_rate": 175 }
            }],
            "next_token": null
        }
        """
        mockResponse(json: json)

        let client = makeClient()
        let response = try await client.fetchStrain()

        #expect(response.records.count == 1)
        #expect(response.records[0].score?.strain == 12.5)
    }

    @Test
    func bearerTokenAttached() async throws {
        let json = """
        { "records": [], "next_token": null }
        """

        var capturedAuth: String?
        MockURLProtocol.requestHandler = { request in
            capturedAuth = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }

        let client = makeClient(authProvider: MockAuthProvider(token: "my_secret_token"))
        _ = try await client.fetchRecovery()

        #expect(capturedAuth == "Bearer my_secret_token")
    }
}

// MARK: - 401 Retry Tests

@Suite("WhoopClient — 401 Retry")
struct WhoopClient401Tests {

    @Test
    func refreshesTokenOn401ThenRetries() async throws {
        let tracker = TrackingAuthProvider()
        var callCount = 0

        MockURLProtocol.requestHandler = { request in
            callCount += 1
            if callCount == 1 {
                // First call: 401
                let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            } else {
                // After refresh: success
                let json = """
                { "records": [], "next_token": null }
                """
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, json.data(using: .utf8)!)
            }
        }

        let client = makeClient(authProvider: tracker)
        _ = try await client.fetchRecovery()

        let refreshCount = await tracker.refreshCallCount
        #expect(refreshCount == 1)
        #expect(callCount == 2) // Initial + retry
    }
}

// MARK: - Server Error Tests

@Suite("WhoopClient — Error Handling")
struct WhoopClientErrorTests {

    @Test
    func throws500AsServerError() async throws {
        mockResponse(statusCode: 500, json: "{}")

        let client = makeClient()

        do {
            _ = try await client.fetchRecovery()
            #expect(Bool(false), "Should have thrown")
        } catch let error as WhoopClient.WhoopClientError {
            if case .serverError(let code) = error {
                #expect(code == 500)
            } else if case .maxRetriesExceeded = error {
                // Also acceptable — backoff exhausted on repeated 500s
            } else {
                #expect(Bool(false), "Expected serverError or maxRetriesExceeded, got \(error)")
            }
        }
    }

    @Test
    func throwsDecodingErrorOnBadJSON() async throws {
        mockResponse(json: "not valid json at all")

        let client = makeClient()

        do {
            _ = try await client.fetchRecovery()
            #expect(Bool(false), "Should have thrown")
        } catch let error as WhoopClient.WhoopClientError {
            if case .decodingError = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected decodingError, got \(error)")
            }
        }
    }
}
