import Foundation

/// DeepSeek provider implementation (OpenAI-compatible API)
///
/// Cost-optimized AI with reasoning mode and prompt caching.
///
/// ## Topics
///
/// ### ProviderProtocol
/// - ``providerType``
/// - ``sendMessage(_:apiKey:)``
/// - ``streamMessage(_:apiKey:)``
///
/// ## See Also
/// - <doc:DeepSeekGuide>
/// - <doc:PromptCaching>
public struct DeepSeekProvider: ProviderProtocol {
    public let providerType: ProviderType = .deepseek

    private let httpClient: HTTPClientManager
    private let baseURL: String
    private let timeout: Int
    private let maxRetries: Int
    private let enableLogging: Bool

    /// Initialize DeepSeek provider with default HTTPClientManager
    /// - Parameters:
    ///   - baseURL: Base URL for DeepSeek API (default: https://api.deepseek.com)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        baseURL: String = "https://api.deepseek.com",
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

    /// Initialize DeepSeek provider with custom HTTP client
    /// - Parameters:
    ///   - httpClient: Custom HTTP client manager
    ///   - baseURL: Base URL for DeepSeek API (default: https://api.deepseek.com)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        httpClient: HTTPClientManager,
        baseURL: String = "https://api.deepseek.com",
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
        // Build DeepSeek request
        let deepseekRequest = try buildDeepSeekRequest(from: request)

        // Prepare endpoint
        let endpoint = "\(baseURL)/chat/completions"

        // Prepare headers (Bearer token authentication)
        let headers = [
            ("Authorization", "Bearer \(apiKey)"),
            ("Content-Type", "application/json")
        ]

        // Encode request to JSON
        let requestData = try JSONEncoder().encode(deepseekRequest)

        // Make HTTP request
        let responseData = try await httpClient.post(
            url: endpoint,
            headers: headers,
            body: requestData
        )

        // Decode response
        let deepseekResponse = try JSONDecoder().decode(DeepSeekResponse.self, from: responseData)

        // Transform to AIResponse
        return transformToAIResponse(deepseekResponse, originalRequest: request)
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
                    // Build DeepSeek request with streaming enabled
                    var streamRequest = try buildDeepSeekRequest(from: request)
                    streamRequest = DeepSeekRequest(
                        model: streamRequest.model,
                        messages: streamRequest.messages,
                        temperature: streamRequest.temperature,
                        top_p: streamRequest.top_p,
                        max_tokens: streamRequest.max_tokens,
                        frequency_penalty: streamRequest.frequency_penalty,
                        presence_penalty: streamRequest.presence_penalty,
                        stream: true,
                        tools: streamRequest.tools,
                        tool_choice: streamRequest.tool_choice,
                        response_format: streamRequest.response_format,
                        stop: streamRequest.stop,
                        n: streamRequest.n,
                        user: streamRequest.user
                    )

                    // Encode request to JSON
                    let requestData = try JSONEncoder().encode(streamRequest)

                    // Accumulated content for delta accumulation
                    var accumulatedContent = ""
                    var accumulatedReasoningContent = ""

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
                            let streamChunk = try JSONDecoder().decode(DeepSeekStreamChunk.self, from: jsonData)

                            // Process delta
                            if let delta = streamChunk.choices.first?.delta {
                                // Accumulate content
                                if let content = delta.content {
                                    accumulatedContent += content
                                }

                                // Accumulate reasoning content (for deepseek-reasoner)
                                if let reasoningContent = delta.reasoning_content {
                                    accumulatedReasoningContent += reasoningContent
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
                                            cachedTokens: usage.prompt_cache_hit_tokens
                                        )
                                    },
                                    provider: .deepseek,
                                    providerData: buildProviderData(
                                        chunk: streamChunk,
                                        accumulatedReasoningContent: accumulatedReasoningContent
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
        // DeepSeek doesn't have a dedicated token counting endpoint
        // Estimate based on content length (rough approximation: 4 chars ≈ 1 token)
        var totalChars = 0

        // Count system prompt
        if let systemPrompt = request.systemPrompt {
            totalChars += systemPrompt.count
        }

        // Count messages
        for message in request.messages {
            totalChars += message.content.count
        }

        // Estimate tokens (4 characters per token is a rough estimate)
        return totalChars / 4
    }

    // MARK: - Private Helpers

