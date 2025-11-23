import Foundation
import AsyncHTTPClient
import NIOCore
import NIOHTTP1

/// HTTP Client Manager for making requests to AI providers
///
/// This manager wraps AsyncHTTPClient and provides:
/// - Automatic retry logic with exponential backoff
/// - Request/response logging
/// - Timeout management
/// - Proper resource cleanup
public actor HTTPClientManager {
    private let httpClient: HTTPClient
    private let maxRetries: Int
    private let timeout: TimeAmount
    private let enableLogging: Bool

    /// Initialize a new HTTP client manager
    ///
    /// - Parameters:
    ///   - httpClient: Optional custom HTTP client (creates default if nil)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - timeout: Request timeout (default: 60 seconds)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        httpClient: HTTPClient? = nil,
        maxRetries: Int = 3,
        timeout: TimeAmount = .seconds(60),
        enableLogging: Bool = false
    ) {
        self.httpClient = httpClient ?? HTTPClient(eventLoopGroupProvider: .singleton)
        self.maxRetries = maxRetries
        self.timeout = timeout
        self.enableLogging = enableLogging
    }

    /// Perform a POST request with JSON body
    ///
    /// - Parameters:
    ///   - url: The request URL
    ///   - headers: HTTP headers
    ///   - body: Request body as Data
    /// - Returns: Response body as Data
    /// - Throws: AIError if request fails
    public func post(
        url: String,
        headers: [(String, String)],
        body: Data
    ) async throws -> Data {
        return try await executeWithRetry {
            try await self.performRequest(
                url: url,
                method: .POST,
                headers: headers,
                body: body
            )
        }
    }

    /// Perform a GET request
    ///
    /// - Parameters:
    ///   - url: The request URL
    ///   - headers: HTTP headers
    /// - Returns: Response body as Data
    /// - Throws: AIError if request fails
    public func get(
        url: String,
        headers: [(String, String)]
    ) async throws -> Data {
        return try await executeWithRetry {
            try await self.performRequest(
                url: url,
                method: .GET,
                headers: headers,
                body: nil
            )
        }
    }

    /// Stream a POST request with Server-Sent Events
    ///
    /// - Parameters:
    ///   - url: The request URL
    ///   - headers: HTTP headers
    ///   - body: Request body as Data
    /// - Returns: AsyncThrowingStream of data chunks
    nonisolated public func streamPost(
        url: String,
        headers: [(String, String)],
        body: Data
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let requestURL = URL(string: url) else {
                        continuation.finish(throwing: AIError.invalidURL(url))
                        return
                    }

                    var request = HTTPClientRequest(url: requestURL.absoluteString)
                    request.method = .POST

                    // Set headers
                    for (key, value) in headers {
                        request.headers.add(name: key, value: value)
                    }

                    // Set body
                    request.body = .bytes(ByteBuffer(data: body))

                    if enableLogging {
                        print("[HTTP] Streaming POST \(url)")
                    }

                    // Execute request with streaming
                    let response = try await httpClient.execute(request, timeout: timeout)

                    guard response.status == .ok else {
                        let bodyData = try await response.body.collect(upTo: 1024 * 1024) // 1MB limit
                        let errorMessage = bodyData.getString(at: 0, length: bodyData.readableBytes) ?? ""
                        continuation.finish(throwing: mapHTTPError(status: response.status, message: errorMessage, provider: .anthropic))
                        return
                    }

                    // Stream response body
                    for try await buffer in response.body {
                        continuation.yield(Data(buffer: buffer))
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Shut down the HTTP client
    public func shutdown() async throws {
        try await httpClient.shutdown()
    }

    // MARK: - Private Methods

    private func performRequest(
        url: String,
        method: HTTPMethod,
        headers: [(String, String)],
        body: Data?
    ) async throws -> Data {
        guard let requestURL = URL(string: url) else {
            throw AIError.invalidURL(url)
        }

        var request = HTTPClientRequest(url: requestURL.absoluteString)
        request.method = method

        // Set headers
        for (key, value) in headers {
            request.headers.add(name: key, value: value)
        }

        // Set body if provided
        if let body = body {
            request.body = .bytes(ByteBuffer(data: body))
        }

        if enableLogging {
            print("[HTTP] \(method.rawValue) \(url)")
            print("[HTTP] Headers: \(headers)")
            if let body = body, let bodyString = String(data: body, encoding: .utf8) {
                print("[HTTP] Body: \(bodyString)")
            }
        }

        let response = try await httpClient.execute(request, timeout: timeout)

        // Collect response body
        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024) // 10MB limit

        if enableLogging {
            print("[HTTP] Status: \(response.status.code)")
            let bodyString = responseBody.getString(at: 0, length: responseBody.readableBytes) ?? ""
            print("[HTTP] Response: \(bodyString)")
        }

        // Handle error status codes
        guard response.status.code >= 200 && response.status.code < 300 else {
            let errorMessage = responseBody.getString(at: 0, length: responseBody.readableBytes) ?? ""
            throw mapHTTPError(status: response.status, message: errorMessage, provider: .anthropic)
        }

        return Data(buffer: responseBody)
    }

    private func executeWithRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        var attempt = 0

        while attempt <= maxRetries {
            do {
                return try await operation()
            } catch let error as AIError {
                lastError = error

                // Only retry on retryable errors
                guard error.isRetryable && attempt < maxRetries else {
                    throw error
                }

                // Exponential backoff
                let delay = min(pow(2.0, Double(attempt)), 32.0) // Max 32 seconds
                if enableLogging {
                    print("[HTTP] Retry attempt \(attempt + 1) after \(delay)s delay")
                }

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                attempt += 1
            } catch {
                // Non-AIError, don't retry
                throw error
            }
        }

        throw lastError ?? AIError.unknown(message: "Max retries exceeded")
    }

    nonisolated private func mapHTTPError(status: HTTPResponseStatus, message: String, provider: ProviderType) -> AIError {
        switch status.code {
        case 400:
            return .invalidRequest(message: message)
        case 401:
            return .invalidAPIKey(provider: provider, message: message)
        case 403:
            return .permissionDenied(provider: provider, message: message)
        case 404:
            return .notFound(resource: "endpoint", provider: provider)
        case 413:
            return .requestTooLarge(size: 0, limit: 0)
        case 429:
            // Try to extract retry-after from message
            return .rateLimitExceeded(provider: provider, retryAfter: nil)
        case 500:
            return .internalError(provider: provider, message: message)
        case 503:
            return .serviceUnavailable(provider: provider)
        case 529:
            return .overloaded(provider: provider)
        default:
            return .providerError(provider: provider, statusCode: Int(status.code), message: message)
        }
    }
}
