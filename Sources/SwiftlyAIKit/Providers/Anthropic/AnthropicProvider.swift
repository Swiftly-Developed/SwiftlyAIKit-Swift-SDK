import Foundation

/// Anthropic Claude API Provider
///
/// Complete implementation of Anthropic's Messages API with full support for Claude models.
///
/// ## Overview
///
/// `AnthropicProvider` implements all Anthropic Claude features:
/// - Messages API (create, stream)
/// - Token counting
/// - Batch API (async bulk processing)
/// - Prompt caching (90% cost reduction)
/// - Extended thinking mode
/// - Tool calling
/// - Vision (images and PDFs)
///
/// ## Basic Usage
///
/// ```swift
/// let provider = AnthropicProvider()
/// let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Hello")
/// let response = try await provider.sendMessage(request, apiKey: "sk-ant-...")
/// ```
///
/// ## With Beta Features
///
/// ```swift
/// let provider = AnthropicProvider(
///     enableBetaFeatures: ["prompt-caching-2024-07-31"]
/// )
/// ```
///
/// ## Topics
///
/// ### Creating Providers
/// - ``init(apiVersion:baseURL:enableBetaFeatures:)``
/// - ``init(httpClient:apiVersion:baseURL:enableBetaFeatures:)``
/// - ``init(apiVersion:baseURL:timeout:maxRetries:enableLogging:enableBetaFeatures:)``
///
/// ### ProviderProtocol Implementation
/// - ``providerType``
/// - ``sendMessage(_:apiKey:)``
/// - ``streamMessage(_:apiKey:)``
/// - ``countTokens(_:apiKey:)``
/// - ``createBatch(_:apiKey:)``
/// - ``retrieveBatch(_:apiKey:)``
/// - ``cancelBatch(_:apiKey:)``
/// - ``listBatches(limit:afterId:apiKey:)``
/// - ``getBatchResults(_:apiKey:)``
/// - ``listModels(apiKey:)``
///
/// ### Related Types
/// - ``ProviderProtocol``
/// - ``AIRequest``
/// - ``AIResponse``
/// - ``BatchStatus``
/// - ``BatchResult``
///
/// ## See Also
/// - <doc:AnthropicGuide>
/// - <doc:PromptCaching>
/// - <doc:BatchProcessing>
/// - <doc:ToolCalling>
// swiftlint:disable:next type_body_length
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
                        thinking: anthropicRequest.thinking,
                        rawMessages: anthropicRequest.rawMessages
                    )

                    let stream = try await streamMessage(anthropicRequest, apiKey: apiKey)

                    var streamModel = anthropicRequest.model
                    var streamId = "stream"
                    // Accumulate tool_use blocks so we can emit a complete tool call
                    // (with fully-assembled arguments) once each block stops.
                    var toolAccumulator = ToolStreamAccumulator()

                    for try await event in stream {
                        if var response = processStreamEvent(event) {
                            // Capture model and id from message_start
                            if response.model != "unknown" {
                                streamModel = response.model
                            }
                            if response.id != "stream" {
                                streamId = response.id
                            }
                            // Inject tracked model and id into all events
                            response = AIResponse(
                                id: streamId,
                                model: streamModel,
                                message: response.message,
                                stopReason: response.stopReason,
                                usage: response.usage,
                                provider: response.provider,
                                providerData: response.providerData
                            )
                            continuation.yield(response)
                        }

                        // Tool-use argument accumulation (surfaces a complete tool block on stop).
                        if let streamed = toolAccumulator.handle(event) {
                            switch streamed {
                            case .client(let index, let toolCall):
                                continuation.yield(AIResponse(
                                    id: streamId,
                                    model: streamModel,
                                    message: AIMessage(role: .assistant, content: [.toolCall(toolCall)]),
                                    provider: .anthropic,
                                    providerData: [
                                        "streamEvent": AnyCodable("tool_use_complete"),
                                        "index": AnyCodable(index)
                                    ]
                                ))
                            case .server(let index, let id, let name, let input):
                                // Server tool (e.g. web_search) — not a client call; surface on providerData.
                                continuation.yield(AIResponse(
                                    id: streamId,
                                    model: streamModel,
                                    message: AIMessage(role: .assistant, text: ""),
                                    provider: .anthropic,
                                    providerData: [
                                        "streamEvent": AnyCodable("server_tool_use_complete"),
                                        "serverToolUse": AnyCodable([
                                            "id": id,
                                            "name": name,
                                            "input": input
                                        ]),
                                        "index": AnyCodable(index)
                                    ]
                                ))
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

        let webSearchBeta = detectWebSearchBeta(tools: request.tools)
        let headers = buildHeaders(apiKey: apiKey, stream: false, additionalBetaFeatures: webSearchBeta)

        let encoder = JSONEncoder()
        // NOTE: Do NOT use .convertToSnakeCase here — all Anthropic model types use explicit
        // CodingKeys with snake_case raw values for cross-platform compatibility (macOS & Linux).
        let body = try encoder.encode(request)

        await aiLog(.debug, "Sending request to Anthropic API", context: logContext, metadata: [
            "url": url,
            "bodySize": "\(body.count) bytes"
        ])

        let responseData = try await httpClient.post(url: url, headers: headers, body: body, context: logContext)

        let decoder = JSONDecoder()
        // NOTE: Do NOT use .convertFromSnakeCase here — it conflicts with explicit
        // CodingKeys that have snake_case raw values on Linux's Foundation implementation.
        // All Anthropic model types use explicit CodingKeys for cross-platform compatibility.

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

        let webSearchBeta = detectWebSearchBeta(tools: request.tools)
        let headers = buildHeaders(apiKey: apiKey, stream: true, additionalBetaFeatures: webSearchBeta)

        let encoder = JSONEncoder()
        // NOTE: Do NOT use .convertToSnakeCase here — all Anthropic model types use explicit
        // CodingKeys with snake_case raw values for cross-platform compatibility (macOS & Linux).
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
        // NOTE: Do NOT use .convertToSnakeCase here — all Anthropic model types use explicit
        // CodingKeys with snake_case raw values for cross-platform compatibility (macOS & Linux).
        let body = try encoder.encode(request)

        let responseData = try await httpClient.post(url: url, headers: headers, body: body)

        let decoder = JSONDecoder()
        // NOTE: Do NOT use .convertFromSnakeCase here — it conflicts with explicit
        // CodingKeys that have snake_case raw values on Linux's Foundation implementation.
        // All Anthropic model types use explicit CodingKeys for cross-platform compatibility.
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
        // NOTE: Do NOT use .convertToSnakeCase here — all Anthropic model types use explicit
        // CodingKeys with snake_case raw values for cross-platform compatibility (macOS & Linux).
        let body = try encoder.encode(payload)

        let responseData = try await httpClient.post(url: url, headers: headers, body: body)

        let decoder = JSONDecoder()
        // NOTE: Do NOT use .convertFromSnakeCase here — it conflicts with explicit
        // CodingKeys that have snake_case raw values on Linux's Foundation implementation.
        // All Anthropic model types use explicit CodingKeys for cross-platform compatibility.
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
        // NOTE: Do NOT use .convertFromSnakeCase here — it conflicts with explicit
        // CodingKeys that have snake_case raw values on Linux's Foundation implementation.
        // All Anthropic model types use explicit CodingKeys for cross-platform compatibility.
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
        // NOTE: Do NOT use .convertFromSnakeCase here — it conflicts with explicit
        // CodingKeys that have snake_case raw values on Linux's Foundation implementation.
        // All Anthropic model types use explicit CodingKeys for cross-platform compatibility.
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
        // NOTE: Do NOT use .convertFromSnakeCase here — it conflicts with explicit
        // CodingKeys that have snake_case raw values on Linux's Foundation implementation.
        // All Anthropic model types use explicit CodingKeys for cross-platform compatibility.

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
                // NOTE: Do NOT use .convertFromSnakeCase here — it conflicts with explicit
        // CodingKeys that have snake_case raw values on Linux's Foundation implementation.
        // All Anthropic model types use explicit CodingKeys for cross-platform compatibility.

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

    /// List available models
    /// - Parameter apiKey: API key for authentication
    /// - Returns: List of available Anthropic models
    public func listModels(apiKey: String) async throws -> AnthropicModelsResponse {
        let url = "\(baseURL)/models"
        let headers = buildHeaders(apiKey: apiKey, stream: false)

        let responseData = try await httpClient.get(url: url, headers: headers)

        let decoder = JSONDecoder()
        // NOTE: Do NOT use .convertFromSnakeCase here — it conflicts with explicit
        // CodingKeys that have snake_case raw values on Linux's Foundation implementation.
        // All Anthropic model types use explicit CodingKeys for cross-platform compatibility.
        return try decoder.decode(AnthropicModelsResponse.self, from: responseData)
    }

    // MARK: - Private Helper Methods

    private func buildHeaders(apiKey: String, stream: Bool, additionalBetaFeatures: [String] = []) -> [(String, String)] {
        var headers = [
            ("x-api-key", apiKey),
            ("anthropic-version", apiVersion),
            ("content-type", "application/json")
        ]

        var allBetaFeatures = enableBetaFeatures + additionalBetaFeatures
        // De-duplicate
        allBetaFeatures = Array(Set(allBetaFeatures))
        if !allBetaFeatures.isEmpty {
            headers.append(("anthropic-beta", allBetaFeatures.joined(separator: ",")))
        }

        if stream {
            headers.append(("accept", "text/event-stream"))
        }

        return headers
    }

    /// Detect if tools contain Anthropic's native web search, requiring the beta header
    private func detectWebSearchBeta(tools: [AnthropicToolDefinition]?) -> [String] {
        guard let tools else { return [] }
        let hasWebSearch = tools.contains { $0.type?.hasPrefix("web_search") == true }
        return hasWebSearch ? ["web-search-2025-03-05"] : []
    }

    // swiftlint:disable:next function_body_length
    func mapToAnthropicRequest(_ request: AIRequest) throws -> AnthropicRequest {
        let cacheTargets = Self.cacheTargets(from: request.providerOptions)

        // Raw messages pass-through: when provided, relay the message objects verbatim so
        // native server-tool blocks (server_tool_use, web_search_tool_result with
        // encrypted_content, tool_search results) reach the wire byte-faithfully.
        let rawMessages: [AnyCodable]? = request.rawMessagesJSON.flatMap {
            try? JSONDecoder().decode([AnyCodable].self, from: $0)
        }

        var messages: [AnthropicMessage] = []
        if rawMessages == nil {
            messages = request.messages.map { message in
                let content = message.content.map { self.mapContentBlock($0) }
                return AnthropicMessage(role: message.role.rawValue, content: content)
            }

            // Apply cache_control to the trailing content block of the final message when opted in.
            if cacheTargets.contains(.messages), let last = messages.last, let lastBlock = last.content.last {
                var newContent = last.content
                if case .text(let text) = lastBlock {
                    newContent[newContent.count - 1] = .textWithCacheControl(text, AnthropicCacheControl())
                    messages[messages.count - 1] = AnthropicMessage(role: last.role, content: newContent)
                }
            }
        }

        // System prompt: prefer raw JSON pass-through (already carries any cache_control),
        // otherwise build from the neutral systemPrompt, applying cache_control when opted in.
        let system: AnthropicSystemPrompt?
        if let rawSystemData = request.rawSystemJSON,
           let blocks = try? JSONDecoder().decode([AnthropicSystemPrompt.SystemBlock].self, from: rawSystemData) {
            system = .blocks(blocks)
        } else if let prompt = request.systemPrompt, !prompt.isEmpty {
            if cacheTargets.contains(.system) {
                system = .blocks([.init(text: prompt, cacheControl: AnthropicCacheControl())])
            } else {
                system = .text(prompt)
            }
        } else {
            system = nil
        }

        // Tools: prefer raw JSON pass-through (preserves full schemas incl. nested objects),
        // otherwise map the neutral [AITool]. Optionally append Anthropic's native web_search.
        var anthropicTools: [AnthropicToolDefinition]?
        if let rawToolsData = request.rawToolsJSON,
           let decoded = try? JSONDecoder().decode([AnthropicToolDefinition].self, from: rawToolsData) {
            anthropicTools = decoded
        } else if let tools = request.tools {
            anthropicTools = tools.map { Self.mapNeutralTool($0) }
        }

        if Self.isWebSearchEnabled(request.providerOptions) {
            var tools = anthropicTools ?? []
            if !tools.contains(where: { $0.type?.hasPrefix("web_search") == true }) {
                tools.append(AnthropicToolDefinition(type: "web_search_20250305", name: "web_search"))
            }
            anthropicTools = tools
        }

        // Cache the tool set (marks the last tool, per Anthropic's prefix-caching model).
        if cacheTargets.contains(.tools), var tools = anthropicTools, !tools.isEmpty {
            tools[tools.count - 1] = tools[tools.count - 1].withCacheControl(AnthropicCacheControl())
            anthropicTools = tools
        }

        // Tool choice: prefer raw JSON pass-through, otherwise map the neutral choice.
        let anthropicToolChoice: AnthropicToolChoice?
        if let rawChoiceData = request.rawToolChoiceJSON,
           let decoded = try? JSONDecoder().decode(AnthropicToolChoice.self, from: rawChoiceData) {
            anthropicToolChoice = decoded
        } else if let choice = request.toolChoice {
            anthropicToolChoice = Self.mapNeutralToolChoice(choice)
        } else {
            anthropicToolChoice = nil
        }

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
            tools: anthropicTools,
            toolChoice: anthropicToolChoice,
            thinking: Self.thinkingConfig(from: request.providerOptions),
            rawMessages: rawMessages
        )
    }

    /// Map a single neutral content part to an Anthropic content block, preserving
    /// tool_use arguments and tool_result payloads for faithful multi-turn round-trips.
    private func mapContentBlock(_ content: AIMessageContent) -> AnthropicContentBlock {
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
            return .document(source: .init(mediaType: mediaType, data: data.base64EncodedString()))
        case .toolCall(let toolCall):
            // Deserialize the JSON arguments string into a structured tool_use input.
            return .toolUse(id: toolCall.id, name: toolCall.name, input: Self.decodeToolInput(toolCall.arguments))
        case .toolResult(let id, let result):
            return .toolResult(toolUseId: id, content: result, isError: false)
        case .custom:
            return .text("")
        }
    }

    // MARK: - Anthropic-specific option mapping

    /// Which parts of the request should carry an ephemeral `cache_control` marker.
    enum CacheTarget: Hashable {
        case system
        case tools
        case messages
    }

    /// Parse the `anthropic_cache` provider option into a set of cache targets.
    ///
    /// Accepted values:
    /// - `true` (Bool): cache the stable prefix — system prompt and tools
    /// - `"system"` / `"tools"` / `"messages"`: cache just that target
    /// - `"all"`: cache system, tools, and trailing message content
    static func cacheTargets(from providerOptions: [String: AnyCodable]?) -> Set<CacheTarget> {
        guard let raw = providerOptions?["anthropic_cache"]?.value else { return [] }

        if let flag = raw as? Bool {
            return flag ? [.system, .tools] : []
        }
        if let str = (raw as? String)?.lowercased() {
            switch str {
            case "system": return [.system]
            case "tools": return [.tools]
            case "messages", "content": return [.messages]
            case "all", "true": return [.system, .tools, .messages]
            case "none", "false", "": return []
            default: return [.system, .tools]
            }
        }
        return []
    }

    /// Build an extended-thinking config from the `anthropic_thinking` provider option.
    ///
    /// Accepted values:
    /// - `true` (Bool): enable with the minimum budget (1024)
    /// - an integer: enable with that budget_tokens
    /// A separate `anthropic_thinking_budget` integer may override the budget.
    static func thinkingConfig(from providerOptions: [String: AnyCodable]?) -> AnthropicThinkingConfig? {
        guard let providerOptions else { return nil }

        let explicitBudget = intValue(providerOptions["anthropic_thinking_budget"]?.value)

        guard let raw = providerOptions["anthropic_thinking"]?.value else { return nil }

        if let flag = raw as? Bool {
            guard flag else { return nil }
            return AnthropicThinkingConfig(enabled: true, budgetTokens: explicitBudget ?? 1024)
        }
        if let budget = intValue(raw) {
            return AnthropicThinkingConfig(enabled: true, budgetTokens: explicitBudget ?? budget)
        }
        return nil
    }

    /// Whether Anthropic's native server-side web search should be enabled.
    static func isWebSearchEnabled(_ providerOptions: [String: AnyCodable]?) -> Bool {
        guard let raw = providerOptions?["anthropic_web_search"]?.value else { return false }
        if let flag = raw as? Bool { return flag }
        if let str = (raw as? String)?.lowercased() { return str == "true" || str == "on" || str == "enabled" }
        return false
    }

    /// Map a neutral tool to an Anthropic custom tool definition, preserving nested schemas.
    static func mapNeutralTool(_ tool: AITool) -> AnthropicToolDefinition {
        let properties = tool.parameters.properties.mapValues { AnyCodable($0.jsonSchemaDictionary()) }
        let schema = ToolInputSchema(
            type: tool.parameters.type,
            properties: properties.isEmpty ? nil : properties,
            required: tool.parameters.required
        )
        return AnthropicToolDefinition(name: tool.name, description: tool.description, inputSchema: schema)
    }

    /// Map the neutral tool choice to Anthropic's tool_choice representation.
    static func mapNeutralToolChoice(_ choice: AIToolChoice) -> AnthropicToolChoice? {
        switch choice {
        case .auto: return .auto
        case .required: return .any
        case .specific(let name): return .tool(name)
        case .none:
            // Anthropic has no explicit "none"; omitting tool_choice lets the model decide,
            // but callers asking for none expect no tool use — represent as auto with no forcing.
            return nil
        }
    }

    /// Deserialize a JSON arguments string into a structured tool_use input dictionary.
    static func decodeToolInput(_ arguments: String) -> [String: AnyCodable] {
        guard let data = arguments.data(using: .utf8), !data.isEmpty,
              let dict = try? JSONDecoder().decode([String: AnyCodable].self, from: data) else {
            return [:]
        }
        return dict
    }

    /// Best-effort extraction of an integer from a decoded JSON value.
    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let intValue as Int: return intValue
        case let doubleValue as Double: return Int(doubleValue)
        case let stringValue as String: return Int(stringValue)
        default: return nil
        }
    }

    func mapToAIResponse(_ response: AnthropicResponse) -> AIResponse {
        var content: [AIMessageContent] = []
        var thinkingParts: [String] = []
        var webSearchResults: [AnyCodable] = []
        var serverToolUses: [AnyCodable] = []
        var unknownBlocks: [AnyCodable] = []

        for block in response.content {
            switch block {
            case .text(let text):
                content.append(.text(text))
            case .textWithCacheControl(let text, _):
                content.append(.text(text))
            case .thinking(let text):
                // Surface reasoning via providerData rather than polluting the neutral text.
                thinkingParts.append(text)
            case .toolUse(let id, let name, let input):
                content.append(.toolCall(AIToolCall(id: id, name: name, arguments: Self.encodeToolInput(input))))
            case .serverToolUse(let id, let name):
                serverToolUses.append(AnyCodable(["id": id, "name": name]))
            case .webSearchToolResult(let rawJSON):
                webSearchResults.append(rawJSON)
            case .unknown(let type, let rawJSON):
                // Preserve unknown/future server-tool blocks (e.g. tool_search_tool_result).
                unknownBlocks.append(AnyCodable(["type": type, "rawJSON": rawJSON.value]))
            case .image, .document, .toolResult:
                continue
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

        var providerData: [String: AnyCodable] = [:]
        if !thinkingParts.isEmpty {
            providerData["thinking"] = AnyCodable(thinkingParts.joined(separator: "\n"))
        }
        if !webSearchResults.isEmpty {
            providerData["webSearchToolResults"] = AnyCodable(webSearchResults.map { $0.value })
        }
        if !serverToolUses.isEmpty {
            providerData["serverToolUse"] = AnyCodable(serverToolUses.map { $0.value })
        }
        if !unknownBlocks.isEmpty {
            providerData["unknownBlocks"] = AnyCodable(unknownBlocks.map { $0.value })
        }
        if let cacheCreation = response.usage.cacheCreationInputTokens {
            providerData["cacheCreationInputTokens"] = AnyCodable(cacheCreation)
        }

        return AIResponse(
            id: response.id,
            model: response.model,
            message: message,
            stopReason: stopReason,
            usage: usage,
            provider: .anthropic,
            providerData: providerData.isEmpty ? nil : providerData
        )
    }

    /// Accumulates streamed `tool_use` content blocks into complete tool calls.
    ///
    /// Anthropic streams a tool call as `content_block_start` (id + name),
    /// a series of `input_json_delta` fragments, then `content_block_stop`.
    /// Feeding each event to ``handle(_:)`` returns the finished ``AIToolCall`` (and its
    /// content-block index) exactly once, when its block stops.
    /// A completed streamed tool block emitted by ``ToolStreamAccumulator``.
    enum StreamedTool {
        /// A client-executed `tool_use` block with fully-assembled arguments.
        case client(index: Int, call: AIToolCall)
        /// A server-executed `server_tool_use` block (e.g. web_search) with its
        /// fully-assembled input JSON. Not a client tool call — surfaced on providerData.
        case server(index: Int, id: String, name: String, input: String)
    }

    struct ToolStreamAccumulator {
        private struct Block {
            var id: String
            var name: String
            var args: String
            var isServer: Bool
        }
        private var blocks: [Int: Block] = [:]

        init() {}

        mutating func handle(_ event: AnthropicStreamEvent) -> StreamedTool? {
            switch event {
            case .contentBlockStart(let start):
                switch start.contentBlock {
                case .toolUse(let id, let name, _):
                    blocks[start.index] = Block(id: id, name: name, args: "", isServer: false)
                case .serverToolUse(let id, let name):
                    blocks[start.index] = Block(id: id, name: name, args: "", isServer: true)
                default:
                    break
                }
            case .contentBlockDelta(let delta):
                if let partial = delta.delta.partialJson, blocks[delta.index] != nil {
                    blocks[delta.index]?.args += partial
                }
            case .contentBlockStop(let stop):
                if let block = blocks.removeValue(forKey: stop.index) {
                    let payload = block.args.isEmpty ? "{}" : block.args
                    if block.isServer {
                        return .server(index: stop.index, id: block.id, name: block.name, input: payload)
                    }
                    return .client(index: stop.index, call: AIToolCall(id: block.id, name: block.name, arguments: payload))
                }
            default:
                break
            }
            return nil
        }
    }

    /// Serialize a structured tool_use input dictionary into a JSON arguments string.
    static func encodeToolInput(_ input: [String: AnyCodable]) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: input.mapValues { $0.value }),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    func processStreamEvent(_ event: AnthropicStreamEvent) -> AIResponse? {
        switch event {
        case .messageStart(let start):
            let startUsage = AIUsage(
                inputTokens: start.message.usage.inputTokens ?? 0,
                outputTokens: start.message.usage.outputTokens ?? 0
            )
            return AIResponse(
                id: start.message.id,
                model: start.message.model,
                message: AIMessage(role: .assistant, text: ""),
                usage: startUsage,
                provider: .anthropic,
                providerData: ["streamEvent": AnyCodable("message_start")]
            )

        case .contentBlockStart(let start):
            switch start.contentBlock {
            case .toolUse(let id, let name, _):
                // Surface tool use starts so callers can track tool execution
                return AIResponse(
                    id: "stream",
                    model: "unknown",
                    message: AIMessage(role: .assistant, content: [
                        .toolCall(AIToolCall(id: id, name: name, arguments: ""))
                    ]),
                    provider: .anthropic,
                    providerData: [
                        "streamEvent": AnyCodable("content_block_start"),
                        "index": AnyCodable(start.index)
                    ]
                )
            case .serverToolUse(let id, let name):
                // Server-initiated tool use (e.g. web_search handled by Anthropic).
                // Do NOT expose as toolCall — Anthropic executes it internally.
                // Surface id + name so callers can correlate the streamed input
                // (accumulated separately) and the following result block.
                return AIResponse(
                    id: "stream",
                    model: "unknown",
                    message: AIMessage(role: .assistant, text: ""),
                    provider: .anthropic,
                    providerData: [
                        "streamEvent": AnyCodable("content_block_start"),
                        "contentBlockType": AnyCodable("server_tool_use"),
                        "serverToolId": AnyCodable(id),
                        "serverToolName": AnyCodable(name),
                        "index": AnyCodable(start.index)
                    ]
                )
            case .webSearchToolResult(let rawJSON):
                // Web search results — surface the full block (urls / text / encrypted_content)
                // so callers can relay citations and re-send the block in history.
                return AIResponse(
                    id: "stream",
                    model: "unknown",
                    message: AIMessage(role: .assistant, text: ""),
                    provider: .anthropic,
                    providerData: [
                        "streamEvent": AnyCodable("content_block_start"),
                        "contentBlockType": AnyCodable("web_search_tool_result"),
                        "webSearchToolResult": rawJSON,
                        "index": AnyCodable(start.index)
                    ]
                )
            case .unknown(let type, let rawJSON):
                // Unknown/future server-tool blocks (e.g. tool_search_tool_result) — pass the
                // full raw block through so callers can render/relay it.
                return AIResponse(
                    id: "stream",
                    model: "unknown",
                    message: AIMessage(role: .assistant, text: ""),
                    provider: .anthropic,
                    providerData: [
                        "streamEvent": AnyCodable("content_block_start"),
                        "contentBlockType": AnyCodable("unknown"),
                        "unknownBlockType": AnyCodable(type),
                        "unknownBlock": rawJSON,
                        "index": AnyCodable(start.index)
                    ]
                )
            default:
                return nil
            }

        case .contentBlockDelta(let delta):
            // Text delta
            if let text = delta.delta.text {
                return AIResponse(
                    id: "stream",
                    model: "unknown",
                    message: AIMessage(role: .assistant, text: text),
                    provider: .anthropic,
                    providerData: ["streamEvent": AnyCodable("text_delta")]
                )
            }
            // Tool input JSON delta
            if let partialJson = delta.delta.partialJson {
                return AIResponse(
                    id: "stream",
                    model: "unknown",
                    message: AIMessage(role: .assistant, text: partialJson),
                    provider: .anthropic,
                    providerData: [
                        "streamEvent": AnyCodable("input_json_delta"),
                        "index": AnyCodable(delta.index)
                    ]
                )
            }
            return nil

        case .contentBlockStop(let stop):
            return AIResponse(
                id: "stream",
                model: "unknown",
                message: AIMessage(role: .assistant, text: ""),
                provider: .anthropic,
                providerData: [
                    "streamEvent": AnyCodable("content_block_stop"),
                    "index": AnyCodable(stop.index)
                ]
            )

        case .messageDelta(let delta):
            let stopReason: AIStopReason? = delta.delta.stopReason.flatMap {
                AIStopReason(rawValue: $0.rawValue)
            }
            let usage: AIUsage? = delta.usage.map {
                AIUsage(inputTokens: $0.inputTokens ?? 0, outputTokens: $0.outputTokens ?? 0)
            }
            return AIResponse(
                id: "stream",
                model: "unknown",
                message: AIMessage(role: .assistant, text: ""),
                stopReason: stopReason,
                usage: usage,
                provider: .anthropic,
                providerData: ["streamEvent": AnyCodable("message_delta")]
            )

        case .messageStop:
            return AIResponse(
                id: "stream",
                model: "unknown",
                message: AIMessage(role: .assistant, text: ""),
                provider: .anthropic,
                providerData: ["streamEvent": AnyCodable("message_stop")]
            )

        case .ping:
            return nil

        case .error(let errorData):
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

    // swiftlint:disable:next cyclomatic_complexity
    func parseSSEEvent(_ event: String) throws -> AnthropicStreamEvent? {
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
        // NOTE: Do NOT use .convertFromSnakeCase here — it conflicts with explicit
        // CodingKeys that have snake_case raw values on Linux's Foundation implementation.
        // All Anthropic model types use explicit CodingKeys for cross-platform compatibility.

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
