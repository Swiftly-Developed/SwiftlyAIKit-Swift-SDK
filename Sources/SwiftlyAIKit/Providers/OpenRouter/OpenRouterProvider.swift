import Foundation

/// OpenRouter provider implementation (OpenAI-compatible aggregator)
///
/// Routes chat completions to many vendors/models through OpenRouter's OpenAI-compatible
/// Chat Completions API. Model ids are namespaced `"vendor/model"` (e.g.
/// `"anthropic/claude-3.5-sonnet"`, `"openai/gpt-4o"`) and are passed through verbatim.
///
/// ## Overview
///
/// `OpenRouterProvider` implements:
/// - Chat Completions API (any OpenRouter-hosted model)
/// - Streaming with SSE
/// - Vision (image analysis for vision-capable models)
/// - Tool/function calling
/// - `listModels(apiKey:)` — the RAW, live `GET /models` catalog (large and dynamic;
///   there is intentionally no hardcoded fallback list)
///
/// ## Basic Usage
///
/// ```swift
/// let provider = OpenRouterProvider()
/// let request = AIRequest(model: "anthropic/claude-3.5-sonnet", prompt: "Hello")
/// let response = try await provider.sendMessage(request, apiKey: "sk-or-v1-...")
/// ```
///
/// ## Attribution Headers
///
/// OpenRouter uses two optional headers for app attribution on its leaderboards. Pass them
/// once at init; they are omitted when `nil`:
///
/// ```swift
/// let provider = OpenRouterProvider(
///     httpReferer: "https://myapp.example",
///     xTitle: "My App"
/// )
/// ```
///
/// ## Topics
///
/// ### Creating Providers
/// - ``init(baseURL:httpReferer:xTitle:timeout:maxRetries:enableLogging:)``
/// - ``init(httpClient:baseURL:httpReferer:xTitle:timeout:maxRetries:enableLogging:)``
///
/// ### ProviderProtocol Implementation
/// - ``providerType``
/// - ``sendMessage(_:apiKey:)``
/// - ``streamMessage(_:apiKey:)``
///
/// ### OpenRouter-Specific Methods
/// - ``listModels(apiKey:)``
public struct OpenRouterProvider: ProviderProtocol {
    public let providerType: ProviderType = .openRouter

    private let httpClient: HTTPClientManager
    private let baseURL: String
    private let httpReferer: String?
    private let xTitle: String?
    private let timeout: Int
    private let maxRetries: Int
    private let enableLogging: Bool

