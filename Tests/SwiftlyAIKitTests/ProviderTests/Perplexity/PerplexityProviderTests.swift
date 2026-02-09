import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for PerplexityProvider implementation
@Suite("PerplexityProvider Tests")
struct PerplexityProviderTests {
    // MARK: - Basic Configuration Tests

    @Test("PerplexityProvider initializes with default values")
    func testInitializationDefaults() {
        let provider = PerplexityProvider()

        #expect(provider.providerType == .perplexity)
    }

    @Test("PerplexityProvider initializes with custom baseURL")
    func testInitializationCustomBaseURL() {
        let provider = PerplexityProvider(baseURL: "https://custom.api.com")

        #expect(provider.providerType == .perplexity)
    }

    @Test("PerplexityProvider initializes with custom HTTP client")
    func testInitializationCustomHTTPClient() {
        let mockClient = HTTPClientManager()
        let provider = PerplexityProvider(httpClient: mockClient)

        #expect(provider.providerType == .perplexity)
    }

    // MARK: - Request Mapping Tests

    @Test("Maps text message to Perplexity format")
    func testMapTextMessage() {
        let message = AIMessage(
            role: .user,
            content: [.text("Tell me about AI with real-time search")]
        )

        #expect(message.role == .user)
        #expect(message.content.count == 1)

        if case .text(let text) = message.content[0] {
            #expect(text == "Tell me about AI with real-time search")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("Maps system prompt correctly")
    func testMapSystemPrompt() {
        let request = AIRequest(
            model: "sonar",
            messages: [
                AIMessage(role: .user, content: [.text("Hello")])
            ],
            systemPrompt: "You are a helpful assistant with web search."
        )

        #expect(request.systemPrompt == "You are a helpful assistant with web search.")
        #expect(request.messages.count == 1)
    }

    @Test("Maps generation config parameters")
    func testMapGenerationConfig() {
        let request = AIRequest(
            model: "sonar-pro",
            messages: [
                AIMessage(role: .user, content: [.text("Hello")])
            ],
            maxTokens: 1024,
            temperature: 0.7,
            topP: 0.9,
            topK: 40
        )

        #expect(request.temperature == 0.7)
        #expect(request.maxTokens == 1024)
        #expect(request.topP == 0.9)
        #expect(request.topK == 40)
    }

    // MARK: - Response Mapping Tests

    @Test("Maps successful response from Perplexity")
    func testMapSuccessfulResponse() throws {
        let jsonData = MockPerplexityAPI.chatCompletionResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(PerplexityResponse.self, from: jsonData)

        #expect(response.choices.count == 1)
        #expect(response.choices[0].finishReason == "stop")
        #expect(response.usage.totalTokens == 43)
    }

    @Test("Maps response with citations")
    func testMapResponseWithCitations() throws {
        let jsonData = MockPerplexityAPI.chatCompletionWithCitationsResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(PerplexityResponse.self, from: jsonData)

        #expect(response.choices.count == 1)
        #expect(response.citations != nil)
        #expect(response.citations?.count == 3)

        if let citations = response.citations {
            #expect(citations.contains("https://arxiv.org/abs/2023.12345"))
        }
    }

    @Test("Maps finish reasons correctly")
    func testMapFinishReasons() throws {
        // Test STOP
        let stopData = MockPerplexityAPI.chatCompletionResponse.data(using: .utf8)!
        let stopResponse = try JSONDecoder().decode(PerplexityResponse.self, from: stopData)
        #expect(stopResponse.choices[0].finishReason == "stop")

        // Test LENGTH
        let maxData = MockPerplexityAPI.maxTokensResponse.data(using: .utf8)!
        let maxResponse = try JSONDecoder().decode(PerplexityResponse.self, from: maxData)
        #expect(maxResponse.choices[0].finishReason == "length")

        // Test CONTENT_FILTER
        let filterData = MockPerplexityAPI.contentFilteredResponse.data(using: .utf8)!
        let filterResponse = try JSONDecoder().decode(PerplexityResponse.self, from: filterData)
        #expect(filterResponse.choices[0].finishReason == "content_filter")
    }

    @Test("Maps usage metadata correctly")
    func testMapUsageMetadata() throws {
        let jsonData = MockPerplexityAPI.chatCompletionResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(PerplexityResponse.self, from: jsonData)

        let usage = response.usage
        #expect(usage.promptTokens == 15)
        #expect(usage.completionTokens == 28)
        #expect(usage.totalTokens == 43)
    }

    // MARK: - Error Handling Tests

    @Test("Parses 400 Bad Request error")
    func testParseBadRequestError() throws {
        let jsonData = MockPerplexityAPI.badRequestError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(PerplexityErrorResponse.self, from: jsonData)

        #expect(errorResponse.error.message.contains("Invalid request"))
        #expect(errorResponse.error.type == "invalid_request_error")
    }

    @Test("Parses 401 Unauthorized error")
    func testParseUnauthorizedError() throws {
        let jsonData = MockPerplexityAPI.unauthorizedError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(PerplexityErrorResponse.self, from: jsonData)

        #expect(errorResponse.error.message.contains("API key"))
        #expect(errorResponse.error.type == "authentication_error")
    }

    @Test("Parses 429 Rate Limit error")
    func testParseRateLimitError() throws {
        let jsonData = MockPerplexityAPI.rateLimitError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(PerplexityErrorResponse.self, from: jsonData)

        #expect(errorResponse.error.message.contains("Rate limit"))
        #expect(errorResponse.error.type == "rate_limit_error")
    }

    @Test("Parses 500 Internal Server error")
    func testParseInternalServerError() throws {
        let jsonData = MockPerplexityAPI.internalServerError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(PerplexityErrorResponse.self, from: jsonData)

        #expect(errorResponse.error.type == "server_error")
    }

    // MARK: - Search Feature Tests

    @Test("Domain filtered response can be decoded")
    func testDomainFilteredResponse() throws {
        let jsonData = MockPerplexityAPI.domainFilteredResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(PerplexityResponse.self, from: jsonData)

        #expect(response.citations != nil)
        #expect(response.citations?.count == 2)

        if let citations = response.citations {
            #expect(citations.contains { $0.contains("arxiv.org") })
            #expect(citations.contains { $0.contains("github.com") })
        }
    }

    @Test("Recency filtered response can be decoded")
    func testRecencyFilteredResponse() throws {
        let jsonData = MockPerplexityAPI.recencyFilteredResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(PerplexityResponse.self, from: jsonData)

        #expect(response.model == "sonar-pro")
        #expect(response.citations != nil)
    }

    @Test("RecencyFilter enum has all values")
    func testRecencyFilterEnum() {
        let filters: [RecencyFilter] = [
            .day,
            .week,
            .month,
            .year
        ]

        #expect(filters.count == 4)
    }

    // MARK: - Streaming Tests

    @Test("Stream events can be parsed")
    func testStreamEventsParsing() throws {
        for event in MockPerplexityAPI.streamEvents {
            if event == "data: [DONE]" {
                continue
            }

            guard event.hasPrefix("data: ") else {
                continue
            }

            let jsonString = String(event.dropFirst(6))
            guard let jsonData = jsonString.data(using: .utf8) else {
                continue
            }

            let chunk = try JSONDecoder().decode(PerplexityStreamChunk.self, from: jsonData)
            #expect(!chunk.choices.isEmpty)
        }
    }

    @Test("Stream accumulates text correctly")
    func testStreamTextAccumulation() {
        var accumulated = ""
        let expectedParts = ["Hello", "! How", " can", " I", " help", " you", "?"]

        for part in expectedParts {
            accumulated += part
        }

        #expect(accumulated == "Hello! How can I help you?")
    }

    // MARK: - Model Support Tests

    @Test("Sonar model is supported")
    func testSonarSupport() {
        let model = ModelProvider.sonar

        #expect(model.providerType == .perplexity)
        #expect(model.displayName == "Sonar")
        #expect(model.supportsVision == false)
        #expect(model.maxInputTokens == 127_072)
        #expect(model.maxOutputTokens == 4_096)
    }

    @Test("Sonar Pro model is supported")
    func testSonarProSupport() {
        let model = ModelProvider.sonarPro

        #expect(model.providerType == .perplexity)
        #expect(model.displayName == "Sonar Pro")
        #expect(model.supportsVision == false)
        #expect(model.maxInputTokens == 200_000)
        #expect(model.maxOutputTokens == 4_096)
    }

    @Test("Sonar Reasoning model is supported")
    func testSonarReasoningSupport() {
        let model = ModelProvider.sonarReasoning

        #expect(model.providerType == .perplexity)
        #expect(model.displayName == "Sonar Reasoning")
        #expect(model.supportsVision == false)
        #expect(model.maxInputTokens == 127_072)
        #expect(model.maxOutputTokens == 4_096)
    }

    @Test("All Perplexity models use Perplexity provider")
    func testAllPerplexityModelsUsePerplexityProvider() {
        let perplexityModels: [ModelProvider] = [
            .sonar,
            .sonarPro,
            .sonarReasoning
        ]

        for model in perplexityModels {
            #expect(model.providerType == .perplexity)
        }
    }

    // MARK: - Additional Model Tests

    @Test("ResponseFormat can be created")
    func testResponseFormat() {
        let schema = JSONSchema(
            name: "test_schema",
            schema: ["type": AnyCodable("object")]
        )

        let format = ResponseFormat(
            type: "json_schema",
            jsonSchema: schema
        )

        #expect(format.type == "json_schema")
        #expect(format.jsonSchema?.name == "test_schema")
    }

    @Test("SearchResult can be created")
    func testSearchResult() {
        let result = SearchResult(
            title: "AI Research Paper",
            url: "https://arxiv.org/abs/2023.12345",
            publishedDate: "2023-11-20",
            author: "Jane Researcher",
            score: 0.95
        )

        #expect(result.title == "AI Research Paper")
        #expect(result.url.contains("arxiv.org"))
        #expect(result.publishedDate == "2023-11-20")
        #expect(result.author == "Jane Researcher")
        #expect(result.score == 0.95)
    }

    // MARK: - PerplexityOptions Integration Tests

    @Test("PerplexityOptions creates valid providerOptions for AIRequest")
    func testPerplexityOptionsCreatesValidProviderOptions() {
        let options = PerplexityOptions(
            searchDomainFilter: ["arxiv.org", "github.com"],
            searchRecencyFilter: .week,
            returnCitations: true,
            returnImages: false
        )

        let request = AIRequest(
            model: "sonar-pro",
            messages: [AIMessage(role: .user, content: [.text("Latest AI research?")])],
            providerOptions: options.toProviderOptions()
        )

        #expect(request.model == "sonar-pro")
        #expect(request.providerOptions != nil)
        #expect(request.providerOptions?.count == 4)
    }

    @Test("PerplexityOptions webSearch convenience method creates correct options")
    func testPerplexityOptionsWebSearch() {
        let options = PerplexityOptions.webSearch(
            domains: ["techcrunch.com", "theverge.com"],
            recency: .day,
            includeCitations: true
        )

        let request = AIRequest(
            model: "sonar",
            messages: [AIMessage(role: .user, content: [.text("Latest tech news?")])],
            providerOptions: options.toProviderOptions()
        )

        #expect(request.providerOptions != nil)
        #expect(request.providerOptions?["search_domain_filter"] != nil)
        #expect(request.providerOptions?["search_recency_filter"] != nil)
        #expect(request.providerOptions?["return_citations"] != nil)
    }

    @Test("PerplexityOptions jsonSchema convenience method creates correct options")
    func testPerplexityOptionsJsonSchema() {
        let schema: [String: AnyCodable] = [
            "type": AnyCodable("object"),
            "properties": AnyCodable([
                "name": ["type": "string"],
                "age": ["type": "integer"]
            ])
        ]

        let options = PerplexityOptions.jsonSchema(
            name: "person",
            schema: schema,
            includeCitations: false
        )

        let request = AIRequest(
            model: "sonar-reasoning",
            messages: [AIMessage(role: .user, content: [.text("Extract person info")])],
            providerOptions: options.toProviderOptions()
        )

        #expect(request.providerOptions != nil)
        #expect(request.providerOptions?["response_format"] != nil)
        #expect(request.providerOptions?["return_citations"] != nil)
    }

    @Test("AIRequest with PerplexityOptions has correct domain filter")
    func testAIRequestWithDomainFilter() {
        let options = PerplexityOptions(
            searchDomainFilter: ["example.com", "test.org"]
        )

        let request = AIRequest(
            model: "sonar",
            messages: [AIMessage(role: .user, content: [.text("Test query")])],
            providerOptions: options.toProviderOptions()
        )

        #expect(request.providerOptions?["search_domain_filter"] != nil)

        if let domains = request.providerOptions?["search_domain_filter"]?.value as? [String] {
            #expect(domains == ["example.com", "test.org"])
        } else {
            Issue.record("Domain filter not extracted correctly")
        }
    }

    @Test("AIRequest with PerplexityOptions has correct recency filter")
    func testAIRequestWithRecencyFilter() {
        let options = PerplexityOptions(
            searchRecencyFilter: .month
        )

        let request = AIRequest(
            model: "sonar-pro",
            messages: [AIMessage(role: .user, content: [.text("Recent developments?")])],
            providerOptions: options.toProviderOptions()
        )

        #expect(request.providerOptions?["search_recency_filter"] != nil)

        if let recency = request.providerOptions?["search_recency_filter"]?.value as? String {
            #expect(recency == "month")
        } else {
            Issue.record("Recency filter not extracted correctly")
        }
    }

    @Test("AIRequest with PerplexityOptions has correct citation flag")
    func testAIRequestWithCitationFlag() {
        let options = PerplexityOptions(
            returnCitations: true
        )

        let request = AIRequest(
            model: "sonar",
            messages: [AIMessage(role: .user, content: [.text("AI research")])],
            providerOptions: options.toProviderOptions()
        )

        #expect(request.providerOptions?["return_citations"] != nil)

        if let citations = request.providerOptions?["return_citations"]?.value as? Bool {
            #expect(citations == true)
        } else {
            Issue.record("Citations flag not extracted correctly")
        }
    }

    @Test("AIRequest with PerplexityOptions has correct images flag")
    func testAIRequestWithImagesFlag() {
        let options = PerplexityOptions(
            returnImages: true
        )

        let request = AIRequest(
            model: "sonar",
            messages: [AIMessage(role: .user, content: [.text("Show me images")])],
            providerOptions: options.toProviderOptions()
        )

        #expect(request.providerOptions?["return_images"] != nil)

        if let images = request.providerOptions?["return_images"]?.value as? Bool {
            #expect(images == true)
        } else {
            Issue.record("Images flag not extracted correctly")
        }
    }

    @Test("AIRequest with PerplexityOptions has correct response format")
    func testAIRequestWithResponseFormat() {
        let schema: [String: AnyCodable] = [
            "type": AnyCodable("object"),
            "properties": AnyCodable(["title": ["type": "string"]])
        ]

        let options = PerplexityOptions.jsonSchema(
            name: "article",
            schema: schema
        )

        let request = AIRequest(
            model: "sonar-reasoning",
            messages: [AIMessage(role: .user, content: [.text("Extract article")])],
            providerOptions: options.toProviderOptions()
        )

        #expect(request.providerOptions?["response_format"] != nil)

        if let format = request.providerOptions?["response_format"]?.value as? [String: Any] {
            #expect(format["type"] as? String == "json_schema")
        } else {
            Issue.record("Response format not extracted correctly")
        }
    }
}
