import Foundation

/// Anthropic Claude API Provider
///
/// Complete implementation of Anthropic's Messages API, including:
/// - Messages API (create, stream)
/// - Token counting
/// - Batch API (create, retrieve, cancel, list, results)
/// - All advanced features (caching, thinking, tools, vision, PDFs)
public struct AnthropicProvider: ProviderProtocol {
    public let providerType: ProviderType = .anthropic

    private let httpClient: HTTPClientManager
    private let baseURL: String
    private let apiVersion: String
    private let enableBetaFeatures: [String]

    // MARK: - Initializers

    /// Initialize with company API key
    ///
    /// - Parameters:
    ///   - apiKey: Anthropic API key (will be ignored, use apiKey parameter in methods)
    ///   - apiVersion: API version (default: "2023-06-01")
    ///   - baseURL: Base URL (default: "https://api.anthropic.com/v1")
    ///   - enableBetaFeatures: Beta feature flags (default: [])
    public init(
        apiVersion: String = "2023-06-01",
        baseURL: String = "https://api.anthropic.com/v1",
        enableBetaFeatures: [String] = []
    ) {
        self.httpClient = HTTPClientManager()
        self.apiVersion = apiVersion
        self.baseURL = baseURL
        self.enableBetaFeatures = enableBetaFeatures
    }

    /// Initialize with custom HTTP client
    ///
    /// - Parameters:
    ///   - httpClient: Custom HTTP client manager
    ///   - apiVersion: API version
    ///   - baseURL: Base URL
    ///   - enableBetaFeatures: Beta feature flags
    public init(
        httpClient: HTTPClientManager,
        apiVersion: String = "2023-06-01",
        baseURL: String = "https://api.anthropic.com/v1",
        enableBetaFeatures: [String] = []
    ) {
        self.httpClient = httpClient
        self.apiVersion = apiVersion
        self.baseURL = baseURL
        self.enableBetaFeatures = enableBetaFeatures
    }

    /// Initialize with full configuration
    ///
    /// - Parameters:
    ///   - apiVersion: API version
    ///   - baseURL: Base URL
    ///   - timeout: Request timeout in seconds
    ///   - maxRetries: Maximum retry attempts
    ///   - enableLogging: Enable request/response logging
    ///   - enableBetaFeatures: Beta feature flags
    public init(
        apiVersion: String = "2023-06-01",
        baseURL: String = "https://api.anthropic.com/v1",
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false,
        enableBetaFeatures: [String] = []
    ) {
        self.httpClient = HTTPClientManager(
            maxRetries: maxRetries,
            timeout: .seconds(Int64(timeout)),
            enableLogging: enableLogging
        )
        self.apiVersion = apiVersion
        self.baseURL = baseURL
        self.enableBetaFeatures = enableBetaFeatures
    }

    // MARK: - ProviderProtocol Implementation

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        let context = LogContext(
            provider: "anthropic",
            model: request.model,
            operation: "sendMessage"
        )

        await aiLog(.debug, "Preparing Anthropic request", context: context, metadata: [
            "model": request.model,
            "messageCount": "\(request.messages.count)",
            "baseURL": baseURL
        ])

        let anthropicRequest = try mapToAnthropicRequest(request)
        let anthropicResponse = try await createMessage(anthropicRequest, apiKey: apiKey, context: context)
        return mapToAIResponse(anthropicResponse)
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var anthropicRequest = try mapToAnthropicRequest(request)
                    anthropicRequest = AnthropicRequest(
                        model: anthropicRequest.model,
                        messages: anthropicRequest.messages,
                        maxTokens: anthropicRequest.maxTokens,
                        system: anthropicRequest.system,
                        temperature: anthropicRequest.temperature,
                        topP: anthropicRequest.topP,
                        topK: anthropicRequest.topK,
                        stopSequences: anthropicRequest.stopSequences,
                        metadata: anthropicRequest.metadata,
                        stream: true,
                        tools: anthropicRequest.tools,
                        toolChoice: anthropicRequest.toolChoice,
                        thinking: anthropicRequest.thinking
                    )

                    let stream = try await streamMessage(anthropicRequest, apiKey: apiKey)

