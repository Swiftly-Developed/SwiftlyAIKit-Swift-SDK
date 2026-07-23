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
/// ### Gemini-Specific Methods
/// - ``listModels(apiKey:)``
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

                            // Extract text and function calls from candidate
                            if let candidate = streamChunk.candidates.first {
                                let chunkText = candidate.content.parts.compactMap { part -> String? in
                                    if case .text(let text) = part { return text }
                                    return nil
                                }.joined()
                                if !chunkText.isEmpty {
                                    accumulatedText += chunkText
                                }

                                // Function calls arrive complete in a single chunk for Gemini.
                                var toolCalls: [AIMessageContent] = []
                                for part in candidate.content.parts {
                                    if case .functionCall(let name, let args) = part {
                                        let argsData = try? JSONSerialization.data(withJSONObject: args.mapValues { $0.value })
                                        let argsString = argsData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                                        toolCalls.append(.toolCall(AIToolCall(
                                            id: name,
                                            type: "function",
                                            name: name,
                                            arguments: argsString
                                        )))
                                    }
                                }

                                var content: [AIMessageContent] = accumulatedText.isEmpty ? [] : [.text(accumulatedText)]
                                content.append(contentsOf: toolCalls)
                                let message = AIMessage(role: .assistant, content: content)

                                let usage: AIUsage?
                                if let metadata = streamChunk.usageMetadata {
                                    usage = AIUsage(
                                        inputTokens: metadata.promptTokenCount,
                                        outputTokens: metadata.candidatesTokenCount
                                    )
                                } else {
                                    usage = nil
                                }

                                let stopReason: AIStopReason? = !toolCalls.isEmpty
                                    ? .toolUse
                                    : candidate.finishReason.map { mapFinishReason($0) }

                                let response = AIResponse(
                                    id: UUID().uuidString,
                                    model: request.model,
                                    message: message,
                                    stopReason: stopReason,
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

    // MARK: - Gemini-Specific Methods

    /// List available models from Google's `GET /v1beta/models` (`models.list`) endpoint.
    ///
    /// Returns the RAW model list — the caller is responsible for filtering (e.g. to entries
    /// whose ``GeminiModelInfo/supportedGenerationMethods`` contain `"generateContent"`).
    /// - Parameter apiKey: Google API key (sent as the `key` query parameter, matching send/stream)
    /// - Returns: List of available Gemini models
    public func listModels(apiKey: String) async throws -> GeminiModelsResponse {
        let url = "\(baseURL)/models?key=\(apiKey)"
        let headers = buildHeaders(stream: false)
        let responseData = try await httpClient.get(url: url, headers: headers)
        let decoder = JSONDecoder()
        // NOTE: plain decoder — Google's payload is camelCase, matching the model properties.
        // Do NOT enable .convertFromSnakeCase (mirrors OpenAIProvider/AnthropicProvider
        // listModels; the strategy misbehaves on the Linux Foundation this SDK ships to).
        return try decoder.decode(GeminiModelsResponse.self, from: responseData)
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

    func mapToGeminiRequest(_ request: AIRequest) throws -> GeminiRequest {
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
        // Build an id -> function-name lookup from every assistant tool call so that a
        // later tool result (which only carries the id) maps to the correct
        // functionResponse name. Gemini identifies function responses by name, not id.
        let toolCallNamesByID = toolCallNameLookup(request.messages)
        return try request.messages.map { message in
            let role = message.role == .user ? "user" : "model"
            let parts = try message.content.map { try mapContentPart($0, toolCallNamesByID: toolCallNamesByID) }
            return GeminiContent(role: role, parts: parts)
        }
    }

    /// Map each tool-call id to its function name across the whole conversation.
    private func toolCallNameLookup(_ messages: [AIMessage]) -> [String: String] {
        var lookup: [String: String] = [:]
        for message in messages {
            for content in message.content {
                if case .toolCall(let toolCall) = content {
                    lookup[toolCall.id] = toolCall.name
                }
            }
        }
        return lookup
    }

    private func mapContentPart(_ content: AIMessageContent, toolCallNamesByID: [String: String]) throws -> GeminiPart {
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
            // Map to Gemini function call. Tolerate an empty / non-object argument string
            // (e.g. a zero-argument call) by falling back to an empty object, mirroring the
            // response-decoding side instead of throwing `.invalidRequest`.
            let args = toolCall.normalizedArgumentsDictionary.mapValues { AnyCodable($0) }
            return .functionCall(name: toolCall.name, args: args)

        case .toolResult(let id, let result):
            // Gemini identifies function responses by the function *name*, not by an id.
            // Resolve the originating tool call's name from the conversation; fall back to
            // the id (which Gemini responses use as the id) when it can't be resolved.
            let name = toolCallNamesByID[id] ?? id
            return .functionResponse(name: name, response: ["result": AnyCodable(result)])

        case .custom:
            throw AIError.unsupportedFeature(feature: "Custom content", provider: .google)
        }
    }

    func mapToAIResponse(_ response: GeminiResponse, model: String) -> AIResponse {
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
        var hasToolCall = false
        let content: [AIMessageContent] = candidate.content.parts.compactMap { part in
            switch part {
            case .text(let text):
                return .text(text)
            case .functionCall(let name, let args):
                hasToolCall = true
                // Convert args back to JSON string
                let argsData = try? JSONSerialization.data(withJSONObject: args.mapValues { $0.value })
                let argsString = argsData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                // Gemini doesn't provide tool-call IDs. Use the function name as the id so a
                // subsequent tool result (which only carries the id) round-trips to the correct
                // functionResponse name.
                return .toolCall(AIToolCall(
                    id: name,
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

        // Gemini reports finishReason STOP even when it emits a function call; surface
        // .toolUse so callers can drive their tool loop consistently across providers.
        let stopReason: AIStopReason? = hasToolCall ? .toolUse : candidate.finishReason.map { mapFinishReason($0) }

        return AIResponse(
            id: UUID().uuidString,
            model: model,
            message: message,
            stopReason: stopReason,
            usage: usage,
            provider: .google
        )
    }

    private func mapTool(_ tool: AITool) -> GeminiFunctionDeclaration {
        // Convert AIToolParameters to Gemini Schema format (recurses into nested
        // objects and arrays-of-objects).
        let schema = GeminiSchema(
            type: tool.parameters.type.uppercased(),
            properties: tool.parameters.properties.mapValues { mapSchemaProperty($0) },
            required: tool.parameters.required
        )

        return GeminiFunctionDeclaration(
            name: tool.name,
            description: tool.description,
            parameters: schema
        )
    }

    /// Recursively map a neutral tool property to Gemini's typed schema property.
    private func mapSchemaProperty(_ property: AIToolProperty) -> GeminiSchemaProperty {
        GeminiSchemaProperty(
            type: property.type.uppercased(),
            description: property.description,
            items: property.items.map { mapSchemaItems($0) },
            enumValues: property.enum,
            properties: property.properties.map { $0.mapValues { mapSchemaProperty($0) } },
            required: property.required
        )
    }

    /// Recursively map a neutral array-items schema to Gemini's typed items schema.
    private func mapSchemaItems(_ items: AIToolPropertyItems) -> GeminiSchemaItems {
        GeminiSchemaItems(
            type: items.type.uppercased(),
            properties: items.properties.map { $0.mapValues { mapSchemaProperty($0) } },
            required: items.required
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

// MARK: - ImageGenerationProvider

extension GeminiProvider: ImageGenerationProvider {
    /// Default model used when a request omits the model id.
    static let defaultImageModel = "gemini-3.1-flash-image"

    /// Image models this provider can serve.
    ///
    /// `gemini-*-image` ids are routed to `:generateContent` (Google's live, recommended
    /// "Nano Banana" image path); `imagen-*` ids are routed to the Imagen `:predict` API,
    /// which Google has deprecated for shutdown on 2026-08-17.
    static let imageModels: [String] = [
        "gemini-3.1-flash-image",
        "gemini-3.1-flash-lite-image",
        "gemini-3-pro-image",
        "gemini-2.5-flash-image",
        "imagen-4.0-generate-001",
        "imagen-4.0-fast-generate-001",
        "imagen-4.0-ultra-generate-001"
    ]

    public var supportsImageGeneration: Bool { true }

    public var imageGenerationModels: [String] { GeminiProvider.imageModels }

    /// Generate images from a text prompt.
    ///
    /// Dispatches on the model id: `imagen-*` ids use the Imagen `:predict` API, all other
    /// (Gemini-native `gemini-*-image`) ids use `:generateContent` with `responseModalities`.
    /// Both paths return base64-encoded image bytes in ``GeneratedImage/base64Data``.
    ///
    /// - Parameters:
    ///   - request: The unified image generation request
    ///   - apiKey: Google API key (sent as the `key` query parameter)
    /// - Returns: Generated images
    /// - Throws: AIError / decoding errors on failure
    public func generateImage(
        _ request: ImageGenerationRequest,
        apiKey: String
    ) async throws -> ImageGenerationResponse {
        let model = request.model.isEmpty ? GeminiProvider.defaultImageModel : request.model

        if model.lowercased().hasPrefix("imagen") {
            return try await generateImageViaImagen(request, model: model, apiKey: apiKey)
        }
        return try await generateImageViaGenerateContent(request, model: model, apiKey: apiKey)
    }

    // MARK: Imagen `:predict`

    private func generateImageViaImagen(
        _ request: ImageGenerationRequest,
        model: String,
        apiKey: String
    ) async throws -> ImageGenerationResponse {
        let predictRequest = ImagenPredictRequest(
            instances: [ImagenInstance(prompt: request.prompt)],
            parameters: ImagenParameters(
                sampleCount: request.numberOfImages,
                aspectRatio: request.size.aspectRatio
            )
        )
        let headers = buildHeaders(stream: false)
        let jsonData = try JSONEncoder().encode(predictRequest)

        let url = "\(baseURL)/models/\(model):predict?key=\(apiKey)"
        let responseData = try await httpClient.post(url: url, headers: headers, body: jsonData)

        let predictResponse = try JSONDecoder().decode(ImagenPredictResponse.self, from: responseData)
        let images = GeminiProvider.mapImagenPredictions(predictResponse, size: request.size)

        return ImageGenerationResponse(
            id: "imagen-img-\(UUID().uuidString.prefix(8))",
            created: Date(),
            provider: .google,
            model: model,
            images: images,
            usage: ImageGenerationUsage(imagesGenerated: images.count)
        )
    }

    /// Map an Imagen `:predict` response to neutral ``GeneratedImage`` values, in order.
    static func mapImagenPredictions(_ response: ImagenPredictResponse, size: ImageSize) -> [GeneratedImage] {
        response.predictions.enumerated().map { index, prediction in
            GeneratedImage(
                index: index,
                url: nil,
                base64Data: prediction.bytesBase64Encoded,
                revisedPrompt: nil,
                size: size,
                contentType: prediction.mimeType ?? "image/png"
            )
        }
    }

    // MARK: Gemini-native `:generateContent`

    private func generateImageViaGenerateContent(
        _ request: ImageGenerationRequest,
        model: String,
        apiKey: String
    ) async throws -> ImageGenerationResponse {
        let generationConfig = GeminiGenerationConfig(
            responseModalities: ["IMAGE"],
            imageConfig: GeminiImageConfig(aspectRatio: request.size.aspectRatio)
        )
        let geminiRequest = GeminiRequest(
            contents: [GeminiContent(role: "user", parts: [.text(request.prompt)])],
            generationConfig: generationConfig
        )
        let headers = buildHeaders(stream: false)
        let jsonData = try JSONEncoder().encode(geminiRequest)

        let url = "\(baseURL)/models/\(model):generateContent?key=\(apiKey)"
        let responseData = try await httpClient.post(url: url, headers: headers, body: jsonData)

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: responseData)
        let images = GeminiProvider.extractImages(from: geminiResponse, size: request.size)

        return ImageGenerationResponse(
            id: "gemini-img-\(UUID().uuidString.prefix(8))",
            created: Date(),
            provider: .google,
            model: model,
            images: images,
            usage: ImageGenerationUsage(imagesGenerated: images.count)
        )
    }

    /// Pull every `inlineData` (image) part out of a `:generateContent` response, in order.
    static func extractImages(from response: GeminiResponse, size: ImageSize) -> [GeneratedImage] {
        var images: [GeneratedImage] = []
        for candidate in response.candidates {
            for part in candidate.content.parts {
                guard case .inlineData(let mimeType, let data) = part else { continue }
                images.append(GeneratedImage(
                    index: images.count,
                    url: nil,
                    base64Data: data,
                    revisedPrompt: nil,
                    size: size,
                    contentType: mimeType
                ))
            }
        }
        return images
    }
}
