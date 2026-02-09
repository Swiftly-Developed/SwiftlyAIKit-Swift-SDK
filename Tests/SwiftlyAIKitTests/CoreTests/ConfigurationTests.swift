import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for Configuration struct
@Suite("Configuration Tests")
struct ConfigurationTests {
    // MARK: - Full Initializer Tests

    @Test("Full initializer sets all properties correctly")
    func testFullInitializer() {
        let betaFeatures: [ProviderType: [String]] = [
            .anthropic: ["prompt-caching-2024-07-31", "message-batches-2024-09-24"]
        ]
        let customURLs: [ProviderType: String] = [
            .anthropic: "https://custom.api.anthropic.com"
        ]
        let providerKeys: [ProviderType: String] = [
            .anthropic: "sk-ant-123",
            .openai: "sk-openai-456"
        ]

        let config = Configuration(
            keyStrategy: .companyKey("sk-company-123"),
            providerKeys: providerKeys,
            timeout: 120,
            maxRetries: 5,
            enableLogging: true,
            betaFeatures: betaFeatures,
            customBaseURLs: customURLs,
            defaultProvider: .openai
        )

        #expect(config.timeout == 120)
        #expect(config.maxRetries == 5)
        #expect(config.enableLogging == true)
        #expect(config.defaultProvider == .openai)
        #expect(config.providerKeys.count == 2)
        #expect(config.betaFeatures.count == 1)
        #expect(config.customBaseURLs.count == 1)
    }

    @Test("Initializer uses default values when not specified")
    func testInitializerDefaults() {
        let config = Configuration(keyStrategy: .clientKey)

        #expect(config.timeout == 60)
        #expect(config.maxRetries == 3)
        #expect(config.enableLogging == false)
        #expect(config.defaultProvider == .anthropic)
        #expect(config.providerKeys.isEmpty)
        #expect(config.betaFeatures.isEmpty)
        #expect(config.customBaseURLs.isEmpty)
    }

    @Test("Initializer accepts zero timeout and retries")
    func testInitializerZeroValues() {
        let config = Configuration(
            keyStrategy: .clientKey,
            timeout: 0,
            maxRetries: 0
        )

        #expect(config.timeout == 0)
        #expect(config.maxRetries == 0)
    }

    // MARK: - withCompanyKey Factory Method

    @Test("withCompanyKey creates correct configuration")
    func testWithCompanyKey() {
        let config = Configuration.withCompanyKey("sk-company-123")

        if case .companyKey(let key) = config.keyStrategy {
            #expect(key == "sk-company-123")
        } else {
            Issue.record("Expected companyKey strategy")
        }

        #expect(config.defaultProvider == .anthropic)
        #expect(config.enableLogging == false)
        #expect(config.timeout == 60)
        #expect(config.maxRetries == 3)
    }

    @Test("withCompanyKey uses custom provider")
    func testWithCompanyKeyCustomProvider() {
        let config = Configuration.withCompanyKey("sk-company-123", provider: .openai)

        #expect(config.defaultProvider == .openai)
    }

    @Test("withCompanyKey enables logging when specified")
    func testWithCompanyKeyLogging() {
        let config = Configuration.withCompanyKey("sk-company-123", enableLogging: true)

        #expect(config.enableLogging == true)
    }

    @Test("withCompanyKey works with all provider types")
    func testWithCompanyKeyAllProviders() {
        let anthropicConfig = Configuration.withCompanyKey("sk-123", provider: .anthropic)
        let openaiConfig = Configuration.withCompanyKey("sk-123", provider: .openai)
        let cohereConfig = Configuration.withCompanyKey("sk-123", provider: .cohere)
        let googleConfig = Configuration.withCompanyKey("sk-123", provider: .google)
        let mistralConfig = Configuration.withCompanyKey("sk-123", provider: .mistral)

        #expect(anthropicConfig.defaultProvider == .anthropic)
        #expect(openaiConfig.defaultProvider == .openai)
        #expect(cohereConfig.defaultProvider == .cohere)
        #expect(googleConfig.defaultProvider == .google)
        #expect(mistralConfig.defaultProvider == .mistral)
    }

    // MARK: - withClientKeys Factory Method

    @Test("withClientKeys creates correct configuration")
    func testWithClientKeys() {
        let config = Configuration.withClientKeys()

        if case .clientKey = config.keyStrategy {
            // Success
        } else {
            Issue.record("Expected clientKey strategy")
        }

        #expect(config.defaultProvider == .anthropic)
        #expect(config.enableLogging == false)
        #expect(config.timeout == 60)
        #expect(config.maxRetries == 3)
    }