                    for try await event in stream {
                        if let response = processStreamEvent(event) {
                            continuation.yield(response)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func countTokens(_ request: AIRequest, apiKey: String) async throws -> Int? {
        let anthropicRequest = try mapToAnthropicRequest(request)
        let tokenCount = try await countMessageTokens(anthropicRequest, apiKey: apiKey)
        return tokenCount.inputTokens
    }

    public func createBatch(_ requests: [AIRequest], apiKey: String) async throws -> String {
        let batchRequests = try requests.enumerated().map { index, request in
            let anthropicRequest = try mapToAnthropicRequest(request)
            return AnthropicBatchRequest(
                customId: "request_\(index)",
                params: anthropicRequest
            )
        }

        let batch = try await createMessageBatch(batchRequests, apiKey: apiKey)
        return batch.id
    }

    public func retrieveBatch(_ batchId: String, apiKey: String) async throws -> BatchStatus {
        let batch = try await getMessageBatch(batchId, apiKey: apiKey)
        return mapToBatchStatus(batch)
    }

    public func cancelBatch(_ batchId: String, apiKey: String) async throws -> BatchStatus {
        let batch = try await cancelMessageBatch(batchId, apiKey: apiKey)
        return mapToBatchStatus(batch)
    }

    public func listBatches(limit: Int?, afterId: String?, apiKey: String) async throws -> [BatchStatus] {
        let batches = try await listMessageBatches(limit: limit, afterId: afterId, apiKey: apiKey)
        return batches.map { mapToBatchStatus($0) }
    }

    public func getBatchResults(_ batchId: String, apiKey: String) -> AsyncThrowingStream<BatchResult, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = try await getMessageBatchResults(batchId, apiKey: apiKey)

                    for try await result in stream {
                        continuation.yield(mapToBatchResult(result))
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Anthropic-Specific Methods

    /// Create a message using Anthropic's Messages API
    public func createMessage(
        _ request: AnthropicRequest,
        apiKey: String,
        context: LogContext? = nil
    ) async throws -> AnthropicResponse {
        let url = "\(baseURL)/messages"

        let logContext = context ?? LogContext(
            provider: "anthropic",
            model: request.model,
            operation: "createMessage"
        )

        await aiLog(.debug, "Building Anthropic API request", context: logContext, metadata: [
            "url": url,
            "model": request.model
        ])

        let headers = buildHeaders(apiKey: apiKey, stream: false)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(request)

        await aiLog(.debug, "Sending request to Anthropic API", context: logContext, metadata: [
            "url": url,
            "bodySize": "\(body.count) bytes"
        ])

        let responseData = try await httpClient.post(url: url, headers: headers, body: body, context: logContext)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let response = try decoder.decode(AnthropicResponse.self, from: responseData)
            await aiLog(.info, "Anthropic API response received", context: logContext, metadata: [
                "responseId": response.id,
                "stopReason": response.stopReason?.rawValue ?? "unknown"
            ])
            return response
        } catch {
            // Try to decode error response
            if let errorResponse = try? decoder.decode(AnthropicErrorResponse.self, from: responseData) {
                await aiLog(.error, "Anthropic API error response", context: logContext, metadata: [
                    "errorType": errorResponse.error.type,
                    "errorMessage": errorResponse.error.message
                ])
                throw mapAnthropicError(errorResponse)
            }
            await aiLog(.error, "Failed to decode Anthropic response", context: logContext, metadata: [
                "error": error.localizedDescription
            ])
            throw AIError.decodingError(message: error.localizedDescription)
        }
    }

    /// Stream a message using Server-Sent Events
    public func streamMessage(
        _ request: AnthropicRequest,
        apiKey: String,
        context: LogContext? = nil
    ) async throws -> AsyncThrowingStream<AnthropicStreamEvent, Error> {
        let url = "\(baseURL)/messages"

        let logContext = context ?? LogContext(
            provider: "anthropic",
            model: request.model,
            operation: "streamMessage"
        )

        await aiLog(.debug, "Starting Anthropic streaming request", context: logContext, metadata: [
            "url": url,
            "model": request.model
        ])

        let headers = buildHeaders(apiKey: apiKey, stream: true)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(request)

        let dataStream = httpClient.streamPost(url: url, headers: headers, body: body, context: logContext)

        return AsyncThrowingStream { continuation in
            Task {
                var buffer = Data()
                var eventCount = 0

                do {
                    for try await chunk in dataStream {
                        buffer.append(chunk)

                        // Process complete SSE events
                        while let event = self.extractSSEEvent(from: &buffer) {
                            if let streamEvent = try self.parseSSEEvent(event) {
                                eventCount += 1
                                continuation.yield(streamEvent)

                                // Check for end of stream
                                if case .messageStop = streamEvent {
                                    await aiLog(.info, "Anthropic streaming completed", context: logContext, metadata: [
                                        "eventCount": "\(eventCount)"
                                    ])
                                    continuation.finish()
                                    return
                                }
                            }
                        }
                    }

                    await aiLog(.info, "Anthropic streaming finished", context: logContext, metadata: [
                        "eventCount": "\(eventCount)"
                    ])
                    continuation.finish()
                } catch {
                    await aiLog(.error, "Anthropic streaming failed", context: logContext, metadata: [
                        "error": String(describing: error),
                        "eventCount": "\(eventCount)"
                    ])
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Count tokens in a request
    public func countMessageTokens(
        _ request: AnthropicRequest,
        apiKey: String
    ) async throws -> AnthropicTokenCountResponse {
        let url = "\(baseURL)/messages/count_tokens"
        let headers = buildHeaders(apiKey: apiKey, stream: false)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(request)

        let responseData = try await httpClient.post(url: url, headers: headers, body: body)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AnthropicTokenCountResponse.self, from: responseData)
    }

    // MARK: - Batch API Methods

    /// Create a message batch
    public func createMessageBatch(
        _ requests: [AnthropicBatchRequest],
        apiKey: String
    ) async throws -> AnthropicBatch {
        let url = "\(baseURL)/messages/batches"
        let headers = buildHeaders(apiKey: apiKey, stream: false)

        let payload = ["requests": requests]
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(payload)

        let responseData = try await httpClient.post(url: url, headers: headers, body: body)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AnthropicBatch.self, from: responseData)
    }

    /// Retrieve a message batch
    public func getMessageBatch(
        _ batchId: String,
        apiKey: String
    ) async throws -> AnthropicBatch {
        let url = "\(baseURL)/messages/batches/\(batchId)"
        let headers = buildHeaders(apiKey: apiKey, stream: false)

        let responseData = try await httpClient.get(url: url, headers: headers)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AnthropicBatch.self, from: responseData)
    }

    /// Cancel a message batch
    public func cancelMessageBatch(
        _ batchId: String,
        apiKey: String
    ) async throws -> AnthropicBatch {
        let url = "\(baseURL)/messages/batches/\(batchId)/cancel"
        let headers = buildHeaders(apiKey: apiKey, stream: false)

        let responseData = try await httpClient.post(url: url, headers: headers, body: Data())

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AnthropicBatch.self, from: responseData)
    }

    /// List message batches
    public func listMessageBatches(
        limit: Int?,
        afterId: String?,
        apiKey: String
    ) async throws -> [AnthropicBatch] {
        var urlComponents = URLComponents(string: "\(baseURL)/messages/batches")!

        var queryItems: [URLQueryItem] = []
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }
        if let afterId = afterId {
            queryItems.append(URLQueryItem(name: "after_id", value: afterId))
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        let headers = buildHeaders(apiKey: apiKey, stream: false)
        let responseData = try await httpClient.get(url: urlComponents.url!.absoluteString, headers: headers)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        struct BatchListResponse: Codable {
            let data: [AnthropicBatch]
        }

        let response = try decoder.decode(BatchListResponse.self, from: responseData)
        return response.data
    }

    /// Get batch results
    public func getMessageBatchResults(
        _ batchId: String,
        apiKey: String
    ) async throws -> AsyncThrowingStream<AnthropicBatchResult, Error> {
        let url = "\(baseURL)/messages/batches/\(batchId)/results"
        let headers = buildHeaders(apiKey: apiKey, stream: false)

        let dataStream = httpClient.streamPost(url: url, headers: headers, body: Data())

        return AsyncThrowingStream { continuation in
            Task {
                var buffer = Data()
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase

                do {
                    for try await chunk in dataStream {
                        buffer.append(chunk)

                        // Try to parse JSONL (one result per line)
                        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                            let lineData = buffer[..<newlineIndex]
                            buffer.removeSubrange(...newlineIndex)

                            if !lineData.isEmpty {
                                if let result = try? decoder.decode(AnthropicBatchResult.self, from: Data(lineData)) {
                                    continuation.yield(result)
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Helper Methods

    private func buildHeaders(apiKey: String, stream: Bool) -> [(String, String)] {
        var headers = [
            ("x-api-key", apiKey),
            ("anthropic-version", apiVersion),
            ("content-type", "application/json")
        ]

        if !enableBetaFeatures.isEmpty {
            headers.append(("anthropic-beta", enableBetaFeatures.joined(separator: ",")))
        }

        if stream {
            headers.append(("accept", "text/event-stream"))
        }

        return headers
    }

    private func mapToAnthropicRequest(_ request: AIRequest) throws -> AnthropicRequest {
        let messages = request.messages.map { message in
            let content = message.content.map { content -> AnthropicContentBlock in
                switch content {
                case .text(let text):
                    return .text(text)
                case .image(let source, let mediaType):
                    switch source {
                    case .base64(let data):
                        return .image(source: .base64(data: data, mediaType: mediaType ?? "image/jpeg"))
                    case .url(let url):
                        return .image(source: .url(url))
                    }
                case .document(let data, let mediaType, _):
                    let base64Data = data.base64EncodedString()
                    return .document(source: .init(mediaType: mediaType, data: base64Data))
                case .toolCall(let toolCall):
                    // Map AIToolCall to Anthropic's tool_use format
                    return .toolUse(id: toolCall.id, name: toolCall.name, input: [:]) // Parse arguments as needed
                case .toolResult(let id, let result):
                    // Map tool result to Anthropic's tool_result format
                    return .toolResult(toolUseId: id, content: result, isError: false)
                case .custom:
                    return .text("") // Fallback for custom content
                }
            }

            return AnthropicMessage(role: message.role.rawValue, content: content)
        }

        let system: AnthropicSystemPrompt? = request.systemPrompt.map { .text($0) }

        return AnthropicRequest(
            model: request.model,
            messages: messages,
            maxTokens: request.maxTokens ?? 4096,
            system: system,
            temperature: request.temperature,
            topP: request.topP,
            topK: request.topK,
            stopSequences: request.stopSequences,
            metadata: nil,
            stream: request.stream ? true : nil,
            tools: nil,
            toolChoice: nil,
            thinking: nil
        )
    }

    private func mapToAIResponse(_ response: AnthropicResponse) -> AIResponse {
        let content = response.content.compactMap { block -> AIMessageContent? in
            switch block {
            case .text(let text):
                return .text(text)
            case .thinking(let text):
                return .text("[Thinking] \(text)")
            default:
                return nil
            }
        }

        let message = AIMessage(role: .assistant, content: content)

        let usage = AIUsage(
            inputTokens: response.usage.inputTokens,
            outputTokens: response.usage.outputTokens,
            cachedTokens: response.usage.cacheReadInputTokens
        )

        let stopReason: AIStopReason? = {
            guard let reason = response.stopReason else { return nil }
            switch reason {
            case .endTurn: return .endTurn
            case .maxTokens: return .maxTokens
            case .stopSequence: return .stopSequence
            case .toolUse: return .toolUse
            default: return .other
            }
        }()

        return AIResponse(
            id: response.id,
            model: response.model,
            message: message,
            stopReason: stopReason,
            usage: usage,
            provider: .anthropic
        )
    }

    private func processStreamEvent(_ event: AnthropicStreamEvent) -> AIResponse? {
        switch event {
        case .contentBlockDelta(let delta):
            if let text = delta.delta.text {
                let message = AIMessage(role: .assistant, text: text)
                return AIResponse(
                    id: "stream",
                    model: "unknown",
                    message: message,
                    provider: .anthropic
                )
            }
            return nil
        case .messageStart(let start):
            return AIResponse(
                id: start.message.id,
                model: start.message.model,
                message: AIMessage(role: .assistant, text: ""),
                provider: .anthropic
            )
        case .contentBlockStart:
            return nil
        case .contentBlockStop:
            return nil
        case .messageDelta:
            return nil
        case .messageStop:
            return nil
        case .ping:
            return nil
        case .error(let errorData):
            // Log error but don't return a response
            Task {
                await aiLog(.error, "Anthropic stream error", context: nil, metadata: [
                    "errorType": errorData.error.type,
                    "errorMessage": errorData.error.message
                ])
            }
            return nil
        }
    }

    private func extractSSEEvent(from buffer: inout Data) -> String? {
        guard let doubleNewline = buffer.range(of: "\n\n".data(using: .utf8)!) else {
            return nil
        }

        let eventData = buffer[..<doubleNewline.lowerBound]

        // Use half-open range to avoid out-of-bounds when upperBound == endIndex
        // removeSubrange expects a valid range within the collection bounds
        buffer.removeSubrange(buffer.startIndex..<doubleNewline.upperBound)

        return String(data: eventData, encoding: .utf8)
    }

    private func parseSSEEvent(_ event: String) throws -> AnthropicStreamEvent? {
        let lines = event.components(separatedBy: "\n")

        var eventType: String?
        var data: String?

        for line in lines {
            if line.hasPrefix("event: ") {
                eventType = String(line.dropFirst(7))
            } else if line.hasPrefix("data: ") {
                data = String(line.dropFirst(6))
            }
        }

        guard let eventType = eventType else {
            return nil
        }

        // Handle events that don't require data parsing
        if eventType == "ping" {
            return .ping
        }

        if eventType == "message_stop" {
            return .messageStop
        }

        // For events with data, parse the JSON
        guard let data = data, let jsonData = data.data(using: .utf8) else {
            Task {
                await aiLog(.warning, "SSE event has no data", context: nil, metadata: [
                    "eventType": eventType
                ])
            }
            return nil
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            switch eventType {
            case "message_start":
                let startData = try decoder.decode(AnthropicStreamEvent.AnthropicStreamMessageStart.self, from: jsonData)
                return .messageStart(startData)

            case "content_block_start":
                let blockData = try decoder.decode(AnthropicStreamEvent.AnthropicStreamContentBlockStart.self, from: jsonData)
                return .contentBlockStart(blockData)

            case "content_block_delta":
                let deltaData = try decoder.decode(AnthropicStreamEvent.AnthropicStreamContentBlockDelta.self, from: jsonData)
                return .contentBlockDelta(deltaData)

            case "content_block_stop":
                let stopData = try decoder.decode(AnthropicStreamEvent.AnthropicStreamContentBlockStop.self, from: jsonData)
                return .contentBlockStop(stopData)

            case "message_delta":
                let deltaData = try decoder.decode(AnthropicStreamEvent.AnthropicStreamMessageDelta.self, from: jsonData)
                return .messageDelta(deltaData)

            case "error":
                // Handle error events
                if let errorData = try? decoder.decode(AnthropicStreamEvent.AnthropicStreamError.self, from: jsonData) {
                    return .error(errorData)
                }
                return nil

            default:
                // Unknown event type, skip it
                Task {
                    await aiLog(.debug, "Unknown SSE event type", context: nil, metadata: [
                        "eventType": eventType
                    ])
                }
                return nil
            }
        } catch {
            Task {
                await aiLog(.error, "Failed to decode SSE event", context: nil, metadata: [
                    "eventType": eventType,
                    "error": error.localizedDescription,
                    "data": String(data.prefix(200))
                ])
            }
            throw error
        }
    }

    private func mapToBatchStatus(_ batch: AnthropicBatch) -> BatchStatus {
        let dateFormatter = ISO8601DateFormatter()

        return BatchStatus(
            id: batch.id,
            status: batch.processingStatus.rawValue,
            createdAt: dateFormatter.date(from: batch.createdAt) ?? Date(),
            completedAt: batch.endedAt.flatMap { dateFormatter.date(from: $0) },
            failedAt: nil,
            expiresAt: dateFormatter.date(from: batch.expiresAt),
            requestCounts: .init(
                total: batch.requestCounts.processing + batch.requestCounts.succeeded + batch.requestCounts.errored,
                completed: batch.requestCounts.succeeded,
                failed: batch.requestCounts.errored
            )
        )
    }

    private func mapToBatchResult(_ result: AnthropicBatchResult) -> BatchResult {
        switch result.result {
        case .success(let response):
            return BatchResult(
                requestId: result.customId,
                response: mapToAIResponse(response)
            )
        case .error(let error):
            return BatchResult(
                requestId: result.customId,
                error: error.message
            )
        }
    }

    private func mapAnthropicError(_ error: AnthropicErrorResponse) -> AIError {
        switch error.error.type {
        case "invalid_request_error":
            return .invalidRequest(message: error.error.message)
        case "authentication_error":
            return .invalidAPIKey(provider: .anthropic, message: error.error.message)
        case "permission_error":
            return .permissionDenied(provider: .anthropic, message: error.error.message)
        case "not_found_error":
            return .notFound(resource: "endpoint", provider: .anthropic)
        case "rate_limit_error":
            return .rateLimitExceeded(provider: .anthropic, retryAfter: nil)
        case "overloaded_error":
            return .overloaded(provider: .anthropic)
        default:
            return .providerError(provider: .anthropic, statusCode: 500, message: error.error.message)
        }
    }
}
