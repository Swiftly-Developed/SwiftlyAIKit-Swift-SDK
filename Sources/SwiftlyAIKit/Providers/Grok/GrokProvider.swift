import Foundation

/// Grok provider implementation (xAI - OpenAI-compatible API)
///
/// Real-time web access, image generation, and reasoning token tracking.
///
/// ## Topics
///
/// ### ProviderProtocol
/// - ``providerType``
/// - ``sendMessage(_:apiKey:)``
/// - ``streamMessage(_:apiKey:)``
/// - ``countTokens(_:apiKey:)``
///
/// ### ImageGenerationProvider
/// - ``supportsImageGeneration``
/// - ``imageGenerationModels``
/// - ``generateImage(_:apiKey:)``
///
/// ## See Also
/// - <doc:GrokGuide>
/// - <doc:ImageGeneration>
public struct GrokProvider: ProviderProtocol, ImageGenerationProvider {
    public let providerType: ProviderType = .grok

    private let httpClient: HTTPClientManager
    private let baseURL: String
    private let timeout: Int
    private let maxRetries: Int
    private let enableLogging: Bool

    /// Initialize Grok provider with default HTTPClientManager
    /// - Parameters:
    ///   - baseURL: Base URL for Grok API (default: https://api.x.ai/v1)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        baseURL: String = "https://api.x.ai/v1",
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

    /// Initialize Grok provider with custom HTTP client
    /// - Parameters:
    ///   - httpClient: Custom HTTP client manager
    ///   - baseURL: Base URL for Grok API (default: https://api.x.ai/v1)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        httpClient: HTTPClientManager,
        baseURL: String = "https://api.x.ai/v1",
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
        // Build Grok request
        let grokRequest = try buildGrokRequest(from: request)

        // Prepare endpoint
        let endpoint = "\(baseURL)/chat/completions"

        // Prepare headers (Bearer token authentication)
        let headers = [
            ("Authorization", "Bearer \(apiKey)"),
            ("Content-Type", "application/json")
        ]

        // Encode request to JSON
        let requestData = try JSONEncoder().encode(grokRequest)

        // Make HTTP request
        let responseData = try await httpClient.post(
            url: endpoint,
            headers: headers,
            body: requestData
        )

        // Decode response
        let grokResponse = try JSONDecoder().decode(GrokResponse.self, from: responseData)

        // Transform to AIResponse
        return transformToAIResponse(grokResponse, originalRequest: request)
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
                    // Build Grok request with streaming enabled
                    let streamRequest = try buildGrokRequest(from: request, streaming: true)

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

