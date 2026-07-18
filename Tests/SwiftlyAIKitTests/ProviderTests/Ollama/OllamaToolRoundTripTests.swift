import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tool round-trip and function-calling tests for OllamaProvider.
@Suite("OllamaProvider Tool Round-Trip Tests")
struct OllamaToolRoundTripTests {
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

    private func json(_ request: OllamaChatRequest) throws -> String {
        String(data: try JSONEncoder().encode(request), encoding: .utf8) ?? ""
    }

    @Test("Tools are wired into the Ollama request with the native function shape")
    func testToolsWired() throws {
        let request = AIRequest(
            model: "llama3.2:latest",
            messages: [AIMessage(role: .user, text: "weather?")],
            tools: [weatherTool()]
        )
        let mapped = OllamaProvider().buildOllamaRequest(from: request, stream: false)

        #expect(mapped.tools?.first?.type == "function")
        #expect(mapped.tools?.first?.function.name == "get_weather")

        let encoded = try json(mapped)
        #expect(encoded.contains("\"type\":\"function\""))
        #expect(encoded.contains("get_weather"))
        #expect(encoded.contains("location"))
        // Ollama's native /api/chat has no tool_choice field — it must never be emitted.
        #expect(!encoded.contains("tool_choice"))
    }

    @Test("Multi-turn tool round-trip preserves tool calls and tool results")
    func testMultiTurnRoundTrip() throws {
        let request = AIRequest(
            model: "llama3.2:latest",
            messages: [
                AIMessage(role: .user, text: "weather in SF?"),
                AIMessage(role: .assistant, content: [
                    .toolCall(AIToolCall(id: "call_1", name: "get_weather", arguments: "{\"location\":\"SF\"}"))
                ]),
                AIMessage(role: .user, content: [.toolResult(id: "call_1", result: "72F")])
            ],
            tools: [weatherTool()]
        )
        let mapped = OllamaProvider().buildOllamaRequest(from: request, stream: false)
        let encoded = try json(mapped)

        #expect(encoded.contains("tool_calls"))
        #expect(encoded.contains("72F"))

        // A tool-role message must exist for the result, referencing the originating call id.
        let hasToolRole = mapped.messages.contains { $0.role == "tool" && $0.toolCallID == "call_1" }
        #expect(hasToolRole)
        // An assistant message must carry the tool call (re-encoded arguments as an object).
        let hasAssistantToolCall = mapped.messages.contains { $0.toolCalls?.first?.function.name == "get_weather" }
        #expect(hasAssistantToolCall)
    }

    @Test("Nested object tool schema is emitted for Ollama")
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
        let request = AIRequest(model: "llama3.2:latest", messages: [AIMessage(role: .user, text: "x")], tools: [tool])
        let encoded = try json(OllamaProvider().buildOllamaRequest(from: request, stream: false))

        #expect(encoded.contains("record"))
        #expect(encoded.contains("name"))
    }
}
