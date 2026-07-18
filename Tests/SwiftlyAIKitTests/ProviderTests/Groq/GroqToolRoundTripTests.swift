import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tool round-trip and function-calling tests for GroqProvider.
@Suite("GroqProvider Tool Round-Trip Tests")
struct GroqToolRoundTripTests {
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

    private func json(_ request: GroqRequest) throws -> String {
        String(data: try JSONEncoder().encode(request), encoding: .utf8) ?? ""
    }

    @Test("Tools and neutral tool choice are wired into the Groq request")
    func testToolsWired() throws {
        let request = AIRequest(
            model: "openai/gpt-oss-120b",
            messages: [AIMessage(role: .user, text: "weather?")],
            tools: [weatherTool()],
            toolChoice: .required
        )
        let mapped = try GroqProvider().buildGroqRequest(from: request)
        #expect(mapped.tools?.first?.function.name == "get_weather")
        // GroqToolChoice isn't Equatable; verify via encoded form.
        #expect(try json(mapped).contains("\"tool_choice\":\"required\""))
    }

    @Test("Specific tool choice maps to a function choice")
    func testSpecificToolChoice() throws {
        let request = AIRequest(
            model: "openai/gpt-oss-120b",
            messages: [AIMessage(role: .user, text: "weather?")],
            tools: [weatherTool()],
            toolChoice: .specific("get_weather")
        )
        let mapped = try GroqProvider().buildGroqRequest(from: request)
        let encoded = try json(mapped)
        #expect(encoded.contains("\"tool_choice\""))
        #expect(encoded.contains("get_weather"))
    }

    @Test("Multi-turn tool round-trip preserves tool calls and tool results")
    func testMultiTurnRoundTrip() throws {
        let request = AIRequest(
            model: "openai/gpt-oss-120b",
            messages: [
                AIMessage(role: .user, text: "weather in SF?"),
                AIMessage(role: .assistant, content: [
                    .toolCall(AIToolCall(id: "call_1", name: "get_weather", arguments: "{\"location\":\"SF\"}"))
                ]),
                AIMessage(role: .user, content: [.toolResult(id: "call_1", result: "72F")])
            ],
            tools: [weatherTool()]
        )
        let mapped = try GroqProvider().buildGroqRequest(from: request)
        let encoded = try json(mapped)

        #expect(encoded.contains("tool_calls"))
        #expect(encoded.contains("call_1"))
        #expect(encoded.contains("tool_call_id"))
        #expect(encoded.contains("72F"))

        // A tool-role message must exist for the result.
        let hasToolRole = mapped.messages.contains { $0.role == "tool" && $0.tool_call_id == "call_1" }
        #expect(hasToolRole)
        // An assistant message must carry the tool call.
        let hasAssistantToolCall = mapped.messages.contains { $0.tool_calls?.first?.id == "call_1" }
        #expect(hasAssistantToolCall)
    }

    @Test("Response tool calls are parsed and stopReason is .toolUse")
    func testResponseToolCallParsing() throws {
        let groqResponse = GroqResponse(
            id: "resp_1",
            object: "chat.completion",
            created: 1,
            model: "openai/gpt-oss-120b",
            choices: [GroqChoice(
                index: 0,
                message: GroqResponseMessage(
                    role: "assistant",
                    content: nil,
                    tool_calls: [GroqToolCall(
                        id: "call_1",
                        function: GroqFunctionCall(name: "get_weather", arguments: "{\"location\":\"SF\"}")
                    )]
                ),
                finish_reason: "tool_calls"
            )]
        )
        let request = AIRequest(model: "openai/gpt-oss-120b", messages: [AIMessage(role: .user, text: "x")])
        let aiResponse = GroqProvider().transformToAIResponse(groqResponse, originalRequest: request)

        #expect(aiResponse.stopReason == .toolUse)
        let call = aiResponse.message.content.compactMap { part -> AIToolCall? in
            if case .toolCall(let c) = part { return c }
            return nil
        }.first
        #expect(call?.name == "get_weather")
    }

    @Test("Nested object tool schema is emitted for Groq")
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
        let request = AIRequest(model: "openai/gpt-oss-120b", messages: [AIMessage(role: .user, text: "x")], tools: [tool])
        let encoded = try json(try GroqProvider().buildGroqRequest(from: request))
        #expect(encoded.contains("record"))
        #expect(encoded.contains("name"))
    }
}
