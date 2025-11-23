import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for AIMessage, AIRequest, AIResponse, and related types
@Suite("AI Models Tests")
struct AIModelsTests {
    // MARK: - AIMessageRole Tests

    @Test("AIMessageRole has all required cases")
    func testMessageRoles() {
        #expect(AIMessageRole.user.rawValue == "user")
        #expect(AIMessageRole.assistant.rawValue == "assistant")
        #expect(AIMessageRole.system.rawValue == "system")
    }

    @Test("AIMessageRole is Codable")
    func testMessageRoleCodable() throws {
        let role = AIMessageRole.user
        let data = try JSONEncoder().encode(role)
        let decoded = try JSONDecoder().decode(AIMessageRole.self, from: data)
        #expect(decoded == .user)
    }

    // MARK: - AIMessageContent Tests

    @Test("Text content can be created")
    func testTextContent() {
        let content = AIMessageContent.text("Hello, world!")
        if case .text(let text) = content {
            #expect(text == "Hello, world!")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("Image content with base64 can be created")
    func testImageContentBase64() {
        let content = AIMessageContent.image(
            source: .base64("iVBORw0KGgo..."),
            mediaType: "image/png"
        )
        if case .image(let source, let mediaType) = content {
            if case .base64(let data) = source {
                #expect(data == "iVBORw0KGgo...")
                #expect(mediaType == "image/png")
            } else {
                Issue.record("Expected base64 source")
            }
        } else {
            Issue.record("Expected image content")
        }
    }

    @Test("Image content with URL can be created")
    func testImageContentURL() {
        let content = AIMessageContent.image(
            source: .url("https://example.com/image.jpg"),
            mediaType: "image/jpeg"
        )
        if case .image(let source, let mediaType) = content {
            if case .url(let urlString) = source {
                #expect(urlString == "https://example.com/image.jpg")
                #expect(mediaType == "image/jpeg")
            } else {
                Issue.record("Expected URL source")
            }
        } else {
            Issue.record("Expected image content")
        }
    }

    @Test("Document content can be created")
    func testDocumentContent() {
        let data = Data("PDF content".utf8)
        let content = AIMessageContent.document(
            data: data,
            mediaType: "application/pdf",
            filename: "document.pdf"
        )
        if case .document(let docData, let mediaType, let filename) = content {
            #expect(docData == data)
            #expect(mediaType == "application/pdf")
            #expect(filename == "document.pdf")
        } else {
            Issue.record("Expected document content")
        }
    }

    @Test("Custom content can be created")
    func testCustomContent() {
        let customData: [String: AnyCodable] = [
            "type": AnyCodable("tool_use"),
            "id": AnyCodable("tool_123")
        ]
        let content = AIMessageContent.custom(data: customData)
        if case .custom(let data) = content {
            #expect(data.count == 2)
        } else {
            Issue.record("Expected custom content")
        }
    }

    @Test("AIMessageContent is Equatable")
    func testMessageContentEquatable() {
        let content1 = AIMessageContent.text("Hello")
        let content2 = AIMessageContent.text("Hello")
        let content3 = AIMessageContent.text("World")

        #expect(content1 == content2)
        #expect(content1 != content3)
    }

    // MARK: - AIMessage Tests

    @Test("AIMessage can be created with text convenience initializer")
    func testMessageTextInit() {
        let message = AIMessage(role: .user, text: "Hello, Claude!")

        #expect(message.role == .user)
        #expect(message.content.count == 1)
        if case .text(let text) = message.content[0] {
            #expect(text == "Hello, Claude!")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("AIMessage can be created with multiple content parts")
    func testMessageMultiContent() {
        let message = AIMessage(role: .user, content: [
            .text("What's in this image?"),
            .image(source: .url("https://example.com/photo.jpg"), mediaType: "image/jpeg"),
            .text("Please describe it.")
        ])

        #expect(message.role == .user)
        #expect(message.content.count == 3)
    }

    @Test("AIMessage textContent extracts all text")
    func testMessageTextContent() {
        let message = AIMessage(role: .assistant, content: [
            .text("Line 1"),
            .text("Line 2"),
            .text("Line 3")
        ])

        let extracted = message.textContent
        #expect(extracted == "Line 1\nLine 2\nLine 3")
    }

    @Test("AIMessage textContent skips non-text content")
    func testMessageTextContentMixed() {
        let message = AIMessage(role: .user, content: [
            .text("Before image"),
            .image(source: .url("https://example.com/img.jpg"), mediaType: nil),
            .text("After image")
        ])

        let extracted = message.textContent
        #expect(extracted == "Before image\nAfter image")
    }

    @Test("AIMessage textContent returns empty for no text")
    func testMessageTextContentEmpty() {
        let message = AIMessage(role: .user, content: [
            .image(source: .url("https://example.com/img.jpg"), mediaType: nil)
        ])

        let extracted = message.textContent
        #expect(extracted.isEmpty)
    }

    @Test("AIMessage with metadata")
    func testMessageMetadata() {
        let metadata = ["user_id": "123", "session": "abc"]
        let message = AIMessage(role: .user, text: "Hello", metadata: metadata)

        #expect(message.metadata?["user_id"] == "123")
        #expect(message.metadata?["session"] == "abc")
    }

    @Test("AIMessage is Equatable")
    func testMessageEquatable() {
        let message1 = AIMessage(role: .user, text: "Hello")
        let message2 = AIMessage(role: .user, text: "Hello")
        let message3 = AIMessage(role: .assistant, text: "Hello")

        #expect(message1 == message2)
        #expect(message1 != message3)
    }

    // MARK: - AIRequest Tests

    @Test("AIRequest can be created with minimal parameters")
    func testRequestMinimal() {
        let request = AIRequest(
            model: "claude-sonnet-4-20250514",
            messages: [
                AIMessage(role: .user, text: "Hello")
            ]
        )

        #expect(request.model == "claude-sonnet-4-20250514")
        #expect(request.messages.count == 1)
        #expect(request.stream == false)
        #expect(request.maxTokens == nil)
        #expect(request.temperature == nil)
    }

    @Test("AIRequest with all parameters")
    func testRequestFull() {
        let request = AIRequest(
            model: "claude-opus-4-20250514",
            messages: [AIMessage(role: .user, text: "Test")],
            maxTokens: 1000,
            systemPrompt: "You are a helpful assistant",
            temperature: 0.7,
            topP: 0.9,
            topK: 40,
            stopSequences: ["END", "STOP"],
            stream: true,
            metadata: ["request_id": "req-123"],
            providerOptions: ["custom": AnyCodable(true)]
        )

        #expect(request.maxTokens == 1000)
        #expect(request.systemPrompt == "You are a helpful assistant")
        #expect(request.temperature == 0.7)
        #expect(request.topP == 0.9)
        #expect(request.topK == 40)
        #expect(request.stopSequences?.count == 2)
        #expect(request.stream == true)
        #expect(request.metadata?["request_id"] == "req-123")
        #expect(request.providerOptions?.count == 1)
    }

    @Test("AIRequest with multi-turn conversation")
    func testRequestMultiTurn() {
        let request = AIRequest(
            model: "claude-sonnet-4-20250514",
            messages: [
                AIMessage(role: .user, text: "What is 2+2?"),
                AIMessage(role: .assistant, text: "4"),
                AIMessage(role: .user, text: "What about 3+3?")
            ]
        )

        #expect(request.messages.count == 3)
        #expect(request.messages[0].role == .user)
        #expect(request.messages[1].role == .assistant)
        #expect(request.messages[2].role == .user)
    }

    @Test("AIRequest is Codable")
    func testRequestCodable() throws {
        let original = AIRequest(
            model: "claude-sonnet-4-20250514",
            messages: [AIMessage(role: .user, text: "Test")],
            maxTokens: 100
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AIRequest.self, from: data)

        #expect(decoded.model == original.model)
        #expect(decoded.messages.count == original.messages.count)
        #expect(decoded.maxTokens == original.maxTokens)
    }

    // MARK: - AIStopReason Tests

    @Test("AIStopReason has all cases")
    func testStopReasons() {
        #expect(AIStopReason.endTurn.rawValue == "end_turn")
        #expect(AIStopReason.maxTokens.rawValue == "max_tokens")
        #expect(AIStopReason.stopSequence.rawValue == "stop_sequence")
        #expect(AIStopReason.toolUse.rawValue == "tool_use")
        #expect(AIStopReason.contentFilter.rawValue == "content_filter")
        #expect(AIStopReason.other.rawValue == "other")
    }

    @Test("AIStopReason is Codable")
    func testStopReasonCodable() throws {
        let reason = AIStopReason.endTurn
        let data = try JSONEncoder().encode(reason)
        let decoded = try JSONDecoder().decode(AIStopReason.self, from: data)
        #expect(decoded == .endTurn)
    }

    // MARK: - AIUsage Tests

    @Test("AIUsage calculates total tokens")
    func testUsageTotalTokens() {
        let usage = AIUsage(inputTokens: 100, outputTokens: 50)
        #expect(usage.totalTokens == 150)
    }

    @Test("AIUsage with cached tokens")
    func testUsageCachedTokens() {
        let usage = AIUsage(inputTokens: 100, outputTokens: 50, cachedTokens: 5000)
        #expect(usage.inputTokens == 100)
        #expect(usage.outputTokens == 50)
        #expect(usage.cachedTokens == 5000)
        #expect(usage.totalTokens == 150)
    }

    @Test("AIUsage is Codable")
    func testUsageCodable() throws {
        let original = AIUsage(inputTokens: 100, outputTokens: 50, cachedTokens: 1000)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AIUsage.self, from: data)

        #expect(decoded.inputTokens == 100)
        #expect(decoded.outputTokens == 50)
        #expect(decoded.cachedTokens == 1000)
    }

    // MARK: - AIResponse Tests

    @Test("AIResponse can be created")
    func testResponseCreation() {
        let response = AIResponse(
            id: "msg_123",
            model: "claude-sonnet-4-20250514",
            message: AIMessage(role: .assistant, text: "Hello!"),
            stopReason: .endTurn,
            usage: AIUsage(inputTokens: 10, outputTokens: 5),
            provider: .anthropic
        )

        #expect(response.id == "msg_123")
        #expect(response.model == "claude-sonnet-4-20250514")
        #expect(response.message.role == .assistant)
        #expect(response.stopReason == .endTurn)
        #expect(response.usage?.totalTokens == 15)
        #expect(response.provider == .anthropic)
    }

    @Test("AIResponse textContent convenience property")
    func testResponseTextContent() {
        let response = AIResponse(
            id: "msg_123",
            model: "claude-sonnet-4-20250514",
            message: AIMessage(role: .assistant, content: [
                .text("First part"),
                .text("Second part")
            ]),
            provider: .anthropic
        )

        #expect(response.textContent == "First part\nSecond part")
    }

    @Test("AIResponse with metadata and provider data")
    func testResponseMetadata() {
        let response = AIResponse(
            id: "msg_123",
            model: "claude-sonnet-4-20250514",
            message: AIMessage(role: .assistant, text: "Response"),
            provider: .anthropic,
            metadata: ["session": "abc"],
            providerData: ["request_id": AnyCodable("req-456")]
        )

        #expect(response.metadata?["session"] == "abc")
        #expect(response.providerData?.count == 1)
    }

    @Test("AIResponse is Codable")
    func testResponseCodable() throws {
        let original = AIResponse(
            id: "msg_123",
            model: "claude-sonnet-4-20250514",
            message: AIMessage(role: .assistant, text: "Hello"),
            stopReason: .endTurn,
            usage: AIUsage(inputTokens: 10, outputTokens: 5),
            provider: .anthropic
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AIResponse.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.model == original.model)
        #expect(decoded.provider == original.provider)
    }

    // MARK: - AnyCodable Tests

    @Test("AnyCodable wraps Int")
    func testAnyCodableInt() {
        let wrapped = AnyCodable(42)
        #expect(wrapped.value as? Int == 42)
    }

    @Test("AnyCodable wraps String")
    func testAnyCodableString() {
        let wrapped = AnyCodable("hello")
        #expect(wrapped.value as? String == "hello")
    }

    @Test("AnyCodable wraps Bool")
    func testAnyCodableBool() {
        let wrapped = AnyCodable(true)
        #expect(wrapped.value as? Bool == true)
    }

    @Test("AnyCodable wraps Double")
    func testAnyCodableDouble() {
        let wrapped = AnyCodable(3.14)
        #expect(wrapped.value as? Double == 3.14)
    }

    @Test("AnyCodable is Codable")
    func testAnyCodableCodable() throws {
        let original = AnyCodable("test")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded.value as? String == "test")
    }

    @Test("AnyCodable in dictionary is Codable")
    func testAnyCodableDictionary() throws {
        let dict: [String: AnyCodable] = [
            "string": AnyCodable("value"),
            "number": AnyCodable(42),
            "bool": AnyCodable(true)
        ]

        let data = try JSONEncoder().encode(dict)
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        #expect(decoded["string"]?.value as? String == "value")
        #expect(decoded["number"]?.value as? Int == 42)
        #expect(decoded["bool"]?.value as? Bool == true)
    }

    // MARK: - Integration Tests

    @Test("Complete request-response flow")
    func testRequestResponseFlow() {
        // Create request
        let request = AIRequest(
            model: "claude-sonnet-4-20250514",
            messages: [
                AIMessage(role: .user, text: "What is AI?")
            ],
            maxTokens: 1000,
            temperature: 0.7
        )

        // Simulate response
        let response = AIResponse(
            id: "msg_response_123",
            model: request.model,
            message: AIMessage(role: .assistant, text: "AI stands for Artificial Intelligence..."),
            stopReason: .endTurn,
            usage: AIUsage(inputTokens: 15, outputTokens: 50),
            provider: .anthropic
        )

        #expect(response.model == request.model)
        #expect(response.message.role == .assistant)
        #expect(!response.textContent.isEmpty)
    }

    @Test("Vision request with image")
    func testVisionRequest() {
        let request = AIRequest(
            model: "claude-sonnet-4-20250514",
            messages: [
                AIMessage(role: .user, content: [
                    .text("What's in this image?"),
                    .image(source: .url("https://example.com/photo.jpg"), mediaType: "image/jpeg")
                ])
            ]
        )

        #expect(request.messages[0].content.count == 2)
        let hasText = request.messages[0].content.contains { content in
            if case .text = content { return true }
            return false
        }
        let hasImage = request.messages[0].content.contains { content in
            if case .image = content { return true }
            return false
        }
        #expect(hasText)
        #expect(hasImage)
    }

    @Test("Streaming request configuration")
    func testStreamingRequest() {
        let request = AIRequest(
            model: "claude-sonnet-4-20250514",
            messages: [AIMessage(role: .user, text: "Tell me a story")],
            stream: true
        )

        #expect(request.stream == true)
    }

    @Test("Multi-message conversation")
    func testConversationHistory() {
        let messages = [
            AIMessage(role: .system, text: "You are a math tutor"),
            AIMessage(role: .user, text: "What is 2+2?"),
            AIMessage(role: .assistant, text: "2+2 equals 4"),
            AIMessage(role: .user, text: "What about 5+5?")
        ]

        let request = AIRequest(
            model: "claude-sonnet-4-20250514",
            messages: messages
        )

        #expect(request.messages.count == 4)
        #expect(request.messages[0].role == .system)
        #expect(request.messages[1].role == .user)
        #expect(request.messages[2].role == .assistant)
        #expect(request.messages[3].role == .user)
    }
}
