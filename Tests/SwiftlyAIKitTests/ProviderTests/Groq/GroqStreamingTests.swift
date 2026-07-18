import Testing
import Foundation
@testable import SwiftlyAIKit

/// End-to-end tests for `GroqProvider` streaming: SSE reassembly, cumulative content,
/// streamed tool-call reconstruction, stop-reason mapping, and — critically — surfacing
/// the terminal `{"choices":[],"usage":{…}}` chunk under real Groq (OpenAI-compatible
/// `include_usage`) framing.
@Suite("GroqProvider Streaming Tests")
struct GroqStreamingTests {
    /// Build a raw SSE byte stream from mock event strings, emitting each event as its
    /// own `Data` chunk (mirroring how the network delivers SSE line-by-line).
    private func dataStream(from events: [String]) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(Data((event + "\n").utf8))
            }
            continuation.finish()
        }
    }

    /// Consume `makeResponseStream` and collect every yielded response.
    private func collect(_ events: [String]) async throws -> [AIResponse] {
        let provider = GroqProvider()
        var responses: [AIResponse] = []
        for try await response in provider.makeResponseStream(from: dataStream(from: events)) {
            responses.append(response)
        }
        return responses
    }

    private func toolCalls(in response: AIResponse) -> [AIToolCall] {
        response.message.content.compactMap { part in
            if case .toolCall(let call) = part { return call }
            return nil
        }
    }

    // MARK: - Content + terminal usage

    @Test("Streaming assembles cumulative content and surfaces the terminal usage chunk")
    func testStreamAssemblesContentAndSurfacesTerminalUsage() async throws {
        let responses = try await collect(MockGroqAPI.streamingResponseRealFraming)

        #expect(!responses.isEmpty)

        // Cumulative content: the final response carries the fully assembled text.
        let final = try #require(responses.last)
        #expect(final.textContent == "Hello, world!")

        // Stop reason survives the delta-less finish chunk.
        #expect(final.stopReason == .endTurn)

        // The terminal `{"choices":[],"usage":{…}}` chunk (no delta) is surfaced.
        let usage = try #require(final.usage, "Terminal usage chunk must be surfaced on the final response")
        #expect(usage.inputTokens == 11)
        #expect(usage.outputTokens == 3)
        #expect(usage.reasoningTokens == 7)
    }

    @Test("Streaming yields cumulative (non-shrinking) content as it arrives")
    func testStreamContentIsCumulative() async throws {
        let responses = try await collect(MockGroqAPI.streamingResponseRealFraming)

        // Content-bearing responses should grow monotonically toward the full text.
        let contents = responses.map(\.textContent).filter { !$0.isEmpty }
        #expect(contents.contains("Hello"))
        #expect(contents.last == "Hello, world!")
        for (previous, next) in zip(contents, contents.dropFirst()) {
            #expect(next.hasPrefix(previous))
        }
    }

    // MARK: - Tool-call reassembly

    @Test("Streaming reassembles tool-call fragments and surfaces terminal usage")
    func testStreamReassemblesToolCalls() async throws {
        let responses = try await collect(MockGroqAPI.streamingToolCallResponseRealFraming)

        let final = try #require(responses.last)

        // Tool-call name + argument fragments are reassembled into one call.
        let calls = toolCalls(in: final)
        #expect(calls.count == 1)
        #expect(calls.first?.id == "call_real123")
        #expect(calls.first?.name == "get_weather")
        #expect(calls.first?.arguments == "{\"location\": \"NYC\"}")

        // Stop reason maps to .toolUse from the delta-less finish chunk.
        #expect(final.stopReason == .toolUse)

        // Terminal usage is surfaced even on a tool-call stream.
        let usage = try #require(final.usage)
        #expect(usage.inputTokens == 25)
        #expect(usage.outputTokens == 15)
    }

    // MARK: - Testable static accumulator

    @Test("accumulateToolCalls reassembles streamed tool-call deltas by index")
    func testAccumulateToolCallsStaticReassembly() {
        var accumulated: [GroqToolCall] = []

        GroqProvider.accumulateToolCalls([
            GroqDeltaToolCall(
                index: 0,
                id: "call_1",
                type: "function",
                function: GroqDeltaFunctionCall(name: "get_weather", arguments: "{\"loc")
            )
        ], into: &accumulated)

        GroqProvider.accumulateToolCalls([
            GroqDeltaToolCall(
                index: 0,
                function: GroqDeltaFunctionCall(name: nil, arguments: "ation\":\"SF\"}")
            )
        ], into: &accumulated)

        #expect(accumulated.count == 1)
        #expect(accumulated[0].id == "call_1")
        #expect(accumulated[0].type == "function")
        #expect(accumulated[0].function.name == "get_weather")
        #expect(accumulated[0].function.arguments == "{\"location\":\"SF\"}")
    }

    @Test("accumulateToolCalls tracks multiple tool calls by index")
    func testAccumulateMultipleToolCalls() {
        var accumulated: [GroqToolCall] = []

        GroqProvider.accumulateToolCalls([
            GroqDeltaToolCall(index: 0, id: "call_a", type: "function",
                              function: GroqDeltaFunctionCall(name: "first", arguments: "{}")),
            GroqDeltaToolCall(index: 1, id: "call_b", type: "function",
                              function: GroqDeltaFunctionCall(name: "second", arguments: "{}"))
        ], into: &accumulated)

        #expect(accumulated.count == 2)
        #expect(accumulated[0].function.name == "first")
        #expect(accumulated[1].function.name == "second")
    }
}
