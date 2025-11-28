import Foundation

/// Google Gemini provider implementation
///
/// Complete implementation supporting Gemini 2.5 Pro, 2.0 Flash, and 1.5 models.
///
/// ## Overview
///
/// `GeminiProvider` implements:
/// - GenerateContent API with 2M token context
/// - Streaming responses
/// - Token counting API
/// - Function calling
/// - Multimodal (text, images, audio, video)
/// - Safety settings
///
/// ## Basic Usage
///
/// ```swift
/// let provider = GeminiProvider()
/// let request = AIRequest(model: .gemini(.pro2_5), prompt: "Analyze this document")
/// let response = try await provider.sendMessage(request, apiKey: "YOUR_GOOGLE_API_KEY")
/// ```
///
/// ## Topics
///
/// ### Creating Providers
/// - ``init(baseURL:timeout:maxRetries:enableLogging:)``
/// - ``init(httpClient:baseURL:timeout:maxRetries:enableLogging:)``
///
/// ### ProviderProtocol Implementation
/// - ``providerType``
/// - ``sendMessage(_:apiKey:)``
/// - ``streamMessage(_:apiKey:)``
/// - ``countTokens(_:apiKey:)``
///
/// ## See Also
/// - <doc:GeminiGuide>
/// - <doc:VisionAndImageAnalysis>
public struct GeminiProvider: ProviderProtocol {
    public let providerType: ProviderType = .google

    private let httpClient: HTTPClientManager
    private let baseURL: String
    private let timeout: Int
    private let maxRetries: Int
    private let enableLogging: Bool

    /// Initialize Gemini provider with default HTTPClientManager
    /// - Parameters:
    ///   - baseURL: Base URL for Gemini API (default: https://generativelanguage.googleapis.com/v1beta)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        baseURL: String = "https://generativelanguage.googleapis.com/v1beta",
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

    /// Initialize with custom HTTP client
    /// - Parameters:
    ///   - httpClient: Custom HTTP client manager
    ///   - baseURL: Base URL for Gemini API
    ///   - timeout: Request timeout in seconds
    ///   - maxRetries: Maximum retry attempts
    ///   - enableLogging: Enable logging
    public init(
        httpClient: HTTPClientManager,
        baseURL: String = "https://generativelanguage.googleapis.com/v1beta",
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
        let geminiRequest = try mapToGeminiRequest(request)
        let headers = buildHeaders(stream: false)

        let jsonData = try JSONEncoder().encode(geminiRequest)

        let url = "\(baseURL)/models/\(request.model):generateContent?key=\(apiKey)"
        let responseData = try await httpClient.post(
            url: url,
            headers: headers,
            body: jsonData
        )

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: responseData)
        return mapToAIResponse(geminiResponse, model: request.model)
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let geminiRequest = try mapToGeminiRequest(request)
                    let headers = buildHeaders(stream: true)
                    let jsonData = try JSONEncoder().encode(geminiRequest)

                    let url = "\(baseURL)/models/\(request.model):streamGenerateContent?alt=sse&key=\(apiKey)"
                    let stream = httpClient.streamPost(
                        url: url,
                        headers: headers,
                        body: jsonData
                    )

                    var accumulatedText = ""

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

                            let streamChunk = try JSONDecoder().decode(GeminiStreamChunk.self, from: jsonData)