    /// Build DeepSeek request from AIRequest
    private func buildDeepSeekRequest(from request: AIRequest) throws -> DeepSeekRequest {
        // Convert messages
        var deepseekMessages: [DeepSeekMessage] = []

        // Add system prompt as first message if present
        if let systemPrompt = request.systemPrompt {
            deepseekMessages.append(DeepSeekMessage(role: "system", content: systemPrompt))
        }

        // Add conversation messages
        for message in request.messages {
            // Convert role to string
            let roleString = message.role.rawValue

            // Convert content to string
            let contentString = message.content.compactMap { content -> String? in
                if case .text(let text) = content {
                    return text
                }
                return nil
            }.joined()

            let deepseekMessage = DeepSeekMessage(
                role: roleString,
                content: contentString.isEmpty ? nil : contentString
            )
            deepseekMessages.append(deepseekMessage)
        }

        // Convert tools if present
        let tools: [DeepSeekTool]? = request.providerOptions?["tools"] as? [DeepSeekTool]

        // Convert tool choice if present
        let toolChoice: DeepSeekToolChoice? = request.providerOptions?["tool_choice"] as? DeepSeekToolChoice

        // Convert response format if present
        let responseFormat: DeepSeekResponseFormat? = request.providerOptions?["response_format"] as? DeepSeekResponseFormat

        return DeepSeekRequest(
            model: request.model,
            messages: deepseekMessages,
            temperature: request.temperature,
            top_p: request.topP,
            max_tokens: request.maxTokens,
            frequency_penalty: request.providerOptions?["frequency_penalty"] as? Double,
            presence_penalty: request.providerOptions?["presence_penalty"] as? Double,
            stream: false,
            tools: tools,
            tool_choice: toolChoice,
            response_format: responseFormat,
            stop: request.stopSequences,
            n: request.providerOptions?["n"] as? Int,
            user: request.providerOptions?["user"] as? String
        )
    }

    /// Transform DeepSeek response to AIResponse
    private func transformToAIResponse(_ response: DeepSeekResponse, originalRequest: AIRequest) -> AIResponse {
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
                        cachedTokens: usage.prompt_cache_hit_tokens
                    )
                },
                provider: .deepseek,
                providerData: nil
            )
        }

        // Build provider data with prompt caching info and reasoning content
        let providerData = buildProviderData(
            response: response,
            message: firstChoice.message
        )

        // Create AI message from content
        let content: [AIMessageContent] = if let messageContent = firstChoice.message.content {
            [.text(messageContent)]
        } else {
            []
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
                    cachedTokens: usage.prompt_cache_hit_tokens
                )
            },
            provider: .deepseek,
            providerData: providerData
        )
    }

    /// Map DeepSeek finish reason to AIStopReason
    private func mapFinishReason(_ reason: String) -> AIStopReason {
        switch reason {
        case "stop": return .endTurn
        case "length": return .maxTokens
        case "tool_calls": return .toolUse
        case "content_filter": return .contentFilter
        default: return .other
        }
    }

    /// Build provider-specific data dictionary
    private func buildProviderData(response: DeepSeekResponse, message: DeepSeekResponseMessage) -> [String: AnyCodable]? {
        var data: [String: AnyCodable] = [:]

        // Add reasoning content if present (for deepseek-reasoner model)
        if let reasoningContent = message.reasoning_content {
            data["reasoning_content"] = AnyCodable(reasoningContent)
        }

        // Add prompt caching information if present
        if let usage = response.usage {
            if let cacheHitTokens = usage.prompt_cache_hit_tokens {
                data["prompt_cache_hit_tokens"] = AnyCodable(cacheHitTokens)
            }
            if let cacheMissTokens = usage.prompt_cache_miss_tokens {
                data["prompt_cache_miss_tokens"] = AnyCodable(cacheMissTokens)
            }
        }

        // Add system fingerprint if present
        if let fingerprint = response.system_fingerprint {
            data["system_fingerprint"] = AnyCodable(fingerprint)
        }

        return data.isEmpty ? nil : data
    }

    /// Build provider-specific data dictionary for streaming
    private func buildProviderData(chunk: DeepSeekStreamChunk, accumulatedReasoningContent: String) -> [String: AnyCodable]? {
        var data: [String: AnyCodable] = [:]

        // Add accumulated reasoning content if present
        if !accumulatedReasoningContent.isEmpty {
            data["reasoning_content"] = AnyCodable(accumulatedReasoningContent)
        }

        // Add prompt caching information if present
        if let usage = chunk.usage {
            if let cacheHitTokens = usage.prompt_cache_hit_tokens {
                data["prompt_cache_hit_tokens"] = AnyCodable(cacheHitTokens)
            }
            if let cacheMissTokens = usage.prompt_cache_miss_tokens {
                data["prompt_cache_miss_tokens"] = AnyCodable(cacheMissTokens)
            }
        }

        // Add system fingerprint if present
        if let fingerprint = chunk.system_fingerprint {
            data["system_fingerprint"] = AnyCodable(fingerprint)
        }

        return data.isEmpty ? nil : data
    }
}
