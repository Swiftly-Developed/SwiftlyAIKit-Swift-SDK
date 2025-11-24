import Vapor
import SwiftlyAIKit

/// Vapor Request extension for AI Gateway access
///
/// Provides convenient methods to interact with AI providers from route handlers.
///
/// Usage in routes:
/// ```swift
/// app.post("chat") { req async throws -> AIResponse in
///     let prompt = try req.content.decode(ChatRequest.self)
///     let aiRequest = AIRequest(model: "claude-sonnet-4-5", prompt: prompt.text)
///     return try await req.ai.sendMessage(aiRequest)
/// }
/// ```
extension Request {
    /// Access the AI Gateway instance
    ///
    /// Usage:
    /// ```swift
    /// let response = try await req.ai.sendMessage(request)
    /// ```
    public var ai: AIGateway {
        application.ai
    }

    /// Extract client API key from request headers
    ///
    /// Checks the following headers in order:
    /// 1. `X-API-Key`
    /// 2. `Authorization` (with or without "Bearer " prefix)
    ///
    /// Usage:
    /// ```swift
    /// let clientKey = req.clientAPIKey
    /// let response = try await req.ai.sendMessage(request, clientAPIKey: clientKey)
    /// ```
    public var clientAPIKey: String? {
        // Check X-API-Key header
        if let apiKey = headers["X-API-Key"].first {
            return apiKey
        }

        // Check Authorization header
        if let auth = headers[.authorization].first {
            // Remove "Bearer " prefix if present
            if auth.lowercased().hasPrefix("bearer ") {
                return String(auth.dropFirst(7))
            }
            return auth
        }

        return nil
    }
}

// MARK: - Convenience Methods

extension Request {
    /// Send a message to an AI provider (convenience method)
    ///
    /// - Parameters:
    ///   - request: AI request
    ///   - provider: Provider to use (optional, uses default if not specified)
    ///   - useClientKey: Whether to extract and use client API key from headers (default: true)
    /// - Returns: AI response
    /// - Throws: AIError on failure
    ///
    /// Usage:
    /// ```swift
    /// let response = try await req.sendAIMessage(
    ///     AIRequest(model: "claude-sonnet-4-5", prompt: "Hello!")
    /// )
    /// ```
    public func sendAIMessage(
        _ request: AIRequest,
        to provider: ProviderType? = nil,
        useClientKey: Bool = true
    ) async throws -> AIResponse {
        let clientKey = useClientKey ? clientAPIKey : nil
        return try await ai.sendMessage(request, to: provider, clientAPIKey: clientKey)
    }

