import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for OllamaProvider implementation
@Suite("OllamaProvider Tests")
struct OllamaProviderTests {
    // MARK: - 1. Basic Configuration Tests

    @Test("OllamaProvider initializes with default base URL")
    func testInitializationDefaults() {
        let provider = OllamaProvider()

        #expect(provider.providerType == .ollama)
        #expect(provider.baseURL == "http://localhost:11434")
        #expect(provider.chatURL == "http://localhost:11434/api/chat")
        #expect(provider.tagsURL == "http://localhost:11434/api/tags")
    }

    @Test("OllamaProvider honors a custom base URL for chat and tags endpoints")
    func testInitializationCustomBaseURL() {
        let provider = OllamaProvider(baseURL: "http://192.168.1.50:11434")

        #expect(provider.baseURL == "http://192.168.1.50:11434")
        #expect(provider.chatURL == "http://192.168.1.50:11434/api/chat")
        #expect(provider.tagsURL == "http://192.168.1.50:11434/api/tags")
    }

    @Test("OllamaProvider initializes with custom HTTP client")
    func testInitializationCustomHTTPClient() {
        let mockClient = HTTPClientManager()
        let provider = OllamaProvider(httpClient: mockClient)

        #expect(provider.providerType == .ollama)
    }

    // MARK: - 2. Header Tests

    @Test("buildHeaders returns only Content-Type and NO Authorization")
    func testBuildHeadersNoAuth() {
        let headers = OllamaProvider().buildHeaders()

        #expect(headers.count == 1)
        #expect(headers.first?.0 == "Content-Type")
        #expect(headers.first?.1 == "application/json")
        #expect(!headers.contains { $0.0.lowercased() == "authorization" })
    }

    // MARK: - 3. Request Mapping Tests

    @Test("Maps text message and system prompt into the Ollama request")
    func testBuildRequestTextAndSystem() {
        let request = AIRequest(
            model: "llama3.2:latest",
            messages: [AIMessage(role: .user, content: [.text("Hello, Ollama!")])],
            systemPrompt: "You are a helpful assistant."
        )

        let mapped = OllamaProvider().buildOllamaRequest(from: request, stream: false)

        #expect(mapped.model == "llama3.2:latest")
        #expect(mapped.stream == false)
        #expect(mapped.messages.count == 2)
        #expect(mapped.messages[0].role == "system")
        #expect(mapped.messages[0].content == "You are a helpful assistant.")
        #expect(mapped.messages[1].role == "user")
        #expect(mapped.messages[1].content == "Hello, Ollama!")
    }

    @Test("Maps generation parameters under options (num_predict from maxTokens)")
    func testBuildRequestGenerationOptions() {
        let request = AIRequest(
            model: "llama3.2:latest",
            messages: [AIMessage(role: .user, content: [.text("Hello")])],
            maxTokens: 1024,
            temperature: 0.7,
            topP: 0.9,
            topK: 40,
            stopSequences: ["STOP", "END"]
        )

        let mapped = OllamaProvider().buildOllamaRequest(from: request, stream: false)

        #expect(mapped.options?.numPredict == 1024)
        #expect(mapped.options?.temperature == 0.7)
        #expect(mapped.options?.topP == 0.9)
        #expect(mapped.options?.topK == 40)
        #expect(mapped.options?.stop == ["STOP", "END"])
    }

    @Test("Streaming build sets the stream flag")
    func testBuildRequestStreamingFlag() {
        let request = AIRequest(
            model: "llama3.2:latest",
            messages: [AIMessage(role: .user, content: [.text("Hello")])]
        )

        let mapped = OllamaProvider().buildOllamaRequest(from: request, stream: true)

        #expect(mapped.stream == true)
    }

    @Test("Tools are wired into the request when request.tools present")
    func testBuildRequestToolsWired() {
        let tool = AITool(
            name: "get_weather",
            description: "Get the current weather",
            parameters: AIToolParameters(
                properties: ["location": AIToolProperty(type: "string", description: "City")],
                required: ["location"]
            )
        )
        let request = AIRequest(
            model: "llama3.2:latest",
            messages: [AIMessage(role: .user, text: "weather?")],
            tools: [tool]
        )

        let mapped = OllamaProvider().buildOllamaRequest(from: request, stream: false)

        #expect(mapped.tools?.count == 1)
        #expect(mapped.tools?.first?.type == "function")
        #expect(mapped.tools?.first?.function.name == "get_weather")
    }

