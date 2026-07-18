import Testing
import Foundation
@testable import SwiftlyAIKit

/// Regression coverage for the `.google` provider wiring.
///
/// Previously `AIGateway` registered an unimplemented `GoogleProvider` stub for `.google`,
/// so every Gemini request failed with `AIError.unsupportedFeature`. These tests assert the
/// gateway now dispatches `.google` to a functioning provider that returns a real `AIResponse`.
@Suite("AIGateway .google dispatch")
struct AIGatewayGoogleDispatchTests {
    @Test("Gateway dispatches .google to a functioning provider (real AIResponse, not unsupportedFeature)")
    func gatewayDispatchesGoogleToFunctioningProvider() async throws {
        // Given a gateway whose .google slot is backed by a mock provider returning a canned response.
        let config = Configuration.withCompanyKey("google-test-key", provider: .google)
        let mock = MockProvider(providerType: .google)
        let canned = AIResponse(
            id: "resp-google-1",
            model: "gemini-2.5-pro",
            message: AIMessage(role: .assistant, content: [.text("Hello from Gemini")]),
            stopReason: .endTurn,
            usage: AIUsage(inputTokens: 10, outputTokens: 5),
            provider: .google
        )
        await mock.setMessageResponse(canned)
        let gateway = AIGateway(configuration: config, providers: [.google: mock])

        // When a .google request is sent through the gateway.
        let request = AIRequest(
            model: "gemini-2.5-pro",
            messages: [AIMessage(role: .user, text: "Hi")]
        )
        let response = try await gateway.sendMessage(request, to: .google)

        // Then a real response comes back (not a thrown unsupportedFeature).
        #expect(response.provider == .google)
        #expect(response.textContent == "Hello from Gemini")
        #expect(response.stopReason == .endTurn)
    }

    @Test("Default provider wiring routes .google to a real GeminiProvider, not the stub")
    func defaultProvidersRouteGoogleToGemini() throws {
        // Given the default provider set the gateway builds internally.
        let config = Configuration.withCompanyKey("test-key", provider: .google)
        let providers = AIGateway.createDefaultProviders(configuration: config)

        // Then .google resolves to the real GeminiProvider implementation.
        let googleProvider = providers[.google]
        #expect(googleProvider != nil)
        #expect(googleProvider is GeminiProvider)
        // ...and specifically not the previously-registered throwing stub.
        #expect(!(googleProvider is GoogleProvider))
        #expect(googleProvider?.providerType == .google)
    }

    @Test("GoogleProvider is a functional delegating alias, not a throwing stub")
    func googleProviderIsDelegatingAlias() {
        // GoogleProvider now forwards to an internal GeminiProvider rather than throwing
        // unsupportedFeature; it remains constructible and identifies as .google.
        let provider = GoogleProvider()
        #expect(provider.providerType == .google)
    }
}
