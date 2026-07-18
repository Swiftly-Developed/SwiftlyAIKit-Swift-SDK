import Testing
@testable import SwiftlyAIKit

// MARK: - Gateway Initialization Tests

@Test("Gateway initializes with company key strategy")
func gatewayInitializesWithCompanyKey() async throws {
    // Given
    let companyKey = "sk-test-company-key"
    let config = Configuration.withCompanyKey(companyKey, provider: .anthropic)

    // When
    let gateway = AIGateway(configuration: config)

    // Then - Gateway should be created successfully (test passes if no error thrown)
    _ = gateway
}

@Test("Gateway initializes with client key strategy")
func gatewayInitializesWithClientKey() async throws {
    // Given
    let config = Configuration.withClientKeys(provider: .openai)

    // When
    let gateway = AIGateway(configuration: config)

    // Then
    _ = gateway
}

@Test("Gateway initializes with hybrid key strategy")
func gatewayInitializesWithHybridKey() async throws {
    // Given
    let defaultKey = "sk-test-default-key"
    let config = Configuration.withHybridKeys(defaultKey: defaultKey, provider: .google)

    // When
    let gateway = AIGateway(configuration: config)

    // Then
    _ = gateway
}

@Test("Gateway initializes with per-provider keys")
func gatewayInitializesWithProviderKeys() async throws {
    // Given
    let providerKeys: [ProviderType: String] = [
        .anthropic: "sk-ant-test",
        .openai: "sk-openai-test",
        .google: "google-test-key"
    ]
    let config = Configuration.withProviderKeys(providerKeys, defaultProvider: .anthropic)

    // When
    let gateway = AIGateway(configuration: config)

    // Then
    _ = gateway
}

@Test("Gateway initializes with custom providers")
func gatewayInitializesWithCustomProviders() async throws {
    // Given
    let config = Configuration.withCompanyKey("test-key")
    let mockProvider = MockProvider(providerType: .anthropic)
    let providers: [ProviderType: ProviderProtocol] = [
        .anthropic: mockProvider
    ]

    // When
    let gateway = AIGateway(configuration: config, providers: providers)

    // Then
    _ = gateway
}

@Test("Gateway initializes with development configuration")
func gatewayInitializesWithDevelopmentConfig() async throws {
    // Given
    let config = Configuration.development(companyKey: "dev-key", provider: .anthropic)

    // When
    let gateway = AIGateway(configuration: config)

    // Then
    _ = gateway
}

@Test("Gateway initializes with production configuration")
func gatewayInitializesWithProductionConfig() async throws {
    // Given
    let config = Configuration.production(
        keyStrategy: .companyKey("prod-key"),
        provider: .openai
    )

    // When
    let gateway = AIGateway(configuration: config)

    // Then
    _ = gateway
}

@Test("Gateway can register additional providers")
func gatewayCanRegisterProviders() async throws {
    // Given
    let config = Configuration.withCompanyKey("test-key")
    let gateway = AIGateway(configuration: config)
    let mockProvider = MockProvider(providerType: .cohere)

    // When
    await gateway.registerProvider(mockProvider, for: .cohere)

    // Then - Registration completes without error
    _ = gateway
}

// MARK: - Provider Dispatch Tests

@Test("Default gateway registers a working provider for .google")
func defaultGatewayRegistersGoogle() async throws {
    // Regression guard for the gateway routing .google to a broken stub.
    let config = Configuration.withCompanyKey("google-test-key", provider: .google)
    let gateway = AIGateway(configuration: config)

    #expect(await gateway.isProviderRegistered(.google))
}

@Test("Gateway dispatches .google requests to the registered provider")
func gatewayDispatchesGoogleToProvider() async throws {
    // Given a gateway whose .google slot is a functioning (mock) provider.
    let mock = MockProvider(providerType: .google)
    let expected = AIResponse(
        id: "resp-google-1",
        model: "gemini-2.5-pro",
        message: AIMessage(role: .assistant, content: [.text("Hello from Gemini")]),
        stopReason: .endTurn,
        usage: AIUsage(inputTokens: 5, outputTokens: 3),
        provider: .google
    )
    await mock.setMessageResponse(expected)

    let config = Configuration.withCompanyKey("google-test-key", provider: .google)
    let gateway = AIGateway(configuration: config, providers: [.google: mock])

    // When
    let request = AIRequest(model: "gemini-2.5-pro", prompt: "Hi")
    let response = try await gateway.sendMessage(request, to: .google)

    // Then - a real AIResponse comes back (not AIError.unsupportedFeature).
    #expect(response.provider == .google)
    #expect(response.id == "resp-google-1")
    if case .text(let text) = response.message.content.first {
        #expect(text == "Hello from Gemini")
    } else {
        Issue.record("Expected text content from .google dispatch")
    }
    #expect(await mock.didCall(operation: "sendMessage"))
}
