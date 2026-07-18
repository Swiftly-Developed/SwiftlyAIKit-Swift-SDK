import Foundation

/// Ollama provider implementation (native `/api/chat` API)
///
/// Local/self-hosted LLM inference via Ollama's native chat API. Ollama differs from the
/// OpenAI-compatible providers in three important ways:
/// - **No API key.** Authentication is simply reachability of the base URL — no `Authorization`
///   header is sent. The `apiKey` parameters required by ``ProviderProtocol`` are ignored.
/// - **Newline-delimited JSON streaming** (not SSE). Each streamed line is a full
///   ``OllamaChatResponse`` carrying a partial `message.content`; the final line has `done == true`.
/// - **Default base URL `http://localhost:11434`** (http, no `/v1`), overridable per instance.
///
/// ## Topics
///
/// ### ProviderProtocol
/// - ``providerType``
/// - ``sendMessage(_:apiKey:)``
/// - ``streamMessage(_:apiKey:)``
///
/// ### Ollama-Specific Methods
/// - ``listModels(apiKey:)``
public struct OllamaProvider: ProviderProtocol {
    public let providerType: ProviderType = .ollama

    private let httpClient: HTTPClientManager
    let baseURL: String
    private let timeout: Int
    private let maxRetries: Int
    private let enableLogging: Bool

    /// Initialize Ollama provider with default HTTPClientManager
    /// - Parameters:
    ///   - baseURL: Base URL for the Ollama server (default: http://localhost:11434)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        baseURL: String = "http://localhost:11434",
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

    /// Initialize Ollama provider with custom HTTP client
    /// - Parameters:
    ///   - httpClient: Custom HTTP client manager
    ///   - baseURL: Base URL for the Ollama server (default: http://localhost:11434)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - enableLogging: Enable request/response logging (default: false)
    public init(
        httpClient: HTTPClientManager,
        baseURL: String = "http://localhost:11434",
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

    // MARK: - Endpoints

    /// Chat endpoint URL for the configured base URL
    var chatURL: String { "\(baseURL)/api/chat" }

    /// Model-listing endpoint URL for the configured base URL
    var tagsURL: String { "\(baseURL)/api/tags" }

    // MARK: - ProviderProtocol Implementation

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        // Build Ollama request (non-streaming)
        let ollamaRequest = buildOllamaRequest(from: request, stream: false)

        // Encode request to JSON
        let requestData = try JSONEncoder().encode(ollamaRequest)

        // Make HTTP request (no Authorization header — Ollama auth is base-URL reachability)
        let responseData = try await httpClient.post(
            url: chatURL,
            headers: buildHeaders(),
            body: requestData
        )

        // Decode response
        let ollamaResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: responseData)

        // Transform to AIResponse
        return transformToAIResponse(ollamaResponse, model: request.model)
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Build Ollama request with streaming enabled
                    let streamRequest = buildOllamaRequest(from: request, stream: true)

                    // Encode request to JSON
                    let requestData = try JSONEncoder().encode(streamRequest)

                    let dataStream = httpClient.streamPost(
                        url: chatURL,
                        headers: buildHeaders(),
                        body: requestData
                    )