    /// Initialize OpenRouter provider with default HTTPClientManager
    /// - Parameters:
    ///   - baseURL: Base URL for the OpenRouter API (default: https://openrouter.ai/api/v1)
    ///   - httpReferer: Optional `HTTP-Referer` attribution header (your app/site URL)
    ///   - xTitle: Optional `X-Title` attribution header (your app name)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        baseURL: String = "https://openrouter.ai/api/v1",
        httpReferer: String? = nil,
        xTitle: String? = nil,
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false
    ) {
        self.httpClient = HTTPClientManager()
        self.baseURL = baseURL
        self.httpReferer = httpReferer
        self.xTitle = xTitle
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.enableLogging = enableLogging
    }

    /// Initialize with a custom HTTP client
    /// - Parameters:
    ///   - httpClient: Custom HTTP client manager
    ///   - baseURL: Base URL for the OpenRouter API
    ///   - httpReferer: Optional `HTTP-Referer` attribution header
    ///   - xTitle: Optional `X-Title` attribution header
    ///   - timeout: Request timeout in seconds
    ///   - maxRetries: Maximum retry attempts
    ///   - enableLogging: Enable logging
    public init(
        httpClient: HTTPClientManager,
        baseURL: String = "https://openrouter.ai/api/v1",
        httpReferer: String? = nil,
        xTitle: String? = nil,
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.httpReferer = httpReferer
        self.xTitle = xTitle
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.enableLogging = enableLogging
    }

    // MARK: - ProviderProtocol Implementation

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        let openRouterRequest = try mapToOpenRouterRequest(request)
        let headers = buildHeaders(apiKey: apiKey, stream: false)

        let jsonData = try JSONEncoder().encode(openRouterRequest)

        let responseData = try await httpClient.post(
            url: "\(baseURL)/chat/completions",
            headers: headers,
            body: jsonData
        )

        let openRouterResponse = try JSONDecoder().decode(OpenRouterResponse.self, from: responseData)
        return mapToAIResponse(openRouterResponse)
    }

    // swiftlint:disable:next function_body_length
    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var openRouterRequest = try mapToOpenRouterRequest(request)
                    openRouterRequest.stream = true

                    let headers = buildHeaders(apiKey: apiKey, stream: true)
                    let jsonData = try JSONEncoder().encode(openRouterRequest)

                    let stream = httpClient.streamPost(
                        url: "\(baseURL)/chat/completions",
                        headers: headers,
                        body: jsonData
                    )

                    var accumulatedContent = ""
                    // Accumulate streamed tool calls by index (id/name arrive first, arguments stream in fragments).
                    var toolCalls: [Int: (id: String, name: String, args: String)] = [:]

                    for try await chunk in stream {
                        let chunkString = String(data: chunk, encoding: .utf8) ?? ""
                        let lines = chunkString.split(separator: "\n")

                        for line in lines {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)

                            // Check for stream end signal
                            if trimmed == "data: [DONE]" {
                                continuation.finish()
                                return
                            }

                            // Parse SSE format: "data: {...}"
                            guard trimmed.hasPrefix("data: ") else { continue }

                            let jsonString = String(trimmed.dropFirst(6))
                            guard let jsonData = jsonString.data(using: .utf8) else { continue }

                            let streamChunk = try JSONDecoder().decode(OpenRouterStreamChunk.self, from: jsonData)
                            let delta = streamChunk.choices.first?.delta

                            // Accumulate tool-call deltas
                            if let toolCallDeltas = delta?.toolCalls {
                                Self.accumulate(toolCallDeltas, into: &toolCalls)
                            }

                            // Extract delta content
                            if let content = delta?.content {
                                accumulatedContent += content

                                let message = AIMessage(
                                    role: .assistant,
                                    content: [.text(accumulatedContent)]
                                )
                                let response = AIResponse(
                                    id: streamChunk.id,
                                    model: streamChunk.model,
                                    message: message,
                                    stopReason: nil,
                                    usage: nil,
                                    provider: .openRouter
                                )

                                continuation.yield(response)
                            }

                            // Check for finish
                            if let finishReason = streamChunk.choices.first?.finishReason {
                                var finalContent: [AIMessageContent] = []
                                if !accumulatedContent.isEmpty {
                                    finalContent.append(.text(accumulatedContent))
                                }
                                // Emit fully-assembled tool calls in order
                                for index in toolCalls.keys.sorted() {
                                    let call = toolCalls[index]!
                                    finalContent.append(.toolCall(AIToolCall(
                                        id: call.id,
                                        name: call.name,
                                        arguments: call.args.isEmpty ? "{}" : call.args
                                    )))
                                }
                                let finalMessage = AIMessage(role: .assistant, content: finalContent)
                                let finalResponse = AIResponse(
                                    id: streamChunk.id,
                                    model: streamChunk.model,
                                    message: finalMessage,
                                    stopReason: mapFinishReason(finishReason),
                                    usage: nil,
                                    provider: .openRouter
                                )
                                continuation.yield(finalResponse)
                                continuation.finish()
                                return
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
        // OpenRouter doesn't have a separate token counting endpoint;
        // tokens are returned in the response usage field.
        nil
    }

    // MARK: - OpenRouter-Specific Methods

    /// List available models from OpenRouter's `GET /api/v1/models` endpoint.
    ///
    /// Returns the RAW, live catalog — hundreds of namespaced `"vendor/model"` ids across
    /// many vendors. This live list is authoritative; the SDK ships no hardcoded fallback.
    /// The caller is responsible for any filtering (e.g. to chat-capable models).
    /// - Parameter apiKey: API key for authentication
    /// - Returns: List of available OpenRouter models
    public func listModels(apiKey: String) async throws -> OpenRouterModelsResponse {
        let url = "\(baseURL)/models"
        let headers = buildHeaders(apiKey: apiKey, stream: false)
        let responseData = try await httpClient.get(url: url, headers: headers)
        let decoder = JSONDecoder()
        // NOTE: Do NOT use .convertFromSnakeCase — mirrors OpenAIProvider.listModels;
        // explicit CodingKeys with snake_case raw values conflict with it on Linux Foundation.
        return try decoder.decode(OpenRouterModelsResponse.self, from: responseData)
    }

    // MARK: - Private Helper Methods

    private func buildHeaders(apiKey: String, stream: Bool) -> [(String, String)] {
        var headers = [
            ("Authorization", "Bearer \(apiKey)"),
            ("Content-Type", "application/json")
        ]

        // Optional OpenRouter attribution headers — included only when configured.
        if let httpReferer = httpReferer {
            headers.append(("HTTP-Referer", httpReferer))
        }
        if let xTitle = xTitle {
            headers.append(("X-Title", xTitle))
        }

        if stream {
            headers.append(("Accept", "text/event-stream"))
        }

        return headers
    }

    func mapToOpenRouterRequest(_ request: AIRequest) throws -> OpenRouterRequest {
        var messages: [OpenRouterMessage] = []

        // Add system message if present (OpenAI-compatible: system rides the messages array).
        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
            messages.append(OpenRouterMessage(
                role: .system,
                content: .text(systemPrompt)
            ))
        }

        // Map AIMessage to OpenRouterMessage
        for message in request.messages {
            let openRouterMessage = try mapMessage(message)
            messages.append(openRouterMessage)
        }

        // Map tools if present
        let tools = request.tools?.map { mapTool($0) }
        let toolChoice = request.toolChoice.map { mapToolChoice($0) }

        return OpenRouterRequest(
            model: request.model,
            messages: messages,
            maxTokens: request.maxTokens,
            temperature: request.temperature,
            topP: request.topP,
            stop: request.stopSequences,
            tools: tools,
            toolChoice: toolChoice
        )
    }

    private func mapMessage(_ message: AIMessage) throws -> OpenRouterMessage {
        let role: OpenRouterMessage.Role
        switch message.role {
        case .user:
            role = .user
        case .assistant:
            role = .assistant
        case .system:
            role = .system
        }

        // Check if message contains tool calls
        let toolCalls = message.content.compactMap { content -> OpenRouterToolCall? in
            if case .toolCall(let toolCall) = content {
                return OpenRouterToolCall(
                    id: toolCall.id,
                    type: toolCall.type,
                    function: OpenRouterToolCall.FunctionCall(
                        name: toolCall.name,
                        arguments: toolCall.normalizedArgumentsJSON
                    )
                )
            }
            return nil
        }

        // Check if message is a tool result
        if let toolResult = message.content.first(where: {
            if case .toolResult = $0 { return true }
            return false
        }) {
            if case .toolResult(let id, let result) = toolResult {
                return OpenRouterMessage(
                    role: .tool,
                    content: .text(result),
                    toolCallId: id
                )
            }
        }

        // If we have tool calls, return assistant message with tool calls
        if !toolCalls.isEmpty {
            return OpenRouterMessage(
                role: .assistant,
                content: nil,
                toolCalls: toolCalls
            )
        }

        // Handle different content types
        if message.content.count == 1, case .text(let text) = message.content[0] {
            // Simple text message
            return OpenRouterMessage(role: role, content: .text(text))
        } else {
            // Multi-part content (text + images, excluding tool calls/results)
            let contentBlocks = try message.content.compactMap { content -> OpenRouterContentBlock? in
                // Skip tool-related content in this mapping
                switch content {
                case .toolCall, .toolResult:
                    return nil
                default:
                    return try mapContentBlock(content)
                }
            }

            if contentBlocks.isEmpty {
                return OpenRouterMessage(role: role, content: nil)
            }

            return OpenRouterMessage(role: role, content: .contentArray(contentBlocks))
        }
    }

    private func mapContentBlock(_ block: AIMessageContent) throws -> OpenRouterContentBlock {
        switch block {
        case .text(let text):
            return .text(text)

        case .image(let source, let mediaType):
            switch source {
            case .url(let url):
                return .imageUrl(url: url, detail: .auto)

            case .base64(let data):
                // Convert to data URL format
                let mimeType = mediaType ?? "image/jpeg"
                let dataUrl = "data:\(mimeType);base64,\(data)"
                return .imageUrl(url: dataUrl, detail: .auto)
            }

        case .document:
            throw AIError.unsupportedFeature(feature: "PDF documents", provider: .openRouter)

        case .toolCall, .toolResult:
            // Tool calls and results are handled separately in mapMessage
            throw AIError.invalidRequest(message: "Tool calls and results should be handled in message mapping")

        case .custom:
            throw AIError.unsupportedFeature(feature: "Custom content", provider: .openRouter)
        }
    }

    func mapToAIResponse(_ response: OpenRouterResponse) -> AIResponse {
        guard let choice = response.choices.first else {
            let emptyMessage = AIMessage(role: .assistant, content: [])
            return AIResponse(
                id: response.id,
                model: response.model,
                message: emptyMessage,
                stopReason: nil,
                usage: nil,
                provider: .openRouter
            )
        }

        var content: [AIMessageContent] = []

        // Add text content if present
        if let messageContent = choice.message.content {
            switch messageContent {
            case .text(let text):
                content.append(.text(text))
            case .contentArray(let blocks):
                content.append(contentsOf: blocks.compactMap { block in
                    switch block {
                    case .text(let text):
                        return .text(text)
                    case .imageUrl:
                        return nil // Images in responses not typical
                    }
                })
            }
        }

        // Add tool calls if present
        if let toolCalls = choice.message.toolCalls {
            content.append(contentsOf: toolCalls.map { toolCall in
                .toolCall(AIToolCall(
                    id: toolCall.id,
                    type: toolCall.type,
                    name: toolCall.function.name,
                    arguments: toolCall.function.arguments
                ))
            })
        }

        let message = AIMessage(role: .assistant, content: content)

        let usage = response.usage.map { usage in
            AIUsage(
                inputTokens: usage.promptTokens,
                outputTokens: usage.completionTokens
            )
        }

        return AIResponse(
            id: response.id,
            model: response.model,
            message: message,
            stopReason: choice.finishReason.map { mapFinishReason($0) },
            usage: usage,
            provider: .openRouter
        )
    }

    private func mapTool(_ tool: AITool) -> OpenRouterToolDefinition {
        // Convert AIToolParameters to a JSON Schema dictionary (recurses into nested
        // objects and arrays-of-objects) and wrap each top-level entry as AnyCodable.
        let parameters = tool.parameters.jsonSchemaDictionary().mapValues { AnyCodable($0) }

        return OpenRouterToolDefinition(
            function: OpenRouterToolDefinition.FunctionDefinition(
                name: tool.name,
                description: tool.description,
                parameters: parameters
            )
        )
    }

    private func mapToolChoice(_ choice: AIToolChoice) -> OpenRouterToolChoice {
        switch choice {
        case .auto:
            return .auto
        case .required:
            return .required
        case .none:
            return .none
        case .specific(let toolName):
            return .function(toolName)
        }
    }

    /// Merge streamed tool-call deltas into an index-keyed accumulator.
    ///
    /// OpenRouter (OpenAI-compatible) streams a tool call's `id`/`name` in the first delta
    /// and its `arguments` as subsequent fragments, all keyed by `index`.
    static func accumulate(
        _ deltas: [OpenRouterStreamChunk.StreamChoice.Delta.DeltaToolCall],
        into accumulator: inout [Int: (id: String, name: String, args: String)]
    ) {
        for delta in deltas {
            var current = accumulator[delta.index] ?? (id: "", name: "", args: "")
            if let id = delta.id { current.id = id }
            if let function = delta.function {
                if let name = function.name { current.name = name }
                if let arguments = function.arguments { current.args += arguments }
            }
            accumulator[delta.index] = current
        }
    }

    private func mapFinishReason(_ reason: String) -> AIStopReason {
        switch reason {
        case "stop":
            return .endTurn
        case "length":
            return .maxTokens
        case "content_filter":
            return .stopSequence
        case "tool_calls", "function_call":
            return .toolUse
        default:
            return .endTurn
        }
    }
}