    @Test("withClientKeys uses custom provider")
    func testWithClientKeysCustomProvider() {
        let config = Configuration.withClientKeys(provider: .openai)

        #expect(config.defaultProvider == .openai)
    }

    @Test("withClientKeys enables logging when specified")
    func testWithClientKeysLogging() {
        let config = Configuration.withClientKeys(enableLogging: true)

        #expect(config.enableLogging == true)
    }

    // MARK: - withHybridKeys Factory Method

    @Test("withHybridKeys creates correct configuration")
    func testWithHybridKeys() {
        let config = Configuration.withHybridKeys(defaultKey: "sk-default-123")

        if case .hybrid(let key) = config.keyStrategy {
            #expect(key == "sk-default-123")
        } else {
            Issue.record("Expected hybrid strategy")
        }

        #expect(config.defaultProvider == .anthropic)
        #expect(config.enableLogging == false)
    }

    @Test("withHybridKeys uses custom provider")
    func testWithHybridKeysCustomProvider() {
        let config = Configuration.withHybridKeys(defaultKey: "sk-default-123", provider: .cohere)

        #expect(config.defaultProvider == .cohere)
    }

    @Test("withHybridKeys enables logging when specified")
    func testWithHybridKeysLogging() {
        let config = Configuration.withHybridKeys(defaultKey: "sk-default-123", enableLogging: true)

        #expect(config.enableLogging == true)
    }

    // MARK: - withProviderKeys Factory Method

    @Test("withProviderKeys creates correct configuration")
    func testWithProviderKeys() {
        let keys: [ProviderType: String] = [
            .anthropic: "sk-ant-123",
            .openai: "sk-openai-456"
        ]
        let config = Configuration.withProviderKeys(keys)

        if case .perProvider(let providerKeys) = config.keyStrategy {
            #expect(providerKeys.count == 2)
            #expect(providerKeys[.anthropic] == "sk-ant-123")
            #expect(providerKeys[.openai] == "sk-openai-456")
        } else {
            Issue.record("Expected perProvider strategy")
        }

        #expect(config.providerKeys.count == 2)
        #expect(config.defaultProvider == .anthropic)
    }

    @Test("withProviderKeys uses custom default provider")
    func testWithProviderKeysCustomDefault() {
        let keys: [ProviderType: String] = [
            .anthropic: "sk-ant-123",
            .openai: "sk-openai-456"
        ]
        let config = Configuration.withProviderKeys(keys, defaultProvider: .openai)

        #expect(config.defaultProvider == .openai)
    }

    @Test("withProviderKeys enables logging when specified")
    func testWithProviderKeysLogging() {
        let keys: [ProviderType: String] = [.anthropic: "sk-ant-123"]
        let config = Configuration.withProviderKeys(keys, enableLogging: true)

        #expect(config.enableLogging == true)
    }

    @Test("withProviderKeys works with empty dictionary")
    func testWithProviderKeysEmpty() {
        let config = Configuration.withProviderKeys([:])

        #expect(config.providerKeys.isEmpty)
    }

    @Test("withProviderKeys works with all providers")
    func testWithProviderKeysAllProviders() {
        let keys: [ProviderType: String] = [
            .anthropic: "sk-ant-123",
            .openai: "sk-openai-456",
            .cohere: "sk-cohere-789",
            .google: "sk-google-abc",
            .mistral: "sk-mistral-def"
        ]
        let config = Configuration.withProviderKeys(keys)

        #expect(config.providerKeys.count == 5)
        #expect(config.providerKeys[.anthropic] == "sk-ant-123")
        #expect(config.providerKeys[.openai] == "sk-openai-456")
        #expect(config.providerKeys[.cohere] == "sk-cohere-789")
        #expect(config.providerKeys[.google] == "sk-google-abc")
        #expect(config.providerKeys[.mistral] == "sk-mistral-def")
    }

    // MARK: - development Factory Method

    @Test("development creates correct configuration")
    func testDevelopment() {
        let config = Configuration.development(companyKey: "sk-dev-123")

        if case .companyKey(let key) = config.keyStrategy {
            #expect(key == "sk-dev-123")
        } else {
            Issue.record("Expected companyKey strategy")
        }

        #expect(config.timeout == 120)
        #expect(config.maxRetries == 1)
        #expect(config.enableLogging == true)
        #expect(config.defaultProvider == .anthropic)
    }

