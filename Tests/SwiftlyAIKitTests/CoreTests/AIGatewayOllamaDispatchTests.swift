import Testing
import Foundation
@testable import SwiftlyAIKit

/// Coverage for the `.ollama` provider wiring in `AIGateway`.
@Suite("AIGateway .ollama dispatch")
struct AIGatewayOllamaDispatchTests {
    @Test("Default provider wiring routes .ollama to a real OllamaProvider")
    func defaultProvidersRouteOllamaToOllamaProvider() throws {
        // Given the default provider set the gateway builds internally.
        let config = Configuration.withCompanyKey("test-key", provider: .ollama)
        let providers = AIGateway.createDefaultProviders(configuration: config)

        // Then .ollama resolves to the real OllamaProvider implementation.
        let ollamaProvider = providers[.ollama]
        #expect(ollamaProvider != nil)
        #expect(ollamaProvider is OllamaProvider)
        #expect(ollamaProvider?.providerType == .ollama)
    }
}
