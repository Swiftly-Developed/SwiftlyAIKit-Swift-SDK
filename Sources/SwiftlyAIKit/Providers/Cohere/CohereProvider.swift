import Foundation

/// Cohere AI provider implementation
///
/// RAG-optimized AI with automatic citations and token counting.
///
/// ## Topics
///
/// ### ProviderProtocol
/// - ``providerType``
/// - ``sendMessage(_:apiKey:)``
/// - ``streamMessage(_:apiKey:)``
/// - ``countTokens(_:apiKey:)``
///
/// ## See Also
/// - <doc:CohereGuide>
/// - <doc:RAGOptimization>
public struct CohereProvider: ProviderProtocol {
    public let providerType: ProviderType = .cohere
    private let httpClient: HTTPClientManager
    private let baseURL: String
    private let timeout: Int
    private let maxRetries: Int
    private let enableLogging: Bool

    // MARK: - Initializers

    /// Initialize with default HTTP client
    public init(
        baseURL: String = "https://api.cohere.com/v2",
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
        baseURL: String = "https://api.cohere.com/v2",
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
        // Build Cohere request
        let cohereRequest = try mapToCohereRequest(request, stream: false)

        // Build headers
        let headers = buildHeaders(apiKey: apiKey, stream: false)

        // Encode request to JSON
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(cohereRequest)

        // Send request
        let endpoint = "\(baseURL)/chat"
        let responseData = try await httpClient.post(
            url: endpoint,
            headers: headers,
            body: jsonData
        )

        // Decode response
        let decoder = JSONDecoder()
        do {
            let cohereResponse = try decoder.decode(CohereResponse.self, from: responseData)
            return mapToAIResponse(cohereResponse)
        } catch {
            // Try to decode as error response
            if let errorResponse = try? decoder.decode(CohereErrorResponse.self, from: responseData) {
                throw mapCohereError(errorResponse)
            }
            throw AIError.decodingError(message: "Failed to decode Cohere response: \(error.localizedDescription)")
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Build Cohere request with streaming enabled
                    let cohereRequest = try mapToCohereRequest(request, stream: true)

                    // Build headers for streaming
                    let headers = buildHeaders(apiKey: apiKey, stream: true)

                    // Encode request to JSON
                    let encoder = JSONEncoder()
                    let jsonData = try encoder.encode(cohereRequest)

                    // Create stream
                    let endpoint = "\(baseURL)/chat"
                    let stream = httpClient.streamPost(
                        url: endpoint,
                        headers: headers,
                        body: jsonData
                    )

                    // Accumulate content and state
                    var accumulatedContent = ""
                    var finishReason: String?
                    var totalUsage: CohereResponse.Usage?
                    var responseId: String?
                    var citations: [CohereCitation] = []

                    // Process stream events
                    for try await chunk in stream {
                        let chunkString = String(data: chunk, encoding: .utf8) ?? ""
                        let lines = chunkString.split(separator: "\n")

                        for line in lines {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)

                            // Skip empty lines
                            guard !trimmed.isEmpty else { continue }

                            // Parse SSE format: "data: {...}"
                            guard trimmed.hasPrefix("data: ") else { continue }
                            let jsonString = trimmed.dropFirst(6) // Remove "data: " prefix

                            // Parse JSON event
                            guard let data = jsonString.data(using: .utf8) else { continue }
                            let decoder = JSONDecoder()
                            let event = try decoder.decode(CohereStreamEvent.self, from: data)

                            // Process event by type
                            switch event.type {
                            case "message-start":
                                // Capture response ID
                                if let id = event.id {
                                    responseId = id
                                }

                            case "content-delta":
                                // Accumulate text content
                                if let text = event.delta?.message?.content?.text {
                                    accumulatedContent += text
                                }

                                // Yield intermediate response
                                let response = AIResponse(
                                    id: responseId ?? "stream-unknown",
                                    model: request.model,
                                    message: AIMessage(
                                        role: .assistant,
                                        content: [.text(accumulatedContent)]
                                    ),
                                    stopReason: nil,
                                    usage: nil,
                                    provider: .cohere
                                )
                                continuation.yield(response)

                            case "citation-start":
                                // Capture citation
                                if let citation = event.citation {
                                    citations.append(citation)
                                }

                            case "message-end":
                                // Extract finish reason and usage
                                if let reason = event.delta?.finishReason {
                                    finishReason = reason
                                }
                                if let usage = event.delta?.usage {
                                    totalUsage = usage
                                }

                                // Yield final response
                                let finalResponse = AIResponse(
                                    id: responseId ?? "stream-unknown",
                                    model: request.model,
                                    message: AIMessage(
                                        role: .assistant,
                                        content: [.text(accumulatedContent)]
                                    ),
                                    stopReason: finishReason.map(mapFinishReason),
                                    usage: totalUsage.map { usage in
                                        AIUsage(
                                            inputTokens: usage.billedUnits?.inputTokens ?? 0,
                                            outputTokens: usage.billedUnits?.outputTokens ?? 0
                                        )
                                    },
                                    provider: .cohere
                                )
                                continuation.yield(finalResponse)

                            default:
                                // Ignore other event types (content-start, content-end, tool events, etc.)
                                break
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
        // Cohere has a dedicated tokenize endpoint
        // Combine system prompt and messages into text
        var fullText = ""
        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
            fullText += systemPrompt + "\n\n"
        }

        for message in request.messages {
            for content in message.content {
                if case .text(let text) = content {
                    fullText += text + "\n"
                }
            }
        }

        // Build tokenize request
        let tokenizeRequest = CohereTokenizeRequest(text: fullText, model: request.model)

        // Build headers
        let headers = buildHeaders(apiKey: apiKey, stream: false)

        // Encode request
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(tokenizeRequest)

        // Send request
        let endpoint = "\(baseURL)/tokenize"
        let responseData = try await httpClient.post(
            url: endpoint,
            headers: headers,
            body: jsonData
        )

        // Decode response
        let decoder = JSONDecoder()
        let tokenizeResponse = try decoder.decode(CohereTokenizeResponse.self, from: responseData)

        return tokenizeResponse.tokens.count
    }

    // MARK: - Private Helpers

    /// Build HTTP headers for Cohere API
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

    /// Map AIRequest to CohereRequest
    private func mapToCohereRequest(_ request: AIRequest, stream: Bool) throws -> CohereRequest {
        // Map messages
        var cohereMessages: [CohereMessage] = []

        // Add system prompt as system message if present
        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
            cohereMessages.append(CohereMessage(
                role: .system,
                content: .text(systemPrompt)
            ))
        }

        // Map request messages
        for message in request.messages {
            cohereMessages.append(try mapMessage(message))
        }

        // Map tools if present
        let tools = request.tools?.map { mapTool($0) }

        // Extract Cohere-specific options from providerOptions if present
        var documents: [CohereDocument]?
        var responseFormat: CohereResponseFormat?
        var safetyMode: CohereRequest.SafetyMode?

        if let providerOptions = request.providerOptions {
            // Check for documents (RAG)
            if let docsValue = providerOptions["documents"],
               let docs = docsValue.value as? [[String: String]] {
                documents = docs.compactMap { doc in
                    guard let id = doc["id"], let text = doc["text"] else { return nil }
                    return CohereDocument(id: id, text: text)
                }
            }

            // Check for safety mode
            if let modeValue = providerOptions["safety_mode"],
               let mode = modeValue.value as? String {
                safetyMode = CohereRequest.SafetyMode(rawValue: mode)
            }

            // Check for response format (JSON mode)
            if let formatValue = providerOptions["response_format"],
               let format = formatValue.value as? [String: Any],
               let type = format["type"] as? String {
                if type == "json_object" {
                    let schema = format["schema"] as? [String: Any]
                    responseFormat = CohereResponseFormat(
                        type: .jsonObject,
                        schema: schema?.mapValues { AnyCodable($0) }
                    )
                }
            }
        }

        // Build request
        return CohereRequest(
            model: request.model,
            messages: cohereMessages,
            stream: stream,
            maxTokens: request.maxTokens,
            temperature: request.temperature,
            topP: request.topP,
            topK: nil, // Cohere supports top_k, could be added to AIRequest
            frequencyPenalty: nil,
            presencePenalty: nil,
            stopSequences: request.stopSequences,
            documents: documents,
            tools: tools,
            responseFormat: responseFormat,
            safetyMode: safetyMode
        )
    }

    /// Map AIMessage to CohereMessage
    private func mapMessage(_ message: AIMessage) throws -> CohereMessage {
        let role: CohereMessage.Role
        switch message.role {
        case .system:
            role = .system
        case .user:
            role = .user
        case .assistant:
            role = .assistant
        }

        // Check if message contains tool calls
        let toolCalls = message.content.compactMap { content -> CohereToolCall? in
            if case .toolCall(let toolCall) = content {
                return CohereToolCall(
                    id: toolCall.id,
                    type: toolCall.type,
                    function: CohereToolCall.FunctionCall(
                        name: toolCall.name,
                        arguments: toolCall.arguments
                    )
                )
            }
            return nil
        }

        // If we have tool calls, create message with tool calls
        if !toolCalls.isEmpty {
            return CohereMessage(role: role, content: nil, toolCalls: toolCalls)
        }

        // Check if message is a tool result
        if let toolResult = message.content.first(where: {
            if case .toolResult = $0 { return true }
            return false
        }) {
            if case .toolResult(let id, let result) = toolResult {
                // Cohere expects tool result in a specific format
                // Since Cohere doesn't have a separate tool result structure in the models,
                // we'll use the tool role with the result in content
                return CohereMessage(
                    role: .tool,
                    content: .text(result),
                    toolCallId: id
                )
            }
        }

        // Map content
        if message.content.isEmpty {
            return CohereMessage(role: role, content: nil)
        } else if message.content.count == 1, case .text(let text) = message.content[0] {
            // Simple text message
            return CohereMessage(role: role, content: .text(text))
        } else {
            // Multi-part content (text + images, excluding tool calls/results)
            let contentBlocks = try message.content.compactMap { content -> CohereContentBlock? in
                // Skip tool-related content in this mapping
                switch content {
                case .toolCall, .toolResult:
                    return nil
                default:
                    return try mapContentBlock(content)
                }
            }

            if contentBlocks.isEmpty {
                return CohereMessage(role: role, content: nil)
            }

            return CohereMessage(role: role, content: .contentArray(contentBlocks))
        }
    }

    /// Map AIMessageContent to CohereContentBlock
    private func mapContentBlock(_ block: AIMessageContent) throws -> CohereContentBlock {
        switch block {
        case .text(let text):
            return .text(text)
        case .image(let source, _):
            switch source {
            case .url(let url):
                return .image(url: url)
            case .base64(let base64String):
                // Create data URL from base64 string
                let dataURL = "data:image/jpeg;base64,\(base64String)"
                return .image(url: dataURL)
            }
        case .document:
            throw AIError.unsupportedFeature(feature: "PDF documents in messages", provider: .cohere)
        case .toolCall, .toolResult:
            // Tool calls and results are handled separately in mapMessage
            throw AIError.invalidRequest(message: "Tool calls and results should be handled in message mapping")
        case .custom:
            throw AIError.unsupportedFeature(feature: "Custom content blocks", provider: .cohere)
        }
    }

    /// Map CohereResponse to AIResponse
    private func mapToAIResponse(_ response: CohereResponse) -> AIResponse {
        var content: [AIMessageContent] = []

        // Extract text content
        if let contentBlocks = response.message.content, !contentBlocks.isEmpty {
            let textContent = contentBlocks.compactMap { block -> AIMessageContent? in
                if case .text(let text) = block {
                    return .text(text)
                }
                return nil
            }
            content.append(contentsOf: textContent)
        }

        // Extract tool calls if present
        if let toolCalls = response.message.toolCalls {
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
        let stopReason = response.finishReason.map(mapFinishReason) ?? .endTurn

        // Map usage
        let usage: AIUsage? = response.usage.map { usage in
            AIUsage(
                inputTokens: usage.billedUnits?.inputTokens ?? 0,
                outputTokens: usage.billedUnits?.outputTokens ?? 0
            )
        }

        return AIResponse(
            id: response.id ?? "unknown",
            model: "", // Cohere doesn't return model in response
            message: AIMessage(
                role: .assistant,
                content: content
            ),
            stopReason: stopReason,
            usage: usage,
            provider: .cohere
        )
    }

    /// Map AITool to CohereTool
    private func mapTool(_ tool: AITool) -> CohereTool {
        // Convert AIToolParameters to Cohere parameter schema format
        // Cohere uses JSON Schema format like OpenAI
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
                return propDict
            })
        ]

        if let required = tool.parameters.required {
            parameters["required"] = AnyCodable(required)
        }

        return CohereTool(
            type: "function",
            function: CohereTool.ToolFunction(
                name: tool.name,
                description: tool.description,
                parameters: parameters
            )
        )
    }

    /// Map Cohere finish reason to AIStopReason
    private func mapFinishReason(_ reason: String) -> AIStopReason {
        switch reason {
        case "COMPLETE":
            return .endTurn
        case "MAX_TOKENS":
            return .maxTokens
        case "STOP_SEQUENCE":
            return .stopSequence
        case "ERROR":
            return .endTurn // Map error to end turn as fallback
        default:
            return .endTurn
        }
    }

    /// Map CohereErrorResponse to AIError
    private func mapCohereError(_ error: CohereErrorResponse) -> AIError {
        let statusCode = error.statusCode ?? 500

        switch statusCode {
        case 401, 403:
            return .invalidAPIKey(provider: .cohere, message: error.message)
        case 429:
            return .rateLimitExceeded(provider: .cohere, retryAfter: nil)
        case 400, 422:
            return .invalidRequest(message: error.message)
        default:
            return .providerError(provider: .cohere, statusCode: statusCode, message: error.message)
        }
    }
}
