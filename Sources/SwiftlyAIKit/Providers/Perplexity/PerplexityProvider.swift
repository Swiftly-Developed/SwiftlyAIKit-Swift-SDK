import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Provider implementation for Perplexity AI
///
/// Real-time web search with automatic citations.
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
public struct PerplexityProvider: ProviderProtocol {
    public let providerType: ProviderType = .perplexity

    /// Perplexity's Sonar API is a pure search/answer API with no function/tool calling.
    ///
    /// Tool calling is therefore unsupported. When a caller passes ``AIRequest/tools`` /
    /// ``AIRequest/toolChoice`` this provider **degrades gracefully**: the tools are ignored
    /// (a documented no-op) and the normal Sonar request proceeds. See ``mapToPerplexityRequest(_:)``
    /// — the neutral request's tool fields are intentionally not mapped onto ``PerplexityRequest``,
    /// which has no tools field, so nothing tool-related ever reaches the wire body.
    ///
    /// Ignore-and-proceed is chosen over throwing because tool support is a *field* on the normal
    /// message path (not a separate operation like batching or image generation, which throw
    /// ``AIError/unsupportedFeature(feature:provider:)``); throwing would break existing callers
    /// that happen to attach tools to an otherwise-valid Sonar request. Callers that need to detect
    /// support up front can read this flag or ``ToolCapabilities/isSupported(by:)``.
    public var supportsTools: Bool { false }

    private let baseURL: String
    private let httpClient: HTTPClientManager

    // MARK: - Initialization

    /// Initialize with default configuration
    public init() {
        self.baseURL = ProviderType.perplexity.baseURL
        self.httpClient = HTTPClientManager()
    }

    /// Initialize with custom base URL
    public init(baseURL: String) {
        self.baseURL = baseURL
        self.httpClient = HTTPClientManager()
    }

    /// Initialize with custom HTTP client
    public init(httpClient: HTTPClientManager) {
        self.baseURL = ProviderType.perplexity.baseURL
        self.httpClient = httpClient
    }

    // MARK: - ProviderProtocol Implementation

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
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

                    for try await chunk in stream {
                        let streamChunk = try JSONDecoder().decode(PerplexityStreamChunk.self, from: chunk)

                        if let choice = streamChunk.choices.first {
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
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Request Mapping

    /// Map a neutral ``AIRequest`` to Perplexity's Sonar request shape.
    ///
    /// `request.tools` / `request.toolChoice` are intentionally **not** mapped: the Sonar API has no
    /// function-calling support, so `PerplexityRequest` has no tools field and any tools attached to
    /// the request are silently dropped (see ``supportsTools``). Exposed as `internal` (rather than
    /// `private`) so tests can assert the wire body omits tools.
    func mapToPerplexityRequest(_ request: AIRequest) throws -> PerplexityRequest {
        let messages = request.messages.map { message in
            let role = mapRole(message.role)
            let content = message.textContent
            return PerplexityMessage(role: role, content: content)
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

    // MARK: - Response Mapping

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
