import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for `OpenRouterProvider`: configuration, request/tool mapping, response and
/// tool-call decoding, streaming tool-call accumulation, and dynamic `/models` decoding
/// (asserting namespaced `"vendor/model"` ids survive verbatim).
@Suite("OpenRouterProvider Tests")
struct OpenRouterProviderTests {
    private func weatherTool() -> AITool {
        AITool(
            name: "get_weather",
            description: "Get the current weather",
            parameters: AIToolParameters(
                properties: ["location": AIToolProperty(type: "string", description: "City")],
                required: ["location"]
            )
        )
    }

    // MARK: - 1. Configuration

    @Test("OpenRouterProvider initializes with default values")
    func testInitializationDefaults() {
        let provider = OpenRouterProvider()
        #expect(provider.providerType == .openRouter)
    }

    @Test("OpenRouterProvider initializes with attribution headers and custom client")
    func testInitializationWithAttribution() {
        let provider = OpenRouterProvider(
            httpClient: HTTPClientManager(),
            httpReferer: "https://myapp.example",
            xTitle: "My App"
        )
        #expect(provider.providerType == .openRouter)
    }

    @Test("Provider type resolves the expected token, display name, and base URL")
    func testProviderTypeMetadata() {
        #expect(ProviderType.openRouter.rawValue == "openrouter")
        #expect(ProviderType.openRouter.displayName == "OpenRouter")
        #expect(ProviderType.openRouter.baseURL == "https://openrouter.ai/api/v1")
    }

    @Test("Capabilities: tool-capable, no image generation")
    func testCapabilities() {
        #expect(ToolCapabilities.isSupported(by: .openRouter) == true)
        #expect(ImageGenerationCapabilities.isSupported(by: .openRouter) == false)
        #expect(ImageGenerationCapabilities.models(for: .openRouter).isEmpty)
        #expect(ImageGenerationCapabilities.defaultModel(for: .openRouter) == nil)
    }

    // MARK: - 2. Request mapping

    @Test("Maps text message, system prompt, and passes namespaced model verbatim")
    func testMapRequestTextAndSystem() throws {
        let request = AIRequest(
            model: "meta-llama/llama-3.3-70b-instruct",
            messages: [AIMessage(role: .user, content: [.text("Hello, OpenRouter!")])],
            systemPrompt: "You are a helpful assistant."
        )

        let mapped = try OpenRouterProvider().mapToOpenRouterRequest(request)

        // Namespaced id is passed through untransformed.
        #expect(mapped.model == "meta-llama/llama-3.3-70b-instruct")
        #expect(mapped.messages.count == 2)
        #expect(mapped.messages[0].role == .system)
        #expect(mapped.messages[1].role == .user)
    }

    @Test("Maps generation parameters into the OpenRouter request")
    func testMapRequestGenerationParameters() throws {
        let request = AIRequest(
            model: "openai/gpt-4o",
            messages: [AIMessage(role: .user, text: "Hello")],
            maxTokens: 1024,
            temperature: 0.7,
            topP: 0.9,
            stopSequences: ["STOP", "END"]
        )

        let mapped = try OpenRouterProvider().mapToOpenRouterRequest(request)

        #expect(mapped.maxTokens == 1024)
        #expect(mapped.temperature == 0.7)
        #expect(mapped.topP == 0.9)
        #expect(mapped.stop == ["STOP", "END"])
    }

    @Test("Tools and tool choice are wired into the OpenRouter request")
    func testToolsWired() throws {
        let request = AIRequest(
            model: "openai/gpt-4o",
            messages: [AIMessage(role: .user, text: "weather?")],
            tools: [weatherTool()],
            toolChoice: .auto
        )
        let mapped = try OpenRouterProvider().mapToOpenRouterRequest(request)
        #expect(mapped.tools?.count == 1)
        #expect(mapped.tools?.first?.function.name == "get_weather")
        #expect(mapped.toolChoice == .auto)
    }

    @Test("Multi-turn tool round-trip maps assistant tool_calls and tool results")
    func testMultiTurnRoundTrip() throws {
        let request = AIRequest(
            model: "anthropic/claude-3.5-sonnet",
            messages: [
                AIMessage(role: .user, text: "weather in SF?"),
                AIMessage(role: .assistant, content: [
                    .toolCall(AIToolCall(id: "call_1", name: "get_weather", arguments: "{\"location\":\"SF\"}"))
                ]),
                AIMessage(role: .user, content: [.toolResult(id: "call_1", result: "72F")])
            ],
            tools: [weatherTool()]
        )
        let mapped = try OpenRouterProvider().mapToOpenRouterRequest(request)

        // Round-trip through JSON.
        let decoded = try JSONDecoder().decode(OpenRouterRequest.self, from: JSONEncoder().encode(mapped))

        let assistant = decoded.messages.first { $0.role == .assistant }
        #expect(assistant?.toolCalls?.first?.id == "call_1")
        #expect(assistant?.toolCalls?.first?.function.name == "get_weather")

        let toolMessage = decoded.messages.first { $0.role == .tool }
        #expect(toolMessage?.toolCallId == "call_1")
    }

