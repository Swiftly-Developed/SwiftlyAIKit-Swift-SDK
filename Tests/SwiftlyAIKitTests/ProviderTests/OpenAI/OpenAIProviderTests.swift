import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for OpenAIProvider tool calling, multi-turn round-tripping, and streaming
/// tool-call accumulation.
@Suite("OpenAIProvider Tool Tests")
struct OpenAIProviderTests {
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

    @Test("Tools and tool choice are wired into the OpenAI request")
    func testToolsWired() throws {
        let request = AIRequest(
            model: "gpt-4o",
            messages: [AIMessage(role: .user, text: "weather?")],
            tools: [weatherTool()],
            toolChoice: .auto
        )
        let mapped = try OpenAIProvider().mapToOpenAIRequest(request)
        #expect(mapped.tools?.count == 1)
        #expect(mapped.tools?.first?.function.name == "get_weather")
        #expect(mapped.toolChoice == .auto)
    }

    @Test("Multi-turn tool round-trip maps assistant tool_calls and tool results")
    func testMultiTurnRoundTrip() throws {
        let request = AIRequest(
            model: "gpt-4o",
            messages: [
                AIMessage(role: .user, text: "weather in SF?"),
                AIMessage(role: .assistant, content: [
                    .toolCall(AIToolCall(id: "call_1", name: "get_weather", arguments: "{\"location\":\"SF\"}"))
                ]),
                AIMessage(role: .user, content: [.toolResult(id: "call_1", result: "72F")])
            ],
            tools: [weatherTool()]
        )
        let mapped = try OpenAIProvider().mapToOpenAIRequest(request)

        // Round-trip through JSON.
        let decoded = try JSONDecoder().decode(OpenAIRequest.self, from: JSONEncoder().encode(mapped))

        let assistant = decoded.messages.first { $0.role == .assistant }
        #expect(assistant?.toolCalls?.first?.id == "call_1")
        #expect(assistant?.toolCalls?.first?.function.name == "get_weather")

        let toolMessage = decoded.messages.first { $0.role == .tool }
        #expect(toolMessage?.toolCallId == "call_1")
    }

    @Test("Response tool calls are parsed and stopReason is .toolUse")
    func testResponseToolCallParsing() throws {
        let json = """
        {
          "id": "chatcmpl-1", "object": "chat.completion", "created": 1,
          "model": "gpt-4o",
          "choices": [{
            "index": 0,
            "message": {
              "role": "assistant",
              "content": null,
              "tool_calls": [{
                "id": "call_1", "type": "function",
                "function": {"name": "get_weather", "arguments": "{\\"location\\":\\"SF\\"}"}
              }]
            },
            "finish_reason": "tool_calls"
          }],
          "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: json)
        let aiResponse = OpenAIProvider().mapToAIResponse(response)

        #expect(aiResponse.stopReason == .toolUse)
        let call = aiResponse.message.content.compactMap { part -> AIToolCall? in
            if case .toolCall(let c) = part { return c }
            return nil
        }.first
        #expect(call?.name == "get_weather")
        #expect(call?.arguments.contains("SF") == true)
    }

    @Test("Streaming tool-call deltas accumulate by index")
    func testStreamingAccumulation() {
        typealias DeltaToolCall = OpenAIStreamChunk.StreamChoice.Delta.DeltaToolCall
        var accumulator: [Int: (id: String, name: String, args: String)] = [:]

        OpenAIProvider.accumulate([
            DeltaToolCall(index: 0, id: "call_1", type: "function",
                          function: .init(name: "get_weather", arguments: "{\"loc"))
        ], into: &accumulator)
        OpenAIProvider.accumulate([
            DeltaToolCall(index: 0, id: nil, type: nil,
                          function: .init(name: nil, arguments: "ation\":\"SF\"}"))
        ], into: &accumulator)

        #expect(accumulator[0]?.id == "call_1")
        #expect(accumulator[0]?.name == "get_weather")
        #expect(accumulator[0]?.args == "{\"location\":\"SF\"}")
    }

    @Test("Nested object tool schema is emitted for OpenAI")
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
        let request = AIRequest(model: "gpt-4o", messages: [AIMessage(role: .user, text: "x")], tools: [tool])
        let mapped = try OpenAIProvider().mapToOpenAIRequest(request)
        let json = String(data: try JSONEncoder().encode(mapped), encoding: .utf8) ?? ""
        #expect(json.contains("record"))
        #expect(json.contains("tags"))
    }

    // MARK: - Models list

    @Test("Decodes models list response")
    func testDecodeModelsListResponse() throws {
        let jsonString = """
        {
          "object": "list",
          "data": [
            {
              "id": "gpt-4o",
              "object": "model",
              "created": 1686935002,
              "owned_by": "system"
            },
            {
              "id": "text-embedding-3-small",
              "object": "model",
              "created": 1705948997,
              "owned_by": "openai"
            }
          ]
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        let response = try JSONDecoder().decode(OpenAIModelsResponse.self, from: jsonData)

        #expect(response.object == "list")
        #expect(response.data.count == 2)
        #expect(response.data[0].id == "gpt-4o")
        #expect(response.data[0].created == 1686935002)
        // Verify the owned_by -> ownedBy snake_case key maps correctly.
        #expect(response.data[0].ownedBy == "system")
        #expect(response.data[1].id == "text-embedding-3-small")
        #expect(response.data[1].ownedBy == "openai")
    }
}