    /// Transform a raw SSE byte stream from the Grok/xAI chat-completions endpoint into
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
                    var accumulatedToolCalls: [GrokToolCall] = []
                    var stopReason: AIStopReason?
                    var usage: AIUsage?
                    var lastChunk: GrokStreamChunk?
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
                            let streamChunk = try JSONDecoder().decode(GrokStreamChunk.self, from: jsonData)
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
        chunk: GrokStreamChunk,
        content: String,
        toolCalls: [GrokToolCall],
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
            provider: .grok,
            providerData: buildProviderData(
                chunk: chunk,
                accumulatedToolCalls: toolCalls
            )
        )
    }

    public func countTokens(_ request: AIRequest, apiKey: String) async throws -> Int {
        // Grok has a dedicated tokenization endpoint
        let endpoint = "\(baseURL)/tokenize-text"

        // Prepare headers
        let headers = [
            ("Authorization", "Bearer \(apiKey)"),
            ("Content-Type", "application/json")
        ]

        // Build text to tokenize
        var textToTokenize = ""

        // Add system prompt
        if let systemPrompt = request.systemPrompt {
            textToTokenize += systemPrompt + "\n"
        }

        // Add messages
        for message in request.messages {
            textToTokenize += message.textContent + "\n"
        }

        // Create tokenize request
        let tokenizeRequest = GrokTokenizeRequest(
            model: request.model,
            text: textToTokenize
        )

        // Encode request
        let requestData = try JSONEncoder().encode(tokenizeRequest)

        // Make HTTP request
        let responseData = try await httpClient.post(
            url: endpoint,
            headers: headers,
            body: requestData
        )

        // Decode response
        let tokenizeResponse = try JSONDecoder().decode(GrokTokenizeResponse.self, from: responseData)

        return tokenizeResponse.tokens.count
    }

    // MARK: - Grok-Specific Methods

    /// Generate images using Grok 2 Image model
    /// - Parameters:
    ///   - request: Image generation request
    ///   - apiKey: API key for authentication
    /// - Returns: Image generation response with URLs or base64 data
    public func generateImage(_ request: GrokImageRequest, apiKey: String) async throws -> GrokImageResponse {
        let endpoint = "\(baseURL)/images/generations"

        let headers = [
            ("Authorization", "Bearer \(apiKey)"),
            ("Content-Type", "application/json")
        ]

        let requestData = try JSONEncoder().encode(request)

        let responseData = try await httpClient.post(
            url: endpoint,
            headers: headers,
            body: requestData
        )

        return try JSONDecoder().decode(GrokImageResponse.self, from: responseData)
    }

    // MARK: - ImageGenerationProvider Implementation

    /// Whether this provider supports image generation
    public var supportsImageGeneration: Bool { true }

    /// Available models for image generation
    public var imageGenerationModels: [String] {
        ["grok-2-image"]
    }

    /// Generate images using the unified ImageGenerationRequest
    ///
    /// This method provides a unified interface that wraps the Grok-specific
    /// `generateImage(GrokImageRequest)` method for cross-provider compatibility.
    ///
    /// - Parameters:
    ///   - request: The unified image generation request
    ///   - apiKey: API key for authentication
    /// - Returns: Unified image generation response
    /// - Throws: AIError on failure
    public func generateImage(
        _ request: ImageGenerationRequest,
        apiKey: String
    ) async throws -> ImageGenerationResponse {
        // Map unified request to Grok-specific request
        let grokRequest = GrokImageRequest(
            prompt: request.prompt,
            model: request.model.isEmpty ? "grok-2-image" : request.model,
            n: request.numberOfImages,
            response_format: request.responseFormat == .base64 ? .b64_json : .url,
            user: request.user
        )

        // Use existing Grok implementation
        let grokResponse = try await generateImage(grokRequest, apiKey: apiKey)

        // Map Grok response to unified response
        let images = grokResponse.data.enumerated().map { index, image in
            GeneratedImage(
                index: index,
                url: image.url,
                base64Data: image.b64_json,
                revisedPrompt: image.revised_prompt,
                size: .square1024, // Grok only supports 1024x1024
                contentType: "image/png"
            )
        }

        return ImageGenerationResponse(
            id: "grok-img-\(UUID().uuidString.prefix(8))",
            created: Date(timeIntervalSince1970: TimeInterval(grokResponse.created)),
            provider: .grok,
            model: request.model.isEmpty ? "grok-2-image" : request.model,
            images: images,
            usage: ImageGenerationUsage(imagesGenerated: images.count)
        )
    }

    /// Get status of a deferred completion
    /// - Parameters:
    ///   - requestId: The request ID returned from a deferred completion
    ///   - apiKey: API key for authentication
    /// - Returns: Deferred completion status with result when complete
    public func getDeferredCompletion(requestId: String, apiKey: String) async throws -> GrokDeferredStatus {
        let endpoint = "\(baseURL)/chat/deferred-completion/\(requestId)"

        let headers = [
            ("Authorization", "Bearer \(apiKey)")
        ]

        let responseData = try await httpClient.get(
            url: endpoint,
            headers: headers
        )

        return try JSONDecoder().decode(GrokDeferredStatus.self, from: responseData)
    }

    /// List available models
    /// - Parameter apiKey: API key for authentication
    /// - Returns: List of available Grok models
    public func listModels(apiKey: String) async throws -> GrokModelsResponse {
        let endpoint = "\(baseURL)/models"

        let headers = [
            ("Authorization", "Bearer \(apiKey)")
        ]

        let responseData = try await httpClient.get(
            url: endpoint,
            headers: headers
        )

        return try JSONDecoder().decode(GrokModelsResponse.self, from: responseData)
    }

    // MARK: - Private Helpers

    /// Build Grok request from AIRequest
    func buildGrokRequest(from request: AIRequest, streaming: Bool = false) throws -> GrokRequest {
        // Convert messages
        var grokMessages: [GrokMessage] = []

        // Add system prompt as first message if present
        if let systemPrompt = request.systemPrompt {
            grokMessages.append(GrokMessage(role: "system", text: systemPrompt))
        }

        // Add conversation messages
        for message in request.messages {
            let roleString = message.role.rawValue

            // Tool results map to individual tool-role messages (OpenAI-compatible).
            let toolResults = message.content.compactMap { content -> GrokMessage? in
                if case .toolResult(let id, let result) = content {
                    return GrokMessage(role: "tool", content: .text(result), tool_call_id: id)
                }
                return nil
            }
            if !toolResults.isEmpty {
                grokMessages.append(contentsOf: toolResults)
                continue
            }

            // Assistant tool calls map to a message carrying tool_calls (content may be nil).
            let toolCalls = message.content.compactMap { content -> GrokToolCall? in
                if case .toolCall(let call) = content {
                    return GrokToolCall(
                        id: call.id,
                        type: call.type,
                        function: GrokFunctionCall(name: call.name, arguments: call.arguments)
                    )
                }
                return nil
            }
            if !toolCalls.isEmpty {
                let text = message.content.compactMap { content -> String? in
                    if case .text(let value) = content { return value }
                    return nil
                }.joined()
                grokMessages.append(GrokMessage(
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
                var parts: [GrokContentPart] = []
                for content in message.content {
                    switch content {
                    case .text(let text):
                        parts.append(.text(text))
                    case .image(let source, _):
                        let imageUrl = GrokImageUrl(url: source.urlString)
                        parts.append(.imageUrl(imageUrl))
                    case .toolCall, .toolResult, .document, .custom:
                        // Handle other content types - skip for multimodal
                        continue
                    }
                }
                grokMessages.append(GrokMessage(role: roleString, content: .multimodal(parts)))
            } else {
                // Text-only message
                let textContent = message.content.compactMap { content -> String? in
                    if case .text(let text) = content {
                        return text
                    }
                    return nil
                }.joined()

                grokMessages.append(GrokMessage(role: roleString, text: textContent))
            }
        }

        // Convert tools if present
        let tools: [GrokTool]? = request.tools?.map { tool in
            GrokTool(
                type: "function",
                function: GrokFunction(
                    name: tool.name,
                    description: tool.description,
                    parameters: convertToolParameters(tool.parameters)
                )
            )
        }

        // Convert tool choice from the neutral request (providerOptions can't carry a typed
        // GrokToolChoice, so map the neutral AIToolChoice directly).
        let toolChoice: GrokToolChoice? = request.toolChoice.map { Self.mapToolChoice($0) }

        // Convert response format if present
        let responseFormat: GrokResponseFormat? = request.providerOptions?["response_format"] as? GrokResponseFormat

        // Extract Grok-specific options
        let searchParameters: GrokSearchParameters? = request.providerOptions?["search_parameters"] as? GrokSearchParameters
        let deferred: Bool? = request.providerOptions?["deferred"] as? Bool

        // Build stream options if streaming
        let streamOptions: GrokStreamOptions? = streaming ? GrokStreamOptions(include_usage: true) : nil

        return GrokRequest(
            model: request.model,
            messages: grokMessages,
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
            top_logprobs: request.providerOptions?["top_logprobs"] as? Int,
            search_parameters: searchParameters,
            deferred: deferred
        )
    }

    /// Transform Grok response to AIResponse
    func transformToAIResponse(_ response: GrokResponse, originalRequest: AIRequest) -> AIResponse {
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
                provider: .grok,
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
            provider: .grok,
            providerData: providerData
        )
    }

    /// Map the neutral tool choice to Grok's (OpenAI-compatible) tool_choice.
    static func mapToolChoice(_ choice: AIToolChoice) -> GrokToolChoice {
        switch choice {
        case .auto: return .auto
        case .required: return .required
        case .none: return .none
        case .specific(let name): return .function(name)
        }
    }

    /// Map Grok finish reason to AIStopReason
    private func mapFinishReason(_ reason: String) -> AIStopReason {
        switch reason {
        case "stop": return .endTurn
        case "length": return .maxTokens
        case "tool_calls": return .toolUse
        case "content_filter": return .contentFilter
        default: return .other
        }
    }

    /// Convert AIToolParameters to [String: AnyCodable] for Grok API
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
    static func accumulateToolCalls(_ deltas: [GrokDeltaToolCall], into accumulated: inout [GrokToolCall]) {
        for delta in deltas {
            // Ensure we have enough slots
            while accumulated.count <= delta.index {
                accumulated.append(GrokToolCall(
                    id: "",
                    type: "function",
                    function: GrokFunctionCall(name: "", arguments: "")
                ))
            }

            // Update the tool call at this index
            var current = accumulated[delta.index]

            if let id = delta.id {
                current = GrokToolCall(
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

                current = GrokToolCall(
                    id: current.id,
                    type: current.type,
                    function: GrokFunctionCall(name: name, arguments: arguments)
                )
            }

            accumulated[delta.index] = current
        }
    }

    /// Build provider-specific data dictionary
    private func buildProviderData(response: GrokResponse, message: GrokResponseMessage) -> [String: AnyCodable]? {
        var data: [String: AnyCodable] = [:]

        // Add detailed token information
        if let usage = response.usage {
            // Reasoning tokens (for Grok 4)
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
    private func buildProviderData(chunk: GrokStreamChunk, accumulatedToolCalls: [GrokToolCall]) -> [String: AnyCodable]? {
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

// MARK: - ImageSource Extension

extension AIMessageContent.ImageSource {
    /// Get URL string representation of the image source
    var urlString: String {
        switch self {
        case .url(let url):
            return url
        case .base64(let data):
            // Default to jpeg if no media type available
            return "data:image/jpeg;base64,\(data)"
        }
    }
}