    @Test("Nested object tool schema is emitted for OpenRouter")
    func testNestedSchema() throws {
        let tool = AITool(
            name: "save",
            description: "save",
            parameters: AIToolParameters(properties: [
                "record": AIToolProperty(type: "object", properties: [
                    "tags": AIToolProperty(type: "array", items: AIToolPropertyItems(type: "string"))
                ], required: ["tags"])
            ])
        )
        let request = AIRequest(model: "openai/gpt-4o", messages: [AIMessage(role: .user, text: "x")], tools: [tool])
        let mapped = try OpenRouterProvider().mapToOpenRouterRequest(request)
        let json = String(data: try JSONEncoder().encode(mapped), encoding: .utf8) ?? ""
        #expect(json.contains("record"))
        #expect(json.contains("tags"))
    }

    // MARK: - 3. Response mapping

    @Test("Decodes a chat completion and maps text + usage to AIResponse")
    func testDecodeAndMapChatResponse() throws {
        let data = MockOpenRouterAPI.chatCompletionResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        let aiResponse = OpenRouterProvider().mapToAIResponse(response)

        #expect(aiResponse.provider == .openRouter)
        #expect(aiResponse.model == "anthropic/claude-3.5-sonnet")
        #expect(aiResponse.stopReason == .endTurn)
        #expect(aiResponse.textContent.contains("OpenRouter"))
        #expect(aiResponse.usage?.inputTokens == 12)
        #expect(aiResponse.usage?.outputTokens == 5)
    }

    @Test("Response tool calls are parsed and stopReason is .toolUse")
    func testResponseToolCallParsing() throws {
        let data = MockOpenRouterAPI.toolCallResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        let aiResponse = OpenRouterProvider().mapToAIResponse(response)

        #expect(aiResponse.stopReason == .toolUse)
        let call = aiResponse.message.content.compactMap { part -> AIToolCall? in
            if case .toolCall(let value) = part { return value }
            return nil
        }.first
        #expect(call?.id == "call_1")
        #expect(call?.name == "get_weather")
        #expect(call?.arguments.contains("SF") == true)
    }

    @Test("Decodes an OpenRouter error response")
    func testDecodeErrorResponse() throws {
        let data = MockOpenRouterAPI.authenticationError.data(using: .utf8)!
        let error = try JSONDecoder().decode(OpenRouterErrorResponse.self, from: data)
        #expect(error.error.code == 401)
        #expect(error.error.message.contains("auth"))
    }

    // MARK: - 4. Streaming accumulation

    @Test("Streaming tool-call deltas accumulate by index")
    func testStreamingAccumulation() {
        typealias DeltaToolCall = OpenRouterStreamChunk.StreamChoice.Delta.DeltaToolCall
        var accumulator: [Int: (id: String, name: String, args: String)] = [:]

        OpenRouterProvider.accumulate([
            DeltaToolCall(index: 0, id: "call_1", type: "function",
                          function: .init(name: "get_weather", arguments: "{\"loc"))
        ], into: &accumulator)
        OpenRouterProvider.accumulate([
            DeltaToolCall(index: 0, id: nil, type: nil,
                          function: .init(name: nil, arguments: "ation\":\"SF\"}"))
        ], into: &accumulator)

        #expect(accumulator[0]?.id == "call_1")
        #expect(accumulator[0]?.name == "get_weather")
        #expect(accumulator[0]?.args == "{\"location\":\"SF\"}")
    }

    @Test("Streaming chunk fixtures decode under OpenAI-compatible framing")
    func testStreamingChunkDecoding() throws {
        // The final content-bearing chunk assembles to the full text; the finish chunk
        // carries a delta-less "stop".
        var assembled = ""
        var finish: String?
        for event in MockOpenRouterAPI.streamingContentEvents where event != "data: [DONE]" {
            let json = String(event.dropFirst(6))
            let chunk = try JSONDecoder().decode(OpenRouterStreamChunk.self, from: Data(json.utf8))
            if let content = chunk.choices.first?.delta.content { assembled += content }
            if let reason = chunk.choices.first?.finishReason { finish = reason }
        }
        #expect(assembled == "Hello, world!")
        #expect(finish == "stop")
    }

    // MARK: - 5. Models list (live, dynamic catalog)

    @Test("Decodes multi-vendor models list; namespaced ids survive verbatim")
    func testDecodeModelsListResponse() throws {
        let data = MockOpenRouterAPI.modelsListResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data)

        #expect(response.data.count == 5)

        let ids = response.data.map(\.id)
        #expect(ids.contains("openai/gpt-4o"))
        #expect(ids.contains("anthropic/claude-3.5-sonnet"))
        #expect(ids.contains("google/gemini-2.0-flash"))
        #expect(ids.contains("meta-llama/llama-3.3-70b-instruct"))
        // The vendor/model namespacing (with the slash) is preserved untouched.
        #expect(ids.allSatisfy { $0.contains("/") })

        // Optional fields map through snake_case CodingKeys.
        let claude = try #require(response.data.first { $0.id == "anthropic/claude-3.5-sonnet" })
        #expect(claude.name == "Anthropic: Claude 3.5 Sonnet")
        #expect(claude.contextLength == 200000)
        #expect(claude.pricing?.prompt == "0.000003")
        #expect(claude.pricing?.completion == "0.000015")

        // An id-only entry decodes with nil optionals.
        let minimal = try #require(response.data.first { $0.id == "mistralai/mistral-large" })
        #expect(minimal.name == nil)
        #expect(minimal.contextLength == nil)
        #expect(minimal.pricing == nil)
    }
}
