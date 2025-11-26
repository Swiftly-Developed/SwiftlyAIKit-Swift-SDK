import Foundation

/// Grok provider implementation (xAI - OpenAI-compatible API)
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

                    // Accumulated content for delta accumulation
                    var accumulatedContent = ""
                    var accumulatedToolCalls: [GrokToolCall] = []

                    let stream = httpClient.streamPost(
                        url: endpoint,
                        headers: headers,
                        body: requestData
                    )

                    for try await chunk in stream {
                        // Convert Data to String
                        let chunkString = String(data: chunk, encoding: .utf8) ?? ""
                        let lines = chunkString.split(separator: "\n")

                        for line in lines {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)

                            // Check for [DONE] signal
                            if trimmed == "data: [DONE]" {
                                continuation.finish()
                                return
                            }

                            // Parse SSE data
                            guard trimmed.hasPrefix("data: ") else { continue }
                            let jsonString = String(trimmed.dropFirst(6))

                            guard let jsonData = jsonString.data(using: .utf8) else { continue }

                            // Decode chunk
                            let streamChunk = try JSONDecoder().decode(GrokStreamChunk.self, from: jsonData)

                            // Process delta
                            if let delta = streamChunk.choices.first?.delta {
                                // Accumulate content
                                if let content = delta.content {
                                    accumulatedContent += content
                                }

                                // Accumulate tool calls
                                if let toolCallDeltas = delta.tool_calls {
                                    accumulateToolCalls(toolCallDeltas, into: &accumulatedToolCalls)
                                }

                                // Create AIResponse with accumulated content
                                let message = AIMessage(
                                    role: .assistant,
                                    content: accumulatedContent.isEmpty ? [] : [.text(accumulatedContent)]
                                )

                                let aiResponse = AIResponse(
                                    id: streamChunk.id,
                                    model: streamChunk.model,
                                    message: message,
                                    stopReason: streamChunk.choices.first?.finish_reason.flatMap { mapFinishReason($0) },
                                    usage: streamChunk.usage.map { usage in
                                        AIUsage(
                                            inputTokens: usage.prompt_tokens,
                                            outputTokens: usage.completion_tokens,
                                            cachedTokens: usage.prompt_tokens_details?.cached_tokens,
                                            reasoningTokens: usage.completion_tokens_details?.reasoning_tokens
                                        )
                                    },
                                    provider: .grok,
                                    providerData: buildProviderData(
                                        chunk: streamChunk,
                                        accumulatedToolCalls: accumulatedToolCalls
                                    )
                                )

                                continuation.yield(aiResponse)
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
    private func buildGrokRequest(from request: AIRequest, streaming: Bool = false) throws -> GrokRequest {
        // Convert messages
        var grokMessages: [GrokMessage] = []

        // Add system prompt as first message if present
        if let systemPrompt = request.systemPrompt {
            grokMessages.append(GrokMessage(role: "system", text: systemPrompt))
        }

        // Add conversation messages
        for message in request.messages {
            let roleString = message.role.rawValue

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

        // Convert tool choice if present
        let toolChoice: GrokToolChoice? = request.providerOptions?["tool_choice"] as? GrokToolChoice

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
    private func transformToAIResponse(_ response: GrokResponse, originalRequest: AIRequest) -> AIResponse {
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
    private func convertToolParameters(_ parameters: AIToolParameters) -> [String: AnyCodable] {
        var result: [String: AnyCodable] = [
            "type": AnyCodable(parameters.type)
        ]

        // Convert properties
        var properties: [String: [String: Any]] = [:]
        for (name, property) in parameters.properties {
            var propDict: [String: Any] = ["type": property.type]
            if let description = property.description {
                propDict["description"] = description
            }
            if let enumValues = property.enum {
                propDict["enum"] = enumValues
            }
            properties[name] = propDict
        }
        result["properties"] = AnyCodable(properties)

        // Add required fields
        if let required = parameters.required {
            result["required"] = AnyCodable(required)
        }

        // Add additionalProperties
        if let additionalProperties = parameters.additionalProperties {
            result["additionalProperties"] = AnyCodable(additionalProperties)
        }

        return result
    }

    /// Accumulate tool calls from streaming deltas
    private func accumulateToolCalls(_ deltas: [GrokDeltaToolCall], into accumulated: inout [GrokToolCall]) {
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
