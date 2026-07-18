import Testing
import Foundation
@testable import SwiftlyAIKit

/// End-to-end tests for `OllamaProvider` streaming: newline-delimited JSON parsing, cumulative
/// content assembly, partial-line buffering across `Data` chunks, tool-call surfacing, and
/// terminal usage/stop-reason handling from the `done == true` line.
@Suite("OllamaProvider Streaming Tests")
struct OllamaStreamingTests {
    /// Build a raw byte stream from mock newline-JSON lines, emitting each line (plus its
    /// terminating `\n`) as its own `Data` chunk.
    private func dataStream(from lines: [String]) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            for line in lines {
                continuation.yield(Data((line + "\n").utf8))
            }
            continuation.finish()
        }
    }

    /// Emit the joined newline-JSON payload as raw `Data` chunks of a fixed byte size, so lines are
    /// deliberately split across chunk boundaries (proving partial-line buffering).
    private func chunkedDataStream(from lines: [String], chunkSize: Int) -> AsyncThrowingStream<Data, Error> {
        let payload = Data((lines.joined(separator: "\n") + "\n").utf8)
        return AsyncThrowingStream { continuation in
            var index = 0
            while index < payload.count {
                let end = min(index + chunkSize, payload.count)
                continuation.yield(payload.subdata(in: index..<end))
                index = end
            }
            continuation.finish()
        }
    }

    private func collect(_ stream: AsyncThrowingStream<Data, Error>, model: String = "llama3.2:latest") async throws -> [AIResponse] {
        let provider = OllamaProvider()
        var responses: [AIResponse] = []
        for try await response in provider.makeResponseStream(from: stream, model: model) {
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

    @Test("Streaming assembles cumulative content and surfaces terminal usage + stop reason")
    func testStreamAssemblesContentAndUsage() async throws {
        let responses = try await collect(dataStream(from: MockOllamaAPI.streamingResponseLines))

        #expect(!responses.isEmpty)

        let final = try #require(responses.last)
        #expect(final.textContent == "Hello, world!")
        #expect(final.stopReason == .endTurn)

        let usage = try #require(final.usage, "The done==true line must surface usage on the final response")
        #expect(usage.inputTokens == 11)
        #expect(usage.outputTokens == 3)
    }

    @Test("Streaming yields cumulative (non-shrinking) content as it arrives")
    func testStreamContentIsCumulative() async throws {
        let responses = try await collect(dataStream(from: MockOllamaAPI.streamingResponseLines))

        let contents = responses.map(\.textContent).filter { !$0.isEmpty }
        #expect(contents.contains("Hello"))
        #expect(contents.last == "Hello, world!")
        for (previous, next) in zip(contents, contents.dropFirst()) {
            #expect(next.hasPrefix(previous))
        }
    }

    // MARK: - Partial-line buffering

    @Test("Streaming reassembles a line split across two Data chunks")
    func testStreamBuffersPartialLinesAcrossChunks() async throws {
        // A tiny chunk size guarantees each newline-JSON line is split mid-way across chunks.
        let responses = try await collect(chunkedDataStream(from: MockOllamaAPI.streamingResponseLines, chunkSize: 7))

        let final = try #require(responses.last)
        #expect(final.textContent == "Hello, world!")
        #expect(final.stopReason == .endTurn)
        #expect(final.usage?.inputTokens == 11)
        #expect(final.usage?.outputTokens == 3)
    }

    // MARK: - Tool-call streaming

    @Test("Streaming surfaces a tool call and terminal usage with .toolUse stop reason")
    func testStreamToolCall() async throws {
        let responses = try await collect(dataStream(from: MockOllamaAPI.streamingToolCallLines))

        let final = try #require(responses.last)

        let calls = toolCalls(in: final)
        #expect(calls.count == 1)
        #expect(calls.first?.name == "get_weather")
        #expect(calls.first?.arguments.contains("NYC") == true)

        #expect(final.stopReason == .toolUse)
        #expect(final.usage?.inputTokens == 25)
        #expect(final.usage?.outputTokens == 15)
    }

    // MARK: - Testable static accumulator

    @Test("accumulate appends content deltas and collects tool calls from a line")
    func testAccumulateStatic() {
        var content = ""
        var toolCalls: [OllamaToolCall] = []

        let first = OllamaChatResponse(
            model: "llama3.2:latest",
            message: OllamaResponseMessage(role: "assistant", content: "Hello"),
            done: false
        )
        let second = OllamaChatResponse(
            model: "llama3.2:latest",
            message: OllamaResponseMessage(
                role: "assistant",
                content: ", world!",
                toolCalls: [OllamaToolCall(function: OllamaToolCallFunction(
                    name: "get_weather",
                    arguments: AnyCodable(["location": "NYC"])
                ))]
            ),
            done: true
        )

        OllamaProvider.accumulate(first, content: &content, toolCalls: &toolCalls)
        OllamaProvider.accumulate(second, content: &content, toolCalls: &toolCalls)

        #expect(content == "Hello, world!")
        #expect(toolCalls.count == 1)
        #expect(toolCalls.first?.function.name == "get_weather")
    }
}