    @Test("Tools are omitted when tool choice is .none")
    func testBuildRequestToolsOmittedWhenNone() {
        let tool = AITool(
            name: "get_weather",
            description: "Get the current weather",
            parameters: AIToolParameters(
                properties: ["location": AIToolProperty(type: "string", description: "City")],
                required: ["location"]
            )
        )
        let request = AIRequest(
            model: "llama3.2:latest",
            messages: [AIMessage(role: .user, text: "weather?")],
            tools: [tool],
            toolChoice: AIToolChoice.none
        )

        let mapped = OllamaProvider().buildOllamaRequest(from: request, stream: false)

        #expect(mapped.tools == nil)
    }

    @Test("Multimodal message carries base64 images")
    func testBuildRequestVision() {
        let request = AIRequest(
            model: "llava:latest",
            messages: [AIMessage(role: .user, content: [
                .text("What's in this image?"),
                .image(source: .base64("aGVsbG8="), mediaType: "image/jpeg")
            ])]
        )

        let mapped = OllamaProvider().buildOllamaRequest(from: request, stream: false)

        #expect(mapped.messages.count == 1)
        #expect(mapped.messages[0].content == "What's in this image?")
        #expect(mapped.messages[0].images == ["aGVsbG8="])
    }

    // MARK: - 4. Response Mapping Tests

    @Test("transformToAIResponse maps text content, usage, and .endTurn stop reason")
    func testTransformTextResponse() throws {
        let response = try JSONDecoder().decode(
            OllamaChatResponse.self,
            from: MockOllamaAPI.responseAsData(MockOllamaAPI.chatResponse)
        )

        let aiResponse = OllamaProvider().transformToAIResponse(response, model: "llama3.2:latest")

        #expect(aiResponse.provider == .ollama)
        #expect(aiResponse.model == "llama3.2:latest")
        #expect(aiResponse.stopReason == .endTurn)
        #expect(aiResponse.textContent.contains("Ollama"))
        #expect(aiResponse.usage?.inputTokens == 26)
        #expect(aiResponse.usage?.outputTokens == 12)
    }

    @Test("transformToAIResponse maps done_reason length to .maxTokens")
    func testTransformMaxTokensResponse() throws {
        let response = try JSONDecoder().decode(
            OllamaChatResponse.self,
            from: MockOllamaAPI.responseAsData(MockOllamaAPI.maxTokensResponse)
        )

        let aiResponse = OllamaProvider().transformToAIResponse(response, model: "llama3.2:latest")

        #expect(aiResponse.stopReason == .maxTokens)
        #expect(aiResponse.usage?.outputTokens == 100)
    }

    @Test("transformToAIResponse maps a tool call, re-encoding arguments to a JSON string")
    func testTransformToolCallResponse() throws {
        let response = try JSONDecoder().decode(
            OllamaChatResponse.self,
            from: MockOllamaAPI.responseAsData(MockOllamaAPI.toolCallResponse)
        )

        let aiResponse = OllamaProvider().transformToAIResponse(response, model: "llama3.2:latest")

        #expect(aiResponse.stopReason == .toolUse)

        let call = aiResponse.message.content.compactMap { part -> AIToolCall? in
            if case .toolCall(let toolCall) = part { return toolCall }
            return nil
        }.first
        let unwrapped = try #require(call)
        #expect(unwrapped.name == "get_weather")

        // Arguments (a JSON object on the wire) are re-encoded to a JSON string.
        #expect(unwrapped.arguments.contains("San Francisco"))
        #expect(unwrapped.arguments.contains("fahrenheit"))
        // The re-encoded arguments are valid JSON that round-trips to a dictionary.
        let argsData = try #require(unwrapped.arguments.data(using: .utf8))
        let decoded = try JSONSerialization.jsonObject(with: argsData) as? [String: Any]
        #expect(decoded?["location"] as? String == "San Francisco, CA")
    }

    // MARK: - 5. Models List Tests

    @Test("Decodes /api/tags models list response")
    func testDecodeModelsListResponse() throws {
        let response = try JSONDecoder().decode(
            OllamaModelsResponse.self,
            from: MockOllamaAPI.responseAsData(MockOllamaAPI.modelsListResponse)
        )

        #expect(response.models.count == 3)
        #expect(response.models[0].name == "llama3.2:latest")
        #expect(response.models[0].details?.family == "llama")
        #expect(response.models[0].details?.parameterSize == "3.2B")
        #expect(response.models.contains { $0.name == "qwen2.5:latest" })
        #expect(response.models.contains { $0.name == "mistral:latest" })
    }

    // MARK: - 6. Error Handling Tests

    @Test("Decodes a bare Ollama error response")
    func testDecodeError() throws {
        let error = try JSONDecoder().decode(
            OllamaError.self,
            from: MockOllamaAPI.responseAsData(MockOllamaAPI.modelNotFoundError)
        )

        #expect(error.error.contains("not found"))
    }
}
