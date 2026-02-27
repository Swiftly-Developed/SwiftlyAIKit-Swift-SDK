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
/// - Server-Sent Events (SSE) streaming
/// - Proper error mapping
///
/// ## Overview
///
/// `HTTPClientManager` is the HTTP layer for all provider communications. It handles:
/// - Making HTTP requests with timeout
/// - Retrying failed requests (exponential backoff)
/// - Streaming Server-Sent Events
/// - Mapping HTTP status codes to ``AIError``
///
/// Uses a shared singleton HTTPClient to avoid shutdown issues.
///
/// ## Usage
///
/// ```swift
/// let manager = HTTPClientManager()
///
/// let data = try await manager.post(
///     url: "https://api.anthropic.com/v1/messages",
///     headers: [("x-api-key", apiKey)],
///     body: requestData
/// )
/// ```
///
/// ## Retry Logic
///
/// Automatically retries on:
/// - Network errors (connection failed, timeout)
/// - 5xx server errors (provider issues)
/// - 429 rate limit (with backoff)
///
/// Does NOT retry on:
/// - 4xx client errors (bad request, invalid key)
/// - Successful responses
///
/// ## Topics
///
/// ### Creating Managers
/// - ``init(httpClient:maxRetries:timeout:enableLogging:)``
///
/// ### HTTP Methods
/// - ``post(url:headers:body:context:)``
/// - ``get(url:headers:context:)``
/// - ``streamPost(url:headers:body:context:)``
///
/// ### Related Types
/// - ``AIError``
/// - ``LogContext``
///
/// ## See Also
/// - <doc:ArchitectureOverview>
/// - <doc:ErrorHandling>
public actor HTTPClientManager {
    /// Shared HTTPClient singleton - lives for app lifetime, no shutdown needed
    private static let sharedHTTPClient = HTTPClient(eventLoopGroupProvider: .singleton)

    private let httpClient: HTTPClient
    private let maxRetries: Int
    private let timeout: TimeAmount
    private let enableLogging: Bool

    /// Initialize a new HTTP client manager
    ///
    /// - Parameters:
    ///   - httpClient: Optional custom HTTP client (uses shared singleton if nil)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - timeout: Request timeout (default: 60 seconds)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        httpClient: HTTPClient? = nil,
        maxRetries: Int = 3,
        timeout: TimeAmount = .seconds(60),
        enableLogging: Bool = false
    ) {
        // Use shared singleton client by default to avoid shutdown issues
        self.httpClient = httpClient ?? Self.sharedHTTPClient
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
    ///   - context: Optional logging context for request correlation
    /// - Returns: Response body as Data
    /// - Throws: AIError if request fails
    public func post(
        url: String,
        headers: [(String, String)],
        body: Data,
        context: LogContext? = nil
    ) async throws -> Data {
        let httpContext = context ?? LogContext(operation: "POST \(extractPath(from: url))")

        await aiLog(.debug, "Starting POST request", context: httpContext, metadata: [
            "url": url,
            "bodySize": "\(body.count) bytes",
            "headerCount": "\(headers.count)"
        ])

        // Log URL components to help diagnose emptyHost errors
        await logURLComponents(url, context: httpContext)

        return try await executeWithRetry(context: httpContext) {
            try await self.performRequest(
                url: url,
                method: .POST,
                headers: headers,
                body: body,
                context: httpContext
            )
        }
    }

    /// Perform a GET request
    ///
    /// - Parameters:
    ///   - url: The request URL
    ///   - headers: HTTP headers
    ///   - context: Optional logging context for request correlation
    /// - Returns: Response body as Data
    /// - Throws: AIError if request fails
    public func get(
        url: String,
        headers: [(String, String)],
        context: LogContext? = nil
    ) async throws -> Data {
        let httpContext = context ?? LogContext(operation: "GET \(extractPath(from: url))")

        await aiLog(.debug, "Starting GET request", context: httpContext, metadata: [
            "url": url,
            "headerCount": "\(headers.count)"
        ])

        // Log URL components to help diagnose emptyHost errors
        await logURLComponents(url, context: httpContext)

        return try await executeWithRetry(context: httpContext) {
            try await self.performRequest(
                url: url,
                method: .GET,
                headers: headers,
                body: nil,
                context: httpContext
            )
        }
    }

    /// Stream a POST request with Server-Sent Events
    ///
    /// - Parameters:
    ///   - url: The request URL
    ///   - headers: HTTP headers
    ///   - body: Request body as Data
    ///   - context: Optional logging context for request correlation
    /// - Returns: AsyncThrowingStream of data chunks
    nonisolated public func streamPost(
        url: String,
        headers: [(String, String)],
        body: Data,
        context: LogContext? = nil
    ) -> AsyncThrowingStream<Data, Error> {
        let streamContext = context ?? LogContext(operation: "STREAM POST \(extractPathNonisolated(from: url))")

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    await aiLog(.debug, "Starting streaming POST request", context: streamContext, metadata: [
                        "url": url,
                        "bodySize": "\(body.count) bytes",
                        "headerCount": "\(headers.count)"
                    ])

                    // Log URL components to diagnose emptyHost errors
                    if let requestURL = URL(string: url) {
                        await aiLog(.debug, "URL components", context: streamContext, metadata: [
                            "scheme": requestURL.scheme ?? "nil",
                            "host": requestURL.host ?? "nil",
                            "port": requestURL.port.map(String.init) ?? "default",
                            "path": requestURL.path
                        ])
                    } else {
                        await aiLog(.error, "Invalid URL - failed to parse", context: streamContext, metadata: ["url": url])
                    }

                    guard let requestURL = URL(string: url) else {
                        await aiLog(.error, "Request failed - invalid URL", context: streamContext, metadata: ["url": url])
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

                    // Execute request with streaming
                    let response = try await self.httpClient.execute(request, timeout: self.timeout)

                    await aiLog(.debug, "Stream response received", context: streamContext, metadata: [
                        "status": "\(response.status.code)"
                    ])

                    guard response.status == .ok else {
                        let bodyData = try await response.body.collect(upTo: 1024 * 1024) // 1MB limit
                        let errorMessage = bodyData.getString(at: 0, length: bodyData.readableBytes) ?? ""
                        let error = self.mapHTTPError(status: response.status, message: errorMessage, provider: .anthropic)
                        await aiLog(.error, "Stream request failed", context: streamContext, metadata: [
                            "status": "\(response.status.code)",
                            "error": errorMessage.prefix(200).description
                        ])
                        continuation.finish(throwing: error)
                        return
                    }

                    // Stream response body
                    var chunkCount = 0
                    for try await buffer in response.body {
                        chunkCount += 1
                        continuation.yield(Data(buffer: buffer))
                    }

                    await aiLog(.info, "Stream completed", context: streamContext, metadata: [
                        "chunks": "\(chunkCount)"
                    ])

                    continuation.finish()
                } catch {
                    await aiLog(.error, "Stream request failed with exception", context: streamContext, metadata: [
                        "error": String(describing: error),
                        "errorType": String(describing: type(of: error))
                    ])
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Shut down the HTTP client
    ///
    /// Note: Only shuts down custom HTTP clients. The shared singleton client
    /// is never shut down as it lives for the app lifetime.
    public func shutdown() async throws {
        // Only shutdown if using a custom (non-shared) client
        if httpClient !== Self.sharedHTTPClient {
            try await httpClient.shutdown()
        }
    }

    // MARK: - Private Methods

    private func performRequest(
        url: String,
        method: HTTPMethod,
        headers: [(String, String)],
        body: Data?,
        context: LogContext? = nil
    ) async throws -> Data {
        guard let requestURL = URL(string: url) else {
            await aiLog(.error, "Invalid URL - failed to parse", context: context, metadata: ["url": url])
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

        await aiLog(.debug, "Executing HTTP request", context: context, metadata: [
            "method": method.rawValue,
            "url": url
        ])

        if enableLogging {
            await aiLog(.debug, "HTTP request details", context: context, metadata: [
                "method": method.rawValue,
                "url": url,
                "headers": "\(headers)",
                "bodySize": body.map { "\($0.count) bytes" } ?? "none"
            ])
        }

        let response: HTTPClientResponse
        do {
            response = try await httpClient.execute(request, timeout: timeout)
        } catch {
            await aiLog(.error, "HTTP request execution failed", context: context, metadata: [
                "error": String(describing: error),
                "errorType": String(describing: type(of: error))
            ])
            throw error
        }

        // Collect response body
        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024) // 10MB limit

        await aiLog(.debug, "HTTP response received", context: context, metadata: [
            "status": "\(response.status.code)",
            "responseSize": "\(responseBody.readableBytes) bytes"
        ])

        if enableLogging {
            let bodyString = responseBody.getString(at: 0, length: responseBody.readableBytes) ?? ""
            await aiLog(.debug, "HTTP response details", context: context, metadata: [
                "status": "\(response.status.code)",
                "response": String(bodyString.prefix(500))
            ])
        }

        // Handle error status codes
        guard response.status.code >= 200 && response.status.code < 300 else {
            let errorMessage = responseBody.getString(at: 0, length: responseBody.readableBytes) ?? ""
            let error = mapHTTPError(status: response.status, message: errorMessage, provider: .anthropic)
            await aiLog(.error, "HTTP request failed with error status", context: context, metadata: [
                "status": "\(response.status.code)",
                "error": errorMessage.prefix(200).description
            ])
            throw error
        }

        await aiLog(.info, "HTTP request completed successfully", context: context, metadata: [
            "status": "\(response.status.code)"
        ])

        return Data(buffer: responseBody)
    }

    private func executeWithRetry<T>(context: LogContext? = nil, _ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        var attempt = 0

        while attempt <= maxRetries {
            do {
                return try await operation()
            } catch let error as AIError {
                lastError = error

                // Only retry on retryable errors
                guard error.isRetryable && attempt < maxRetries else {
                    await aiLog(.error, "Request failed (not retryable or max retries reached)", context: context, metadata: [
                        "attempt": "\(attempt + 1)",
                        "maxRetries": "\(maxRetries)",
                        "isRetryable": "\(error.isRetryable)",
                        "error": error.localizedDescription
                    ])
                    throw error
                }

                // Exponential backoff
                let delay = min(pow(2.0, Double(attempt)), 32.0) // Max 32 seconds
                await aiLog(.warning, "Request failed, will retry", context: context, metadata: [
                    "attempt": "\(attempt + 1)",
                    "maxRetries": "\(maxRetries)",
                    "delaySeconds": "\(delay)",
                    "error": error.localizedDescription
                ])

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                attempt += 1
            } catch {
                // Non-AIError - log it and don't retry
                await aiLog(.error, "Request failed with non-AIError", context: context, metadata: [
                    "error": String(describing: error),
                    "errorType": String(describing: type(of: error))
                ])
                throw error
            }
        }

        throw lastError ?? AIError.unknown(message: "Max retries exceeded")
    }

    // MARK: - Logging Helpers

    /// Log URL components to help diagnose emptyHost and other URL issues
    private func logURLComponents(_ urlString: String, context: LogContext?) async {
        if let url = URL(string: urlString) {
            await aiLog(.debug, "URL components", context: context, metadata: [
                "scheme": url.scheme ?? "nil",
                "host": url.host ?? "nil",
                "port": url.port.map(String.init) ?? "default",
                "path": url.path.isEmpty ? "/" : url.path
            ])
        } else {
            await aiLog(.error, "Failed to parse URL", context: context, metadata: ["rawURL": urlString])
        }
    }

    /// Extract path from URL for logging context (actor-isolated version)
    private func extractPath(from urlString: String) -> String {
        if let url = URL(string: urlString) {
            return url.path.isEmpty ? "/" : url.path
        }
        return urlString
    }

    /// Extract path from URL for logging context (nonisolated version for streamPost)
    nonisolated private func extractPathNonisolated(from urlString: String) -> String {
        if let url = URL(string: urlString) {
            return url.path.isEmpty ? "/" : url.path
        }
        return urlString
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
