import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Provider implementation for Perplexity AI
///
/// Real-time web search with automatic citations (the Sonar Chat Completions API) **plus** custom
/// function / tool calling (the Agent API).
///
/// ## Two endpoints, routed by the request
///
/// Perplexity exposes two distinct surfaces, and this provider routes to the right one automatically:
///
/// - **Sonar** (`POST /chat/completions`) — real-time, web-grounded answers with citations. Used
///   for ordinary (tool-free) requests. Has **no** function/tool calling.
/// - **Agent API** (`POST /v1/responses`) — an OpenAI *Responses*-API-compatible surface that adds
///   custom function calling and built-in tools. Used whenever a request carries ``AIRequest/tools``
///   (or continues a tool run). See ``buildAgentRequest(from:stream:)``.
///
/// Because custom function calling is only available on the Agent API — and the Agent API addresses
/// models as `provider/model` ids (e.g. `openai/gpt-5.6-sol`, `perplexity/sonar`) rather than the
/// plain Sonar ids — a tool-bearing request whose model is a plain Sonar id (`sonar`, `sonar-pro`,
/// …) is routed to the configured Agent model (``agentModel``, default `openai/gpt-5.6-sol`). Pass an
/// explicit `provider/model` id (e.g. `perplexity/sonar`), set ``agentModel``, or send
/// `providerOptions["agent_model"]` to control which model handles the tool run.
///
/// ## Topics
///
/// ### ProviderProtocol
/// - ``providerType``
/// - ``sendMessage(_:apiKey:)``
/// - ``streamMessage(_:apiKey:)``
///
/// ## See Also
/// - <doc:PerplexityGuide>
// swiftlint:disable:next type_body_length
public struct PerplexityProvider: ProviderProtocol {
    public let providerType: ProviderType = .perplexity

    /// Perplexity supports tool / function calling via its **Agent API** (`POST /v1/responses`).
    ///
    /// When a caller passes ``AIRequest/tools`` / ``AIRequest/toolChoice``, this provider routes the
    /// request to the Agent API (OpenAI *Responses*-API shape), maps the neutral tools to the
    /// Agent `tools` array, parses returned `function_call` items into ``AIMessageContent/toolCall(_:)``
    /// content, and round-trips tool results (`function_call_output`) for multi-turn runs. Tool-free
    /// requests continue to use the Sonar Chat Completions API unchanged.
    ///
    /// Note: the Agent API addresses models by `provider/model` id, so a tool-bearing request whose
    /// model is a plain Sonar id is served by ``agentModel`` (default `openai/gpt-5.6-sol`) unless a
    /// `provider/model` id or `providerOptions["agent_model"]` overrides it.
    public var supportsTools: Bool { true }

    /// Default Agent-API model used for tool runs when the request model is a plain Sonar id.
    ///
    /// `openai/gpt-5.6-sol` is Perplexity's documented model for custom function calling. Callers who
    /// prefer Perplexity's own grounded model can pass `perplexity/sonar` (any `provider/model` id
    /// passes through) or override ``agentModel`` / `providerOptions["agent_model"]`.
    public static let defaultAgentModel = "openai/gpt-5.6-sol"

    private let baseURL: String
    private let httpClient: HTTPClientManager

    /// Agent-API model used for tool runs when the request carries a plain Sonar model id.
    public let agentModel: String

    // MARK: - Initialization

    /// Initialize with default configuration
    /// - Parameter agentModel: Agent-API model for tool runs with a plain Sonar model id
    ///   (default ``defaultAgentModel``).
    public init(agentModel: String = Self.defaultAgentModel) {
        self.baseURL = ProviderType.perplexity.baseURL
        self.httpClient = HTTPClientManager()
        self.agentModel = agentModel
    }

    /// Initialize with custom base URL
    /// - Parameters:
    ///   - baseURL: Base URL for the Perplexity API
    ///   - agentModel: Agent-API model for tool runs with a plain Sonar model id
    ///     (default ``defaultAgentModel``).
    public init(baseURL: String, agentModel: String = Self.defaultAgentModel) {
        self.baseURL = baseURL
        self.httpClient = HTTPClientManager()
        self.agentModel = agentModel
    }

