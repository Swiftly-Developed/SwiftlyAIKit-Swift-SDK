import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests that `PerplexityProvider` reports no tool support and degrades gracefully when a caller
/// attaches tools to a request (Perplexity's Sonar API has no function/tool calling).
@Suite("PerplexityProvider Tool Degradation Tests")
struct PerplexityToolDegradationTests {
    // MARK: - Capability Flag

    @Test("PerplexityProvider reports no tool support")
    func testSupportsToolsIsFalse() {
        #expect(PerplexityProvider().supportsTools == false)
        #expect(ToolCapabilities.isSupported(by: PerplexityProvider().providerType) == false)
    }

    // MARK: - Graceful Degradation

    /// A request carrying `tools`/`toolChoice` should map to a Sonar request whose encoded wire
    /// body omits any tools field — the tools are ignored (documented no-op), not sent.
    @Test("Request with tools maps to a Sonar body that omits tools")
    func testToolsAreDroppedFromWireBody() throws {
        let tool = AITool(
            name: "get_weather",
            description: "Get the current weather",
            parameters: AIToolParameters(properties: [:])
        )

        let request = AIRequest(
            model: "sonar",
            messages: [AIMessage(role: .user, content: [.text("What is the weather?")])],
            tools: [tool],
            toolChoice: .auto
        )

        // Sanity: the neutral request really does carry tools.
        #expect(request.tools?.count == 1)

        // Map through the provider and encode the resulting Sonar request.
        let provider = PerplexityProvider()
        let perplexityRequest = try provider.mapToPerplexityRequest(request)

        let encoder = JSONEncoder()
        let data = try encoder.encode(perplexityRequest)
        let json = String(data: data, encoding: .utf8) ?? ""

        // The wire body must not mention tools in any form.
        #expect(!json.contains("\"tools\""))
        #expect(!json.contains("tool_choice"))
        #expect(!json.contains("get_weather"))

        // ...but the normal request still proceeds intact.
        #expect(json.contains("sonar"))
        #expect(json.contains("What is the weather?"))
    }

    @Test("Mapping a tools request does not throw")
    func testMappingDoesNotThrow() throws {
        let tool = AITool(
            name: "lookup",
            description: "Look something up",
            parameters: AIToolParameters(properties: [:])
        )
        let request = AIRequest(
            model: "sonar-pro",
            messages: [AIMessage(role: .user, content: [.text("Hello")])],
            tools: [tool]
        )

        // Should not throw — degradation is ignore-and-proceed, not error.
        let mapped = try PerplexityProvider().mapToPerplexityRequest(request)
        #expect(mapped.model == "sonar-pro")
        #expect(mapped.messages.count == 1)
    }
}
