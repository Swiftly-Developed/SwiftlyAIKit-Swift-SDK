import Testing
import Foundation
@testable import SwiftlyAIKit

/// Coverage for the `.openRouter` provider wiring in `AIGateway`.
@Suite("AIGateway .openRouter dispatch")
struct AIGatewayOpenRouterDispatchTests {
    @Test("Default provider wiring routes .openRouter to a real OpenRouterProvider")
    func defaultProvidersRouteOpenRouterToOpenRouterProvider() throws {
        // Given the default provider set the gateway builds internally.
        let config = Configuration.withCompanyKey("test-key", provider: .openRouter)
        let providers = AIGateway.createDefaultProviders(configuration: config)

        // Then .openRouter resolves to the real OpenRouterProvider implementation.
        let provider = providers[.openRouter]
        #expect(provider != nil)
        #expect(provider is OpenRouterProvider)
        #expect(provider?.providerType == .openRouter)
    }
}
