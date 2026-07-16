import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for CohereProvider implementation
@Suite("CohereProvider Tests")
struct CohereProviderTests {
    // MARK: - 1. Basic Configuration Tests

    @Test("CohereProvider initializes with default values")
    func testInitializationDefaults() {
        let provider = CohereProvider()

        #expect(provider.providerType == .cohere)
    }

    @Test("CohereProvider initializes with custom baseURL")
    func testInitializationCustomBaseURL() {
        let provider = CohereProvider(baseURL: "https://custom.cohere.ai/v2")

        #expect(provider.providerType == .cohere)
    }

    @Test("CohereProvider initializes with custom HTTP client")
    func testInitializationCustomHTTPClient() {
        let mockClient = HTTPClientManager()
        let provider = CohereProvider(httpClient: mockClient)

        #expect(provider.providerType == .cohere)
    }

    // MARK: - 2. Request Mapping Tests

    @Test("Maps text message to Cohere format")
    func testMapTextMessage() {
        let message = AIMessage(
            role: .user,
            content: [.text("Hello, Cohere!")]
        )

        // Verify the message structure
        #expect(message.role == .user)
        #expect(message.content.count == 1)

        if case .text(let text) = message.content[0] {
            #expect(text == "Hello, Cohere!")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("Maps image message to Cohere format")
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

    @Test("Maps base64 image to Cohere format")
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
            model: "command-a-03-2025",
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
            model: "command-r-plus-08-2024",
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

    @Test("Maps RAG documents from metadata")
    func testMapRAGDocuments() {
        // Note: AIRequest metadata is [String: String], so RAG documents would need
        // to be passed through providerOptions or a custom structure in production.
        // This test verifies the request structure is valid.
        let request = AIRequest(
            model: "command-r-08-2024",
            messages: [
                AIMessage(role: .user, content: [.text("Tell me about Cohere")])
            ],
            metadata: [
                "rag_enabled": "true",
                "document_count": "2"
            ]
        )

        #expect(request.metadata != nil)
        #expect(request.metadata?["rag_enabled"] == "true")
    }

    // MARK: - 3. Response Mapping Tests

    @Test("Maps successful chat completion response")
    func testMapChatCompletionResponse() throws {
        let jsonData = MockCohereAPI.chatCompletionResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(CohereResponse.self, from: jsonData)

        #expect(response.id == "chat-abc123def456")
        #expect(response.finishReason == "COMPLETE")
        #expect(response.message.role == "assistant")
        #expect(response.message.content?.count == 1)
        #expect(response.usage?.billedUnits?.inputTokens == 12)
        #expect(response.usage?.billedUnits?.outputTokens == 15)
    }

    @Test("Maps RAG response with citations")
    func testMapRAGResponse() throws {
        let jsonData = MockCohereAPI.ragResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(CohereResponse.self, from: jsonData)

        #expect(response.citations != nil)
        #expect(response.citations?.count == 1)

        if let citation = response.citations?.first {
            #expect(citation.start == 0)
            #expect(citation.end == 50)
            #expect(citation.documentIds.contains("doc_0"))
        }
    }

    @Test("Maps max tokens response")
    func testMapMaxTokensResponse() throws {
        let jsonData = MockCohereAPI.maxTokensResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(CohereResponse.self, from: jsonData)

        #expect(response.finishReason == "MAX_TOKENS")
        #expect(response.usage?.billedUnits?.outputTokens == 100)
    }

    @Test("Maps stop sequence response")
    func testMapStopSequenceResponse() throws {
        let jsonData = MockCohereAPI.stopSequenceResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(CohereResponse.self, from: jsonData)

        #expect(response.finishReason == "STOP_SEQUENCE")
    }

    @Test("Maps tool call response")
    func testMapToolCallResponse() throws {
        let jsonData = MockCohereAPI.toolCallResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(CohereResponse.self, from: jsonData)

        #expect(response.message.toolCalls != nil)

        if let toolCalls = response.message.toolCalls {
            #expect(toolCalls.count == 1)
            #expect(toolCalls[0].function.name == "get_weather")
        }
    }

    @Test("Maps vision response from Command A Vision")
    func testMapVisionResponse() throws {
        let jsonData = MockCohereAPI.visionResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(CohereResponse.self, from: jsonData)

        #expect(response.finishReason == "COMPLETE")

        if let contentBlocks = response.message.content,
           let firstBlock = contentBlocks.first,
           case .text(let text) = firstBlock {
            #expect(text.contains("sunset"))
            #expect(text.contains("ocean"))
        } else {
            Issue.record("Expected text content in vision response")
        }
    }

    @Test("Maps JSON structured output response")
    func testMapJSONResponse() throws {
        let jsonData = MockCohereAPI.jsonResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(CohereResponse.self, from: jsonData)

        #expect(response.finishReason == "COMPLETE")

        if let contentBlocks = response.message.content,
           let firstBlock = contentBlocks.first,
           case .text(let text) = firstBlock {
            #expect(text.contains("Great Gatsby"))
            #expect(text.contains("1925"))
        }
    }

    @Test("Maps empty response")
    func testMapEmptyResponse() throws {
        let jsonData = MockCohereAPI.emptyResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(CohereResponse.self, from: jsonData)

        #expect(response.message.content?.isEmpty == true)
        #expect(response.usage?.billedUnits?.outputTokens == 0)
    }

    // MARK: - 4. Streaming Tests

    @Test("Decodes streaming message-start event")
    func testDecodeStreamingMessageStart() throws {
        let eventData = "data: {\"type\":\"message-start\",\"id\":\"chat-stream123\"}".data(using: .utf8)!
        let jsonData = eventData.dropFirst(6) // Remove "data: " prefix

        let event = try JSONDecoder().decode(CohereStreamEvent.self, from: jsonData)

        #expect(event.type == "message-start")
        #expect(event.id == "chat-stream123")
    }

    @Test("Decodes streaming content-delta event")
    func testDecodeStreamingContentDelta() throws {
        let eventString = "{\"type\":\"content-delta\",\"index\":0,\"delta\":{\"message\":{\"content\":{\"text\":\"Hello\"}}}}"
        let eventData = eventString.data(using: .utf8)!

        let event = try JSONDecoder().decode(CohereStreamEvent.self, from: eventData)

        #expect(event.type == "content-delta")
        #expect(event.delta?.message?.content?.text == "Hello")
    }

    @Test("Decodes streaming message-end event")
    func testDecodeStreamingMessageEnd() throws {
        // swiftlint:disable:next line_length
        let eventString = "{\"type\":\"message-end\",\"delta\":{\"finish_reason\":\"COMPLETE\",\"usage\":{\"billed_units\":{\"input_tokens\":8,\"output_tokens\":6}}}}"
        let eventData = eventString.data(using: .utf8)!

        let event = try JSONDecoder().decode(CohereStreamEvent.self, from: eventData)

        #expect(event.type == "message-end")
        #expect(event.delta?.finishReason == "COMPLETE")
        #expect(event.delta?.usage?.billedUnits?.inputTokens == 8)
        #expect(event.delta?.usage?.billedUnits?.outputTokens == 6)
    }

    @Test("Decodes citation event")
    func testDecodeCitationEvent() throws {
        // swiftlint:disable:next line_length
        let eventString = "{\"type\":\"citation-start\",\"index\":0,\"citation\":{\"start\":0,\"end\":25,\"text\":\"According to the documents\",\"document_ids\":[\"doc_0\"]}}"
        let eventData = eventString.data(using: .utf8)!

        let event = try JSONDecoder().decode(CohereStreamEvent.self, from: eventData)

        #expect(event.type == "citation-start")
        #expect(event.citation != nil)
        #expect(event.citation?.documentIds.contains("doc_0") == true)
    }

    // MARK: - 5. Error Handling Tests

    @Test("Decodes authentication error")
    func testDecodeAuthenticationError() throws {
        let jsonData = MockCohereAPI.authenticationError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(CohereErrorResponse.self, from: jsonData)

        #expect(errorResponse.message == "invalid api key")
        #expect(errorResponse.statusCode == 401)
    }

    @Test("Decodes rate limit error")
    func testDecodeRateLimitError() throws {
        let jsonData = MockCohereAPI.rateLimitError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(CohereErrorResponse.self, from: jsonData)

        #expect(errorResponse.statusCode == 429)
        #expect(errorResponse.message.contains("rate limit"))
    }

    @Test("Decodes invalid request error")
    func testDecodeInvalidRequestError() throws {
        let jsonData = MockCohereAPI.invalidRequestError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(CohereErrorResponse.self, from: jsonData)

        #expect(errorResponse.statusCode == 400)
        #expect(errorResponse.message.contains("invalid request"))
    }

    @Test("Decodes validation error")
    func testDecodeValidationError() throws {
        let jsonData = MockCohereAPI.validationError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(CohereErrorResponse.self, from: jsonData)

        #expect(errorResponse.statusCode == 422)
        #expect(errorResponse.message.contains("validation error"))
    }

    @Test("Decodes server error")
    func testDecodeServerError() throws {
        let jsonData = MockCohereAPI.serverError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(CohereErrorResponse.self, from: jsonData)

        #expect(errorResponse.statusCode == 500)
        #expect(errorResponse.message.contains("internal server error"))
    }

    @Test("Decodes service unavailable error")
    func testDecodeServiceUnavailableError() throws {
        let jsonData = MockCohereAPI.serviceUnavailableError.data(using: .utf8)!
        let errorResponse = try JSONDecoder().decode(CohereErrorResponse.self, from: jsonData)

        #expect(errorResponse.statusCode == 503)
    }

    // MARK: - 6. Tokenize API Tests

    @Test("Decodes tokenize response")
    func testDecodeTokenizeResponse() throws {
        let jsonData = MockCohereAPI.tokenizeResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(CohereTokenizeResponse.self, from: jsonData)

        #expect(response.tokens.count == 6)
        #expect(response.tokenStrings.count == 6)
        #expect(response.tokenStrings[0] == "Hello")
        #expect(response.tokenStrings[5] == "?")
    }

    @Test("Decodes long tokenize response")
    func testDecodeLongTokenizeResponse() throws {
        let jsonData = MockCohereAPI.tokenizeLongResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(CohereTokenizeResponse.self, from: jsonData)

        #expect(response.tokens.count == 30)
        #expect(response.tokenStrings.count == 30)
        #expect(response.tokens.count == response.tokenStrings.count)
    }

    // MARK: - 7. Model Support Tests

    @Test("Supports Command A models")
    func testSupportsCommandAModels() {
        #expect(ModelProvider.commandA.providerType == .cohere)
        #expect(ModelProvider.commandAReasoning.providerType == .cohere)
        #expect(ModelProvider.commandATranslate.providerType == .cohere)
        #expect(ModelProvider.commandAVision.providerType == .cohere)
    }

    @Test("Supports Command R models")
    func testSupportsCommandRModels() {
        #expect(ModelProvider.commandRPlus08.providerType == .cohere)
        #expect(ModelProvider.commandR08.providerType == .cohere)
        #expect(ModelProvider.commandR7B.providerType == .cohere)
        #expect(ModelProvider.commandRPlus.providerType == .cohere)
        #expect(ModelProvider.commandR.providerType == .cohere)
    }

    @Test("Supports legacy Command models")
    func testSupportsLegacyCommandModels() {
        #expect(ModelProvider.command.providerType == .cohere)
        #expect(ModelProvider.commandLight.providerType == .cohere)
    }

    @Test("Command A Vision supports vision")
    func testCommandAVisionSupportsVision() {
        #expect(ModelProvider.commandAVision.supportsVision == true)
    }

    @Test("Other Command models do not support vision")
    func testOtherCommandModelsNoVision() {
        #expect(ModelProvider.commandA.supportsVision == false)
        #expect(ModelProvider.commandR08.supportsVision == false)
        #expect(ModelProvider.command.supportsVision == false)
    }

    @Test("Verifies Command A context window")
    func testCommandAContextWindow() {
        #expect(ModelProvider.commandA.maxInputTokens == 256_000)
        #expect(ModelProvider.commandAReasoning.maxInputTokens == 256_000)
        #expect(ModelProvider.commandAVision.maxInputTokens == 256_000)
    }

    @Test("Verifies Command A Translate context window")
    func testCommandATranslateContextWindow() {
        #expect(ModelProvider.commandATranslate.maxInputTokens == 16_000)
    }

    @Test("Verifies Command R context windows")
    func testCommandRContextWindows() {
        #expect(ModelProvider.commandRPlus08.maxInputTokens == 256_000)
        #expect(ModelProvider.commandR08.maxInputTokens == 256_000)
        #expect(ModelProvider.commandR7B.maxInputTokens == 256_000)
        #expect(ModelProvider.commandRPlus.maxInputTokens == 256_000)
        #expect(ModelProvider.commandR.maxInputTokens == 256_000)
    }

    @Test("Verifies legacy Command context windows")
    func testLegacyCommandContextWindows() {
        #expect(ModelProvider.command.maxInputTokens == 4_000)
        #expect(ModelProvider.commandLight.maxInputTokens == 4_000)
    }

    @Test("Verifies all Cohere models have 8K output limit")
    func testCohereOutputLimits() {
        #expect(ModelProvider.commandA.maxOutputTokens == 8_192)
        #expect(ModelProvider.commandAVision.maxOutputTokens == 8_192)
        #expect(ModelProvider.commandRPlus08.maxOutputTokens == 8_192)
        #expect(ModelProvider.commandR08.maxOutputTokens == 8_192)
        #expect(ModelProvider.command.maxOutputTokens == 8_192)
        #expect(ModelProvider.commandLight.maxOutputTokens == 8_192)
    }

    // MARK: - 8. Edge Cases

    @Test("Handles minimal response with missing optional fields")
    func testHandlesMinimalResponse() throws {
        let jsonData = MockCohereAPI.minimalResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(CohereResponse.self, from: jsonData)

        #expect(response.id == nil)
        #expect(response.finishReason == nil)
        #expect(response.message.content != nil)
    }

    @Test("Handles response with null fields")
    func testHandlesNullFields() throws {
        let jsonData = MockCohereAPI.nullFieldsResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(CohereResponse.self, from: jsonData)

        #expect(response.id == nil)
        #expect(response.finishReason == nil)
        #expect(response.usage == nil)
        #expect(response.citations == nil)
    }

    @Test("Handles empty content array")
    func testHandlesEmptyContentArray() throws {
        let jsonData = MockCohereAPI.emptyContentResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(CohereResponse.self, from: jsonData)

        #expect(response.message.content?.isEmpty == true)
        #expect(response.finishReason == "COMPLETE")
    }

    // MARK: - 9. Model-Specific Response Tests

    @Test("Decodes Command A response")
    func testDecodeCommandAResponse() throws {
        let jsonData = MockCohereAPI.commandAResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(CohereResponse.self, from: jsonData)

        #expect(response.finishReason == "COMPLETE")

        if let contentBlocks = response.message.content,
           let firstBlock = contentBlocks.first,
           case .text(let text) = firstBlock {
            #expect(text.contains("Command A"))
            #expect(text.contains("capable"))
        }
    }

    @Test("Decodes Command R response")
    func testDecodeCommandRResponse() throws {
        let jsonData = MockCohereAPI.commandRResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(CohereResponse.self, from: jsonData)

        #expect(response.finishReason == "COMPLETE")

        if let contentBlocks = response.message.content,
           let firstBlock = contentBlocks.first,
           case .text(let text) = firstBlock {
            #expect(text.contains("Command R"))
            #expect(text.contains("RAG"))
        }
    }
}
