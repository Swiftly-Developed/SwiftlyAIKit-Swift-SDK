import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tool round-trip and function-calling request-mapping tests for OpenAIProvider.
@Suite("OpenAIProvider Tool Round-Trip Tests")
struct OpenAIToolRoundTripTests {
    @Test("Tool round-trip tolerates empty args and produces a valid request")
    func testEmptyArgsRoundTrip() throws {
        // Neutral conversation: assistant tool call with an empty arguments string, followed
        // by the user's tool result. Request mapping must NOT throw `.invalidRequest` and must
        // normalize the empty arguments to a valid JSON object ("{}").
        let request = AIRequest(
            model: "gpt-4o",
            messages: [
                AIMessage(role: .user, content: [.text("hi")]),
                AIMessage(role: .assistant, content: [
                    .toolCall(AIToolCall(id: "t1", type: "function", name: "search", arguments: ""))
                ]),
                AIMessage(role: .user, content: [.toolResult(id: "t1", result: "ok")])
            ]
        )

        let mapped = try OpenAIProvider().mapToOpenAIRequest(request)

        // Assistant message carries the tool call with normalized "{}" arguments.
        let assistant = mapped.messages.first { $0.role == .assistant }
        let toolCall = assistant?.toolCalls?.first
        #expect(toolCall?.function.name == "search")
        #expect(toolCall?.function.arguments == "{}")

        // Tool result maps to a `.tool` message referencing the originating call id.
        let toolMessage = mapped.messages.first { $0.role == .tool }
        #expect(toolMessage?.toolCallId == "t1")
    }
}