    /// Stream a message from an AI provider (convenience method)
    ///
    /// - Parameters:
    ///   - request: AI request
    ///   - provider: Provider to use (optional, uses default if not specified)
    ///   - useClientKey: Whether to extract and use client API key from headers (default: true)
    /// - Returns: AsyncThrowingStream of responses
    ///
    /// Usage:
    /// ```swift
    /// let stream = req.streamAIMessage(
    ///     AIRequest(model: "claude-sonnet-4-5", prompt: "Hello!")
    /// )
    /// for try await response in stream {
    ///     // Handle each chunk
    /// }
    /// ```
    public func streamAIMessage(
        _ request: AIRequest,
        from provider: ProviderType? = nil,
        useClientKey: Bool = true
    ) -> AsyncThrowingStream<AIResponse, Error> {
        let clientKey = useClientKey ? clientAPIKey : nil
        let gateway = ai

        return AsyncThrowingStream { continuation in
            Task {
                let stream = await gateway.streamMessage(request, to: provider, clientAPIKey: clientKey)
                do {
                    for try await response in stream {
                        continuation.yield(response)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Count tokens in a request (convenience method)
    ///
    /// - Parameters:
    ///   - request: AI request
    ///   - provider: Provider to use (optional, uses default if not specified)
    ///   - useClientKey: Whether to extract and use client API key from headers (default: true)
    /// - Returns: Token count (nil if provider doesn't support)
    /// - Throws: AIError on failure
    ///
    /// Usage:
    /// ```swift
    /// let tokenCount = try await req.countAITokens(
    ///     AIRequest(model: "claude-sonnet-4-5", prompt: "Hello!")
    /// )
    /// ```
    public func countAITokens(
        _ request: AIRequest,
        for provider: ProviderType? = nil,
        useClientKey: Bool = true
    ) async throws -> Int? {
        let clientKey = useClientKey ? clientAPIKey : nil
        return try await ai.countTokens(request, for: provider, clientAPIKey: clientKey)
    }

    /// Create a batch of messages (convenience method)
    ///
    /// - Parameters:
    ///   - requests: Array of AI requests
    ///   - provider: Provider to use (optional, uses default if not specified)
    ///   - useClientKey: Whether to extract and use client API key from headers (default: true)
    /// - Returns: Batch ID
    /// - Throws: AIError on failure
    ///
    /// Usage:
    /// ```swift
    /// let batchId = try await req.createAIBatch([request1, request2, request3])
    /// ```
    public func createAIBatch(
        _ requests: [AIRequest],
        for provider: ProviderType? = nil,
        useClientKey: Bool = true
    ) async throws -> String {
        let clientKey = useClientKey ? clientAPIKey : nil
        return try await ai.createBatch(requests, for: provider, clientAPIKey: clientKey)
    }

    /// Retrieve batch status (convenience method)
    ///
    /// - Parameters:
    ///   - batchId: Batch identifier
    ///   - provider: Provider to use (optional, uses default if not specified)
    ///   - useClientKey: Whether to extract and use client API key from headers (default: true)
    /// - Returns: Batch status
    /// - Throws: AIError on failure
    ///
    /// Usage:
    /// ```swift
    /// let status = try await req.retrieveAIBatch("batch_123")
    /// ```
    public func retrieveAIBatch(
        _ batchId: String,
        from provider: ProviderType? = nil,
        useClientKey: Bool = true
    ) async throws -> BatchStatus {
        let clientKey = useClientKey ? clientAPIKey : nil
        return try await ai.retrieveBatch(batchId, from: provider, clientAPIKey: clientKey)
    }
}

// MARK: - Response Helpers

extension Request {
    /// Create an EventStream response for streaming AI responses
    ///
    /// - Parameter stream: AsyncThrowingStream of AI responses
    /// - Returns: Response with text/event-stream content type
    ///
    /// Usage:
    /// ```swift
    /// app.post("stream") { req async throws -> Response in
    ///     let aiRequest = AIRequest(model: "claude-sonnet-4-5", prompt: "Hello!")
    ///     let stream = req.streamAIMessage(aiRequest)
    ///     return req.aiStreamResponse(stream)
    /// }
    /// ```
    public func aiStreamResponse(
        _ stream: AsyncThrowingStream<AIResponse, Error>
    ) -> Response {
        let response = Response()
        response.headers.contentType = .init(type: "text", subType: "event-stream")
        response.headers.replaceOrAdd(name: .cacheControl, value: "no-cache")
        response.headers.replaceOrAdd(name: .connection, value: "keep-alive")

        response.body = .init(stream: { writer in
            Task {
                do {
                    for try await aiResponse in stream {
                        // Send SSE event
                        let jsonData = try JSONEncoder().encode(aiResponse)
                        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                        try await writer.write(.buffer(.init(string: "data: \(jsonString)\n\n")))
                    }

                    // Send completion event
                    try await writer.write(.buffer(.init(string: "data: [DONE]\n\n")))
                    try await writer.write(.end)
                } catch {
                    // Send error event
                    let errorMessage = error.localizedDescription
                    try? await writer.write(.buffer(.init(string: "event: error\ndata: \(errorMessage)\n\n")))
                    try? await writer.write(.end)
                }
            }
        })

        return response
    }
}