    /// Initialize with custom HTTP client
    /// - Parameters:
    ///   - httpClient: Custom HTTP client manager
    ///   - agentModel: Agent-API model for tool runs with a plain Sonar model id
    ///     (default ``defaultAgentModel``).
    public init(httpClient: HTTPClientManager, agentModel: String = Self.defaultAgentModel) {
        self.baseURL = ProviderType.perplexity.baseURL
        self.httpClient = httpClient
        self.agentModel = agentModel
    }

    // MARK: - ProviderProtocol Implementation

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        // Tool-bearing requests can only be served by the Agent API; tool-free requests use Sonar.
        if requestUsesTools(request) {
            return try await sendAgentMessage(request, apiKey: apiKey)
        }

        let perplexityRequest = try mapToPerplexityRequest(request)
        let url = "\(baseURL)/chat/completions"

        let headers: [(String, String)] = [
            ("Authorization", "Bearer \(apiKey)"),
            ("Content-Type", "application/json")
        ]

        let jsonData = try JSONEncoder().encode(perplexityRequest)
        let responseData = try await httpClient.post(
            url: url,
            headers: headers,
            body: jsonData
        )

        let perplexityResponse = try JSONDecoder().decode(PerplexityResponse.self, from: responseData)
        return try mapToAIResponse(perplexityResponse, model: request.model)
    }

    public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        // Tool-bearing requests stream via the Agent API; tool-free requests via Sonar.
        if requestUsesTools(request) {
            return streamAgentMessage(request, apiKey: apiKey)
        }
        return streamSonarMessage(request, apiKey: apiKey)
    }

    // MARK: - Sonar Streaming

    private func streamSonarMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var streamRequest = try mapToPerplexityRequest(request)
                    streamRequest = PerplexityRequest(
                        model: streamRequest.model,
                        messages: streamRequest.messages,
                        maxTokens: streamRequest.maxTokens,
                        temperature: streamRequest.temperature,
                        topP: streamRequest.topP,
                        topK: streamRequest.topK,
                        stream: true,
                        searchDomainFilter: streamRequest.searchDomainFilter,
                        searchRecencyFilter: streamRequest.searchRecencyFilter,
                        returnCitations: streamRequest.returnCitations,
                        returnImages: streamRequest.returnImages,
                        responseFormat: streamRequest.responseFormat
                    )

                    let url = "\(baseURL)/chat/completions"
                    let headers: [(String, String)] = [
                        ("Authorization", "Bearer \(apiKey)"),
                        ("Content-Type", "application/json"),
                        ("Accept", "text/event-stream")
                    ]

                    let jsonData = try JSONEncoder().encode(streamRequest)

                    let stream = httpClient.streamPost(
                        url: url,
                        headers: headers,
                        body: jsonData
                    )

                    var accumulatedText = ""
                    var buffer = ""

                    for try await chunk in stream {
                        let (payloads, done) = Self.parseSSEDataPayloads(from: chunk, buffer: &buffer)
                        for jsonString in payloads {
                            guard let data = jsonString.data(using: .utf8),
                                  let streamChunk = try? JSONDecoder().decode(PerplexityStreamChunk.self, from: data)
                            else { continue }

                            guard let choice = streamChunk.choices.first else { continue }
                            if let content = choice.delta.content {
                                accumulatedText += content
                            }

                            let message = AIMessage(
                                role: .assistant,
                                content: [.text(accumulatedText)]
                            )

                            let response = AIResponse(
                                id: streamChunk.id,
                                model: streamChunk.model,
                                message: message,
                                stopReason: mapFinishReason(choice.finishReason),
                                usage: AIUsage(inputTokens: 0, outputTokens: 0),
                                provider: .perplexity
                            )

                            continuation.yield(response)
                        }

                        if done {
                            continuation.finish()
                            return
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Agent API (Tool Calling)

    /// Whether a request must be served by the Agent API rather than the Sonar path.
    ///
    /// True when the request carries tools, or continues an in-flight tool run (a message already
    /// holds a `toolCall`/`toolResult` even if `tools` was dropped on the follow-up turn).
    func requestUsesTools(_ request: AIRequest) -> Bool {
        if let tools = request.tools, !tools.isEmpty { return true }
        return request.messages.contains { message in
            message.content.contains { part in
                switch part {
                case .toolCall, .toolResult:
                    return true
                default:
                    return false
                }
            }
        }
    }

    /// Resolve the Agent-API model id for a tool run.
    ///
    /// A `provider/model` id (containing `/`, e.g. `perplexity/sonar`) passes through unchanged; a
    /// plain Sonar id is replaced by `providerOptions["agent_model"]` if present, otherwise
    /// ``agentModel``.
    func resolveAgentModel(for request: AIRequest) -> String {
        if let override = request.providerOptions?["agent_model"]?.value as? String, !override.isEmpty {
            return override
        }
        if request.model.contains("/") {
            return request.model
        }
        return agentModel
    }

    /// Map a neutral ``AIRequest`` to the Agent API (Responses) request shape.
    ///
    /// Exposed as `internal` (not `private`) so tests can assert the wire body carries
    /// `tools`/`tool_choice` and the replayed `function_call`/`function_call_output` input items.
    func buildAgentRequest(from request: AIRequest, stream: Bool) throws -> PerplexityAgentRequest {
        var input: [PerplexityAgentInputItem] = []
        for message in request.messages {
            input.append(contentsOf: agentInputItems(from: message))
        }

        let tools = request.tools?.map { mapAgentTool($0) }
        let toolChoice = request.toolChoice.map { mapAgentToolChoice($0) }

        return PerplexityAgentRequest(
            model: resolveAgentModel(for: request),
            input: input,
            instructions: request.systemPrompt,
            maxOutputTokens: request.maxTokens,
            temperature: request.temperature,
            topP: request.topP,
            stream: stream ? true : nil,
            tools: tools,
            toolChoice: toolChoice
        )
    }

    private func sendAgentMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        let agentRequest = try buildAgentRequest(from: request, stream: false)
        let url = "\(baseURL)/v1/responses"

        let headers: [(String, String)] = [
            ("Authorization", "Bearer \(apiKey)"),
            ("Content-Type", "application/json")
        ]

        let jsonData = try JSONEncoder().encode(agentRequest)
        let responseData = try await httpClient.post(
            url: url,
            headers: headers,
            body: jsonData
        )

        let agentResponse = try JSONDecoder().decode(PerplexityAgentResponse.self, from: responseData)
        return transformAgentResponse(agentResponse, model: agentRequest.model)
    }

    private func streamAgentMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let agentRequest = try buildAgentRequest(from: request, stream: true)
                    let url = "\(baseURL)/v1/responses"
                    let headers: [(String, String)] = [
                        ("Authorization", "Bearer \(apiKey)"),
                        ("Content-Type", "application/json"),
                        ("Accept", "text/event-stream")
                    ]

                    let jsonData = try JSONEncoder().encode(agentRequest)
                    let stream = httpClient.streamPost(url: url, headers: headers, body: jsonData)

                    let model = agentRequest.model
                    var responseID = ""
                    var accumulatedText = ""
                    var toolCalls: [Int: AgentToolCallAccumulator] = [:]
                    var buffer = ""

                    for try await chunk in stream {
                        let (payloads, done) = Self.parseSSEDataPayloads(from: chunk, buffer: &buffer)
                        for jsonString in payloads {
                            guard let data = jsonString.data(using: .utf8),
                                  let event = try? JSONDecoder().decode(PerplexityAgentStreamEvent.self, from: data)
                            else { continue }

                            if event.type == "response.completed" {
                                let final = finalizeAgentStream(
                                    event: event,
                                    responseID: responseID,
                                    accumulatedText: accumulatedText,
                                    toolCalls: toolCalls,
                                    model: model
                                )
                                continuation.yield(final)
                                continuation.finish()
                                return
                            }

                            if let partial = Self.reduceAgentStreamEvent(
                                event,
                                responseID: &responseID,
                                accumulatedText: &accumulatedText,
                                toolCalls: &toolCalls,
                                model: model
                            ) {
                                continuation.yield(partial)
                            }
                        }

                        if done {
                            continuation.finish()
                            return
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Agent Request Mapping

    private func agentInputItems(from message: AIMessage) -> [PerplexityAgentInputItem] {
        var items: [PerplexityAgentInputItem] = []
        var textParts: [String] = []

        for part in message.content {
            switch part {
            case .text(let text):
                textParts.append(text)
            case .toolCall(let call):
                items.append(.functionCall(callID: call.id, name: call.name, arguments: call.arguments))
            case .toolResult(let id, let result):
                items.append(.functionCallOutput(callID: id, output: result))
            default:
                break // images/documents are not supported on the tool path
            }
        }

        if !textParts.isEmpty {
            let messageItem = PerplexityAgentInputItem.message(
                role: mapRole(message.role),
                content: textParts.joined(separator: "\n")
            )
            items.insert(messageItem, at: 0)
        }

        return items
    }

    private func mapAgentTool(_ tool: AITool) -> PerplexityAgentTool {
        let parameters = tool.parameters.jsonSchemaDictionary().mapValues { AnyCodable($0) }
        return PerplexityAgentTool(
            name: tool.name,
            description: tool.description,
            parameters: parameters
        )
    }

    private func mapAgentToolChoice(_ choice: AIToolChoice) -> PerplexityAgentToolChoice {
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

    // MARK: - Agent Response Mapping

    /// Map an Agent API response into a neutral ``AIResponse``, parsing `function_call` output items
    /// into ``AIMessageContent/toolCall(_:)`` content (keyed by `call_id`) and setting the stop reason
    /// to ``AIStopReason/toolUse`` when the model requested a tool.
    ///
    /// Exposed as `internal` so tests can decode a fixture and assert the neutral mapping.
    func transformAgentResponse(_ response: PerplexityAgentResponse, model: String) -> AIResponse {
        var content: [AIMessageContent] = []
        var sawToolCall = false

        for item in response.output {
            switch item.type {
            case "message":
                for part in item.content ?? [] where part.text?.isEmpty == false {
                    content.append(.text(part.text ?? ""))
                }
            case "function_call":
                guard let name = item.name else { continue }
                sawToolCall = true
                content.append(.toolCall(AIToolCall(
                    id: item.callID ?? item.id ?? "",
                    name: name,
                    arguments: item.arguments ?? "{}"
                )))
            default:
                break
            }
        }

        let usage = response.usage.map {
            AIUsage(inputTokens: $0.inputTokens ?? 0, outputTokens: $0.outputTokens ?? 0)
        }

        return AIResponse(
            id: response.id,
            model: response.model ?? model,
            message: AIMessage(role: .assistant, content: content),
            stopReason: sawToolCall ? .toolUse : .endTurn,
            usage: usage,
            provider: .perplexity
        )
    }

    // MARK: - Agent Streaming Helpers

    /// Per-function-call accumulator for streamed Agent API tool calls.
    struct AgentToolCallAccumulator: Sendable, Equatable {
        var callID: String
        var name: String
        var arguments: String
    }

    /// Merge one Agent API stream event into the running text + tool-call accumulators.
    ///
    /// A `function_call` streams as `response.output_item.added` (announcing `call_id`/`name`), then
    /// `response.function_call_arguments.delta` fragments, then `.done`; text streams as
    /// `response.output_text.delta`. Returns a partial ``AIResponse`` to yield for incremental text,
    /// or `nil` for tool-call/bookkeeping events. Exposed `internal` so tests can drive accumulation.
    static func reduceAgentStreamEvent(
        _ event: PerplexityAgentStreamEvent,
        responseID: inout String,
        accumulatedText: inout String,
        toolCalls: inout [Int: AgentToolCallAccumulator],
        model: String
    ) -> AIResponse? {
        switch event.type {
        case "response.created", "response.in_progress":
            if let id = event.response?.id { responseID = id }
            return nil

        case "response.output_item.added":
            if let item = event.item, item.type == "function_call", let index = event.outputIndex {
                toolCalls[index] = AgentToolCallAccumulator(
                    callID: item.callID ?? item.id ?? "",
                    name: item.name ?? "",
                    arguments: item.arguments ?? ""
                )
            }
            return nil

        case "response.function_call_arguments.delta":
            if let index = event.outputIndex, let delta = event.delta {
                var current = toolCalls[index] ?? AgentToolCallAccumulator(callID: "", name: "", arguments: "")
                current.arguments += delta
                toolCalls[index] = current
            }
            return nil

        case "response.function_call_arguments.done":
            if let index = event.outputIndex, let arguments = event.arguments {
                var current = toolCalls[index] ?? AgentToolCallAccumulator(callID: "", name: "", arguments: "")
                current.arguments = arguments
                toolCalls[index] = current
            }
            return nil

        case "response.output_text.delta":
            guard let delta = event.delta else { return nil }
            accumulatedText += delta
            return AIResponse(
                id: responseID.isEmpty ? (event.itemID ?? "pplx-agent") : responseID,
                model: model,
                message: AIMessage(role: .assistant, content: [.text(accumulatedText)]),
                stopReason: nil,
                usage: nil,
                provider: .perplexity
            )

        default:
            return nil
        }
    }

    /// Build the terminal ``AIResponse`` for a streaming Agent run.
    ///
    /// Prefers the authoritative full response carried on `response.completed`; otherwise assembles
    /// from the streamed text and tool-call accumulators.
    private func finalizeAgentStream(
        event: PerplexityAgentStreamEvent,
        responseID: String,
        accumulatedText: String,
        toolCalls: [Int: AgentToolCallAccumulator],
        model: String
    ) -> AIResponse {
        if let response = event.response {
            return transformAgentResponse(response, model: model)
        }

        var content: [AIMessageContent] = []
        if !accumulatedText.isEmpty {
            content.append(.text(accumulatedText))
        }
        for index in toolCalls.keys.sorted() {
            guard let call = toolCalls[index] else { continue }
            content.append(.toolCall(AIToolCall(
                id: call.callID,
                name: call.name,
                arguments: call.arguments.isEmpty ? "{}" : call.arguments
            )))
        }

        return AIResponse(
            id: responseID.isEmpty ? "pplx-agent" : responseID,
            model: model,
            message: AIMessage(role: .assistant, content: content),
            stopReason: toolCalls.isEmpty ? .endTurn : .toolUse,
            usage: nil,
            provider: .perplexity
        )
    }

    // MARK: - Sonar Request Mapping

    /// Map a neutral ``AIRequest`` to Perplexity's Sonar (Chat Completions) request shape.
    ///
    /// This path serves **tool-free** requests only — the Sonar API has no function calling, so
    /// `request.tools` / `request.toolChoice` have no wire representation here. Tool-bearing requests
    /// never reach this method: ``sendMessage(_:apiKey:)`` routes them to the Agent API via
    /// ``buildAgentRequest(from:stream:)``. Exposed as `internal` so tests can assert the Sonar body.
    func mapToPerplexityRequest(_ request: AIRequest) throws -> PerplexityRequest {
        var messages = request.messages.map { message in
            let role = mapRole(message.role)
            let content = message.textContent
            return PerplexityMessage(role: role, content: content)
        }

        // Sonar has no separate system parameter, so forward `systemPrompt` as a leading `system`
        // message (mirrors `OpenAIProvider.mapToOpenAIRequest`, and Perplexity's own Agent path,
        // which sends `systemPrompt` as `instructions`). Precedence: an explicit leading system
        // message supplied by the caller wins — skip the prepend so we never send two.
        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty,
           messages.first?.role != "system" {
            messages.insert(PerplexityMessage(role: "system", content: systemPrompt), at: 0)
        }

        return PerplexityRequest(
            model: request.model,
            messages: messages,
            maxTokens: request.maxTokens,
            temperature: request.temperature,
            topP: request.topP,
            topK: request.topK,
            stream: false,
            searchDomainFilter: extractSearchDomainFilter(from: request),
            searchRecencyFilter: extractSearchRecencyFilter(from: request),
            returnCitations: extractReturnCitations(from: request),
            returnImages: extractReturnImages(from: request),
            responseFormat: extractResponseFormat(from: request)
        )
    }

    private func mapRole(_ role: AIMessageRole) -> String {
        switch role {
        case .system:
            return "system"
        case .user:
            return "user"
        case .assistant:
            return "assistant"
        }
    }

    private func extractSearchDomainFilter(from request: AIRequest) -> [String]? {
        guard let providerOptions = request.providerOptions else { return nil }
        guard let domains = providerOptions["search_domain_filter"] else { return nil }

        // Handle array of strings
        if let array = domains.value as? [Any] {
            return array.compactMap { $0 as? String }
        }

        return nil
    }

    private func extractSearchRecencyFilter(from request: AIRequest) -> String? {
        guard let providerOptions = request.providerOptions else { return nil }
        guard let filter = providerOptions["search_recency_filter"] else { return nil }

        return filter.value as? String
    }

    private func extractReturnCitations(from request: AIRequest) -> Bool? {
        guard let providerOptions = request.providerOptions else { return nil }
        guard let citations = providerOptions["return_citations"] else { return nil }

        return citations.value as? Bool
    }

    private func extractReturnImages(from request: AIRequest) -> Bool? {
        guard let providerOptions = request.providerOptions else { return nil }
        guard let images = providerOptions["return_images"] else { return nil }

        return images.value as? Bool
    }

    private func extractResponseFormat(from request: AIRequest) -> ResponseFormat? {
        guard let providerOptions = request.providerOptions else { return nil }
        guard let format = providerOptions["response_format"] else { return nil }

        // Extract format dictionary
        guard let formatDict = format.value as? [String: Any] else { return nil }
        guard let type = formatDict["type"] as? String else { return nil }

        // Extract optional JSON schema
        var jsonSchema: JSONSchema?
        if let schemaDict = formatDict["json_schema"] as? [String: Any],
           let name = schemaDict["name"] as? String,
           let schemaObj = schemaDict["schema"] as? [String: Any] {
            // Convert [String: Any] to [String: AnyCodable]
            let anyCodableSchema = schemaObj.mapValues { AnyCodable($0) }
            jsonSchema = JSONSchema(name: name, schema: anyCodableSchema)
        }

        return ResponseFormat(type: type, jsonSchema: jsonSchema)
    }

    // MARK: - Sonar Response Mapping

    private func mapToAIResponse(_ response: PerplexityResponse, model: String) throws -> AIResponse {
        guard let choice = response.choices.first else {
            throw AIError.invalidResponse(message: "No choices in response")
        }

        let message = AIMessage(
            role: .assistant,
            content: [.text(choice.message.content)]
        )

        let usage = AIUsage(
            inputTokens: response.usage.promptTokens,
            outputTokens: response.usage.completionTokens
        )

        let stopReason = mapFinishReason(choice.finishReason)

        var providerData: [String: AnyCodable]?
        if let citations = response.citations {
            providerData = [
                "citations": AnyCodable(citations)
            ]
        }

        return AIResponse(
            id: response.id,
            model: model,
            message: message,
            stopReason: stopReason,
            usage: usage,
            provider: .perplexity,
            providerData: providerData
        )
    }

    private func mapFinishReason(_ reason: String?) -> AIStopReason {
        guard let reason = reason else {
            return .endTurn
        }

        switch reason {
        case "stop":
            return .endTurn
        case "length":
            return .maxTokens
        case "content_filter":
            return .contentFilter
        default:
            return .endTurn
        }
    }
}

// MARK: - SSE Framing

extension PerplexityProvider {
    /// Extract the JSON payloads of `data:` Server-Sent-Event lines from one streamed byte chunk.
    ///
    /// Both Perplexity stream paths — Sonar (`/chat/completions`) and the Agent API
    /// (`/v1/responses`) — frame their responses as SSE: `data: <json>` lines terminated by
    /// newlines, closed by a `data: [DONE]` sentinel. This helper appends the chunk to `buffer`,
    /// splits off every complete (newline-terminated) line, keeps only `data:` lines, strips the
    /// prefix, and reports via `done` whether the terminal `[DONE]` sentinel was seen. A partial
    /// trailing line is retained in `buffer` so a `data:` line split across chunk boundaries is
    /// reassembled on the next call. Exposed `internal` so tests can drive the framing directly.
    static func parseSSEDataPayloads(
        from chunk: Data,
        buffer: inout String
    ) -> (payloads: [String], done: Bool) {
        buffer += String(data: chunk, encoding: .utf8) ?? ""
        var payloads: [String] = []
        var done = false

        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newlineIndex])
            buffer.removeSubrange(buffer.startIndex...newlineIndex)

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("data:") else { continue }

            let payload = trimmed.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" {
                done = true
                break
            }
            if payload.isEmpty { continue }
            payloads.append(String(payload))
        }

        return (payloads, done)
    }
}
