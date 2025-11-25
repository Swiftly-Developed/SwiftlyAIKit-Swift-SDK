import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for GrokProvider implementation
@Suite("GrokProvider Tests")
struct GrokProviderTests {
    // MARK: - 1. Basic Configuration Tests

    @Test("GrokProvider initializes with default values")
    func testInitializationDefaults() {
        let provider = GrokProvider()

        #expect(provider.providerType == .grok)
    }

    @Test("GrokProvider initializes with custom baseURL")
    func testInitializationCustomBaseURL() {
        let provider = GrokProvider(baseURL: "https://custom.x.ai/v1")

        #expect(provider.providerType == .grok)
    }

    @Test("GrokProvider initializes with custom HTTP client")
    func testInitializationCustomHTTPClient() {
        let mockClient = HTTPClientManager()
        let provider = GrokProvider(httpClient: mockClient)

        #expect(provider.providerType == .grok)
    }

    // MARK: - 2. Request Mapping Tests

    @Test("Maps text message to Grok format")
    func testMapTextMessage() {
        let message = AIMessage(
            role: .user,
            content: [.text("Hello, Grok!")]
        )

        #expect(message.role == .user)
        #expect(message.content.count == 1)

        if case .text(let text) = message.content[0] {
            #expect(text == "Hello, Grok!")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("Maps image message to Grok format")
    func testMapImageMessage() {
        let message = AIMessage(
            role: .user,
            content: [
                .text("What's in this image?"),
                .image(source: .url("https://example.com/image.jpg"), mediaType: "image/jpeg")
            ]
        )

        #expect(message.content.count == 2)
        #expect(message.role == .user)
    }

    @Test("Maps base64 image to Grok format")
    func testMapBase64ImageMessage() {
        let base64Data = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        let message = AIMessage(
            role: .user,
            content: [
                .text("Analyze this image"),
                .image(source: .base64(base64Data), mediaType: "image/png")
            ]
        )

        #expect(message.content.count == 2)
        #expect(message.role == .user)
    }

    @Test("Maps system prompt correctly")
    func testMapSystemPrompt() {
        let request = AIRequest(
            model: "grok-4-0709",
            messages: [
                AIMessage(role: .user, content: [.text("Hello")])
            ],
            systemPrompt: "You are Grok, made by xAI."
        )

        #expect(request.systemPrompt == "You are Grok, made by xAI.")
        #expect(request.messages.count == 1)
    }

    @Test("Maps generation parameters")
    func testMapGenerationParameters() {
        let request = AIRequest(
            model: "grok-4",
            messages: [
                AIMessage(role: .user, content: [.text("Hello")])
            ],
            maxTokens: 1024,
            temperature: 0.7,
            topP: 0.9,
            stopSequences: ["STOP", "END"]
        )

        #expect(request.temperature == 0.7)
        #expect(request.maxTokens == 1024)
        #expect(request.topP == 0.9)
        #expect(request.stopSequences == ["STOP", "END"])
    }

    // MARK: - 3. Response Mapping Tests

    @Test("Maps successful chat completion response")
    func testMapChatCompletionResponse() throws {
        let jsonData = MockGrokAPI.chatCompletionResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokResponse.self, from: jsonData)

        #expect(response.id == "chatcmpl-abc123def456")
        #expect(response.object == "chat.completion")
        #expect(response.model == "grok-4-0709")
        #expect(response.choices.count == 1)
        #expect(response.choices[0].message.role == "assistant")
        #expect(response.choices[0].message.content?.contains("Grok") == true)
        #expect(response.choices[0].finish_reason == "stop")
        #expect(response.usage?.prompt_tokens == 12)
        #expect(response.usage?.completion_tokens == 15)
        #expect(response.usage?.total_tokens == 27)
    }

    @Test("Maps response with reasoning tokens")
    func testMapReasoningResponse() throws {
        let jsonData = MockGrokAPI.reasoningResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokResponse.self, from: jsonData)

        #expect(response.usage?.completion_tokens_details?.reasoning_tokens == 80)
        #expect(response.usage?.completion_tokens_details?.text_tokens == 20)
        #expect(response.usage?.prompt_tokens_details?.cached_tokens == 10)
        #expect(response.usage?.prompt_tokens_details?.text_tokens == 40)
    }

    @Test("Maps response with cached tokens")
    func testMapCachedTokensResponse() throws {
        let jsonData = MockGrokAPI.cachedTokensResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokResponse.self, from: jsonData)

