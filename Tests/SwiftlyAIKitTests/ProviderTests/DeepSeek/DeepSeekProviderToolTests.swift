import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for DeepSeekProvider unified tool-API wiring: request mapping, multi-turn
/// round-tripping, response parsing, and streaming tool-call accumulation.
@Suite("DeepSeekProvider Tool Tests")
struct DeepSeekProviderToolTests {
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

    @Test("Neutral request.tools and toolChoice are wired into the DeepSeek request")
    func testToolsWired() throws {
        let request = AIRequest(
            model: "deepseek-chat",
            messages: [AIMessage(role: .user, text: "weather?")],
            tools: [weatherTool()],
            toolChoice: .auto
        )
        // Built from request.tools / request.toolChoice — NOT providerOptions.
        let built = try DeepSeekProvider().buildDeepSeekRequest(from: request)

        #expect(built.tools?.count == 1)
        #expect(built.tools?.first?.function.name == "get_weather")
        #expect(built.tools?.first?.function.description == "Get the current weather")

        if case .auto = built.tool_choice {
            // expected
        } else {
            Issue.record("Expected tool_choice .auto, got \(String(describing: built.tool_choice))")
        }

        // The schema reaches the wire body.
        let json = String(data: try JSONEncoder().encode(built), encoding: .utf8) ?? ""
        #expect(json.contains("get_weather"))
        #expect(json.contains("location"))
    }

    @Test("Specific tool choice maps to a function choice")
    func testSpecificToolChoice() throws {
        let request = AIRequest(
            model: "deepseek-chat",
            messages: [AIMessage(role: .user, text: "weather?")],
            tools: [weatherTool()],
            toolChoice: .specific("get_weather")
        )
        let built = try DeepSeekProvider().buildDeepSeekRequest(from: request)

        if case .function(let name) = built.tool_choice {
            #expect(name == "get_weather")
        } else {
            Issue.record("Expected tool_choice .function, got \(String(describing: built.tool_choice))")
        }
    }

    @Test("Multi-turn tool round-trip maps assistant tool_calls and tool results")
    func testMultiTurnRoundTrip() throws {
        let request = AIRequest(
            model: "deepseek-chat",
            messages: [
                AIMessage(role: .user, text: "weather in SF?"),
                AIMessage(role: .assistant, content: [
                    .toolCall(AIToolCall(id: "call_1", name: "get_weather", arguments: "{\"location\":\"SF\"}"))
                ]),
                AIMessage(role: .user, content: [.toolResult(id: "call_1", result: "72F")])
            ],
            tools: [weatherTool()]
        )
        let built = try DeepSeekProvider().buildDeepSeekRequest(from: request)

        // Round-trip through JSON to prove the tool fields hit the wire body.
        let decoded = try JSONDecoder().decode(DeepSeekRequest.self, from: JSONEncoder().encode(built))

        let assistant = decoded.messages.first { $0.role == "assistant" && $0.tool_calls != nil }
        #expect(assistant?.tool_calls?.first?.id == "call_1")
        #expect(assistant?.tool_calls?.first?.function.name == "get_weather")

        let toolMessage = decoded.messages.first { $0.role == "tool" }
        #expect(toolMessage?.tool_call_id == "call_1")
        #expect(toolMessage?.content == "72F")
    }

    @Test("Response tool calls are parsed into .toolCall and stopReason is .toolUse")
    func testResponseToolCallParsing() throws {
        let jsonData = MockDeepSeekAPI.toolCallResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(DeepSeekResponse.self, from: jsonData)

        let originalRequest = AIRequest(model: "deepseek-chat", messages: [AIMessage(role: .user, text: "weather?")])
        let aiResponse = DeepSeekProvider().transformToAIResponse(response, originalRequest: originalRequest)

        #expect(aiResponse.stopReason == .toolUse)
        let call = aiResponse.message.content.compactMap { part -> AIToolCall? in
            if case .toolCall(let toolCall) = part { return toolCall }
            return nil
        }.first
        #expect(call?.id == "call_abc123")
        #expect(call?.name == "get_weather")
        #expect(call?.arguments.contains("San Francisco") == true)
    }

    @Test("Streaming tool-call deltas accumulate by index")
    func testStreamingAccumulation() {
        var accumulator: [Int: (id: String, name: String, args: String)] = [:]

        DeepSeekProvider.accumulate([
            DeepSeekDeltaToolCall(index: 0, id: "call_1", type: "function",
                                  function: .init(name: "get_weather", arguments: "{\"loc"))
        ], into: &accumulator)
        DeepSeekProvider.accumulate([
            DeepSeekDeltaToolCall(index: 0, id: nil, type: nil,
                                  function: .init(name: nil, arguments: "ation\":\"SF\"}"))
        ], into: &accumulator)

        #expect(accumulator[0]?.id == "call_1")
        #expect(accumulator[0]?.name == "get_weather")
        #expect(accumulator[0]?.args == "{\"location\":\"SF\"}")
    }

    @Test("Nested object tool schema is emitted for DeepSeek")
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
        let request = AIRequest(model: "deepseek-chat", messages: [AIMessage(role: .user, text: "x")], tools: [tool])
        let built = try DeepSeekProvider().buildDeepSeekRequest(from: request)
        let json = String(data: try JSONEncoder().encode(built), encoding: .utf8) ?? ""
        #expect(json.contains("record"))
        #expect(json.contains("tags"))
    }
}
