import Foundation

/// Mistral AI provider implementation
///
/// Supports chat completions with the Mistral AI API, which uses an OpenAI-compatible format.
/// API Documentation: https://docs.mistral.ai/api
///
/// Features:
/// - Chat completions (standard and streaming)
/// - Vision support (image URLs)
/// - Function calling with tools
/// - JSON mode via response_format
/// - Safety prompts and deterministic sampling
///
/// Models:
/// - Mistral Large 2.1 (128K context)
/// - Mistral Medium 3 (128K context)
/// - Mistral Small 3.1 (128K context)
/// - Codestral (32K context, code generation)
/// - Magistral models (reasoning with chain-of-thought)
/// - Ministral models (edge computing)
public struct MistralProvider: ProviderProtocol {
    public let providerType: ProviderType = .mistral
    private let httpClient: HTTPClientManager
    private let baseURL: String
    private let timeout: Int
    private let maxRetries: Int
    private let enableLogging: Bool

    // MARK: - Initializers

    /// Initialize with default HTTP client
    public init(
        baseURL: String = "https://api.mistral.ai/v1",
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false
    ) {
        self.httpClient = HTTPClientManager(
            maxRetries: maxRetries,
            enableLogging: enableLogging
        )
        self.baseURL = baseURL
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.enableLogging = enableLogging
    }

    /// Initialize with custom HTTP client (for testing)
    public init(
        httpClient: HTTPClientManager,
        baseURL: String = "https://api.mistral.ai/v1",
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
        // Build Mistral request
        let mistralRequest = try mapToMistralRequest(request, stream: false)

        // Build headers
        let headers = buildHeaders(apiKey: apiKey, stream: false)

        // Encode request to JSON
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(mistralRequest)

        // Send request
        let endpoint = "\(baseURL)/chat/completions"
        let responseData = try await httpClient.post(
            url: endpoint,
            headers: headers,
            body: jsonData
        )

        // Decode response
        let decoder = JSONDecoder()
        let mistralResponse = try decoder.decode(MistralResponse.self, from: responseData)

        // Map to AIResponse
        return mapToAIResponse(mistralResponse)
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Build Mistral request with streaming enabled
                    let mistralRequest = try mapToMistralRequest(request, stream: true)

                    // Build headers for streaming
                    let headers = buildHeaders(apiKey: apiKey, stream: true)

                    // Encode request to JSON
                    let encoder = JSONEncoder()
                    let jsonData = try encoder.encode(mistralRequest)

                    // Create stream
                    let endpoint = "\(baseURL)/chat/completions"
                    let stream = try await httpClient.streamPost(
                        url: endpoint,
                        headers: headers,
                        body: jsonData
                    )

                    // Accumulate content
                    var accumulatedContent = ""
                    var finishReason: String?
                    var totalUsage: MistralStreamChunk.Usage?

                    // Process stream chunks
                    for try await chunk in stream {
                        let chunkString = String(data: chunk, encoding: .utf8) ?? ""
                        let lines = chunkString.split(separator: "\n")

                        for line in lines {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)

                            // Check for stream end signal
                            if trimmed == "data: [DONE]" {
                                break
                            }

                            // Parse SSE format: "data: {...}"
                            guard trimmed.hasPrefix("data: ") else { continue }
                            let jsonString = trimmed.dropFirst(6) // Remove "data: " prefix

                            // Parse JSON chunk
                            guard let data = jsonString.data(using: .utf8) else { continue }
                            let decoder = JSONDecoder()
                            let streamChunk = try decoder.decode(MistralStreamChunk.self, from: data)

                            // Extract delta content
                            guard let choice = streamChunk.choices.first else { continue }

                            // Accumulate content
                            if let content = choice.delta.content {
                                accumulatedContent += content
                            }

                            // Check finish reason
                            if let reason = choice.finishReason {
                                finishReason = reason
                            }

                            // Capture usage if present
                            if let usage = streamChunk.usage {
                                totalUsage = usage
                            }

                            // Yield intermediate response
                            let response = AIResponse(
                                id: streamChunk.id,
                                model: streamChunk.model,
                                message: AIMessage(
                                    role: .assistant,
                                    content: [.text(accumulatedContent)]
                                ),
                                stopReason: finishReason.map(mapFinishReason),
                                usage: totalUsage.map { usage in
                                    AIUsage(
                                        inputTokens: usage.promptTokens,
                                        outputTokens: usage.completionTokens
                                    )
                                },
                                provider: .mistral
                            )
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
        // Mistral doesn't have a separate token counting endpoint
        // Tokens are available in the response usage field
        return nil
    }

    // MARK: - Private Helpers

    /// Build HTTP headers for Mistral API
    private func buildHeaders(apiKey: String, stream: Bool) -> [(String, String)] {
        var headers = [
            ("Authorization", "Bearer \(apiKey)"),
            ("Content-Type", "application/json")
        ]
        if stream {
            headers.append(("Accept", "text/event-stream"))
        }
        return headers
    }

    /// Map AIRequest to MistralRequest
    private func mapToMistralRequest(_ request: AIRequest, stream: Bool) throws -> MistralRequest {
        // Map messages
        var mistralMessages: [MistralMessage] = []

        // Add system prompt as system message if present
        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
            mistralMessages.append(MistralMessage(
                role: .system,
                content: .text(systemPrompt)
            ))
        }

        // Map request messages
        for message in request.messages {
            mistralMessages.append(try mapMessage(message))
        }

        // Map tools if present
        let tools = request.tools?.map { mapTool($0) }
        let toolChoice = request.toolChoice.map { mapToolChoice($0) }

        // Build request
        return MistralRequest(
            model: request.model,
            messages: mistralMessages,
            maxTokens: request.maxTokens,
            temperature: request.temperature,
            topP: request.topP,
            stream: stream,
            safePrompt: nil, // Can be added as an option
            randomSeed: nil, // Can be added as an option
            stop: request.stopSequences,
            responseFormat: nil, // Can be added for JSON mode
            tools: tools,
            toolChoice: toolChoice,
            frequencyPenalty: nil,
            presencePenalty: nil
        )
    }

