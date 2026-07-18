import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for `ToolCapabilities` and the `ProviderProtocol.supportsTools` capability flag
@Suite("ToolCapabilities Tests")
struct ToolCapabilitiesTests {
    // MARK: - Per-Provider Support

    @Test("Perplexity does not support tool calling")
    func testPerplexityUnsupported() {
        #expect(ToolCapabilities.isSupported(by: .perplexity) == false)
    }

    @Test("Apple Intelligence does not support tool calling (not wired)")
    func testAppleIntelligenceUnsupported() {
        #expect(ToolCapabilities.isSupported(by: .appleIntelligence) == false)
    }

    @Test("Tool-capable providers support tool calling")
    func testToolCapableProviders() {
        #expect(ToolCapabilities.isSupported(by: .openai) == true)
        #expect(ToolCapabilities.isSupported(by: .anthropic) == true)
        #expect(ToolCapabilities.isSupported(by: .google) == true)
        #expect(ToolCapabilities.isSupported(by: .cohere) == true)
        #expect(ToolCapabilities.isSupported(by: .mistral) == true)
        #expect(ToolCapabilities.isSupported(by: .deepseek) == true)
        #expect(ToolCapabilities.isSupported(by: .grok) == true)
    }

    @Test("Every provider type has an explicit tool-support verdict")
    func testExhaustiveCoverage() {
        // Guards the exhaustive switch: every CaseIterable case resolves without trapping.
        for provider in ProviderType.allCases {
            let supported = ToolCapabilities.isSupported(by: provider)
            #expect(supported == true || supported == false)
        }
    }

    // MARK: - Protocol Default

    @Test("ProviderProtocol default supportsTools is true")
    func testDefaultSupportsToolsIsTrue() {
        // A minimal conformer that does not override supportsTools inherits the extension default.
        #expect(DefaultToolSupportProvider().supportsTools == true)
    }
}

/// Minimal `ProviderProtocol` conformer used to verify the `supportsTools` extension default.
private struct DefaultToolSupportProvider: ProviderProtocol {
    let providerType: ProviderType = .openai

    func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        throw AIError.unsupportedFeature(feature: "sendMessage", provider: providerType)
    }

    func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}