                    // Delegate newline-JSON parsing / reassembly to the testable helper so the
                    // exact same logic drives production and unit tests.
                    for try await response in makeResponseStream(from: dataStream, model: request.model) {
                        continuation.yield(response)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Transform a raw newline-delimited JSON byte stream from the Ollama `/api/chat` endpoint into
    /// neutral ``AIResponse`` values.
    ///
    /// Ollama emits one complete JSON object per line (no `data:` prefix, no `[DONE]` sentinel).
    /// Incoming `Data` chunks are split on `\n` with a buffer carried across chunks so that a line
    /// split mid-way between two network chunks is reassembled before decoding. Content is
    /// accumulated and yielded cumulatively as it streams; the terminal `done == true` line carries
    /// the token usage and stop reason, which are surfaced on the final yielded response.
    ///
    /// - Parameters:
    ///   - dataStream: Raw data chunks (as produced by ``HTTPClientManager/streamPost(url:headers:body:context:)``).
    ///   - model: The requested model identifier (echoed onto responses).
    /// - Returns: A stream of neutral responses; the final response carries the fully assembled
    ///   content, tool calls, stop reason, and usage.
    func makeResponseStream(
        from dataStream: AsyncThrowingStream<Data, Error>,
        model: String
    ) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var buffer = ""
                    var accumulatedContent = ""
                    var accumulatedToolCalls: [OllamaToolCall] = []

                    for try await data in dataStream {
                        buffer += String(data: data, encoding: .utf8) ?? ""

                        // Split into complete lines; retain any trailing partial line in the buffer.
                        var lines = buffer.components(separatedBy: "\n")
                        buffer = lines.removeLast()

                        for line in lines {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty, let lineData = trimmed.data(using: .utf8) else { continue }

                            let chunk = try JSONDecoder().decode(OllamaChatResponse.self, from: lineData)
                            Self.accumulate(chunk, content: &accumulatedContent, toolCalls: &accumulatedToolCalls)

                            continuation.yield(makeStreamResponse(
                                chunk: chunk,
                                model: model,
                                content: accumulatedContent,
                                toolCalls: accumulatedToolCalls
                            ))
                        }
                    }

                    // Decode any complete object left in the buffer (stream may end without a
                    // trailing newline).
                    let remaining = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !remaining.isEmpty, let lineData = remaining.data(using: .utf8),
                       let chunk = try? JSONDecoder().decode(OllamaChatResponse.self, from: lineData) {
                        Self.accumulate(chunk, content: &accumulatedContent, toolCalls: &accumulatedToolCalls)
                        continuation.yield(makeStreamResponse(
                            chunk: chunk,
                            model: model,
                            content: accumulatedContent,
                            toolCalls: accumulatedToolCalls
                        ))
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Accumulate content and tool calls from a streamed ``OllamaChatResponse`` line.
    ///
    /// Exposed as a `static` helper so the reassembly is unit-testable. Ollama delivers each
    /// tool call as a complete object (arguments are not fragmented across lines), so accumulation
    /// simply appends any tool calls carried on the line.
    static func accumulate(
        _ chunk: OllamaChatResponse,
        content: inout String,
        toolCalls: inout [OllamaToolCall]
    ) {
        if let delta = chunk.message?.content {
            content += delta
        }
        if let calls = chunk.message?.toolCalls {
            toolCalls.append(contentsOf: calls)
        }
    }

    /// Build a streaming ``AIResponse`` from accumulated stream state.
    private func makeStreamResponse(
        chunk: OllamaChatResponse,
        model: String,
        content: String,
        toolCalls: [OllamaToolCall]
    ) -> AIResponse {
        var streamContent: [AIMessageContent] = content.isEmpty ? [] : [.text(content)]
        for (index, call) in toolCalls.enumerated() {
            streamContent.append(.toolCall(AIToolCall(
                id: "call_\(index)",
                type: "function",
                name: call.function.name,
                arguments: Self.argumentsJSONString(call.function.arguments)
            )))
        }
        let message = AIMessage(role: .assistant, content: streamContent)

        // Usage and stop reason ride the terminal `done == true` line.
        let usage: AIUsage? = chunk.done
            ? AIUsage(inputTokens: chunk.promptEvalCount ?? 0, outputTokens: chunk.evalCount ?? 0)
            : nil
        let stopReason: AIStopReason? = chunk.done
            ? (toolCalls.isEmpty ? mapDoneReason(chunk.doneReason) : .toolUse)
            : nil

        return AIResponse(
            id: chunk.createdAt ?? model,
            model: chunk.model.isEmpty ? model : chunk.model,
            message: message,
            stopReason: stopReason,
            usage: usage,
            provider: .ollama,
            providerData: nil
        )
    }

    // MARK: - Ollama-Specific Methods

    /// List locally-available models
    ///
    /// - Parameter apiKey: Ignored — Ollama does not use API keys.
    /// - Returns: List of models available on the Ollama server
    public func listModels(apiKey: String) async throws -> OllamaModelsResponse {
        // GET /api/tags with no Authorization header.
        let responseData = try await httpClient.get(url: tagsURL, headers: [])
        return try JSONDecoder().decode(OllamaModelsResponse.self, from: responseData)
    }

    // MARK: - Request Building

    /// Build the HTTP headers for an Ollama request.
    ///
    /// Returns **only** `Content-Type: application/json`. Ollama does not authenticate with an API
    /// key, so no `Authorization` header is sent — reaching the base URL is the authentication.
    func buildHeaders() -> [(String, String)] {
        [("Content-Type", "application/json")]
    }

    /// Build an ``OllamaChatRequest`` from a neutral ``AIRequest``.
    // swiftlint:disable:next function_body_length
    func buildOllamaRequest(from request: AIRequest, stream: Bool) -> OllamaChatRequest {
        var messages: [OllamaMessage] = []

        // Add system prompt as first message if present.
        if let systemPrompt = request.systemPrompt {
            messages.append(OllamaMessage(role: "system", content: systemPrompt))
        }

        // Add conversation messages.
        for message in request.messages {
            let roleString = message.role.rawValue

            // Tool results map to individual `tool`-role messages.
            let toolResults = message.content.compactMap { content -> OllamaMessage? in
                if case .toolResult(let id, let result) = content {
                    return OllamaMessage(role: "tool", content: result, toolCallID: id)
                }
                return nil
            }
            if !toolResults.isEmpty {
                messages.append(contentsOf: toolResults)
                continue
            }

            // Assistant tool calls map to a message carrying `tool_calls`.
            let toolCalls = message.content.compactMap { content -> OllamaToolCall? in
                if case .toolCall(let call) = content {
                    return OllamaToolCall(function: OllamaToolCallFunction(
                        name: call.name,
                        arguments: Self.argumentsAnyCodable(from: call.arguments)
                    ))
                }
                return nil
            }
            if !toolCalls.isEmpty {
                let text = message.content.compactMap { content -> String? in
                    if case .text(let value) = content { return value }
                    return nil
                }.joined()
                messages.append(OllamaMessage(
                    role: roleString,
                    content: text.isEmpty ? nil : text,
                    toolCalls: toolCalls
                ))
                continue
            }

            // Multimodal content: text + base64 images.
            let images = message.content.compactMap { content -> String? in
                if case .image(let source, _) = content {
                    switch source {
                    case .base64(let data): return data
                    case .url(let url): return url
                    }
                }
                return nil
            }
            let text = message.content.compactMap { content -> String? in
                if case .text(let value) = content { return value }
                return nil
            }.joined()

            messages.append(OllamaMessage(
                role: roleString,
                content: text.isEmpty ? nil : text,
                images: images.isEmpty ? nil : images
            ))
        }

        // Map tools. Ollama's native `/api/chat` has no `tool_choice` field; when tools are present
        // we simply include the tools array. A neutral `.none` tool choice omits tools entirely
        // (an absent — `nil` — tool choice still includes them).
        let includeTools: Bool
        if case .some(.none) = request.toolChoice {
            includeTools = false
        } else {
            includeTools = true
        }
        let tools: [OllamaToolDefinition]? = includeTools ? request.tools?.map { tool in
            OllamaToolDefinition(
                type: "function",
                function: OllamaFunctionDefinition(
                    name: tool.name,
                    description: tool.description,
                    parameters: tool.parameters.jsonSchemaDictionary().mapValues { AnyCodable($0) }
                )
            )
        } : nil

        // Generation parameters nest under `options`.
        let options = OllamaOptions(
            temperature: request.temperature,
            topP: request.topP,
            topK: request.topK,
            numPredict: request.maxTokens,
            stop: request.stopSequences
        )

        return OllamaChatRequest(
            model: request.model,
            messages: messages,
            stream: stream,
            tools: tools,
            options: options.isEmpty ? nil : options
        )
    }

    // MARK: - Response Transformation

    /// Transform an ``OllamaChatResponse`` into a neutral ``AIResponse``.
    func transformToAIResponse(_ response: OllamaChatResponse, model: String) -> AIResponse {
        var content: [AIMessageContent] = []

        // Text content.
        if let text = response.message?.content, !text.isEmpty {
            content.append(.text(text))
        }

        // Tool calls — re-encode each object-valued `arguments` to a JSON string for AIToolCall.
        let toolCalls = response.message?.toolCalls ?? []
        for (index, call) in toolCalls.enumerated() {
            content.append(.toolCall(AIToolCall(
                id: "call_\(index)",
                type: "function",
                name: call.function.name,
                arguments: Self.argumentsJSONString(call.function.arguments)
            )))
        }

        let message = AIMessage(role: .assistant, content: content)

        let stopReason: AIStopReason = toolCalls.isEmpty
            ? mapDoneReason(response.doneReason)
            : .toolUse

        let usage = AIUsage(
            inputTokens: response.promptEvalCount ?? 0,
            outputTokens: response.evalCount ?? 0
        )

        return AIResponse(
            id: response.createdAt ?? model,
            model: response.model.isEmpty ? model : response.model,
            message: message,
            stopReason: stopReason,
            usage: usage,
            provider: .ollama,
            providerData: nil
        )
    }

    // MARK: - Private Helpers

    /// Map an Ollama `done_reason` to ``AIStopReason``.
    private func mapDoneReason(_ reason: String?) -> AIStopReason {
        switch reason {
        case "stop": return .endTurn
        case "length": return .maxTokens
        default: return .endTurn
        }
    }

    /// Re-encode an object-valued tool-call `arguments` (Ollama) to a JSON string (neutral API).
    static func argumentsJSONString(_ arguments: AnyCodable) -> String {
        guard let data = try? JSONEncoder().encode(arguments),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    /// Decode a neutral JSON-string tool-call `arguments` into an ``AnyCodable`` object (Ollama).
    static func argumentsAnyCodable(from jsonString: String) -> AnyCodable {
        guard let data = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(AnyCodable.self, from: data) else {
            return AnyCodable([String: AnyCodable]())
        }
        return decoded
    }
}