    /// Map AIMessage to MistralMessage
    private func mapMessage(_ message: AIMessage) throws -> MistralMessage {
        let role: MistralMessage.Role
        switch message.role {
        case .system:
            role = .system
        case .user:
            role = .user
        case .assistant:
            role = .assistant
        }

        // Check if message contains tool calls
        let toolCalls = message.content.compactMap { content -> MistralToolCall? in
            if case .toolCall(let toolCall) = content {
                return MistralToolCall(
                    id: toolCall.id,
                    type: toolCall.type,
                    function: MistralToolCall.FunctionCall(
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
                return MistralMessage(
                    role: .tool,
                    content: .text(result),
                    toolCallId: id
                )
            }
        }

        // If we have tool calls, return assistant message with tool calls
        if !toolCalls.isEmpty {
            return MistralMessage(
                role: .assistant,
                content: nil,
                toolCalls: toolCalls
            )
        }

        // Map content
        if message.content.isEmpty {
            return MistralMessage(role: role, content: nil)
        } else if message.content.count == 1, case .text(let text) = message.content[0] {
            // Simple text message
            return MistralMessage(role: role, content: .text(text))
        } else {
            // Multi-part content (text + images, excluding tool calls/results)
            let contentBlocks = try message.content.compactMap { content -> MistralContentBlock? in
                // Skip tool-related content in this mapping
                switch content {
                case .toolCall, .toolResult:
                    return nil
                default:
                    return try mapContentBlock(content)
                }
            }

            if contentBlocks.isEmpty {
                return MistralMessage(role: role, content: nil)
            }

            return MistralMessage(role: role, content: .contentArray(contentBlocks))
        }
    }

    /// Map AIMessageContent to MistralContentBlock
    private func mapContentBlock(_ block: AIMessageContent) throws -> MistralContentBlock {
        switch block {
        case .text(let text):
            return .text(text)
        case .image(let source, _):
            switch source {
            case .url(let url):
                return .imageUrl(url: url, detail: nil)
            case .base64(let base64String):
                // Create data URL from base64 string
                let dataURL = "data:image/jpeg;base64,\(base64String)"
                return .imageUrl(url: dataURL, detail: nil)
            }
        case .document:
            throw AIError.unsupportedFeature(feature: "PDF documents", provider: .mistral)
        case .toolCall, .toolResult:
            // Tool calls and results are handled separately in mapMessage
            throw AIError.invalidRequest(message: "Tool calls and results should be handled in message mapping")
        case .custom:
            throw AIError.unsupportedFeature(feature: "Custom content blocks", provider: .mistral)
        }
    }

    /// Map MistralResponse to AIResponse
    private func mapToAIResponse(_ response: MistralResponse) -> AIResponse {
        guard let choice = response.choices.first else {
            return AIResponse(
                id: response.id,
                model: response.model,
                message: AIMessage(role: .assistant, content: []),
                stopReason: .endTurn,
                usage: nil,
                provider: .mistral
            )
        }

        var content: [AIMessageContent] = []

        // Extract message content
        if let messageContent = choice.message.content {
            switch messageContent {
            case .text(let text):
                content.append(.text(text))
            case .contentArray(let blocks):
                content.append(contentsOf: blocks.compactMap { block in
                    if case .text(let text) = block {
                        return .text(text)
                    }
                    return nil
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

        // Map finish reason
        let stopReason = choice.finishReason.map(mapFinishReason) ?? .endTurn

        // Map usage
        let usage = AIUsage(
            inputTokens: response.usage.promptTokens,
            outputTokens: response.usage.completionTokens
        )

        return AIResponse(
            id: response.id,
            model: response.model,
            message: AIMessage(
                role: .assistant,
                content: content
            ),
            stopReason: stopReason,
            usage: usage,
            provider: .mistral
        )
    }

    /// Map AITool to MistralToolDefinition
    private func mapTool(_ tool: AITool) -> MistralToolDefinition {
        // Convert AIToolParameters properties to Mistral format
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

        return MistralToolDefinition(
            function: MistralToolDefinition.FunctionDefinition(
                name: tool.name,
                description: tool.description,
                parameters: parameters
            )
        )
    }

    /// Map AIToolChoice to MistralToolChoice
    private func mapToolChoice(_ choice: AIToolChoice) -> MistralToolChoice {
        switch choice {
        case .auto:
            return .auto
        case .required:
            return .any
        case .none:
            return .none
        case .specific(let toolName):
            return .specific(name: toolName)
        }
    }

    /// Map Mistral finish reason to AIStopReason
    private func mapFinishReason(_ reason: String) -> AIStopReason {
        switch reason {
        case "stop":
            return .endTurn
        case "length":
            return .maxTokens
        case "tool_calls":
            return .toolUse
        case "content_filter":
            return .stopSequence // Map to stopSequence as closest match
        default:
            return .endTurn
        }
    }
}
