import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for the v0.9.1 server-tool signal passthrough (S1/S2/S3) and request-side
/// fidelity fixes (R1 `defer_loading`/extras, R2 `rawMessagesJSON`).
@Suite("Anthropic Server-Tool Signals (v0.9.1)")
struct AnthropicServerToolTests {
    private func makeProvider() -> AnthropicProvider { AnthropicProvider() }

    private func parsedEvents() throws -> [AnthropicStreamEvent] {
        let provider = makeProvider()
        return try MockAnthropicAPI.streamEventsWithServerTools.compactMap { try provider.parseSSEEvent($0) }
    }

    // MARK: - R1: defer_loading + extras round-trip

    @Test("AnthropicToolDefinition round-trips defer_loading and unknown extras")
    func testToolDefinitionRoundTrip() throws {
        let json = """
        {"name":"lookup","description":"d","input_schema":{"type":"object"},"defer_loading":true,"custom_field":{"nested":42}}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnthropicToolDefinition.self, from: json)

        #expect(decoded.deferLoading == true)
        #expect(decoded.extras?["custom_field"] != nil)

        let reencoded = try JSONEncoder().encode(decoded)
        let obj = try JSONSerialization.jsonObject(with: reencoded) as? [String: Any]
        #expect(obj?["defer_loading"] as? Bool == true)
        #expect((obj?["custom_field"] as? [String: Any])?["nested"] as? Int == 42)
    }

    @Test("rawToolsJSON with defer_loading survives map→encode (R1)")
    func testRawToolsDeferLoadingSurvives() throws {
        let rawTools = """
        [
          {"name":"hot","description":"h","input_schema":{"type":"object"},"defer_loading":false},
          {"name":"cold","description":"c","input_schema":{"type":"object"},"defer_loading":true}
        ]
        """.data(using: .utf8)!
        let request = AIRequest(
            model: "claude",
            messages: [AIMessage(role: .user, text: "hi")],
            rawToolsJSON: rawTools
        )
        let mapped = try makeProvider().mapToAnthropicRequest(request)
        #expect(mapped.tools?.count == 2)
        #expect(mapped.tools?.first(where: { $0.name == "cold" })?.deferLoading == true)

        let json = String(data: try JSONEncoder().encode(mapped), encoding: .utf8) ?? ""
        // Both defer_loading flags must reach the wire (hot/cold set preserved).
        #expect(json.contains("defer_loading"))
    }

    // MARK: - R2: rawMessagesJSON byte-faithful passthrough

    @Test("rawMessagesJSON relays server-tool blocks with encrypted_content verbatim (R2)")
    func testRawMessagesPassthrough() throws {
        let rawMessages = """
        [
          {"role":"user","content":[{"type":"text","text":"latest swift news"}]},
          {"role":"assistant","content":[
            {"type":"server_tool_use","id":"srvtoolu_1","name":"web_search","input":{"query":"swift"}},
            {"type":"web_search_tool_result","tool_use_id":"srvtoolu_1","content":[
              {"type":"web_search_result","url":"https://swift.org","title":"Swift","encrypted_content":"ENCRYPTED_XYZ"}
            ]}
          ]}
        ]
        """.data(using: .utf8)!
        let request = AIRequest(
            model: "claude",
            messages: [AIMessage(role: .user, text: "ignored placeholder")],
            rawMessagesJSON: rawMessages
        )
        let mapped = try makeProvider().mapToAnthropicRequest(request)
        #expect(mapped.rawMessages != nil)

        let json = String(data: try JSONEncoder().encode(mapped), encoding: .utf8) ?? ""
        // The exact server-tool payload Anthropic requires on re-send must survive.
        #expect(json.contains("encrypted_content"))
        #expect(json.contains("ENCRYPTED_XYZ"))
        #expect(json.contains("server_tool_use"))
        #expect(json.contains("web_search_tool_result"))
        // The neutral placeholder message must NOT be sent when raw messages are provided.
        #expect(!json.contains("ignored placeholder"))
    }

    // MARK: - S1: web_search_tool_result rawJSON surfaced

    @Test("web_search_tool_result decodes the full block (urls + encrypted_content)")
    func testWebSearchResultFullCapture() throws {
        let events = try parsedEvents()
        var found = false
        for event in events {
            if case .contentBlockStart(let start) = event,
               case .webSearchToolResult(let rawJSON) = start.contentBlock {
                let dict = rawJSON.value as? [String: Any]
                #expect(dict?["tool_use_id"] as? String == "srvtoolu_1")
                let content = dict?["content"] as? [Any]
                let first = content?.first as? [String: Any]
                #expect(first?["encrypted_content"] as? String == "ENCRYPTED_ABC123")
                found = true
            }
        }
        #expect(found)
    }

    @Test("processStreamEvent surfaces web_search_tool_result on providerData (S1)")
    func testWebSearchStreamProviderData() throws {
        let provider = makeProvider()
        var surfaced = false
        for event in try parsedEvents() {
            guard let response = provider.processStreamEvent(event) else { continue }
            if response.providerData?["webSearchToolResult"] != nil {
                let raw = response.providerData?["webSearchToolResult"]?.value as? [String: Any]
                let content = raw?["content"] as? [Any]
                #expect((content?.first as? [String: Any])?["encrypted_content"] as? String == "ENCRYPTED_ABC123")
                surfaced = true
            }
        }
        #expect(surfaced)
    }

    // MARK: - S2: server_tool_use id + accumulated input

    @Test("ToolStreamAccumulator surfaces server_tool_use with accumulated input (S2)")
    func testServerToolAccumulation() throws {
        var accumulator = AnthropicProvider.ToolStreamAccumulator()
        var serverTools: [(id: String, name: String, input: String)] = []
        var clientTools: [AIToolCall] = []

        for event in try parsedEvents() {
            switch accumulator.handle(event) {
            case .server(_, let id, let name, let input):
                serverTools.append((id, name, input))
            case .client(_, let call):
                clientTools.append(call)
            case nil:
                break
            }
        }

        #expect(clientTools.isEmpty) // web_search is a server tool, not a client call
        #expect(serverTools.count == 1)
        #expect(serverTools.first?.id == "srvtoolu_1")
        #expect(serverTools.first?.name == "web_search")
        #expect(serverTools.first?.input.contains("swift concurrency") == true)

        // Accumulated input is valid JSON.
        let data = serverTools.first!.input.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: data)
        #expect(decoded["query"]?.value as? String == "swift concurrency")
    }

    // MARK: - S3: unknown block passthrough

    @Test("Unknown content block captures full raw JSON (S3)")
    func testUnknownBlockFullCapture() throws {
        for event in try parsedEvents() {
            if case .contentBlockStart(let start) = event,
               case .unknown(let type, let rawJSON) = start.contentBlock {
                #expect(type == "tool_search_tool_result")
                let dict = rawJSON.value as? [String: Any]
                #expect(dict?["type"] as? String == "tool_search_tool_result")
                #expect(dict?["tool_use_id"] as? String == "srvtoolu_2")
                return
            }
        }
        Issue.record("Expected an unknown tool_search_tool_result block")
    }

    @Test("processStreamEvent surfaces unknown block on providerData (S3)")
    func testUnknownStreamProviderData() throws {
        let provider = makeProvider()
        var surfaced = false
        for event in try parsedEvents() {
            guard let response = provider.processStreamEvent(event) else { continue }
            if response.providerData?["unknownBlock"] != nil {
                #expect(response.providerData?["unknownBlockType"]?.value as? String == "tool_search_tool_result")
                surfaced = true
            }
        }
        #expect(surfaced)
    }

    @Test("Non-streaming mapToAIResponse surfaces unknown blocks (S3)")
    func testUnknownNonStreaming() throws {
        let json = """
        {
          "id":"msg_x","type":"message","role":"assistant",
          "content":[
            {"type":"tool_search_tool_result","tool_use_id":"t1","content":{"tools":["a"]}},
            {"type":"text","text":"done"}
          ],
          "model":"claude","stop_reason":"end_turn","stop_sequence":null,
          "usage":{"input_tokens":5,"output_tokens":5}
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: json)
        let aiResponse = makeProvider().mapToAIResponse(response)

        #expect(aiResponse.textContent == "done")
        #expect(aiResponse.providerData?["unknownBlocks"] != nil)
    }

    // MARK: - Backward compatibility

    @Test("v0.9.0 defaults unchanged: no raw fields => neutral mapping still used")
    func testBackwardCompatible() throws {
        let request = AIRequest(model: "claude", messages: [AIMessage(role: .user, text: "hello")])
        let mapped = try makeProvider().mapToAnthropicRequest(request)
        #expect(mapped.rawMessages == nil)
        #expect(mapped.messages.count == 1)
        let json = String(data: try JSONEncoder().encode(mapped), encoding: .utf8) ?? ""
        #expect(json.contains("hello"))
    }
}
