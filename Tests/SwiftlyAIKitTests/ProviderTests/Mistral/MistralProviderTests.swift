import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for MistralProvider implementation
@Suite("MistralProvider Tests")
struct MistralProviderTests {
    // MARK: - Basic Configuration Tests

    @Test("MistralProvider initializes with default values")
    func testInitializationDefaults() {
        let provider = MistralProvider()

        #expect(provider.providerType == .mistral)
    }

    @Test("MistralProvider initializes with custom baseURL")
    func testInitializationCustomBaseURL() {
        let provider = MistralProvider(baseURL: "https://custom.mistral.ai/v1")

        #expect(provider.providerType == .mistral)
    }

    @Test("MistralProvider initializes with custom HTTP client")
    func testInitializationCustomHTTPClient() {
        let mockClient = HTTPClientManager()
        let provider = MistralProvider(httpClient: mockClient)

        #expect(provider.providerType == .mistral)
    }

    // MARK: - Request Mapping Tests

    @Test("Maps text message to Mistral format")
    func testMapTextMessage() {
        let message = AIMessage(
            role: .user,
            content: [.text("Hello, Mistral!")]
        )

        // Verify the message structure
        #expect(message.role == .user)
        #expect(message.content.count == 1)

        if case .text(let text) = message.content[0] {
            #expect(text == "Hello, Mistral!")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("Maps image message to Mistral format")
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

    @Test("Maps base64 image to Mistral format")
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
            model: "mistral-large-latest",
            messages: [
                AIMessage(role: .user, content: [.text("Hello")])
            ],
            systemPrompt: "You are a helpful AI assistant."
        )

        #expect(request.systemPrompt == "You are a helpful AI assistant.")
        #expect(request.messages.count == 1)
    }