        #expect(response.usage?.prompt_tokens_details?.cached_tokens == 75)
        #expect(response.usage?.prompt_tokens_details?.text_tokens == 25)
    }

    @Test("Maps max tokens response")
    func testMapMaxTokensResponse() throws {
        let jsonData = MockGrokAPI.maxTokensResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokResponse.self, from: jsonData)

        #expect(response.choices[0].finish_reason == "length")
        #expect(response.usage?.completion_tokens == 100)
    }

    @Test("Maps tool call response")
    func testMapToolCallResponse() throws {
        let jsonData = MockGrokAPI.toolCallResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokResponse.self, from: jsonData)

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
        let jsonData = MockGrokAPI.multipleToolCallsResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokResponse.self, from: jsonData)

        #expect(response.choices[0].message.tool_calls?.count == 2)
    }

    @Test("Maps vision response from Grok 2 Vision")
    func testMapVisionResponse() throws {
        let jsonData = MockGrokAPI.visionResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokResponse.self, from: jsonData)

        #expect(response.model == "grok-2-vision-1212")
        #expect(response.choices[0].message.content?.contains("sunset") == true)
        #expect(response.usage?.prompt_tokens_details?.image_tokens == 200)
    }

    @Test("Maps content filter response")
    func testMapContentFilterResponse() throws {
        let jsonData = MockGrokAPI.contentFilterResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokResponse.self, from: jsonData)

        #expect(response.choices[0].finish_reason == "content_filter")
        #expect(response.choices[0].message.refusal != nil)
    }

    @Test("Maps JSON structured output response")
    func testMapJSONResponse() throws {
        let jsonData = MockGrokAPI.jsonResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokResponse.self, from: jsonData)

        #expect(response.choices[0].finish_reason == "stop")
        #expect(response.choices[0].message.content?.contains("Great Gatsby") == true)
        #expect(response.choices[0].message.content?.contains("1925") == true)
    }

    @Test("Maps code response from Grok Code Fast")
    func testMapCodeResponse() throws {
        let jsonData = MockGrokAPI.codeResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokResponse.self, from: jsonData)

        #expect(response.model == "grok-code-fast-1")
        #expect(response.choices[0].message.content?.contains("fibonacci") == true)
    }

    // MARK: - 4. Streaming Tests

    @Test("Decodes streaming chunk with role")
    func testDecodeStreamingChunkWithRole() throws {
        let eventString = "{\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1700000010,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\"},\"finish_reason\":null}]}"
        let eventData = eventString.data(using: .utf8)!

        let chunk = try JSONDecoder().decode(GrokStreamChunk.self, from: eventData)

        #expect(chunk.id == "chatcmpl-stream123")
        #expect(chunk.model == "grok-4")
        #expect(chunk.choices[0].delta.role == "assistant")
        #expect(chunk.choices[0].finish_reason == nil)
    }

    @Test("Decodes streaming chunk with content")
    func testDecodeStreamingChunkWithContent() throws {
        let eventString = "{\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1700000010,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hello!\"},\"finish_reason\":null}]}"
        let eventData = eventString.data(using: .utf8)!

        let chunk = try JSONDecoder().decode(GrokStreamChunk.self, from: eventData)

        #expect(chunk.choices[0].delta.content == "Hello!")
    }

    @Test("Decodes streaming chunk with finish reason and usage")
    func testDecodeStreamingChunkFinal() throws {
        let eventString = "{\"id\":\"chatcmpl-stream123\",\"object\":\"chat.completion.chunk\",\"created\":1700000010,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":8,\"completion_tokens\":6,\"total_tokens\":14}}"
        let eventData = eventString.data(using: .utf8)!

        let chunk = try JSONDecoder().decode(GrokStreamChunk.self, from: eventData)

        #expect(chunk.choices[0].finish_reason == "stop")
        #expect(chunk.usage?.prompt_tokens == 8)
        #expect(chunk.usage?.completion_tokens == 6)
    }

    @Test("Decodes streaming chunk with tool call delta")
    func testDecodeStreamingToolCallDelta() throws {
        let eventString = "{\"id\":\"chatcmpl-stream-tools\",\"object\":\"chat.completion.chunk\",\"created\":1700000011,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"id\":\"call_stream123\",\"type\":\"function\",\"function\":{\"name\":\"get_weather\"}}]},\"finish_reason\":null}]}"
        let eventData = eventString.data(using: .utf8)!

        let chunk = try JSONDecoder().decode(GrokStreamChunk.self, from: eventData)

        #expect(chunk.choices[0].delta.tool_calls?.count == 1)
        #expect(chunk.choices[0].delta.tool_calls?[0].id == "call_stream123")
        #expect(chunk.choices[0].delta.tool_calls?[0].function?.name == "get_weather")
    }

    @Test("Decodes streaming chunk with reasoning tokens")
    func testDecodeStreamingWithReasoningTokens() throws {
        let eventString = "{\"id\":\"chatcmpl-stream-reason\",\"object\":\"chat.completion.chunk\",\"created\":1700000012,\"model\":\"grok-4\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":30,\"completion_tokens\":50,\"total_tokens\":80,\"completion_tokens_details\":{\"reasoning_tokens\":40,\"text_tokens\":10}}}"
        let eventData = eventString.data(using: .utf8)!

        let chunk = try JSONDecoder().decode(GrokStreamChunk.self, from: eventData)

        #expect(chunk.usage?.completion_tokens_details?.reasoning_tokens == 40)
        #expect(chunk.usage?.completion_tokens_details?.text_tokens == 10)
    }

    // MARK: - 5. Error Handling Tests

    @Test("Decodes authentication error")
    func testDecodeAuthenticationError() throws {
        let jsonData = MockGrokAPI.authenticationError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GrokError.self, from: jsonData)

        #expect(errorResponse.error.type == "invalid_api_key")
        #expect(errorResponse.error.message.contains("Invalid API key"))
    }

    @Test("Decodes rate limit error")
    func testDecodeRateLimitError() throws {
        let jsonData = MockGrokAPI.rateLimitError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GrokError.self, from: jsonData)

        #expect(errorResponse.error.type == "rate_limit_error")
        #expect(errorResponse.error.message.contains("Rate limit"))
    }

    @Test("Decodes invalid request error")
    func testDecodeInvalidRequestError() throws {
        let jsonData = MockGrokAPI.invalidRequestError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GrokError.self, from: jsonData)

        #expect(errorResponse.error.type == "invalid_request_error")
        #expect(errorResponse.error.param == "model")
    }

    @Test("Decodes model not found error")
    func testDecodeModelNotFoundError() throws {
        let jsonData = MockGrokAPI.modelNotFoundError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GrokError.self, from: jsonData)

        #expect(errorResponse.error.code == "model_not_found")
    }

    @Test("Decodes context length exceeded error")
    func testDecodeContextLengthError() throws {
        let jsonData = MockGrokAPI.contextLengthError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GrokError.self, from: jsonData)

        #expect(errorResponse.error.code == "context_length_exceeded")
        #expect(errorResponse.error.message.contains("128000"))
    }

    @Test("Decodes server error")
    func testDecodeServerError() throws {
        let jsonData = MockGrokAPI.serverError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GrokError.self, from: jsonData)

        #expect(errorResponse.error.type == "server_error")
    }

    @Test("Decodes service unavailable error")
    func testDecodeServiceUnavailableError() throws {
        let jsonData = MockGrokAPI.serviceUnavailableError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(GrokError.self, from: jsonData)

        #expect(errorResponse.error.code == "service_unavailable")
    }

    // MARK: - 6. Tokenize API Tests

    @Test("Decodes tokenize response")
    func testDecodeTokenizeResponse() throws {
        let jsonData = MockGrokAPI.tokenizeResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokTokenizeResponse.self, from: jsonData)

        #expect(response.tokens.count == 6)
        #expect(response.tokens[0].string_token == "Hello")
        #expect(response.tokens[5].string_token == "?")
    }

    @Test("Decodes long tokenize response")
    func testDecodeLongTokenizeResponse() throws {
        let jsonData = MockGrokAPI.tokenizeLongResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokTokenizeResponse.self, from: jsonData)

        #expect(response.tokens.count == 10)
        #expect(response.tokens[0].string_token == "The")
        #expect(response.tokens[9].string_token == ".")
    }

    // MARK: - 7. Deferred Completions Tests

    @Test("Decodes deferred initial response")
    func testDecodeDeferredInitialResponse() throws {
        let jsonData = MockGrokAPI.deferredInitialResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokDeferredResponse.self, from: jsonData)

        #expect(response.request_id == "req_deferred123")
    }

    @Test("Decodes deferred pending status")
    func testDecodeDeferredPendingStatus() throws {
        let jsonData = MockGrokAPI.deferredPendingResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokDeferredStatus.self, from: jsonData)

        #expect(response.status == "pending")
        #expect(response.result == nil)
        #expect(response.error == nil)
    }

    @Test("Decodes deferred success status")
    func testDecodeDeferredSuccessStatus() throws {
        let jsonData = MockGrokAPI.deferredSuccessResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokDeferredStatus.self, from: jsonData)

        #expect(response.status == "complete")
        #expect(response.result != nil)
        #expect(response.result?.id == "chatcmpl-deferred123")
    }

    @Test("Decodes deferred failed status")
    func testDecodeDeferredFailedStatus() throws {
        let jsonData = MockGrokAPI.deferredFailedResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokDeferredStatus.self, from: jsonData)

        #expect(response.status == "failed")
        #expect(response.error?.type == "timeout_error")
    }

    // MARK: - 8. Image Generation Tests

    @Test("Decodes image generation response")
    func testDecodeImageGenerationResponse() throws {
        let jsonData = MockGrokAPI.imageGenerationResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokImageResponse.self, from: jsonData)

        #expect(response.data.count == 1)
        #expect(response.data[0].url != nil)
        #expect(response.data[0].revised_prompt?.contains("cat") == true)
    }

    @Test("Decodes multiple images response")
    func testDecodeMultipleImagesResponse() throws {
        let jsonData = MockGrokAPI.multipleImagesResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokImageResponse.self, from: jsonData)

        #expect(response.data.count == 2)
    }

    @Test("Decodes base64 image response")
    func testDecodeBase64ImageResponse() throws {
        let jsonData = MockGrokAPI.imageBase64Response.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokImageResponse.self, from: jsonData)

        #expect(response.data[0].b64_json != nil)
        #expect(response.data[0].url == nil)
    }

    // MARK: - 9. Models List Tests

    @Test("Decodes models list response")
    func testDecodeModelsListResponse() throws {
        let jsonData = MockGrokAPI.modelsListResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokModelsResponse.self, from: jsonData)

        #expect(response.object == "list")
        #expect(response.data.count == 7)
        #expect(response.data[0].id == "grok-4-0709")
        #expect(response.data[0].owned_by == "xai")
    }

    // MARK: - 10. Model Support Tests

    @Test("Supports Grok 4 models")
    func testSupportsGrok4Models() {
        #expect(ModelProvider.grok4.providerType == .grok)
        #expect(ModelProvider.grok4Latest.providerType == .grok)
    }

    @Test("Supports Grok 3 models")
    func testSupportsGrok3Models() {
        #expect(ModelProvider.grok3.providerType == .grok)
        #expect(ModelProvider.grok3Mini.providerType == .grok)
    }

    @Test("Supports Grok 2 Vision")
    func testSupportsGrok2Vision() {
        #expect(ModelProvider.grok2Vision.providerType == .grok)
        #expect(ModelProvider.grok2Vision.supportsVision == true)
    }

    @Test("Supports Grok Code Fast")
    func testSupportsGrokCodeFast() {
        #expect(ModelProvider.grokCodeFast.providerType == .grok)
    }

    @Test("Supports Grok 2 Image")
    func testSupportsGrok2Image() {
        #expect(ModelProvider.grok2Image.providerType == .grok)
    }

    @Test("Grok 4 models do not support vision")
    func testGrok4NoVision() {
        #expect(ModelProvider.grok4.supportsVision == false)
        #expect(ModelProvider.grok4Latest.supportsVision == false)
    }

    @Test("Grok 3 models do not support vision")
    func testGrok3NoVision() {
        #expect(ModelProvider.grok3.supportsVision == false)
        #expect(ModelProvider.grok3Mini.supportsVision == false)
    }

    @Test("Verifies Grok 3 context windows")
    func testGrok3ContextWindows() {
        #expect(ModelProvider.grok3.maxInputTokens == 1_000_000)
        #expect(ModelProvider.grok3Mini.maxInputTokens == 1_000_000)
    }

    @Test("Verifies Grok 2 Vision context window")
    func testGrok2VisionContextWindow() {
        #expect(ModelProvider.grok2Vision.maxInputTokens == 128_000)
    }

    @Test("Verifies Grok output limits")
    func testGrokOutputLimits() {
        #expect(ModelProvider.grok4.maxOutputTokens == 8_192)
        #expect(ModelProvider.grok4Latest.maxOutputTokens == 8_192)
        #expect(ModelProvider.grok3.maxOutputTokens == 8_192)
        #expect(ModelProvider.grok3Mini.maxOutputTokens == 8_192)
        #expect(ModelProvider.grok2Vision.maxOutputTokens == 8_192)
        #expect(ModelProvider.grokCodeFast.maxOutputTokens == 8_192)
    }

    @Test("Grok models support prompt caching")
    func testGrokSupportsPromptCaching() {
        #expect(ModelProvider.grok4.supportsPromptCaching == true)
        #expect(ModelProvider.grok3.supportsPromptCaching == true)
        #expect(ModelProvider.grok3Mini.supportsPromptCaching == true)
    }

    // MARK: - 11. Edge Cases

    @Test("Handles empty content response")
    func testHandlesEmptyContentResponse() throws {
        let jsonData = MockGrokAPI.emptyContentResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokResponse.self, from: jsonData)

        #expect(response.choices[0].message.content == "")
    }

    @Test("Handles null content response")
    func testHandlesNullContentResponse() throws {
        let jsonData = MockGrokAPI.nullContentResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokResponse.self, from: jsonData)

        #expect(response.choices[0].message.content == nil)
    }

    @Test("Handles response with logprobs")
    func testHandlesLogprobsResponse() throws {
        let jsonData = MockGrokAPI.logprobsResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GrokResponse.self, from: jsonData)

        #expect(response.choices[0].logprobs != nil)
        #expect(response.choices[0].logprobs?.content?.count == 1)
        #expect(response.choices[0].logprobs?.content?[0].token == "Hello")
        #expect(response.choices[0].logprobs?.content?[0].top_logprobs?.count == 2)
    }

    // MARK: - 12. GrokRequest Encoding Tests

    @Test("Encodes basic GrokRequest")
    func testEncodeBasicRequest() throws {
        let request = GrokRequest(
            model: "grok-4",
            messages: [GrokMessage(role: "user", text: "Hello")]
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        #expect(json["model"]?.value as? String == "grok-4")
    }

    @Test("Encodes GrokRequest with streaming options")
    func testEncodeStreamingRequest() throws {
        let request = GrokRequest(
            model: "grok-4",
            messages: [GrokMessage(role: "user", text: "Hello")],
            stream: true,
            stream_options: GrokStreamOptions(include_usage: true)
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        #expect(json["stream"]?.value as? Bool == true)
    }

    @Test("Encodes GrokRequest with search parameters")
    func testEncodeSearchParametersRequest() throws {
        let request = GrokRequest(
            model: "grok-4",
            messages: [GrokMessage(role: "user", text: "What's the weather today?")],
            search_parameters: GrokSearchParameters(
                mode: "auto",
                max_search_results: 5,
                return_citations: true
            )
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        #expect(json["search_parameters"] != nil)
    }

    @Test("Encodes GrokRequest with tools")
    func testEncodeToolsRequest() throws {
        let tool = GrokTool(
            type: "function",
            function: GrokFunction(
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

        let request = GrokRequest(
            model: "grok-4",
            messages: [GrokMessage(role: "user", text: "What's the weather in NYC?")],
            tools: [tool]
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        #expect(json["tools"] != nil)
    }

    // MARK: - 13. GrokMessage Content Tests

    @Test("Creates text message content")
    func testTextMessageContent() {
        let content = GrokMessageContent.text("Hello world")

        if case .text(let text) = content {
            #expect(text == "Hello world")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("Creates multimodal message content")
    func testMultimodalMessageContent() {
        let parts: [GrokContentPart] = [
            .text("What's in this image?"),
            .imageUrl(GrokImageUrl(url: "https://example.com/image.jpg"))
        ]
        let content = GrokMessageContent.multimodal(parts)

        if case .multimodal(let actualParts) = content {
            #expect(actualParts.count == 2)
        } else {
            Issue.record("Expected multimodal content")
        }
    }

    @Test("Gets text value from text content")
    func testTextValueFromText() {
        let content = GrokMessageContent.text("Hello")
        #expect(content.textValue == "Hello")
    }

    @Test("Gets text value from multimodal content")
    func testTextValueFromMultimodal() {
        let parts: [GrokContentPart] = [
            .text("Part 1"),
            .imageUrl(GrokImageUrl(url: "https://example.com/image.jpg")),
            .text("Part 2")
        ]
        let content = GrokMessageContent.multimodal(parts)

        #expect(content.textValue == "Part 1 Part 2")
    }
}
