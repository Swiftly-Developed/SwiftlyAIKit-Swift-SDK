import Foundation

/// OpenAI provider implementation for GPT models and DALL-E image generation
public struct OpenAIProvider: ProviderProtocol, ImageGenerationProvider {
    public let providerType: ProviderType = .openai

    private let httpClient: HTTPClientManager
    private let baseURL: String
    private let organizationId: String?
    private let timeout: Int
    private let maxRetries: Int
    private let enableLogging: Bool

    /// Initialize OpenAI provider with default HTTPClientManager
    /// - Parameters:
    ///   - baseURL: Base URL for OpenAI API (default: https://api.openai.com/v1)
    ///   - organizationId: Optional organization ID for multi-tenant accounts
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        baseURL: String = "https://api.openai.com/v1",
        organizationId: String? = nil,
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false
    ) {
        self.httpClient = HTTPClientManager()
        self.baseURL = baseURL
        self.organizationId = organizationId
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.enableLogging = enableLogging
    }

    /// Initialize with custom HTTP client
    /// - Parameters:
    ///   - httpClient: Custom HTTP client manager
    ///   - baseURL: Base URL for OpenAI API
    ///   - organizationId: Optional organization ID
    ///   - timeout: Request timeout in seconds
    ///   - maxRetries: Maximum retry attempts
    ///   - enableLogging: Enable logging
    public init(
        httpClient: HTTPClientManager,
        baseURL: String = "https://api.openai.com/v1",
        organizationId: String? = nil,
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.organizationId = organizationId
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.enableLogging = enableLogging
    }

    // MARK: - ProviderProtocol Implementation

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        let openAIRequest = try mapToOpenAIRequest(request)
        let headers = buildHeaders(apiKey: apiKey, stream: false)

        let jsonData = try JSONEncoder().encode(openAIRequest)

        let responseData = try await httpClient.post(
            url: "\(baseURL)/chat/completions",
            headers: headers,
            body: jsonData
        )

        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: responseData)
        return mapToAIResponse(openAIResponse)
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var openAIRequest = try mapToOpenAIRequest(request)
                    openAIRequest.stream = true

                    let headers = buildHeaders(apiKey: apiKey, stream: true)
                    let jsonData = try JSONEncoder().encode(openAIRequest)

                    let stream = httpClient.streamPost(
                        url: "\(baseURL)/chat/completions",
                        headers: headers,
                        body: jsonData
                    )

                    var accumulatedContent = ""

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

                            let streamChunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: jsonData)

                            // Extract delta content
                            if let delta = streamChunk.choices.first?.delta,
                               let content = delta.content {
                                accumulatedContent += content

                                // Create AIResponse for this chunk
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
                                    provider: .openai
                                )

                                continuation.yield(response)
                            }

                            // Check for finish
                            if let finishReason = streamChunk.choices.first?.finishReason {
                                let finalMessage = AIMessage(
                                    role: .assistant,
                                    content: [.text(accumulatedContent)]
                                )
                                let finalResponse = AIResponse(
                                    id: streamChunk.id,
                                    model: streamChunk.model,
                                    message: finalMessage,
                                    stopReason: mapFinishReason(finishReason),
                                    usage: nil,
                                    provider: .openai
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
        // OpenAI doesn't have a separate token counting endpoint
        // Tokens are returned in the response usage field
        return nil
    }

    // MARK: - ImageGenerationProvider Implementation

    /// Whether this provider supports image generation
    public var supportsImageGeneration: Bool { true }

    /// Available models for image generation
    public var imageGenerationModels: [String] {
        ["dall-e-3", "dall-e-2"]
    }

    /// Generate images from a text prompt using DALL-E
    ///
    /// - Parameters:
    ///   - request: The image generation request
    ///   - apiKey: OpenAI API key
    /// - Returns: Generated images
    /// - Throws: AIError on failure
    public func generateImage(
        _ request: ImageGenerationRequest,
        apiKey: String
    ) async throws -> ImageGenerationResponse {
        // Map unified request to OpenAI-specific request
        let openAIRequest = mapToOpenAIImageRequest(request)

        let headers = [
            ("Authorization", "Bearer \(apiKey)"),
            ("Content-Type", "application/json")
        ]

        let jsonData = try JSONEncoder().encode(openAIRequest)

        let responseData = try await httpClient.post(
            url: "\(baseURL)/images/generations",
            headers: headers,
            body: jsonData
        )

        let openAIResponse = try JSONDecoder().decode(OpenAIImageResponse.self, from: responseData)

        return mapToImageGenerationResponse(openAIResponse, request: request)
    }

    // MARK: - Private Image Generation Helpers

    private func mapToOpenAIImageRequest(_ request: ImageGenerationRequest) -> OpenAIImageRequest {
        // Map size enum to OpenAI string format
        let sizeString = request.size.rawValue

        // Map quality enum to OpenAI string
        let qualityString = request.quality?.rawValue

        // Map style enum to OpenAI string (only vivid/natural for OpenAI)
        let styleString: String?
        if let style = request.style {
            switch style {
            case .vivid, .natural:
                styleString = style.rawValue
            default:
                styleString = nil // Apple styles not supported
            }
        } else {
            styleString = nil
        }

        // Map response format
        let responseFormatString: String?
        switch request.responseFormat {
        case .url:
            responseFormatString = "url"
        case .base64:
            responseFormatString = "b64_json"
        }

        return OpenAIImageRequest(
            prompt: request.prompt,
            model: request.model,
            n: request.numberOfImages,
            size: sizeString,
            quality: qualityString,
            style: styleString,
            responseFormat: responseFormatString,
            user: request.user
        )
    }

    private func mapToImageGenerationResponse(
        _ response: OpenAIImageResponse,
        request: ImageGenerationRequest
    ) -> ImageGenerationResponse {
        let images = response.data.enumerated().map { index, image in
            GeneratedImage(
                index: index,
                url: image.url,
                base64Data: image.b64Json,
                revisedPrompt: image.revisedPrompt,
                size: request.size,
                contentType: "image/png"
            )
        }

        return ImageGenerationResponse(
            id: "img-\(UUID().uuidString.prefix(8))",
            created: Date(timeIntervalSince1970: TimeInterval(response.created)),
            provider: .openai,
            model: request.model,
            images: images,
            usage: ImageGenerationUsage(imagesGenerated: images.count)
        )
    }

    // MARK: - Private Helper Methods

    private func buildHeaders(apiKey: String, stream: Bool) -> [(String, String)] {
        var headers = [
            ("Authorization", "Bearer \(apiKey)"),
            ("Content-Type", "application/json")
        ]

        if let orgId = organizationId {
            headers.append(("OpenAI-Organization", orgId))
        }

        if stream {
            headers.append(("Accept", "text/event-stream"))
        }

        return headers
    }

    private func mapToOpenAIRequest(_ request: AIRequest) throws -> OpenAIRequest {
        var messages: [OpenAIMessage] = []

        // Add system message if present (OpenAI uses messages array, not separate parameter)
        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
            messages.append(OpenAIMessage(
                role: .system,
                content: .text(systemPrompt)
            ))
        }

        // Map AIMessage to OpenAIMessage
        for message in request.messages {
            let openAIMessage = try mapMessage(message)
            messages.append(openAIMessage)
        }

        // Map tools if present
        let tools = request.tools?.map { mapTool($0) }
        let toolChoice = request.toolChoice.map { mapToolChoice($0) }

        return OpenAIRequest(
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

    private func mapMessage(_ message: AIMessage) throws -> OpenAIMessage {
        let role: OpenAIMessage.Role
        switch message.role {
        case .user:
            role = .user
        case .assistant:
            role = .assistant
        case .system:
            role = .system
        }

        // Check if message contains tool calls
        let toolCalls = message.content.compactMap { content -> OpenAIToolCall? in
            if case .toolCall(let toolCall) = content {
                return OpenAIToolCall(
                    id: toolCall.id,
                    type: toolCall.type,
                    function: OpenAIToolCall.FunctionCall(
                        name: toolCall.name,
                        arguments: toolCall.arguments
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
                return OpenAIMessage(
                    role: .tool,
                    content: .text(result),
                    toolCallId: id
                )
            }
        }

        // If we have tool calls, return assistant message with tool calls
        if !toolCalls.isEmpty {
            return OpenAIMessage(
                role: .assistant,
                content: nil,
                toolCalls: toolCalls
            )
        }

        // Handle different content types
        if message.content.count == 1, case .text(let text) = message.content[0] {
            // Simple text message
            return OpenAIMessage(role: role, content: .text(text))
        } else {
            // Multi-part content (text + images, excluding tool calls/results)
            let contentBlocks = try message.content.compactMap { content -> OpenAIContentBlock? in
                // Skip tool-related content in this mapping
                switch content {
                case .toolCall, .toolResult:
                    return nil
                default:
                    return try mapContentBlock(content)
                }
            }

            if contentBlocks.isEmpty {
                return OpenAIMessage(role: role, content: nil)
            }

            return OpenAIMessage(role: role, content: .contentArray(contentBlocks))
        }
    }

    private func mapContentBlock(_ block: AIMessageContent) throws -> OpenAIContentBlock {
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
            throw AIError.unsupportedFeature(feature: "PDF documents", provider: .openai)

        case .toolCall, .toolResult:
            // Tool calls and results are handled separately in mapMessage
            throw AIError.invalidRequest(message: "Tool calls and results should be handled in message mapping")

        case .custom:
            throw AIError.unsupportedFeature(feature: "Custom content", provider: .openai)
        }
    }

    private func mapToAIResponse(_ response: OpenAIResponse) -> AIResponse {
        guard let choice = response.choices.first else {
            let emptyMessage = AIMessage(role: .assistant, content: [])
            return AIResponse(
                id: response.id,
                model: response.model,
                message: emptyMessage,
                stopReason: nil,
                usage: nil,
                provider: .openai
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

        let usage = AIUsage(
            inputTokens: response.usage.promptTokens,
            outputTokens: response.usage.completionTokens
        )

        return AIResponse(
            id: response.id,
            model: response.model,
            message: message,
            stopReason: choice.finishReason.map { mapFinishReason($0) },
            usage: usage,
            provider: .openai
        )
    }

    private func mapTool(_ tool: AITool) -> OpenAIToolDefinition {
        // Convert AIToolParameters properties to OpenAI format
        var parameters: [String: AnyCodable] = [
            "type": AnyCodable(tool.parameters.type),
            "properties": AnyCodable(tool.parameters.properties.mapValues { property in
                var propDict: [String: Any] = ["type": property.type]
                if let desc = property.description {
                    propDict["description"] = desc
                }
                if let enumValues = property.enum {
                    propDict["enum"] = enumValues
                }
                if let items = property.items {
                    var itemsDict: [String: Any] = ["type": items.type]
                    if let desc = items.description {
                        itemsDict["description"] = desc
                    }
                    propDict["items"] = itemsDict
                }
                if let min = property.minimum {
                    propDict["minimum"] = min
                }
                if let max = property.maximum {
                    propDict["maximum"] = max
                }
                return propDict
            })
        ]

        if let required = tool.parameters.required {
            parameters["required"] = AnyCodable(required)
        }

        if let additionalProperties = tool.parameters.additionalProperties {
            parameters["additionalProperties"] = AnyCodable(additionalProperties)
        }

        return OpenAIToolDefinition(
            function: OpenAIToolDefinition.FunctionDefinition(
                name: tool.name,
                description: tool.description,
                parameters: parameters
            )
        )
    }

    private func mapToolChoice(_ choice: AIToolChoice) -> OpenAIToolChoice {
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