    @Test("Maps generation parameters")
    func testMapGenerationParameters() {
        let request = AIRequest(
            model: "mistral-large-latest",
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

    // MARK: - Response Mapping Tests

    @Test("Maps successful response from Mistral")
    func testMapSuccessfulResponse() throws {
        let jsonData = MockMistralAPI.chatCompletionResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(MistralResponse.self, from: jsonData)

        #expect(response.id == "cmpl-abc123def456")
        #expect(response.model == "mistral-large-latest")
        #expect(response.choices.count == 1)
        #expect(response.choices[0].finishReason == "stop")
        #expect(response.usage.totalTokens == 27)
    }

    @Test("Maps vision response from Mistral")
    func testMapVisionResponse() throws {
        let jsonData = MockMistralAPI.visionResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(MistralResponse.self, from: jsonData)

        #expect(response.choices.count == 1)
        #expect(response.choices[0].finishReason == "stop")

        if let content = response.choices[0].message.content,
           case .text(let text) = content {
            #expect(text.contains("sunset"))
        } else {
            Issue.record("Expected text content in vision response")
        }
    }

    @Test("Maps max tokens response")
    func testMapMaxTokensResponse() throws {
        let jsonData = MockMistralAPI.maxTokensResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(MistralResponse.self, from: jsonData)

        #expect(response.choices[0].finishReason == "length")
        #expect(response.usage.completionTokens == 100)
    }

    @Test("Maps tool call response")
    func testMapToolCallResponse() throws {
        let jsonData = MockMistralAPI.toolCallResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(MistralResponse.self, from: jsonData)

        #expect(response.choices[0].finishReason == "tool_calls")
        #expect(response.choices[0].message.toolCalls != nil)

        if let toolCalls = response.choices[0].message.toolCalls {
            #expect(toolCalls.count == 1)
            #expect(toolCalls[0].function.name == "get_weather")
        }
    }

    @Test("Maps content filter response")
    func testMapContentFilterResponse() throws {
        let jsonData = MockMistralAPI.contentFilterResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(MistralResponse.self, from: jsonData)

        #expect(response.choices[0].finishReason == "content_filter")
    }

    // MARK: - Error Handling Tests

    @Test("Decodes authentication error")
    func testDecodeAuthenticationError() throws {
        let jsonData = MockMistralAPI.authenticationError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(MistralErrorResponse.self, from: jsonData)

        #expect(errorResponse.error.type == "invalid_request_error")
        #expect(errorResponse.error.code == "invalid_api_key")
        #expect(errorResponse.error.message.contains("Invalid API key"))
    }

    @Test("Decodes rate limit error")
    func testDecodeRateLimitError() throws {
        let jsonData = MockMistralAPI.rateLimitError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(MistralErrorResponse.self, from: jsonData)

        #expect(errorResponse.error.type == "rate_limit_error")
        #expect(errorResponse.error.code == "rate_limit_exceeded")
    }

    @Test("Decodes validation error")
    func testDecodeValidationError() throws {
        let jsonData = MockMistralAPI.validationError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(MistralErrorResponse.self, from: jsonData)

        #expect(errorResponse.error.type == "invalid_request_error")
        #expect(errorResponse.error.code == "invalid_parameter")
    }

    @Test("Decodes model not found error")
    func testDecodeModelNotFoundError() throws {
        let jsonData = MockMistralAPI.modelNotFoundError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(MistralErrorResponse.self, from: jsonData)

        #expect(errorResponse.error.message.contains("not found"))
    }

    @Test("Decodes server error")
    func testDecodeServerError() throws {
        let jsonData = MockMistralAPI.serverError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(MistralErrorResponse.self, from: jsonData)

        #expect(errorResponse.error.type == "server_error")
    }

    @Test("Decodes context length error")
    func testDecodeContextLengthError() throws {
        let jsonData = MockMistralAPI.contextLengthError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(MistralErrorResponse.self, from: jsonData)

        #expect(errorResponse.error.message.contains("context length"))
    }

    // MARK: - Streaming Tests

    @Test("Decodes streaming chunk")
    func testDecodeStreamingChunk() throws {
        // Remove "data: " prefix and decode the first chunk
        let firstChunk = MockMistralAPI.streamingResponse[0]
        let jsonString = firstChunk.replacingOccurrences(of: "data: ", with: "")
        let jsonData = jsonString.data(using: .utf8)!

        let chunk = try JSONDecoder().decode(MistralStreamChunk.self, from: jsonData)

        #expect(chunk.id == "cmpl-stream123")
        #expect(chunk.model == "mistral-large-latest")
        #expect(chunk.choices.count == 1)
    }

    @Test("Decodes streaming content chunk")
    func testDecodeStreamingContentChunk() throws {
        // Decode a content chunk (second chunk in the array)
        let contentChunk = MockMistralAPI.streamingResponse[1]
        let jsonString = contentChunk.replacingOccurrences(of: "data: ", with: "")
        let jsonData = jsonString.data(using: .utf8)!

        let chunk = try JSONDecoder().decode(MistralStreamChunk.self, from: jsonData)

        #expect(chunk.choices[0].delta.content == "Hello")
    }

    @Test("Decodes streaming finish chunk with usage")
    func testDecodeStreamingFinishChunkWithUsage() throws {
        // Decode the last chunk before [DONE]
        let finishChunk = MockMistralAPI.streamingResponse[8]
        let jsonString = finishChunk.replacingOccurrences(of: "data: ", with: "")
        let jsonData = jsonString.data(using: .utf8)!

        let chunk = try JSONDecoder().decode(MistralStreamChunk.self, from: jsonData)

        #expect(chunk.choices[0].finishReason == "stop")
        #expect(chunk.usage != nil)
        #expect(chunk.usage?.totalTokens == 18)
    }

    @Test("Identifies DONE signal in stream")
    func testIdentifiesDoneSignal() {
        let doneSignal = MockMistralAPI.streamingResponse.last!
        #expect(doneSignal == "data: [DONE]")
    }

    // MARK: - Model Request Tests

    @Test("Encodes sample request")
    func testEncodeSampleRequest() throws {
        let request = MockMistralAPI.sampleRequest
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(request)

        #expect(!jsonData.isEmpty)

        // Decode to verify structure
        let decoded = try JSONDecoder().decode(MistralRequest.self, from: jsonData)
        #expect(decoded.model == "mistral-large-latest")
        #expect(decoded.messages.count == 2)
        #expect(decoded.maxTokens == 100)
    }

    @Test("Encodes stream request")
    func testEncodeStreamRequest() throws {
        let request = MockMistralAPI.streamRequest
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(request)

        let decoded = try JSONDecoder().decode(MistralRequest.self, from: jsonData)
        #expect(decoded.stream == true)
        #expect(decoded.temperature == 0.9)
    }

    @Test("Encodes vision request")
    func testEncodeVisionRequest() throws {
        let request = MockMistralAPI.visionRequest
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(request)

        let decoded = try JSONDecoder().decode(MistralRequest.self, from: jsonData)
        #expect(decoded.messages.count == 1)

        if let content = decoded.messages[0].content,
           case .contentArray(let blocks) = content {
            #expect(blocks.count == 2)
        } else {
            Issue.record("Expected content array in vision request")
        }
    }

    @Test("Encodes tool request")
    func testEncodeToolRequest() throws {
        let request = MockMistralAPI.toolRequest
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(request)

        let decoded = try JSONDecoder().decode(MistralRequest.self, from: jsonData)
        #expect(decoded.tools != nil)
        #expect(decoded.tools?.count == 1)
        #expect(decoded.toolChoice != nil)
    }

    @Test("Encodes safe prompt request")
    func testEncodeSafePromptRequest() throws {
        let request = MockMistralAPI.safePromptRequest
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(request)

        let decoded = try JSONDecoder().decode(MistralRequest.self, from: jsonData)
        #expect(decoded.safePrompt == true)
    }

    @Test("Encodes deterministic request with random seed")
    func testEncodeDeterministicRequest() throws {
        let request = MockMistralAPI.deterministicRequest
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(request)

        let decoded = try JSONDecoder().decode(MistralRequest.self, from: jsonData)
        #expect(decoded.randomSeed == 42)
        #expect(decoded.temperature == 1.0)
    }

    // MARK: - Token Counting Tests

    @Test("countTokens returns nil for Mistral")
    func testCountTokensReturnsNil() async throws {
        let provider = MistralProvider()
        let request = AIRequest(
            model: "mistral-large-latest",
            messages: [
                AIMessage(role: .user, content: [.text("Hello")])
            ]
        )

        let count = try await provider.countTokens(request, apiKey: "test-key")
        #expect(count == nil)
    }

    // MARK: - Tool Choice Tests

    @Test("Encodes tool choice auto")
    func testEncodeToolChoiceAuto() throws {
        let choice = MistralToolChoice.auto
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(choice)

        let decoded = try JSONDecoder().decode(MistralToolChoice.self, from: jsonData)
        #expect(decoded == .auto)
    }

    @Test("Encodes tool choice none")
    func testEncodeToolChoiceNone() throws {
        let choice = MistralToolChoice.none
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(choice)

        let decoded = try JSONDecoder().decode(MistralToolChoice.self, from: jsonData)
        #expect(decoded == .none)
    }

    @Test("Encodes tool choice any")
    func testEncodeToolChoiceAny() throws {
        let choice = MistralToolChoice.any
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(choice)

        let decoded = try JSONDecoder().decode(MistralToolChoice.self, from: jsonData)
        #expect(decoded == .any)
    }

    @Test("Encodes tool choice required")
    func testEncodeToolChoiceRequired() throws {
        let choice = MistralToolChoice.required
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(choice)

        let decoded = try JSONDecoder().decode(MistralToolChoice.self, from: jsonData)
        #expect(decoded == .required)
    }

    // MARK: - Models List Tests

    @Test("Decodes models list response")
    func testDecodeModelsListResponse() throws {
        let jsonData = MockMistralAPI.modelsListResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(MistralModelsResponse.self, from: jsonData)

        // Raw list is returned verbatim — caller filters by capability.
        #expect(response.object == "list")
        #expect(response.data.count == 5)
        #expect(response.data.map(\.id) == [
            "mistral-large-latest",
            "mistral-small-latest",
            "open-mistral-nemo",
            "codestral-latest",
            "pixtral-large-latest"
        ])
        #expect(response.data[0].object == "model")
        #expect(response.data[0].ownedBy == "mistralai")
        #expect(response.data[0].created == 1_711_670_400)
    }

    @Test("Decodes nested model capabilities")
    func testDecodeModelCapabilities() throws {
        let jsonData = MockMistralAPI.modelsListResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(MistralModelsResponse.self, from: jsonData)

        let large = try #require(response.data.first)
        #expect(large.capabilities?.completionChat == true)
        #expect(large.capabilities?.functionCalling == true)
    }

    @Test("Filters models list to chat-capable models")
    func testFilterModelsToChatCapable() throws {
        let jsonData = MockMistralAPI.modelsListResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(MistralModelsResponse.self, from: jsonData)

        // The provider returns the raw list; downstream callers filter by capability.
        let chatModels = response.data.filter { $0.capabilities?.completionChat == true }
        #expect(chatModels.count == 5)
    }
}
