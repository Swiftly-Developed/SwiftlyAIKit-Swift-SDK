import Testing
import Foundation
@testable import SwiftlyAIKit

/// Coverage for the `.groq` provider wiring in `AIGateway`.
@Suite("AIGateway .groq dispatch")
struct AIGatewayGroqDispatchTests {
    @Test("Default provider wiring routes .groq to a real GroqProvider")
    func defaultProvidersRouteGroqToGroqProvider() throws {
        // Given the default provider set the gateway builds internally.
        let config = Configuration.withCompanyKey("test-key", provider: .groq)
        let providers = AIGateway.createDefaultProviders(configuration: config)

        // Then .groq resolves to the real GroqProvider implementation.
        let groqProvider = providers[.groq]
        #expect(groqProvider != nil)
        #expect(groqProvider is GroqProvider)
        #expect(groqProvider?.providerType == .groq)
    }
}