    @Test("development uses custom provider")
    func testDevelopmentCustomProvider() {
        let config = Configuration.development(companyKey: "sk-dev-123", provider: .openai)

        #expect(config.defaultProvider == .openai)
    }

    @Test("development has longer timeout than default")
    func testDevelopmentTimeout() {
        let config = Configuration.development(companyKey: "sk-dev-123")
        let defaultConfig = Configuration.withCompanyKey("sk-dev-123")

        #expect(config.timeout > defaultConfig.timeout)
        #expect(config.timeout == 120)
    }

    @Test("development has fewer retries than default")
    func testDevelopmentRetries() {
        let config = Configuration.development(companyKey: "sk-dev-123")
        let defaultConfig = Configuration.withCompanyKey("sk-dev-123")

        #expect(config.maxRetries < defaultConfig.maxRetries)
        #expect(config.maxRetries == 1)
    }

    @Test("development always enables logging")
    func testDevelopmentLogging() {
        let config = Configuration.development(companyKey: "sk-dev-123")

        #expect(config.enableLogging == true)
    }

    // MARK: - production Factory Method

    @Test("production creates correct configuration")
    func testProduction() {
        let config = Configuration.production(keyStrategy: .companyKey("sk-prod-123"))

        if case .companyKey(let key) = config.keyStrategy {
            #expect(key == "sk-prod-123")
        } else {
            Issue.record("Expected companyKey strategy")
        }

        #expect(config.timeout == 60)
        #expect(config.maxRetries == 3)
        #expect(config.enableLogging == false)
        #expect(config.defaultProvider == .anthropic)
    }

    @Test("production uses custom provider")
    func testProductionCustomProvider() {
        let config = Configuration.production(keyStrategy: .clientKey, provider: .openai)

        #expect(config.defaultProvider == .openai)
    }

    @Test("production disables logging")
    func testProductionLogging() {
        let config = Configuration.production(keyStrategy: .companyKey("sk-prod-123"))

        #expect(config.enableLogging == false)
    }

    @Test("production works with all key strategies")
    func testProductionAllStrategies() {
        let companyConfig = Configuration.production(keyStrategy: .companyKey("sk-123"))
        let clientConfig = Configuration.production(keyStrategy: .clientKey)
        let hybridConfig = Configuration.production(keyStrategy: .hybrid(defaultKey: "sk-123"))
        let perProviderConfig = Configuration.production(keyStrategy: .perProvider([.anthropic: "sk-123"]))

        #expect(companyConfig.enableLogging == false)
        #expect(clientConfig.enableLogging == false)
        #expect(hybridConfig.enableLogging == false)
        #expect(perProviderConfig.enableLogging == false)
    }

    // MARK: - Configuration Comparison

    @Test("development and production have different settings")
    func testDevelopmentVsProduction() {
        let devConfig = Configuration.development(companyKey: "sk-123")
        let prodConfig = Configuration.production(keyStrategy: .companyKey("sk-123"))

        #expect(devConfig.timeout != prodConfig.timeout)
        #expect(devConfig.maxRetries != prodConfig.maxRetries)
        #expect(devConfig.enableLogging != prodConfig.enableLogging)
    }

    @Test("All factory methods create valid configurations")
    func testAllFactoryMethodsValid() {
        let companyConfig = Configuration.withCompanyKey("sk-123")
        let clientConfig = Configuration.withClientKeys()
        let hybridConfig = Configuration.withHybridKeys(defaultKey: "sk-123")
        let providerConfig = Configuration.withProviderKeys([.anthropic: "sk-123"])
        let devConfig = Configuration.development(companyKey: "sk-123")
        let prodConfig = Configuration.production(keyStrategy: .companyKey("sk-123"))

        // All should have valid timeout and retry values
        #expect(companyConfig.timeout > 0)
        #expect(clientConfig.timeout > 0)
        #expect(hybridConfig.timeout > 0)
        #expect(providerConfig.timeout > 0)
        #expect(devConfig.timeout > 0)
        #expect(prodConfig.timeout > 0)

        #expect(companyConfig.maxRetries >= 0)
        #expect(clientConfig.maxRetries >= 0)
        #expect(hybridConfig.maxRetries >= 0)
        #expect(providerConfig.maxRetries >= 0)
        #expect(devConfig.maxRetries >= 0)
        #expect(prodConfig.maxRetries >= 0)
    }

    // MARK: - Beta Features

