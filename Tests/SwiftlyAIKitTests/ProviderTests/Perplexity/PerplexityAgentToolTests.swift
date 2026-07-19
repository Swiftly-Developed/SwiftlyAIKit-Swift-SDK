import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tool round-trip and function-calling tests for `PerplexityProvider`.
///
/// Perplexity's Sonar Chat Completions API has no function calling; the provider routes tool-bearing
/// requests to Perplexity's **Agent API** (`/v1/responses`, OpenAI *Responses*-API shape). These
/// tests cover the request mapping (tools/tool_choice + model routing + multi-turn replay), the
/// response parse (`function_call` → `.toolCall`), and streamed tool-call accumulation.
@Suite("PerplexityProvider Agent Tool Tests")
struct PerplexityAgentToolTests {
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

    /// Deterministic (sorted-key) JSON string for stable substring assertions.
    private func agentJSON(_ request: PerplexityAgentRequest) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(data: try encoder.encode(request), encoding: .utf8) ?? ""
    }

    private func decodeStreamEvents(_ lines: [String]) throws -> [PerplexityAgentStreamEvent] {
        try lines.compactMap { line in
            guard line.hasPrefix("data: ") else { return nil }
            let json = String(line.dropFirst(6))
            guard json != "[DONE]", let data = json.data(using: .utf8) else { return nil }
            return try JSONDecoder().decode(PerplexityAgentStreamEvent.self, from: data)
        }
    }

    // MARK: - Capability Flags

    @Test("PerplexityProvider now reports tool support")
    func testSupportsToolsIsTrue() {
        #expect(PerplexityProvider().supportsTools == true)
        #expect(ToolCapabilities.isSupported(by: .perplexity) == true)
        #expect(ToolCapabilities.isSupported(by: PerplexityProvider().providerType) == true)
    }

    // MARK: - Routing

    @Test("Requests carrying tools route to the Agent API")
    func testRequestUsesToolsForToolBearingRequest() {
        let request = AIRequest(
            model: "sonar",
            messages: [AIMessage(role: .user, text: "weather?")],
            tools: [weatherTool()]
        )
        #expect(PerplexityProvider().requestUsesTools(request) == true)
    }

    @Test("Tool-free requests stay on the Sonar path")
    func testRequestUsesToolsForPlainRequest() {
        let request = AIRequest(model: "sonar", messages: [AIMessage(role: .user, text: "hi")])
        #expect(PerplexityProvider().requestUsesTools(request) == false)
    }

    @Test("A follow-up carrying a tool result still routes to the Agent API")
    func testRequestUsesToolsForToolResultFollowUp() {
        let request = AIRequest(
            model: "sonar",
            messages: [AIMessage(role: .user, content: [.toolResult(id: "call_1", result: "72F")])]
        )
        #expect(PerplexityProvider().requestUsesTools(request) == true)
    }

    // MARK: - Model Resolution

    @Test("Plain Sonar model id is routed to the default Agent model")
    func testPlainSonarModelRoutesToAgentModel() {
        let request = AIRequest(model: "sonar", messages: [AIMessage(role: .user, text: "x")], tools: [weatherTool()])
        #expect(PerplexityProvider().resolveAgentModel(for: request) == PerplexityProvider.defaultAgentModel)
        #expect(PerplexityProvider().resolveAgentModel(for: request) == "openai/gpt-5.6-sol")
    }

    @Test("A provider/model id passes through unchanged")
    func testAgentModelIdPassesThrough() {
        let request = AIRequest(model: "perplexity/sonar", messages: [AIMessage(role: .user, text: "x")], tools: [weatherTool()])
        #expect(PerplexityProvider().resolveAgentModel(for: request) == "perplexity/sonar")
    }

    @Test("providerOptions[agent_model] overrides the model")
    func testAgentModelProviderOptionOverride() {
        let request = AIRequest(
            model: "sonar",
            messages: [AIMessage(role: .user, text: "x")],
            providerOptions: ["agent_model": AnyCodable("anthropic/claude-sonnet-5")],
            tools: [weatherTool()]
        )
        #expect(PerplexityProvider().resolveAgentModel(for: request) == "anthropic/claude-sonnet-5")
    }

    @Test("A custom agentModel on the provider is used for plain Sonar ids")
    func testCustomAgentModelInit() {
        let request = AIRequest(model: "sonar-pro", messages: [AIMessage(role: .user, text: "x")], tools: [weatherTool()])
        let provider = PerplexityProvider(agentModel: "google/gemini-3-flash-preview")
        #expect(provider.resolveAgentModel(for: request) == "google/gemini-3-flash-preview")
    }

    // MARK: - Request Wire Body

    @Test("Tools and tool choice are wired onto the Agent request body")
    func testToolsWiredIntoAgentRequest() throws {
        let request = AIRequest(
            model: "sonar",
            messages: [AIMessage(role: .user, text: "weather in SF?")],
            tools: [weatherTool()],
            toolChoice: .auto
        )
        let mapped = try PerplexityProvider().buildAgentRequest(from: request, stream: false)

        #expect(mapped.model == "openai/gpt-5.6-sol")
        #expect(mapped.tools?.first?.name == "get_weather")
        #expect(mapped.tools?.first?.type == "function")

        let json = try agentJSON(mapped)
        #expect(json.contains("\"tools\""))
        #expect(json.contains("\"type\":\"function\""))
        #expect(json.contains("\"name\":\"get_weather\""))
        #expect(json.contains("\"parameters\""))
        #expect(json.contains("location"))
        #expect(json.contains("\"tool_choice\":\"auto\""))
    }

    @Test("Required tool choice encodes as the required string")
    func testRequiredToolChoice() throws {
        let request = AIRequest(
            model: "sonar",
            messages: [AIMessage(role: .user, text: "weather?")],
            tools: [weatherTool()],
            toolChoice: .required
        )
        let json = try agentJSON(try PerplexityProvider().buildAgentRequest(from: request, stream: false))
        #expect(json.contains("\"tool_choice\":\"required\""))
    }

    @Test("Specific tool choice encodes as a flattened function object")
    func testSpecificToolChoice() throws {
        let request = AIRequest(
            model: "sonar",
            messages: [AIMessage(role: .user, text: "weather?")],
            tools: [weatherTool()],
            toolChoice: .specific("get_weather")
        )
        let json = try agentJSON(try PerplexityProvider().buildAgentRequest(from: request, stream: false))
        // Responses form: {"type":"function","name":"get_weather"} (not nested under "function").
        #expect(json.contains("\"tool_choice\":{"))
        #expect(json.contains("\"name\":\"get_weather\""))
        #expect(!json.contains("\"function\":{\"name\""))
    }

    @Test("System prompt maps to instructions")
    func testSystemPromptMapsToInstructions() throws {
        let request = AIRequest(
            model: "sonar",
            messages: [AIMessage(role: .user, text: "hi")],
            systemPrompt: "You are helpful.",
            tools: [weatherTool()]
        )
        let mapped = try PerplexityProvider().buildAgentRequest(from: request, stream: false)
        #expect(mapped.instructions == "You are helpful.")
    }

    @Test("Nested object tool schema is emitted")
    func testNestedSchema() throws {
        let tool = AITool(
            name: "save",
            description: "save",
            parameters: AIToolParameters(properties: [
                "record": AIToolProperty(type: "object", properties: [
                    "name": AIToolProperty(type: "string")
                ], required: ["name"])
            ])
        )
        let request = AIRequest(model: "sonar", messages: [AIMessage(role: .user, text: "x")], tools: [tool])
        let json = try agentJSON(try PerplexityProvider().buildAgentRequest(from: request, stream: false))
        #expect(json.contains("record"))
        #expect(json.contains("name"))
    }

    // MARK: - Multi-Turn Round-Trip

    @Test("Multi-turn replays function_call and function_call_output keyed by call_id")
    func testMultiTurnRoundTrip() throws {
        let request = AIRequest(
            model: "sonar",
            messages: [
                AIMessage(role: .user, text: "weather in SF?"),
                AIMessage(role: .assistant, content: [
                    .toolCall(AIToolCall(id: "call_1", name: "get_weather", arguments: "{\"location\":\"SF\"}"))
                ]),
                AIMessage(role: .user, content: [.toolResult(id: "call_1", result: "72F")])
            ],
            tools: [weatherTool()]
        )
        let mapped = try PerplexityProvider().buildAgentRequest(from: request, stream: false)

        // The input list must carry the replayed call and its output, both keyed by call_1.
        #expect(mapped.input.contains(.functionCall(callID: "call_1", name: "get_weather", arguments: "{\"location\":\"SF\"}")))
        #expect(mapped.input.contains(.functionCallOutput(callID: "call_1", output: "72F")))
        #expect(mapped.input.contains(.message(role: "user", content: "weather in SF?")))

        let json = try agentJSON(mapped)
        #expect(json.contains("function_call"))
        #expect(json.contains("function_call_output"))
        #expect(json.contains("call_1"))
        #expect(json.contains("72F"))
    }

    // MARK: - Response Parsing

    @Test("Agent function_call response parses into a .toolCall with stopReason .toolUse")
    func testFunctionCallResponseParsing() throws {
        let data = MockPerplexityAPI.agentFunctionCallResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(PerplexityAgentResponse.self, from: data)
        let aiResponse = PerplexityProvider().transformAgentResponse(response, model: "openai/gpt-5.6-sol")

        #expect(aiResponse.stopReason == .toolUse)
        #expect(aiResponse.provider == .perplexity)
        #expect(aiResponse.usage?.inputTokens == 40)
        #expect(aiResponse.usage?.outputTokens == 12)

        let call = aiResponse.message.content.compactMap { part -> AIToolCall? in
            if case .toolCall(let toolCall) = part { return toolCall }
            return nil
        }.first
        #expect(call?.name == "get_weather")
        // The neutral tool call id is the Agent call_id (the multi-turn correlation key).
        #expect(call?.id == "call_xyz789")
        #expect(call?.arguments.contains("San Francisco") == true)
    }

    @Test("Agent message response parses into text with stopReason .endTurn")
    func testMessageResponseParsing() throws {
        let data = MockPerplexityAPI.agentMessageResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(PerplexityAgentResponse.self, from: data)
        let aiResponse = PerplexityProvider().transformAgentResponse(response, model: "openai/gpt-5.6-sol")

        #expect(aiResponse.stopReason == .endTurn)
        #expect(aiResponse.textContent.contains("72F"))
        #expect(aiResponse.usage?.outputTokens == 18)
        // No tool calls present.
        let hasToolCall = aiResponse.message.content.contains { if case .toolCall = $0 { return true }; return false }
        #expect(hasToolCall == false)
    }

    // MARK: - Streaming

    @Test("Streamed function-call argument deltas accumulate correctly")
    func testStreamToolCallAccumulation() throws {
        let events = try decodeStreamEvents(MockPerplexityAPI.agentToolStreamEvents)

        var responseID = ""
        var accumulatedText = ""
        var toolCalls: [Int: PerplexityProvider.AgentToolCallAccumulator] = [:]

        for event in events where event.type != "response.completed" {
            _ = PerplexityProvider.reduceAgentStreamEvent(
                event,
                responseID: &responseID,
                accumulatedText: &accumulatedText,
                toolCalls: &toolCalls,
                model: "openai/gpt-5.6-sol"
            )
        }

        #expect(toolCalls[0]?.callID == "call_1")
        #expect(toolCalls[0]?.name == "get_weather")
        #expect(toolCalls[0]?.arguments == "{\"location\":\"SF\"}")
    }

    @Test("Streamed text deltas accumulate correctly")
    func testStreamTextAccumulation() throws {
        let events = try decodeStreamEvents(MockPerplexityAPI.agentTextStreamEvents)

        var responseID = ""
        var accumulatedText = ""
        var toolCalls: [Int: PerplexityProvider.AgentToolCallAccumulator] = [:]
        var lastPartial: AIResponse?

        for event in events where event.type != "response.completed" {
            if let partial = PerplexityProvider.reduceAgentStreamEvent(
                event,
                responseID: &responseID,
                accumulatedText: &accumulatedText,
                toolCalls: &toolCalls,
                model: "openai/gpt-5.6-sol"
            ) {
                lastPartial = partial
            }
        }

        #expect(accumulatedText == "Hello world")
        #expect(lastPartial?.textContent == "Hello world")
        #expect(toolCalls.isEmpty)
    }

    @Test("The completed stream event carries the authoritative final tool call")
    func testStreamCompletedResponseParsing() throws {
        let events = try decodeStreamEvents(MockPerplexityAPI.agentToolStreamEvents)
        let completed = try #require(events.first { $0.type == "response.completed" }?.response)
        let aiResponse = PerplexityProvider().transformAgentResponse(completed, model: "openai/gpt-5.6-sol")

        #expect(aiResponse.stopReason == .toolUse)
        let call = aiResponse.message.content.compactMap { part -> AIToolCall? in
            if case .toolCall(let toolCall) = part { return toolCall }
            return nil
        }.first
        #expect(call?.name == "get_weather")
        #expect(call?.id == "call_1")
    }
}
