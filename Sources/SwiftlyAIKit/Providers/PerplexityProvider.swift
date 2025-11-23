import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Provider implementation for Perplexity AI
public struct PerplexityProvider: ProviderProtocol {
    public let providerType: ProviderType = .perplexity

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
        return AsyncThrowingStream { continuation in
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

                    let stream = try await httpClient.streamPost(
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

    private func mapToPerplexityRequest(_ request: AIRequest) throws -> PerplexityRequest {
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
        // TODO: Implement when AIRequest supports AnyCodable metadata
        return nil
    }

    private func extractSearchRecencyFilter(from request: AIRequest) -> String? {
        // TODO: Implement when AIRequest supports AnyCodable metadata
        return nil
    }

    private func extractReturnCitations(from request: AIRequest) -> Bool? {
        // TODO: Implement when AIRequest supports AnyCodable metadata
        return nil
    }

    private func extractReturnImages(from request: AIRequest) -> Bool? {
        // TODO: Implement when AIRequest supports AnyCodable metadata
        return nil
    }

    private func extractResponseFormat(from request: AIRequest) -> ResponseFormat? {
        // TODO: Implement when AIRequest supports AnyCodable metadata
        return nil
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