    @Test("Beta features can be configured")
    func testBetaFeatures() {
        let betaFeatures: [ProviderType: [String]] = [
            .anthropic: ["prompt-caching-2024-07-31", "message-batches-2024-09-24"]
        ]
        let config = Configuration(
            keyStrategy: .companyKey("sk-123"),
            betaFeatures: betaFeatures
        )

        #expect(config.betaFeatures.count == 1)
        #expect(config.betaFeatures[.anthropic]?.count == 2)
        #expect(config.betaFeatures[.anthropic]?.contains("prompt-caching-2024-07-31") == true)
    }

    @Test("Multiple providers can have beta features")
    func testBetaFeaturesMultipleProviders() {
        let betaFeatures: [ProviderType: [String]] = [
            .anthropic: ["prompt-caching-2024-07-31"],
            .openai: ["gpt-4-turbo-preview"]
        ]
        let config = Configuration(
            keyStrategy: .companyKey("sk-123"),
            betaFeatures: betaFeatures
        )

        #expect(config.betaFeatures.count == 2)
        #expect(config.betaFeatures[.anthropic]?.count == 1)
        #expect(config.betaFeatures[.openai]?.count == 1)
    }

    // MARK: - Custom Base URLs

    @Test("Custom base URLs can be configured")
    func testCustomBaseURLs() {
        let customURLs: [ProviderType: String] = [
            .anthropic: "https://custom.api.anthropic.com"
        ]
        let config = Configuration(
            keyStrategy: .companyKey("sk-123"),
            customBaseURLs: customURLs
        )

        #expect(config.customBaseURLs.count == 1)
        #expect(config.customBaseURLs[.anthropic] == "https://custom.api.anthropic.com")
    }

    @Test("Multiple providers can have custom URLs")
    func testCustomBaseURLsMultipleProviders() {
        let customURLs: [ProviderType: String] = [
            .anthropic: "https://custom.anthropic.com",
            .openai: "https://custom.openai.com"
        ]
        let config = Configuration(
            keyStrategy: .companyKey("sk-123"),
            customBaseURLs: customURLs
        )

        #expect(config.customBaseURLs.count == 2)
        #expect(config.customBaseURLs[.anthropic] == "https://custom.anthropic.com")
        #expect(config.customBaseURLs[.openai] == "https://custom.openai.com")
    }

    // MARK: - Real-World Scenarios

    @Test("Scenario: Simple startup with single API key")
    func testSimpleStartupScenario() {
        let config = Configuration.withCompanyKey("sk-company-key")

        #expect(!config.enableLogging)
        #expect(config.defaultProvider == .anthropic)
        if case .companyKey = config.keyStrategy {
            // Success
        } else {
            Issue.record("Expected companyKey strategy")
        }
    }

    @Test("Scenario: Multi-tenant SaaS with client keys")
    func testMultiTenantScenario() {
        let config = Configuration.withClientKeys(provider: .anthropic)

        if case .clientKey = config.keyStrategy {
            // Success
        } else {
            Issue.record("Expected clientKey strategy")
        }
        #expect(config.defaultProvider == .anthropic)
    }

    @Test("Scenario: Enterprise with multiple provider accounts")
    func testEnterpriseScenario() {
        let config = Configuration.withProviderKeys([
            .anthropic: "sk-anthropic-enterprise",
            .openai: "sk-openai-enterprise",
            .cohere: "sk-cohere-enterprise"
        ])

        if case .perProvider(let keys) = config.keyStrategy {
            #expect(keys.count == 3)
        } else {
            Issue.record("Expected perProvider strategy")
        }
    }

    @Test("Scenario: Local development environment")
    func testLocalDevelopmentScenario() {
        let config = Configuration.development(companyKey: "sk-dev-key")

        #expect(config.enableLogging == true)
        #expect(config.timeout == 120) // Longer for debugging
        #expect(config.maxRetries == 1) // Fewer retries for fast feedback
    }

    @Test("Scenario: Production environment with high availability")
    func testProductionScenario() {
        let config = Configuration.production(
            keyStrategy: .hybrid(defaultKey: "sk-company-fallback"),
            provider: .anthropic
        )

        #expect(config.enableLogging == false)
        #expect(config.timeout == 60)
        #expect(config.maxRetries == 3)
    }

    @Test("Scenario: Custom proxy or gateway URL")
    func testCustomProxyScenario() {
        let config = Configuration(
            keyStrategy: .companyKey("sk-123"),
            customBaseURLs: [
                .anthropic: "https://proxy.company.com/anthropic",
                .openai: "https://proxy.company.com/openai"
            ]
        )

        #expect(config.customBaseURLs.count == 2)
        #expect(config.customBaseURLs[.anthropic]?.contains("proxy.company.com") == true)
    }
}