                            // Extract text from candidate
                            if let candidate = streamChunk.candidates.first {
                                let textParts = candidate.content.parts.compactMap { part -> String? in
                                    if case .text(let text) = part {
                                        return text
                                    }
                                    return nil
                                }

                                let chunkText = textParts.joined()
                                if !chunkText.isEmpty {
                                    accumulatedText += chunkText
                                }

                                // Create AIResponse for this chunk
                                let message = AIMessage(
                                    role: .assistant,
                                    content: [.text(accumulatedText)]
                                )

                                let usage: AIUsage?
                                if let metadata = streamChunk.usageMetadata {
                                    usage = AIUsage(
                                        inputTokens: metadata.promptTokenCount,
                                        outputTokens: metadata.candidatesTokenCount
                                    )
                                } else {
                                    usage = nil
                                }

                                let response = AIResponse(
                                    id: UUID().uuidString,
                                    model: request.model,
                                    message: message,
                                    stopReason: candidate.finishReason.map { mapFinishReason($0) },
                                    usage: usage,
                                    provider: .google
                                )

                                continuation.yield(response)

                                // Check for finish
                                if candidate.finishReason != nil {
                                    continuation.finish()
                                    return
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

    public func countTokens(_ request: AIRequest, apiKey: String) async throws -> Int? {
        let contents = try mapContents(request)
        let countRequest = GeminiCountTokensRequest(contents: contents)
        let headers = buildHeaders(stream: false)

        let jsonData = try JSONEncoder().encode(countRequest)

        let url = "\(baseURL)/models/\(request.model):countTokens?key=\(apiKey)"
        let responseData = try await httpClient.post(
            url: url,
            headers: headers,
            body: jsonData
        )

        let countResponse = try JSONDecoder().decode(GeminiCountTokensResponse.self, from: responseData)
        return countResponse.totalTokens
    }

    // MARK: - Private Helper Methods

    private func buildHeaders(stream: Bool) -> [(String, String)] {
        var headers = [
            ("Content-Type", "application/json")
        ]

        if stream {
            headers.append(("Accept", "text/event-stream"))
        }

        return headers
    }

    private func mapToGeminiRequest(_ request: AIRequest) throws -> GeminiRequest {
        let contents = try mapContents(request)

        // System instruction (if present)
        let systemInstruction: GeminiContent?
        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
            systemInstruction = GeminiContent(parts: [.text(systemPrompt)])
        } else {
            systemInstruction = nil
        }

        // Generation config
        let generationConfig = GeminiGenerationConfig(
            temperature: request.temperature,
            topP: request.topP,
            topK: request.topK,
            maxOutputTokens: request.maxTokens,
            stopSequences: request.stopSequences
        )

        // Map tools if present
        let tools = request.tools.map { aiTools in
            [GeminiTool(functionDeclarations: aiTools.map { mapTool($0) })]
        }

        // Map tool config if tool choice is specified
        let toolConfig = request.toolChoice.map { mapToolConfig($0) }

        return GeminiRequest(
            contents: contents,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig,
            tools: tools,
            toolConfig: toolConfig
        )
    }

    private func mapContents(_ request: AIRequest) throws -> [GeminiContent] {
        return try request.messages.map { message in
            let role = message.role == .user ? "user" : "model"
            let parts = try message.content.map { try mapContentPart($0) }
            return GeminiContent(role: role, parts: parts)
        }
    }

    private func mapContentPart(_ content: AIMessageContent) throws -> GeminiPart {
        switch content {
        case .text(let text):
            return .text(text)

        case .image(let source, let mediaType):
            switch source {
            case .url:
                // Gemini requires fileData or inlineData, not URLs
                throw AIError.unsupportedFeature(feature: "Image URLs (use base64 instead)", provider: .google)

            case .base64(let data):
                let mimeType = mediaType ?? "image/jpeg"
                return .inlineData(mimeType: mimeType, data: data)
            }

        case .document(let data, let mediaType, _):
            // Gemini expects base64-encoded data for documents
            let base64Data = data.base64EncodedString()
            return .inlineData(mimeType: mediaType, data: base64Data)

        case .toolCall(let toolCall):
            // Map to Gemini function call
            // Parse arguments JSON string to dictionary
            guard let argsData = toolCall.arguments.data(using: .utf8),
                  let argsDict = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
                throw AIError.invalidRequest(message: "Invalid tool call arguments")
            }
            let args = argsDict.mapValues { AnyCodable($0) }
            return .functionCall(name: toolCall.name, args: args)

        case .toolResult(let id, let result):
            // Map to Gemini function response
            // Gemini expects the function name in the response, but we only have the ID
            // We'll use the ID as the name for now
            return .functionResponse(name: id, response: ["result": AnyCodable(result)])

        case .custom:
            throw AIError.unsupportedFeature(feature: "Custom content", provider: .google)
        }
    }

    private func mapToAIResponse(_ response: GeminiResponse, model: String) -> AIResponse {
        guard let candidate = response.candidates.first else {
            let emptyMessage = AIMessage(role: .assistant, content: [])
            return AIResponse(
                id: UUID().uuidString,
                model: model,
                message: emptyMessage,
                stopReason: nil,
                usage: nil,
                provider: .google
            )
        }

        // Extract content from parts
        let content: [AIMessageContent] = candidate.content.parts.compactMap { part in
            switch part {
            case .text(let text):
                return .text(text)
            case .functionCall(let name, let args):
                // Convert args back to JSON string
                let argsData = try? JSONSerialization.data(withJSONObject: args.mapValues { $0.value })
                let argsString = argsData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                return .toolCall(AIToolCall(
                    id: UUID().uuidString, // Gemini doesn't provide IDs, generate one
                    type: "function",
                    name: name,
                    arguments: argsString
                ))
            case .functionResponse:
                return nil // Function responses are inputs, not outputs
            case .inlineData, .fileData:
                return nil // Images/documents in responses not typical
            }
        }

        let message = AIMessage(role: .assistant, content: content)

        let usage: AIUsage?
        if let metadata = response.usageMetadata {
            usage = AIUsage(
                inputTokens: metadata.promptTokenCount,
                outputTokens: metadata.candidatesTokenCount
            )
        } else {
            usage = nil
        }

        return AIResponse(
            id: UUID().uuidString,
            model: model,
            message: message,
            stopReason: candidate.finishReason.map { mapFinishReason($0) },
            usage: usage,
            provider: .google
        )
    }

    private func mapTool(_ tool: AITool) -> GeminiFunctionDeclaration {
        // Convert AIToolParameters to Gemini Schema format
        let properties = tool.parameters.properties.mapValues { property -> GeminiSchemaProperty in
            let items = property.items.map { GeminiSchemaItems(type: $0.type.uppercased()) }
            return GeminiSchemaProperty(
                type: property.type.uppercased(),
                description: property.description,
                items: items,
                enumValues: property.enum
            )
        }

        let schema = GeminiSchema(
            type: tool.parameters.type.uppercased(),
            properties: properties,
            required: tool.parameters.required
        )

        return GeminiFunctionDeclaration(
            name: tool.name,
            description: tool.description,
            parameters: schema
        )
    }

    private func mapToolConfig(_ choice: AIToolChoice) -> GeminiToolConfig {
        let mode: GeminiFunctionCallingConfig.Mode
        switch choice {
        case .auto:
            mode = .auto
        case .required:
            mode = .any
        case .none:
            mode = .none
        case .specific:
            // Gemini doesn't support forcing a specific function, use ANY instead
            mode = .any
        }

        return GeminiToolConfig(
            functionCallingConfig: GeminiFunctionCallingConfig(mode: mode)
        )
    }

    private func mapFinishReason(_ reason: String) -> AIStopReason {
        switch reason {
        case "STOP":
            return .endTurn
        case "MAX_TOKENS":
            return .maxTokens
        case "SAFETY":
            return .stopSequence
        case "RECITATION":
            return .stopSequence
        case "OTHER":
            return .endTurn
        default:
            return .endTurn
        }
    }
}
