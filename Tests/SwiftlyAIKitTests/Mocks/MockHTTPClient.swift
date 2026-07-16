import Foundation
import NIOCore
@testable import SwiftlyAIKit

/// Mock HTTP client for testing
///
/// Provides programmable responses and request capture for verification.
/// Supports both regular and streaming responses with error injection.
public actor MockHTTPClient {
    // MARK: - Response Configuration

    /// Configured responses by URL
    private var responses: [String: ResponseConfig] = [:]

    /// Captured requests for verification
    private(set) var capturedRequests: [CapturedRequest] = []

    /// Response configuration
    public struct ResponseConfig {
        let data: Data
        let statusCode: Int
        let delay: TimeInterval

        public init(data: Data, statusCode: Int = 200, delay: TimeInterval = 0) {
            self.data = data
            self.statusCode = statusCode
            self.delay = delay
        }
    }

    /// Captured request details
    public struct CapturedRequest {
        public let url: String
        public let method: String
        public let headers: [(String, String)]
        public let body: Data?

        public init(url: String, method: String, headers: [(String, String)], body: Data?) {
            self.url = url
            self.method = method
            self.headers = headers
            self.body = body
        }
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Configuration

    /// Set a response for a specific URL
    ///
    /// - Parameters:
    ///   - url: The URL to match
    ///   - data: Response body data
    ///   - statusCode: HTTP status code (default: 200)
    ///   - delay: Simulated network delay (default: 0)
    public func setResponse(for url: String, data: Data, statusCode: Int = 200, delay: TimeInterval = 0) {
        responses[url] = ResponseConfig(data: data, statusCode: statusCode, delay: delay)
    }

    /// Set a JSON response for a specific URL
    ///
    /// - Parameters:
    ///   - url: The URL to match
    ///   - json: Encodable object to serialize
    ///   - statusCode: HTTP status code (default: 200)
    ///   - delay: Simulated network delay (default: 0)
    public func setResponse<T: Encodable>(for url: String, json: T, statusCode: Int = 200, delay: TimeInterval = 0) throws {
        let data = try JSONEncoder().encode(json)
        responses[url] = ResponseConfig(data: data, statusCode: statusCode, delay: delay)
    }

    /// Set an error response for a specific URL
    ///
    /// - Parameters:
    ///   - url: The URL to match
    ///   - error: AIError to throw
    public func setError(for url: String, error: AIError) {
        let errorMessage = error.localizedDescription
        let data = errorMessage.data(using: .utf8) ?? Data()
        let statusCode: Int

        switch error {
        case .invalidRequest: statusCode = 400
        case .invalidAPIKey: statusCode = 401
        case .permissionDenied: statusCode = 403
        case .notFound: statusCode = 404
        case .requestTooLarge: statusCode = 413
        case .rateLimitExceeded: statusCode = 429
        case .internalError: statusCode = 500
        case .serviceUnavailable: statusCode = 503
        case .overloaded: statusCode = 529
        default: statusCode = 500
        }

        responses[url] = ResponseConfig(data: data, statusCode: statusCode, delay: 0)
    }

    /// Clear all configured responses
    public func clearResponses() {
        responses.removeAll()
    }

    /// Clear all captured requests
    public func clearCapturedRequests() {
        capturedRequests.removeAll()
    }

    // MARK: - HTTP Methods

    /// Perform a POST request
    ///
    /// - Parameters:
    ///   - url: Request URL
    ///   - headers: HTTP headers
    ///   - body: Request body
    /// - Returns: Response data
    /// - Throws: AIError if response indicates error
    public func post(url: String, headers: [(String, String)], body: Data) async throws -> Data {
        // Capture request
        capturedRequests.append(CapturedRequest(url: url, method: "POST", headers: headers, body: body))

        // Get configured response
        guard let config = responses[url] else {
            throw AIError.unknown(message: "No mock response configured for URL: \(url)")
        }

        // Simulate network delay
        if config.delay > 0 {
            try await Task.sleep(for: .seconds(config.delay))
        }

        // Throw error if status code indicates failure
        if config.statusCode >= 400 {
            throw mapHTTPError(statusCode: config.statusCode, data: config.data)
        }

        return config.data
    }

    /// Perform a GET request
    ///
    /// - Parameters:
    ///   - url: Request URL
    ///   - headers: HTTP headers
    /// - Returns: Response data
    /// - Throws: AIError if response indicates error
    public func get(url: String, headers: [(String, String)]) async throws -> Data {
        // Capture request
        capturedRequests.append(CapturedRequest(url: url, method: "GET", headers: headers, body: nil))

        // Get configured response
        guard let config = responses[url] else {
            throw AIError.unknown(message: "No mock response configured for URL: \(url)")
        }

        // Simulate network delay
        if config.delay > 0 {
            try await Task.sleep(for: .seconds(config.delay))
        }

        // Throw error if status code indicates failure
        if config.statusCode >= 400 {
            throw mapHTTPError(statusCode: config.statusCode, data: config.data)
        }

        return config.data
    }

    // MARK: - Streaming Support

    /// Stream POST responses (for SSE testing)
    ///
    /// - Parameters:
    ///   - url: Request URL
    ///   - headers: HTTP headers
    ///   - body: Request body
    ///   - chunks: Pre-configured data chunks to stream
    /// - Returns: AsyncThrowingStream of data chunks
    nonisolated public func streamPost(
        url: String,
        headers: [(String, String)],
        body: Data,
        chunks: [Data]
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // Capture request
                await captureStreamRequest(url: url, headers: headers, body: body)

                // Stream chunks
                for chunk in chunks {
                    continuation.yield(chunk)
                    try? await Task.sleep(for: .milliseconds(10)) // 10ms between chunks
                }

                continuation.finish()
            }
        }
    }

    private func captureStreamRequest(url: String, headers: [(String, String)], body: Data) {
        capturedRequests.append(CapturedRequest(url: url, method: "POST", headers: headers, body: body))
    }

    // MARK: - Helper Methods

    /// Map HTTP status code to AIError
    nonisolated private func mapHTTPError(statusCode: Int, data: Data) -> AIError {
        let message = String(data: data, encoding: .utf8) ?? ""

        switch statusCode {
        case 400:
            return .invalidRequest(message: message)
        case 401:
            return .invalidAPIKey(provider: .anthropic, message: message)
        case 403:
            return .permissionDenied(provider: .anthropic, message: message)
        case 404:
            return .notFound(resource: "endpoint", provider: .anthropic)
        case 413:
            return .requestTooLarge(size: 0, limit: 0)
        case 429:
            return .rateLimitExceeded(provider: .anthropic, retryAfter: nil)
        case 500:
            return .internalError(provider: .anthropic, message: message)
        case 503:
            return .serviceUnavailable(provider: .anthropic)
        case 529:
            return .overloaded(provider: .anthropic)
        default:
            return .providerError(provider: .anthropic, statusCode: statusCode, message: message)
        }
    }

    // MARK: - Verification Helpers

    /// Get the number of requests captured
    public var requestCount: Int {
        capturedRequests.count
    }

    /// Get the last captured request
    public var lastRequest: CapturedRequest? {
        capturedRequests.last
    }

    /// Check if a request was made to a specific URL
    ///
    /// - Parameter url: URL to check
    /// - Returns: True if request was made to URL
    public func didRequest(url: String) -> Bool {
        capturedRequests.contains { $0.url == url }
    }

    /// Get all requests made to a specific URL
    ///
    /// - Parameter url: URL to filter by
    /// - Returns: Array of requests to that URL
    public func requests(to url: String) -> [CapturedRequest] {
        capturedRequests.filter { $0.url == url }
    }

    /// Get request body as JSON
    ///
    /// - Parameter index: Request index (default: last)
    /// - Returns: Decoded JSON object
    /// - Throws: DecodingError if body cannot be decoded
    public func getRequestBody<T: Decodable>(at index: Int? = nil, as type: T.Type) throws -> T {
        let request = index != nil ? capturedRequests[index!] : capturedRequests.last
        guard let body = request?.body else {
            throw AIError.unknown(message: "No request body found")
        }
        return try JSONDecoder().decode(type, from: body)
    }
}
