import Foundation

/// Groq provider implementation (OpenAI-compatible API)
///
/// Fast inference for open models via Groq's OpenAI-compatible Chat Completions API.
///
/// ## Topics
///
/// ### ProviderProtocol
/// - ``providerType``
/// - ``sendMessage(_:apiKey:)``
/// - ``streamMessage(_:apiKey:)``
///
/// ### Groq-Specific Methods
/// - ``listModels(apiKey:)``
///
/// ## See Also
/// - <doc:GrokGuide>
public struct GroqProvider: ProviderProtocol {
    public let providerType: ProviderType = .groq

    private let httpClient: HTTPClientManager
    private let baseURL: String
    private let timeout: Int
    private let maxRetries: Int
    private let enableLogging: Bool

    /// Initialize Groq provider with default HTTPClientManager
    /// - Parameters:
    ///   - baseURL: Base URL for Groq API (default: https://api.groq.com/openai/v1)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        baseURL: String = "https://api.groq.com/openai/v1",
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false
    ) {
        self.httpClient = HTTPClientManager()
        self.baseURL = baseURL
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.enableLogging = enableLogging
    }

    /// Initialize Groq provider with custom HTTP client
    /// - Parameters:
    ///   - httpClient: Custom HTTP client manager
    ///   - baseURL: Base URL for Groq API (default: https://api.groq.com/openai/v1)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        httpClient: HTTPClientManager,
        baseURL: String = "https://api.groq.com/openai/v1",
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.enableLogging = enableLogging
    }

    // MARK: - ProviderProtocol Implementation

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        // Build Groq request
        let groqRequest = try buildGroqRequest(from: request)

        // Prepare endpoint
        let endpoint = "\(baseURL)/chat/completions"

        // Prepare headers (Bearer token authentication)
        let headers = [
            ("Authorization", "Bearer \(apiKey)"),
            ("Content-Type", "application/json")
        ]

        // Encode request to JSON
        let requestData = try JSONEncoder().encode(groqRequest)

        // Make HTTP request
        let responseData = try await httpClient.post(
            url: endpoint,
            headers: headers,
            body: requestData
        )

        // Decode response
        let groqResponse = try JSONDecoder().decode(GroqResponse.self, from: responseData)

        // Transform to AIResponse
        return transformToAIResponse(groqResponse, originalRequest: request)
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        // Prepare endpoint
        let endpoint = "\(baseURL)/chat/completions"

        // Prepare headers
        let headers = [
            ("Authorization", "Bearer \(apiKey)"),
            ("Content-Type", "application/json")
        ]

        // Create SSE stream
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Build Groq request with streaming enabled
                    let streamRequest = try buildGroqRequest(from: request, streaming: true)

                    // Encode request to JSON
                    let requestData = try JSONEncoder().encode(streamRequest)

                    let dataStream = httpClient.streamPost(
                        url: endpoint,
                        headers: headers,
                        body: requestData
                    )

                    // Delegate SSE parsing / reassembly to the testable helper so the
                    // exact same logic drives production and unit tests.
                    for try await response in makeResponseStream(from: dataStream) {
                        continuation.yield(response)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Transform a raw SSE byte stream from the Groq chat-completions endpoint into
    /// neutral ``AIResponse`` values.
    ///
    /// Content is accumulated and yielded cumulatively as it streams (matching the
    /// accumulate-and-yield behavior used across the SDK's providers). Crucially,
    /// `finish_reason` and `usage` are read off **every** chunk unconditionally — not
    /// gated on a non-nil `delta` — so the terminal OpenAI-compatible
    /// `{"choices":[],"usage":{…}}` chunk (which carries streamed token usage but no
    /// delta) is surfaced on the final yielded response instead of being dropped.
    ///
    /// - Parameter dataStream: Raw SSE data chunks (as produced by ``HTTPClientManager/streamPost(url:headers:body:context:)``).
    /// - Returns: A stream of neutral responses; the final response carries the fully
    ///   assembled content, tool calls, stop reason, and usage.
    func makeResponseStream(
        from dataStream: AsyncThrowingStream<Data, Error>
    ) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var accumulatedContent = ""
                    var accumulatedToolCalls: [GroqToolCall] = []
                    var stopReason: AIStopReason?
                    var usage: AIUsage?
                    var lastChunk: GroqStreamChunk?
                    var didYieldFinal = false

                    // Emit the fully-assembled final response exactly once (content +
                    // tool calls + stop reason + terminal usage).
                    func yieldFinal() {
                        guard !didYieldFinal, let chunk = lastChunk else { return }
                        didYieldFinal = true
                        continuation.yield(makeStreamResponse(
                            chunk: chunk,
                            content: accumulatedContent,
                            toolCalls: accumulatedToolCalls,
                            stopReason: stopReason,
                            usage: usage
                        ))
                    }

                    for try await data in dataStream {
                        let chunkString = String(data: data, encoding: .utf8) ?? ""
                        let lines = chunkString.split(separator: "\n")

                        for line in lines {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)

                            // Check for [DONE] signal — surface the assembled final
                            // response (with usage) before finishing.
                            if trimmed == "data: [DONE]" {
                                yieldFinal()
                                continuation.finish()
                                return
                            }

                            // Parse SSE data
                            guard trimmed.hasPrefix("data: ") else { continue }
                            let jsonString = String(trimmed.dropFirst(6))

                            guard let jsonData = jsonString.data(using: .utf8) else { continue }

                            // Decode chunk
                            let streamChunk = try JSONDecoder().decode(GroqStreamChunk.self, from: jsonData)
                            lastChunk = streamChunk

                            // finish_reason and usage ride their own chunks under
                            // OpenAI-compatible SSE (the finish chunk has an empty delta,
                            // the usage chunk has `choices: []`). Read them off every
                            // chunk, independent of whether a delta is present.
                            if let reason = streamChunk.choices.first?.finish_reason.flatMap({ mapFinishReason($0) }) {
                                stopReason = reason
                            }
                            if let chunkUsage = streamChunk.usage {
                                usage = AIUsage(
                                    inputTokens: chunkUsage.prompt_tokens,
                                    outputTokens: chunkUsage.completion_tokens,
                                    cachedTokens: chunkUsage.prompt_tokens_details?.cached_tokens,
                                    reasoningTokens: chunkUsage.completion_tokens_details?.reasoning_tokens
                                )
                            }

                            // Accumulate incremental content / tool-call deltas and yield
                            // the running content so consumers see it stream.
                            if let delta = streamChunk.choices.first?.delta {
                                if let content = delta.content {
                                    accumulatedContent += content
                                }
                                if let toolCallDeltas = delta.tool_calls {
                                    Self.accumulateToolCalls(toolCallDeltas, into: &accumulatedToolCalls)
                                }
                                if delta.content != nil {
                                    continuation.yield(makeStreamResponse(
                                        chunk: streamChunk,
                                        content: accumulatedContent,
                                        toolCalls: accumulatedToolCalls,
                                        stopReason: nil,
                                        usage: nil
                                    ))
                                }
                            }
                        }
                    }

                    // Stream ended without an explicit [DONE] — still surface the
                    // assembled final response.
                    yieldFinal()
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Build a streaming ``AIResponse`` from accumulated stream state.
    private func makeStreamResponse(
        chunk: GroqStreamChunk,
        content: String,
        toolCalls: [GroqToolCall],
        stopReason: AIStopReason?,
        usage: AIUsage?
    ) -> AIResponse {
        var streamContent: [AIMessageContent] = content.isEmpty ? [] : [.text(content)]
        for call in toolCalls where !(call.id.isEmpty && call.function.name.isEmpty) {
            streamContent.append(.toolCall(AIToolCall(
                id: call.id,
                type: call.type,
                name: call.function.name,
                arguments: call.function.arguments
            )))
        }
        let message = AIMessage(role: .assistant, content: streamContent)

        return AIResponse(
            id: chunk.id,
            model: chunk.model,
            message: message,
            stopReason: stopReason,
            usage: usage,
            provider: .groq,
            providerData: buildProviderData(
                chunk: chunk,
                accumulatedToolCalls: toolCalls
            )
        )
    }

    // MARK: - Groq-Specific Methods

    /// List available models
    /// - Parameter apiKey: API key for authentication
    /// - Returns: List of available Groq models
    public func listModels(apiKey: String) async throws -> GroqModelsResponse {
        let endpoint = "\(baseURL)/models"
        let headers = [("Authorization", "Bearer \(apiKey)")]
        let responseData = try await httpClient.get(url: endpoint, headers: headers)
        return try JSONDecoder().decode(GroqModelsResponse.self, from: responseData)
    }

    // MARK: - Private Helpers

    /// Build Groq request from AIRequest
    func buildGroqRequest(from request: AIRequest, streaming: Bool = false) throws -> GroqRequest {
        // Convert messages
        var groqMessages: [GroqMessage] = []

        // Add system prompt as first message if present
        if let systemPrompt = request.systemPrompt {
            groqMessages.append(GroqMessage(role: "system", text: systemPrompt))
        }

        // Add conversation messages
        for message in request.messages {
            let roleString = message.role.rawValue

            // Tool results map to individual tool-role messages (OpenAI-compatible).
            let toolResults = message.content.compactMap { content -> GroqMessage? in
                if case .toolResult(let id, let result) = content {
                    return GroqMessage(role: "tool", content: .text(result), tool_call_id: id)
                }
                return nil
            }
            if !toolResults.isEmpty {
                groqMessages.append(contentsOf: toolResults)
                continue
            }

            // Assistant tool calls map to a message carrying tool_calls (content may be nil).
            let toolCalls = message.content.compactMap { content -> GroqToolCall? in
                if case .toolCall(let call) = content {
                    return GroqToolCall(
                        id: call.id,
                        type: call.type,
                        function: GroqFunctionCall(name: call.name, arguments: call.arguments)
                    )
                }
                return nil
            }
            if !toolCalls.isEmpty {
                let text = message.content.compactMap { content -> String? in
                    if case .text(let value) = content { return value }
                    return nil
                }.joined()
                groqMessages.append(GroqMessage(
                    role: roleString,
                    content: text.isEmpty ? nil : .text(text),
                    tool_calls: toolCalls
                ))
                continue
            }

            // Check for multimodal content (vision)
            let hasImages = message.content.contains { content in
                if case .image = content { return true }
                return false
            }

            if hasImages {
                // Build multimodal content array
                var parts: [GroqContentPart] = []
                for content in message.content {
                    switch content {
                    case .text(let text):
                        parts.append(.text(text))
                    case .image(let source, _):
                        let imageUrl = GroqImageUrl(url: source.urlString)
                        parts.append(.imageUrl(imageUrl))
                    case .toolCall, .toolResult, .document, .custom:
                        // Handle other content types - skip for multimodal
                        continue
                    }
                }
                groqMessages.append(GroqMessage(role: roleString, content: .multimodal(parts)))
            } else {
                // Text-only message
                let textContent = message.content.compactMap { content -> String? in
                    if case .text(let text) = content {
                        return text
                    }
                    return nil
                }.joined()

                groqMessages.append(GroqMessage(role: roleString, text: textContent))
            }
        }

        // Convert tools if present
        let tools: [GroqTool]? = request.tools?.map { tool in
            GroqTool(
                type: "function",
                function: GroqFunction(
                    name: tool.name,
                    description: tool.description,
                    parameters: convertToolParameters(tool.parameters)
                )
            )
        }

        // Convert tool choice from the neutral request (providerOptions can't carry a typed
        // GroqToolChoice, so map the neutral AIToolChoice directly).
        let toolChoice: GroqToolChoice? = request.toolChoice.map { Self.mapToolChoice($0) }

        // Convert response format if present
        let responseFormat: GroqResponseFormat? = request.providerOptions?["response_format"] as? GroqResponseFormat

        // Build stream options if streaming
        let streamOptions: GroqStreamOptions? = streaming ? GroqStreamOptions(include_usage: true) : nil

        return GroqRequest(
            model: request.model,
            messages: groqMessages,
            temperature: request.temperature,
            top_p: request.topP,
            max_tokens: request.maxTokens,
            frequency_penalty: request.providerOptions?["frequency_penalty"] as? Double,
            presence_penalty: request.providerOptions?["presence_penalty"] as? Double,
            stream: streaming,
            stream_options: streamOptions,
            tools: tools,
            tool_choice: toolChoice,
            response_format: responseFormat,
            stop: request.stopSequences,
            n: request.providerOptions?["n"] as? Int,
            user: request.providerOptions?["user"] as? String,
            seed: request.providerOptions?["seed"] as? Int,
            logprobs: request.providerOptions?["logprobs"] as? Bool,
            top_logprobs: request.providerOptions?["top_logprobs"] as? Int
        )
    }

    /// Transform Groq response to AIResponse
    func transformToAIResponse(_ response: GroqResponse, originalRequest: AIRequest) -> AIResponse {
        // Extract first choice
        guard let firstChoice = response.choices.first else {
            let emptyMessage = AIMessage(role: .assistant, content: [])
            return AIResponse(
                id: response.id,
                model: response.model,
                message: emptyMessage,
                stopReason: nil,
                usage: response.usage.map { usage in
                    AIUsage(
                        inputTokens: usage.prompt_tokens,
                        outputTokens: usage.completion_tokens,
                        cachedTokens: usage.prompt_tokens_details?.cached_tokens,
                        reasoningTokens: usage.completion_tokens_details?.reasoning_tokens
                    )
                },
                provider: .groq,
                providerData: nil
            )
        }

        // Build provider data with detailed token info and tool calls
        let providerData = buildProviderData(
            response: response,
            message: firstChoice.message
        )

        // Create AI message from content
        var content: [AIMessageContent] = []

        // Add text content
        if let messageContent = firstChoice.message.content {
            content.append(.text(messageContent))
        }

        // Add tool calls if present
        if let toolCalls = firstChoice.message.tool_calls {
            for toolCall in toolCalls {
                let aiToolCall = AIToolCall(
                    id: toolCall.id,
                    type: toolCall.type,
                    name: toolCall.function.name,
                    arguments: toolCall.function.arguments
                )
                content.append(.toolCall(aiToolCall))
            }
        }

        let message = AIMessage(role: .assistant, content: content)

        return AIResponse(
            id: response.id,
            model: response.model,
            message: message,
            stopReason: firstChoice.finish_reason.flatMap { mapFinishReason($0) },
            usage: response.usage.map { usage in
                AIUsage(
                    inputTokens: usage.prompt_tokens,
                    outputTokens: usage.completion_tokens,
                    cachedTokens: usage.prompt_tokens_details?.cached_tokens,
                    reasoningTokens: usage.completion_tokens_details?.reasoning_tokens
                )
            },
            provider: .groq,
            providerData: providerData
        )
    }

    /// Map the neutral tool choice to Groq's (OpenAI-compatible) tool_choice.
    static func mapToolChoice(_ choice: AIToolChoice) -> GroqToolChoice {
        switch choice {
        case .auto: return .auto
        case .required: return .required
        case .none: return .none
        case .specific(let name): return .function(name)
        }
    }

    /// Map Groq finish reason to AIStopReason
    private func mapFinishReason(_ reason: String) -> AIStopReason {
        switch reason {
        case "stop": return .endTurn
        case "length": return .maxTokens
        case "tool_calls": return .toolUse
        case "content_filter": return .contentFilter
        default: return .other
        }
    }

    /// Convert AIToolParameters to [String: AnyCodable] for Groq API
    ///
    /// Uses the shared JSON Schema serializer so nested objects and arrays-of-objects
    /// (including enums and validation bounds) survive to the wire.
    private func convertToolParameters(_ parameters: AIToolParameters) -> [String: AnyCodable] {
        parameters.jsonSchemaDictionary().mapValues { AnyCodable($0) }
    }

    /// Accumulate tool calls from streaming deltas
    ///
    /// Exposed as a `static` helper (mirroring ``OpenAIProvider/accumulate(_:into:)``) so
    /// the index-keyed reassembly of streamed tool-call fragments is unit-testable.
    static func accumulateToolCalls(_ deltas: [GroqDeltaToolCall], into accumulated: inout [GroqToolCall]) {
        for delta in deltas {
            // Ensure we have enough slots
            while accumulated.count <= delta.index {
                accumulated.append(GroqToolCall(
                    id: "",
                    type: "function",
                    function: GroqFunctionCall(name: "", arguments: "")
                ))
            }

            // Update the tool call at this index
            var current = accumulated[delta.index]

            if let id = delta.id {
                current = GroqToolCall(
                    id: id,
                    type: delta.type ?? current.type,
                    function: current.function
                )
            }

            if let functionDelta = delta.function {
                var name = current.function.name
                var arguments = current.function.arguments

                if let deltaName = functionDelta.name {
                    name = deltaName
                }
                if let deltaArgs = functionDelta.arguments {
                    arguments += deltaArgs
                }

                current = GroqToolCall(
                    id: current.id,
                    type: current.type,
                    function: GroqFunctionCall(name: name, arguments: arguments)
                )
            }

            accumulated[delta.index] = current
        }
    }

    /// Build provider-specific data dictionary
    private func buildProviderData(response: GroqResponse, message: GroqResponseMessage) -> [String: AnyCodable]? {
        var data: [String: AnyCodable] = [:]

        // Add detailed token information
        if let usage = response.usage {
            // Reasoning tokens
            if let reasoningTokens = usage.completion_tokens_details?.reasoning_tokens {
                data["reasoning_tokens"] = AnyCodable(reasoningTokens)
            }

            // Cached tokens
            if let cachedTokens = usage.prompt_tokens_details?.cached_tokens {
                data["cached_tokens"] = AnyCodable(cachedTokens)
            }

            // Full prompt tokens details
            if let promptDetails = usage.prompt_tokens_details {
                var details: [String: AnyCodable] = [:]
                if let cached = promptDetails.cached_tokens {
                    details["cached_tokens"] = AnyCodable(cached)
                }
                if let text = promptDetails.text_tokens {
                    details["text_tokens"] = AnyCodable(text)
                }
                if let image = promptDetails.image_tokens {
                    details["image_tokens"] = AnyCodable(image)
                }
                if !details.isEmpty {
                    data["prompt_tokens_details"] = AnyCodable(details)
                }
            }

            // Full completion tokens details
            if let completionDetails = usage.completion_tokens_details {
                var details: [String: AnyCodable] = [:]
                if let reasoning = completionDetails.reasoning_tokens {
                    details["reasoning_tokens"] = AnyCodable(reasoning)
                }
                if let text = completionDetails.text_tokens {
                    details["text_tokens"] = AnyCodable(text)
                }
                if !details.isEmpty {
                    data["completion_tokens_details"] = AnyCodable(details)
                }
            }
        }

        // Add refusal message if present
        if let refusal = message.refusal {
            data["refusal"] = AnyCodable(refusal)
        }

        // Add system fingerprint if present
        if let fingerprint = response.system_fingerprint {
            data["system_fingerprint"] = AnyCodable(fingerprint)
        }

        return data.isEmpty ? nil : data
    }

    /// Build provider-specific data dictionary for streaming
    private func buildProviderData(chunk: GroqStreamChunk, accumulatedToolCalls: [GroqToolCall]) -> [String: AnyCodable]? {
        var data: [String: AnyCodable] = [:]

        // Add detailed token information from usage (if present in final chunk)
        if let usage = chunk.usage {
            if let reasoningTokens = usage.completion_tokens_details?.reasoning_tokens {
                data["reasoning_tokens"] = AnyCodable(reasoningTokens)
            }
            if let cachedTokens = usage.prompt_tokens_details?.cached_tokens {
                data["cached_tokens"] = AnyCodable(cachedTokens)
            }
        }

        // Add tool calls if accumulated
        if !accumulatedToolCalls.isEmpty {
            let toolCallsData = accumulatedToolCalls.map { toolCall -> [String: AnyCodable] in
                [
                    "id": AnyCodable(toolCall.id),
                    "type": AnyCodable(toolCall.type),
                    "function": AnyCodable([
                        "name": toolCall.function.name,
                        "arguments": toolCall.function.arguments
                    ])
                ]
            }
            data["tool_calls"] = AnyCodable(toolCallsData)
        }

        // Add system fingerprint if present
        if let fingerprint = chunk.system_fingerprint {
            data["system_fingerprint"] = AnyCodable(fingerprint)
        }

        return data.isEmpty ? nil : data
    }
}
