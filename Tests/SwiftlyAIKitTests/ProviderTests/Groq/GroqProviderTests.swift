import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for GroqProvider implementation
@Suite("GroqProvider Tests")
// swiftlint:disable:next type_body_length
struct GroqProviderTests {
    // MARK: - 1. Basic Configuration Tests

    @Test("GroqProvider initializes with default values")
    func testInitializationDefaults() {
        let provider = GroqProvider()

        #expect(provider.providerType == .groq)
    }

    @Test("GroqProvider initializes with custom baseURL")
    func testInitializationCustomBaseURL() {
        let provider = GroqProvider(baseURL: "https://custom.groq.com/openai/v1")

        #expect(provider.providerType == .groq)
    }

    @Test("GroqProvider initializes with custom HTTP client")
    func testInitializationCustomHTTPClient() {
        let mockClient = HTTPClientManager()
        let provider = GroqProvider(httpClient: mockClient)

        #expect(provider.providerType == .groq)
    }

    // MARK: - 2. Request Mapping Tests

    @Test("Maps text message and system prompt into the Groq request")
    func testBuildRequestTextAndSystem() throws {
        let request = AIRequest(
            model: "openai/gpt-oss-120b",
            messages: [AIMessage(role: .user, content: [.text("Hello, Groq!")])],
            systemPrompt: "You are a helpful assistant."
        )

        let mapped = try GroqProvider().buildGroqRequest(from: request)

        #expect(mapped.model == "openai/gpt-oss-120b")
        #expect(mapped.messages.count == 2)
        #expect(mapped.messages[0].role == "system")
        #expect(mapped.messages[0].content?.textValue == "You are a helpful assistant.")
        #expect(mapped.messages[1].role == "user")
        #expect(mapped.messages[1].content?.textValue == "Hello, Groq!")
    }

    @Test("Maps generation parameters into the Groq request")
    func testBuildRequestGenerationParameters() throws {
        let request = AIRequest(
            model: "openai/gpt-oss-120b",
            messages: [AIMessage(role: .user, content: [.text("Hello")])],
            maxTokens: 1024,
            temperature: 0.7,
            topP: 0.9,
            stopSequences: ["STOP", "END"]
        )

        let mapped = try GroqProvider().buildGroqRequest(from: request)

        #expect(mapped.temperature == 0.7)
        #expect(mapped.max_tokens == 1024)
        #expect(mapped.top_p == 0.9)
        #expect(mapped.stop == ["STOP", "END"])
    }

    @Test("Streaming build enables stream and include_usage")
    func testBuildRequestStreaming() throws {
        let request = AIRequest(
            model: "openai/gpt-oss-120b",
            messages: [AIMessage(role: .user, content: [.text("Hello")])]
        )

        let mapped = try GroqProvider().buildGroqRequest(from: request, streaming: true)

        #expect(mapped.stream == true)
        #expect(mapped.stream_options?.include_usage == true)
    }

    @Test("Maps multimodal (vision) message to content parts")
    func testBuildRequestVision() throws {
        let request = AIRequest(
            model: "meta-llama/llama-4-scout-17b-16e-instruct",
            messages: [AIMessage(role: .user, content: [
                .text("What's in this image?"),
                .image(source: .url("https://example.com/image.jpg"), mediaType: "image/jpeg")
            ])]
        )

        let mapped = try GroqProvider().buildGroqRequest(from: request)

        #expect(mapped.messages.count == 1)
        if case .multimodal(let parts) = mapped.messages[0].content {
            #expect(parts.count == 2)
        } else {
            Issue.record("Expected multimodal content")
        }
    }

    // MARK: - 3. Response Mapping Tests

    @Test("Maps successful chat completion response")
    func testMapChatCompletionResponse() throws {
        let jsonData = MockGroqAPI.chatCompletionResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GroqResponse.self, from: jsonData)

