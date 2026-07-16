import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tool round-trip and function-calling tests for GeminiProvider.
@Suite("GeminiProvider Tool Round-Trip Tests")
struct GeminiToolRoundTripTests {
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

    @Test("Tools map to functionDeclarations")
    func testToolsWired() throws {
        let request = AIRequest(
            model: "gemini-2.5-pro",
            messages: [AIMessage(role: .user, text: "weather?")],
            tools: [weatherTool()],
            toolChoice: .required
        )
        let mapped = try GeminiProvider().mapToGeminiRequest(request)
        #expect(mapped.tools?.first?.functionDeclarations.first?.name == "get_weather")
        #expect(mapped.toolConfig?.functionCallingConfig.mode == .any)
    }

    @Test("Multi-turn tool round-trip maps functionCall and functionResponse")
    func testMultiTurnRoundTrip() throws {
        // Gemini has no tool-call IDs, so a tool result's id carries the function name.
        let request = AIRequest(
            model: "gemini-2.5-pro",
            messages: [
                AIMessage(role: .user, text: "weather in SF?"),
                AIMessage(role: .assistant, content: [
                    .toolCall(AIToolCall(id: "get_weather", name: "get_weather", arguments: "{\"location\":\"SF\"}"))
                ]),
                AIMessage(role: .user, content: [.toolResult(id: "get_weather", result: "72F")])
            ],
            tools: [weatherTool()]
        )
        let mapped = try GeminiProvider().mapToGeminiRequest(request)

        guard case .functionCall(let callName, let args) = mapped.contents[1].parts.first else {
            Issue.record("Expected functionCall part")
            return
        }
        #expect(callName == "get_weather")
        #expect(args["location"]?.value as? String == "SF")

        guard case .functionResponse(let respName, _) = mapped.contents[2].parts.first else {
            Issue.record("Expected functionResponse part")
            return
        }
        #expect(respName == "get_weather")
    }

    @Test("Function-call response sets stopReason .toolUse")
    func testFunctionCallStopReason() throws {
        let data = MockGeminiAPI.functionCallResponse.data(using: .utf8)!
        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
        let aiResponse = GeminiProvider().mapToAIResponse(response, model: "gemini-2.5-pro")

        #expect(aiResponse.stopReason == .toolUse)
        let hasToolCall = aiResponse.message.content.contains { part in
            if case .toolCall = part { return true }
            return false
        }
        #expect(hasToolCall)
    }

    @Test("Nested object tool schema survives Gemini mapping")
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
        let request = AIRequest(model: "gemini-2.5-pro", messages: [AIMessage(role: .user, text: "x")], tools: [tool])
        let mapped = try GeminiProvider().mapToGeminiRequest(request)
        let recordProp = mapped.tools?.first?.functionDeclarations.first?.parameters?.properties?["record"]
        #expect(recordProp?.properties?["name"]?.type == "STRING")
    }
}
