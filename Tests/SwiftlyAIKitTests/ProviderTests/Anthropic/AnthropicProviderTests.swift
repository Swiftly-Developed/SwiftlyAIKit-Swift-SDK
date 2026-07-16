import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for AnthropicProvider tool calling, prompt caching, extended thinking,
/// tool_use round-tripping, streaming accumulation, and web search.
@Suite("AnthropicProvider Parity Tests")
struct AnthropicProviderTests {
    // MARK: - Helpers

    private func makeProvider() -> AnthropicProvider { AnthropicProvider() }

    private func weatherTool() -> AITool {
        AITool(
            name: "get_weather",
            description: "Get the current weather for a location",
            parameters: AIToolParameters(
                properties: [
                    "location": AIToolProperty(type: "string", description: "City and state"),
                    "unit": AIToolProperty(type: "string", enumValues: ["celsius", "fahrenheit"])
                ],
                required: ["location"]
            )
        )
    }

    private func toolCalls(_ content: [AIMessageContent]) -> [AIToolCall] {
        content.compactMap { part in
            if case .toolCall(let call) = part { return call }
            return nil
        }
    }

    private func encodedJSON<T: Encodable>(_ value: T) throws -> String {
        String(data: try JSONEncoder().encode(value), encoding: .utf8) ?? ""
    }

    // MARK: - Tools wiring (item 1)

    @Test("Neutral tools are mapped into the Anthropic request")
    func testNeutralToolsWired() throws {
        let request = AIRequest(
            model: "claude-sonnet-4-5",
            messages: [AIMessage(role: .user, text: "Weather in SF?")],
            tools: [weatherTool()]
        )
        let mapped = try makeProvider().mapToAnthropicRequest(request)

        #expect(mapped.tools?.count == 1)
        #expect(mapped.tools?.first?.name == "get_weather")
        #expect(mapped.tools?.first?.inputSchema?.required == ["location"])

        let json = try encodedJSON(mapped)
        #expect(json.contains("input_schema"))
        #expect(json.contains("get_weather"))
    }

    @Test("Neutral tool choice maps to Anthropic tool_choice")
    func testToolChoiceMapping() throws {
        let provider = makeProvider()
        func choice(_ neutral: AIToolChoice) throws -> AnthropicToolChoice? {
            let request = AIRequest(
                model: "claude",
                messages: [AIMessage(role: .user, text: "hi")],
                tools: [weatherTool()],
                toolChoice: neutral
            )
            return try provider.mapToAnthropicRequest(request).toolChoice
        }
        #expect(try choice(.auto) == .auto)
        #expect(try choice(.required) == .any)
        #expect(try choice(.specific("get_weather")) == .tool("get_weather"))
    }

    @Test("Raw tools JSON pass-through takes precedence over neutral tools")
    func testRawToolsPassThrough() throws {
        let rawTools = """
        [{"name":"custom_tool","description":"d","input_schema":{"type":"object","properties":{}}}]
        """.data(using: .utf8)!
        let request = AIRequest(
            model: "claude",
            messages: [AIMessage(role: .user, text: "hi")],
            tools: [weatherTool()],
            rawToolsJSON: rawTools
        )
        let mapped = try makeProvider().mapToAnthropicRequest(request)
        #expect(mapped.tools?.count == 1)
        #expect(mapped.tools?.first?.name == "custom_tool")
    }

    // MARK: - tool_use round-trip (items 4, 5, 6)

