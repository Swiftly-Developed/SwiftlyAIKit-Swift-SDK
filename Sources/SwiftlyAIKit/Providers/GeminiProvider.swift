import Foundation
import Vapor

/// Google Gemini provider implementation
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
        return try mapToAIResponse(geminiResponse, model: request.model)
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let geminiRequest = try mapToGeminiRequest(request)
                    let headers = buildHeaders(stream: true)
                    let jsonData = try JSONEncoder().encode(geminiRequest)

                    let url = "\(baseURL)/models/\(request.model):streamGenerateContent?alt=sse&key=\(apiKey)"
                    let stream = try await httpClient.streamPost(
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

        return GeminiRequest(
            contents: contents,
            systemInstruction: systemInstruction,
            generationConfig: generationConfig
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
            case .url(let url):
                // Gemini requires fileData or inlineData, not URLs
                throw AIError.unsupportedFeature(feature: "Image URLs (use base64 instead)", provider: .google)

            case .base64(let data):
                let mimeType = mediaType ?? "image/jpeg"
                return .inlineData(mimeType: mimeType, data: data)
            }

        case .document(let source, let mediaType):
            switch source {
            case .url(let url):
                // For file URIs uploaded via Files API
                let mimeType = mediaType ?? "application/pdf"
                return .fileData(mimeType: mimeType, fileUri: url)

            case .base64(let data):
                let mimeType = mediaType ?? "application/pdf"
                return .inlineData(mimeType: mimeType, data: data)
            }

        case .custom:
            throw AIError.unsupportedFeature(feature: "Custom content", provider: .google)
        }
    }

    private func mapToAIResponse(_ response: GeminiResponse, model: String) throws -> AIResponse {
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

        // Extract text content from parts
        let content: [AIMessageContent] = candidate.content.parts.compactMap { part in
            switch part {
            case .text(let text):
                return .text(text)
            case .functionCall:
                return nil // Tool calls not mapped yet
            case .functionResponse:
                return nil
            case .inlineData, .fileData:
                return nil
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