        #expect(response.id == "chatcmpl-abc123def456")
        #expect(response.object == "chat.completion")
        #expect(response.model == "openai/gpt-oss-120b")
        #expect(response.choices.count == 1)
        #expect(response.choices[0].message.role == "assistant")
        #expect(response.choices[0].message.content?.contains("Groq") == true)
        #expect(response.choices[0].finish_reason == "stop")
        #expect(response.usage?.prompt_tokens == 12)
        #expect(response.usage?.completion_tokens == 15)
        #expect(response.usage?.total_tokens == 27)
    }

    @Test("transformToAIResponse maps text and usage to AIResponse")
    func testTransformToAIResponse() throws {
        let jsonData = MockGroqAPI.chatCompletionResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GroqResponse.self, from: jsonData)
        let original = AIRequest(model: "openai/gpt-oss-120b", messages: [AIMessage(role: .user, text: "Hi")])

        let aiResponse = GroqProvider().transformToAIResponse(response, originalRequest: original)

        #expect(aiResponse.provider == .groq)
        #expect(aiResponse.stopReason == .endTurn)
        #expect(aiResponse.textContent.contains("Groq"))
        #expect(aiResponse.usage?.inputTokens == 12)
        #expect(aiResponse.usage?.outputTokens == 15)
    }

    @Test("Maps response with reasoning tokens")
    func testMapReasoningResponse() throws {
        let jsonData = MockGroqAPI.reasoningResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GroqResponse.self, from: jsonData)

        #expect(response.usage?.completion_tokens_details?.reasoning_tokens == 80)
        #expect(response.usage?.completion_tokens_details?.text_tokens == 20)
        #expect(response.usage?.prompt_tokens_details?.cached_tokens == 10)
        #expect(response.usage?.prompt_tokens_details?.text_tokens == 40)
    }

    @Test("Maps response with cached tokens")
    func testMapCachedTokensResponse() throws {
        let jsonData = MockGroqAPI.cachedTokensResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GroqResponse.self, from: jsonData)

        #expect(response.usage?.prompt_tokens_details?.cached_tokens == 75)
        #expect(response.usage?.prompt_tokens_details?.text_tokens == 25)
    }

    @Test("Maps max tokens response")
    func testMapMaxTokensResponse() throws {
        let jsonData = MockGroqAPI.maxTokensResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GroqResponse.self, from: jsonData)

        #expect(response.choices[0].finish_reason == "length")
        #expect(response.usage?.completion_tokens == 100)
    }

    @Test("Maps tool call response")
    func testMapToolCallResponse() throws {
        let jsonData = MockGroqAPI.toolCallResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GroqResponse.self, from: jsonData)

        #expect(response.choices[0].finish_reason == "tool_calls")
        #expect(response.choices[0].message.tool_calls != nil)

        if let toolCalls = response.choices[0].message.tool_calls {
            #expect(toolCalls.count == 1)
            #expect(toolCalls[0].function.name == "get_weather")
            #expect(toolCalls[0].id == "call_abc123")
        }
    }

    @Test("Maps multiple tool calls response")
    func testMapMultipleToolCallsResponse() throws {
        let jsonData = MockGroqAPI.multipleToolCallsResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GroqResponse.self, from: jsonData)

        #expect(response.choices[0].message.tool_calls?.count == 2)
    }

    @Test("Maps vision response")
    func testMapVisionResponse() throws {
        let jsonData = MockGroqAPI.visionResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GroqResponse.self, from: jsonData)

        #expect(response.model == "meta-llama/llama-4-scout-17b-16e-instruct")
        #expect(response.choices[0].message.content?.contains("sunset") == true)
        #expect(response.usage?.prompt_tokens_details?.image_tokens == 200)
    }

    @Test("Maps content filter response")
    func testMapContentFilterResponse() throws {
        let jsonData = MockGroqAPI.contentFilterResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GroqResponse.self, from: jsonData)

        #expect(response.choices[0].finish_reason == "content_filter")
        #expect(response.choices[0].message.refusal != nil)
    }

    @Test("Maps JSON structured output response")
    func testMapJSONResponse() throws {
        let jsonData = MockGroqAPI.jsonResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GroqResponse.self, from: jsonData)

        #expect(response.choices[0].finish_reason == "stop")
        #expect(response.choices[0].message.content?.contains("Great Gatsby") == true)
        #expect(response.choices[0].message.content?.contains("1925") == true)
    }

    // MARK: - 4. Error Handling Tests

    @Test("Decodes authentication error")
    func testDecodeAuthenticationError() throws {
        let jsonData = MockGroqAPI.authenticationError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GroqError.self, from: jsonData)

        #expect(errorResponse.error.type == "invalid_api_key")
        #expect(errorResponse.error.message.contains("Invalid API key"))
    }

    @Test("Decodes rate limit error")
    func testDecodeRateLimitError() throws {
        let jsonData = MockGroqAPI.rateLimitError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GroqError.self, from: jsonData)

        #expect(errorResponse.error.type == "rate_limit_error")
        #expect(errorResponse.error.message.contains("Rate limit"))
    }

    @Test("Decodes invalid request error")
    func testDecodeInvalidRequestError() throws {
        let jsonData = MockGroqAPI.invalidRequestError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GroqError.self, from: jsonData)

        #expect(errorResponse.error.type == "invalid_request_error")
        #expect(errorResponse.error.param == "model")
    }

    @Test("Decodes model not found error")
    func testDecodeModelNotFoundError() throws {
        let jsonData = MockGroqAPI.modelNotFoundError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GroqError.self, from: jsonData)

        #expect(errorResponse.error.code == "model_not_found")
    }

    @Test("Decodes context length exceeded error")
    func testDecodeContextLengthError() throws {
        let jsonData = MockGroqAPI.contextLengthError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GroqError.self, from: jsonData)

        #expect(errorResponse.error.code == "context_length_exceeded")
        #expect(errorResponse.error.message.contains("128000"))
    }

    @Test("Decodes server error")
    func testDecodeServerError() throws {
        let jsonData = MockGroqAPI.serverError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GroqError.self, from: jsonData)

        #expect(errorResponse.error.type == "server_error")
    }

    @Test("Decodes service unavailable error")
    func testDecodeServiceUnavailableError() throws {
        let jsonData = MockGroqAPI.serviceUnavailableError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GroqError.self, from: jsonData)

        #expect(errorResponse.error.code == "service_unavailable")
    }

    // MARK: - 5. Models List Tests

    @Test("Decodes models list response")
    func testDecodeModelsListResponse() throws {
        let jsonData = MockGroqAPI.modelsListResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GroqModelsResponse.self, from: jsonData)

        #expect(response.object == "list")
        #expect(response.data.count == 8)
        #expect(response.data[0].id == "openai/gpt-oss-120b")
        #expect(response.data[0].owned_by == "OpenAI")
        #expect(response.data.contains { $0.id == "gemma2-9b-it" && $0.owned_by == "Google" })
    }

    // MARK: - 6. Edge Cases

    @Test("Handles empty content response")
    func testHandlesEmptyContentResponse() throws {
        let jsonData = MockGroqAPI.emptyContentResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GroqResponse.self, from: jsonData)

        #expect(response.choices[0].message.content?.isEmpty == true)
    }

    @Test("Handles null content response")
    func testHandlesNullContentResponse() throws {
        let jsonData = MockGroqAPI.nullContentResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GroqResponse.self, from: jsonData)

        #expect(response.choices[0].message.content == nil)
    }

    @Test("Handles response with logprobs")
    func testHandlesLogprobsResponse() throws {
        let jsonData = MockGroqAPI.logprobsResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GroqResponse.self, from: jsonData)

        #expect(response.choices[0].logprobs != nil)
        #expect(response.choices[0].logprobs?.content?.count == 1)
        #expect(response.choices[0].logprobs?.content?[0].token == "Hello")
        #expect(response.choices[0].logprobs?.content?[0].top_logprobs?.count == 2)
    }

    // MARK: - 7. GroqRequest Encoding Tests

    @Test("Encodes basic GroqRequest")
    func testEncodeBasicRequest() throws {
        let request = GroqRequest(
            model: "openai/gpt-oss-120b",
            messages: [GroqMessage(role: "user", text: "Hello")]
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        #expect(json["model"]?.value as? String == "openai/gpt-oss-120b")
    }

    @Test("Encodes GroqRequest with streaming options")
    func testEncodeStreamingRequest() throws {
        let request = GroqRequest(
            model: "openai/gpt-oss-120b",
            messages: [GroqMessage(role: "user", text: "Hello")],
            stream: true,
            stream_options: GroqStreamOptions(include_usage: true)
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        #expect(json["stream"]?.value as? Bool == true)
    }

    @Test("Encodes GroqRequest with tools")
    func testEncodeToolsRequest() throws {
        let tool = GroqTool(
            type: "function",
            function: GroqFunction(
                name: "get_weather",
                description: "Get the current weather",
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "location": ["type": "string", "description": "The city"]
                    ])
                ]
            )
        )

        let request = GroqRequest(
            model: "openai/gpt-oss-120b",
            messages: [GroqMessage(role: "user", text: "What's the weather in NYC?")],
            tools: [tool]
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        #expect(json["tools"] != nil)
    }

    // MARK: - 8. GroqMessage Content Tests

    @Test("Creates text message content")
    func testTextMessageContent() {
        let content = GroqMessageContent.text("Hello world")

        if case .text(let text) = content {
            #expect(text == "Hello world")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("Creates multimodal message content")
    func testMultimodalMessageContent() {
        let parts: [GroqContentPart] = [
            .text("What's in this image?"),
            .imageUrl(GroqImageUrl(url: "https://example.com/image.jpg"))
        ]
        let content = GroqMessageContent.multimodal(parts)

        if case .multimodal(let actualParts) = content {
            #expect(actualParts.count == 2)
        } else {
            Issue.record("Expected multimodal content")
        }
    }

    @Test("Gets text value from text content")
    func testTextValueFromText() {
        let content = GroqMessageContent.text("Hello")
        #expect(content.textValue == "Hello")
    }

    @Test("Gets text value from multimodal content")
    func testTextValueFromMultimodal() {
        let parts: [GroqContentPart] = [
            .text("Part 1"),
            .imageUrl(GroqImageUrl(url: "https://example.com/image.jpg")),
            .text("Part 2")
        ]
        let content = GroqMessageContent.multimodal(parts)

        #expect(content.textValue == "Part 1 Part 2")
    }
}