    @Test("Non-streaming tool_use is parsed with decoded arguments and stopReason .toolUse")
    func testToolUseResponseParsing() throws {
        let data = MockAnthropicAPI.messageWithToolUse.data(using: .utf8)!
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let aiResponse = makeProvider().mapToAIResponse(response)

        #expect(aiResponse.stopReason == .toolUse)
        let calls = toolCalls(aiResponse.message.content)
        #expect(calls.count == 1)
        #expect(calls.first?.name == "get_weather")
        #expect(calls.first?.arguments.contains("San Francisco") == true)

        // Arguments must be valid JSON with real values, not an empty object.
        let argsData = calls.first!.arguments.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: argsData)
        #expect(decoded["location"]?.value as? String == "San Francisco, CA")
        #expect(decoded["unit"]?.value as? String == "fahrenheit")
    }

    @Test("Multi-turn tool round-trip survives encode/decode")
    func testMultiTurnToolRoundTrip() throws {
        let request = AIRequest(
            model: "claude",
            messages: [
                AIMessage(role: .user, text: "What's the weather in SF?"),
                AIMessage(role: .assistant, content: [
                    .toolCall(AIToolCall(id: "toolu_1", name: "get_weather", arguments: "{\"location\":\"SF\"}"))
                ]),
                AIMessage(role: .user, content: [
                    .toolResult(id: "toolu_1", result: "72F and sunny")
                ]),
                AIMessage(role: .assistant, text: "It's 72F and sunny in SF.")
            ]
        )

        let mapped = try makeProvider().mapToAnthropicRequest(request)
        // Round-trip through JSON to prove nothing is lost on the wire.
        let data = try JSONEncoder().encode(mapped)
        let decoded = try JSONDecoder().decode(AnthropicRequest.self, from: data)

        // Assistant tool_use preserves decoded arguments.
        guard case .toolUse(let id, let name, let input) = decoded.messages[1].content.first else {
            Issue.record("Expected tool_use block on assistant message")
            return
        }
        #expect(id == "toolu_1")
        #expect(name == "get_weather")
        #expect(input["location"]?.value as? String == "SF")

        // User tool_result is preserved.
        guard case .toolResult(let toolUseId, let content, _) = decoded.messages[2].content.first else {
            Issue.record("Expected tool_result block on user message")
            return
        }
        #expect(toolUseId == "toolu_1")
        #expect(content == "72F and sunny")
    }

    // MARK: - Extended thinking (item 3)

    @Test("Thinking config encodes to Anthropic wire format")
    func testThinkingWireFormat() throws {
        let enabled = AnthropicThinkingConfig(enabled: true, budgetTokens: 2000)
        let json = try encodedJSON(enabled)
        #expect(json.contains("\"type\":\"enabled\""))
        #expect(json.contains("\"budget_tokens\":2000"))

        let disabled = AnthropicThinkingConfig(enabled: false)
        let disabledJSON = try encodedJSON(disabled)
        #expect(disabledJSON.contains("\"type\":\"disabled\""))
        #expect(!disabledJSON.contains("budget_tokens"))
    }

    @Test("Extended thinking is enabled via providerOptions")
    func testThinkingEnabledViaOptions() throws {
        let boolRequest = AIRequest(
            model: "claude",
            messages: [AIMessage(role: .user, text: "think")],
            providerOptions: ["anthropic_thinking": AnyCodable(true)]
        )
        let boolMapped = try makeProvider().mapToAnthropicRequest(boolRequest)
        #expect(boolMapped.thinking?.enabled == true)
        #expect(boolMapped.thinking?.budgetTokens == 1024)

        let budgetRequest = AIRequest(
            model: "claude",
            messages: [AIMessage(role: .user, text: "think")],
            providerOptions: ["anthropic_thinking": AnyCodable(5000)]
        )
        let budgetMapped = try makeProvider().mapToAnthropicRequest(budgetRequest)
        #expect(budgetMapped.thinking?.enabled == true)
        #expect(budgetMapped.thinking?.budgetTokens == 5000)
    }

    @Test("Thinking blocks are surfaced on providerData, not in text")
    func testThinkingResponseParsing() throws {
        let data = MockAnthropicAPI.messageWithThinking.data(using: .utf8)!
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let aiResponse = makeProvider().mapToAIResponse(response)

        #expect(aiResponse.textContent == "Based on my analysis, the answer is 42.")
        let thinking = aiResponse.providerData?["thinking"]?.value as? String
        #expect(thinking?.contains("step by step") == true)
    }

    // MARK: - Prompt caching (item 2)

    @Test("System prompt caching via providerOptions")
    func testSystemCaching() throws {
        let request = AIRequest(
            model: "claude",
            messages: [AIMessage(role: .user, text: "hi")],
            systemPrompt: "You are a helpful assistant.",
            providerOptions: ["anthropic_cache": AnyCodable("system")]
        )
        let mapped = try makeProvider().mapToAnthropicRequest(request)

        guard case .blocks(let blocks) = mapped.system else {
            Issue.record("Expected system prompt as cache-controlled blocks")
            return
        }
        #expect(blocks.first?.cacheControl?.type == "ephemeral")
        #expect(try encodedJSON(mapped).contains("cache_control"))
    }

    @Test("Trailing message content caching via providerOptions")
    func testTrailingContentCaching() throws {
        let request = AIRequest(
            model: "claude",
            messages: [AIMessage(role: .user, text: "A very long document...")],
            providerOptions: ["anthropic_cache": AnyCodable("messages")]
        )
        let mapped = try makeProvider().mapToAnthropicRequest(request)

        guard case .textWithCacheControl = mapped.messages.last?.content.last else {
            Issue.record("Expected trailing content to carry cache_control")
            return
        }
        #expect(try encodedJSON(mapped).contains("cache_control"))
    }

    @Test("Tool definitions are cached when opted in")
    func testToolCaching() throws {
        let request = AIRequest(
            model: "claude",
            messages: [AIMessage(role: .user, text: "hi")],
            providerOptions: ["anthropic_cache": AnyCodable(true)],
            tools: [weatherTool()]
        )
        let mapped = try makeProvider().mapToAnthropicRequest(request)
        #expect(mapped.tools?.last?.cacheControl?.type == "ephemeral")
    }

    @Test("No cache_control emitted when option is absent")
    func testNoCacheByDefault() throws {
        let request = AIRequest(
            model: "claude",
            messages: [AIMessage(role: .user, text: "hi")],
            systemPrompt: "You are helpful.",
            tools: [weatherTool()]
        )
        let mapped = try makeProvider().mapToAnthropicRequest(request)
        #expect(!(try encodedJSON(mapped).contains("cache_control")))
    }

    // MARK: - Streaming tool accumulation (item 7)

    @Test("Streaming tool_use accumulates input_json_delta into complete arguments")
    func testStreamingToolAccumulation() throws {
        let provider = makeProvider()
        var accumulator = AnthropicProvider.ToolStreamAccumulator()
        var completed: [AIToolCall] = []

        for raw in MockAnthropicAPI.streamEventsWithToolUse {
            guard let event = try provider.parseSSEEvent(raw) else { continue }
            if let (_, call) = accumulator.handle(event) {
                completed.append(call)
            }
        }

        #expect(completed.count == 1)
        #expect(completed.first?.id == "toolu_01A09q90qw90lq917835lq9")
        #expect(completed.first?.name == "get_weather")
        #expect(completed.first?.arguments.contains("San Francisco") == true)

        // The assembled arguments are valid JSON.
        let argsData = completed.first!.arguments.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: argsData)
        #expect(decoded["location"]?.value as? String == "San Francisco, CA")
    }

    // MARK: - Web search (item 8)

    @Test("Web search tool is injected via providerOptions")
    func testWebSearchEnabled() throws {
        let request = AIRequest(
            model: "claude",
            messages: [AIMessage(role: .user, text: "latest swift news")],
            providerOptions: ["anthropic_web_search": AnyCodable(true)]
        )
        let mapped = try makeProvider().mapToAnthropicRequest(request)
        #expect(mapped.tools?.contains { $0.type == "web_search_20250305" } == true)
        #expect(try encodedJSON(mapped).contains("web_search_20250305"))
    }

    @Test("Web search results are surfaced on providerData")
    func testWebSearchResponseParsing() throws {
        let data = MockAnthropicAPI.messageWithWebSearch.data(using: .utf8)!
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let aiResponse = makeProvider().mapToAIResponse(response)

        #expect(aiResponse.textContent.contains("structured concurrency"))
        #expect(aiResponse.providerData?["webSearchToolResults"] != nil)
        #expect(aiResponse.providerData?["serverToolUse"] != nil)
    }

    // MARK: - Nested schema (Part C)

    @Test("Nested object tool schema survives Anthropic mapping")
    func testNestedSchemaMapping() throws {
        let tool = AITool(
            name: "create_contact",
            description: "Create a contact",
            parameters: AIToolParameters(
                properties: [
                    "contact": AIToolProperty(
                        type: "object",
                        description: "Contact details",
                        properties: [
                            "name": AIToolProperty(type: "string"),
                            "emails": AIToolProperty(
                                type: "array",
                                items: AIToolPropertyItems(
                                    type: "object",
                                    properties: ["address": AIToolProperty(type: "string")],
                                    required: ["address"]
                                )
                            )
                        ],
                        required: ["name"]
                    )
                ],
                required: ["contact"]
            )
        )
        let request = AIRequest(model: "claude", messages: [AIMessage(role: .user, text: "x")], tools: [tool])
        let json = try encodedJSON(try makeProvider().mapToAnthropicRequest(request))

        #expect(json.contains("contact"))
        #expect(json.contains("emails"))
        #expect(json.contains("address"))
    }
}
