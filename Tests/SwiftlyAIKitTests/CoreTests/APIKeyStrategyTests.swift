import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for APIKeyStrategy enum
@Suite("APIKeyStrategy Tests")
struct APIKeyStrategyTests {
    // MARK: - Company Key Strategy

    @Test("Company key returns company key regardless of client key")
    func testCompanyKeyWithoutClientKey() throws {
        let strategy = APIKeyStrategy.companyKey("sk-company-123")

        let key = try strategy.resolveKey(for: .anthropic, clientKey: nil)
        #expect(key == "sk-company-123")
    }

    @Test("Company key ignores provided client key")
    func testCompanyKeyIgnoresClientKey() throws {
        let strategy = APIKeyStrategy.companyKey("sk-company-123")

        let key = try strategy.resolveKey(for: .anthropic, clientKey: "sk-client-456")
        #expect(key == "sk-company-123")
    }

    @Test("Company key works for all providers")
    func testCompanyKeyAllProviders() throws {
        let strategy = APIKeyStrategy.companyKey("sk-company-123")

        let anthropicKey = try strategy.resolveKey(for: .anthropic, clientKey: nil)
        let openaiKey = try strategy.resolveKey(for: .openai, clientKey: nil)
        let cohereKey = try strategy.resolveKey(for: .cohere, clientKey: nil)

        #expect(anthropicKey == "sk-company-123")
        #expect(openaiKey == "sk-company-123")
        #expect(cohereKey == "sk-company-123")
    }

    @Test("Company key does not accept client keys")
    func testCompanyKeyAcceptsClientKey() {
        let strategy = APIKeyStrategy.companyKey("sk-company-123")
        #expect(!strategy.acceptsClientKey)
    }

    @Test("Company key does not require client keys")
    func testCompanyKeyRequiresClientKey() {
        let strategy = APIKeyStrategy.companyKey("sk-company-123")
        #expect(!strategy.requiresClientKey)
    }

    // MARK: - Client Key Strategy

    @Test("Client key returns provided client key")
    func testClientKeyWithValidClientKey() throws {
        let strategy = APIKeyStrategy.clientKey

        let key = try strategy.resolveKey(for: .anthropic, clientKey: "sk-client-123")
        #expect(key == "sk-client-123")
    }

    @Test("Client key throws error when no client key provided")
    func testClientKeyWithoutClientKey() {
        let strategy = APIKeyStrategy.clientKey

        #expect(throws: AIError.self) {
            _ = try strategy.resolveKey(for: .anthropic, clientKey: nil)
        }
    }

    @Test("Client key throws error when empty client key provided")
    func testClientKeyWithEmptyClientKey() {
        let strategy = APIKeyStrategy.clientKey

        #expect(throws: AIError.self) {
            _ = try strategy.resolveKey(for: .anthropic, clientKey: "")
        }
    }

    @Test("Client key throws correct error type")
    func testClientKeyThrowsCorrectError() {
        let strategy = APIKeyStrategy.clientKey

        do {
            _ = try strategy.resolveKey(for: .anthropic, clientKey: nil)
            Issue.record("Expected AIError.missingAPIKey to be thrown")
        } catch let error as AIError {
            if case .missingAPIKey(let provider) = error {
                #expect(provider == .anthropic)
            } else {
                Issue.record("Expected AIError.missingAPIKey, got \(error)")
            }
        } catch {
            Issue.record("Expected AIError, got \(error)")
        }
    }

    @Test("Client key requires client keys")
    func testClientKeyRequiresClientKey() {
        let strategy = APIKeyStrategy.clientKey
        #expect(strategy.requiresClientKey)
    }

    @Test("Client key accepts client keys")
    func testClientKeyAcceptsClientKey() {
        let strategy = APIKeyStrategy.clientKey
        #expect(strategy.acceptsClientKey)
    }

    // MARK: - Hybrid Strategy

    @Test("Hybrid returns client key when provided")
    func testHybridWithClientKey() throws {
        let strategy = APIKeyStrategy.hybrid(defaultKey: "sk-default-123")

        let key = try strategy.resolveKey(for: .anthropic, clientKey: "sk-client-456")
        #expect(key == "sk-client-456")
    }

    @Test("Hybrid returns default key when no client key")
    func testHybridWithoutClientKey() throws {
        let strategy = APIKeyStrategy.hybrid(defaultKey: "sk-default-123")

        let key = try strategy.resolveKey(for: .anthropic, clientKey: nil)
        #expect(key == "sk-default-123")
    }

    @Test("Hybrid returns default key when empty client key")
    func testHybridWithEmptyClientKey() throws {
        let strategy = APIKeyStrategy.hybrid(defaultKey: "sk-default-123")

        let key = try strategy.resolveKey(for: .anthropic, clientKey: "")
        #expect(key == "sk-default-123")
    }

    @Test("Hybrid client key takes precedence over default")
    func testHybridClientKeyPrecedence() throws {
        let strategy = APIKeyStrategy.hybrid(defaultKey: "sk-default-123")

        let keyWithClient = try strategy.resolveKey(for: .anthropic, clientKey: "sk-client-456")
        let keyWithoutClient = try strategy.resolveKey(for: .anthropic, clientKey: nil)

        #expect(keyWithClient == "sk-client-456")
        #expect(keyWithoutClient == "sk-default-123")
        #expect(keyWithClient != keyWithoutClient)
    }

    @Test("Hybrid does not require client keys")
    func testHybridRequiresClientKey() {
        let strategy = APIKeyStrategy.hybrid(defaultKey: "sk-default-123")
        #expect(!strategy.requiresClientKey)
    }

    @Test("Hybrid accepts client keys")
    func testHybridAcceptsClientKey() {
        let strategy = APIKeyStrategy.hybrid(defaultKey: "sk-default-123")
        #expect(strategy.acceptsClientKey)
    }

    // MARK: - Per Provider Strategy

    @Test("Per provider returns client key when provided")
    func testPerProviderWithClientKey() throws {
        let strategy = APIKeyStrategy.perProvider([
            .anthropic: "sk-anthropic-123",
            .openai: "sk-openai-456"
        ])

        let key = try strategy.resolveKey(for: .anthropic, clientKey: "sk-client-789")
        #expect(key == "sk-client-789")
    }

    @Test("Per provider returns provider-specific key without client key")
    func testPerProviderWithoutClientKey() throws {
        let strategy = APIKeyStrategy.perProvider([
            .anthropic: "sk-anthropic-123",
            .openai: "sk-openai-456"
        ])

        let anthropicKey = try strategy.resolveKey(for: .anthropic, clientKey: nil)
        let openaiKey = try strategy.resolveKey(for: .openai, clientKey: nil)

        #expect(anthropicKey == "sk-anthropic-123")
        #expect(openaiKey == "sk-openai-456")
    }

    @Test("Per provider throws error for missing provider")
    func testPerProviderMissingProvider() {
        let strategy = APIKeyStrategy.perProvider([
            .anthropic: "sk-anthropic-123"
        ])

        #expect(throws: AIError.self) {
            _ = try strategy.resolveKey(for: .openai, clientKey: nil)
        }
    }

    @Test("Per provider client key takes precedence")
    func testPerProviderClientKeyPrecedence() throws {
        let strategy = APIKeyStrategy.perProvider([
            .anthropic: "sk-anthropic-123",
            .openai: "sk-openai-456"
        ])

        let keyWithClient = try strategy.resolveKey(for: .anthropic, clientKey: "sk-client-789")
        let keyWithoutClient = try strategy.resolveKey(for: .anthropic, clientKey: nil)

        #expect(keyWithClient == "sk-client-789")
        #expect(keyWithoutClient == "sk-anthropic-123")
        #expect(keyWithClient != keyWithoutClient)
    }

    @Test("Per provider works with all provider types")
    func testPerProviderAllTypes() throws {
        let strategy = APIKeyStrategy.perProvider([
            .anthropic: "sk-anthropic-123",
            .openai: "sk-openai-456",
            .cohere: "sk-cohere-789",
            .google: "sk-google-abc",
            .mistral: "sk-mistral-def"
        ])

        let anthropicKey = try strategy.resolveKey(for: .anthropic, clientKey: nil)
        let openaiKey = try strategy.resolveKey(for: .openai, clientKey: nil)
        let cohereKey = try strategy.resolveKey(for: .cohere, clientKey: nil)
        let googleKey = try strategy.resolveKey(for: .google, clientKey: nil)
        let mistralKey = try strategy.resolveKey(for: .mistral, clientKey: nil)

        #expect(anthropicKey == "sk-anthropic-123")
        #expect(openaiKey == "sk-openai-456")
        #expect(cohereKey == "sk-cohere-789")
        #expect(googleKey == "sk-google-abc")
        #expect(mistralKey == "sk-mistral-def")
    }

    @Test("Per provider does not require client keys")
    func testPerProviderRequiresClientKey() {
        let strategy = APIKeyStrategy.perProvider([.anthropic: "sk-anthropic-123"])
        #expect(!strategy.requiresClientKey)
    }

    @Test("Per provider accepts client keys")
    func testPerProviderAcceptsClientKey() {
        let strategy = APIKeyStrategy.perProvider([.anthropic: "sk-anthropic-123"])
        #expect(strategy.acceptsClientKey)
    }

    // MARK: - Edge Cases

    @Test("Empty company key returns empty string")
    func testEmptyCompanyKey() throws {
        let strategy = APIKeyStrategy.companyKey("")

        let key = try strategy.resolveKey(for: .anthropic, clientKey: nil)
        #expect(key == "")
    }

    @Test("Per provider with empty dictionary throws for any provider")
    func testPerProviderEmptyDictionary() {
        let strategy = APIKeyStrategy.perProvider([:])

        #expect(throws: AIError.self) {
            _ = try strategy.resolveKey(for: .anthropic, clientKey: nil)
        }
    }

    @Test("Client key works with different providers")
    func testClientKeyDifferentProviders() throws {
        let strategy = APIKeyStrategy.clientKey

        let anthropicKey = try strategy.resolveKey(for: .anthropic, clientKey: "sk-client-123")
        let openaiKey = try strategy.resolveKey(for: .openai, clientKey: "sk-client-456")

        #expect(anthropicKey == "sk-client-123")
        #expect(openaiKey == "sk-client-456")
    }

    // MARK: - Strategy Properties

    @Test("All strategies have consistent acceptsClientKey property")
    func testAcceptsClientKeyConsistency() {
        let companyKey = APIKeyStrategy.companyKey("sk-123")
        let clientKey = APIKeyStrategy.clientKey
        let hybrid = APIKeyStrategy.hybrid(defaultKey: "sk-123")
        let perProvider = APIKeyStrategy.perProvider([.anthropic: "sk-123"])

        #expect(!companyKey.acceptsClientKey)
        #expect(clientKey.acceptsClientKey)
        #expect(hybrid.acceptsClientKey)
        #expect(perProvider.acceptsClientKey)
    }

    @Test("All strategies have consistent requiresClientKey property")
    func testRequiresClientKeyConsistency() {
        let companyKey = APIKeyStrategy.companyKey("sk-123")
        let clientKey = APIKeyStrategy.clientKey
        let hybrid = APIKeyStrategy.hybrid(defaultKey: "sk-123")
        let perProvider = APIKeyStrategy.perProvider([.anthropic: "sk-123"])

        #expect(!companyKey.requiresClientKey)
        #expect(clientKey.requiresClientKey)
        #expect(!hybrid.requiresClientKey)
        #expect(!perProvider.requiresClientKey)
    }

    // MARK: - Real-World Scenarios

    @Test("Scenario: Single-tenant app with company key")
    func testSingleTenantScenario() throws {
        let strategy = APIKeyStrategy.companyKey("sk-company-production-key")

        // All users use the same company key
        let user1Key = try strategy.resolveKey(for: .anthropic, clientKey: nil)
        let user2Key = try strategy.resolveKey(for: .anthropic, clientKey: nil)

        #expect(user1Key == user2Key)
        #expect(user1Key == "sk-company-production-key")
    }

    @Test("Scenario: Multi-tenant app with client keys")
    func testMultiTenantScenario() throws {
        let strategy = APIKeyStrategy.clientKey

        // Each tenant provides their own key
        let tenant1Key = try strategy.resolveKey(for: .anthropic, clientKey: "sk-tenant1-key")
        let tenant2Key = try strategy.resolveKey(for: .anthropic, clientKey: "sk-tenant2-key")

        #expect(tenant1Key != tenant2Key)
        #expect(tenant1Key == "sk-tenant1-key")
        #expect(tenant2Key == "sk-tenant2-key")
    }

    @Test("Scenario: Freemium app with hybrid keys")
    func testFreemiumScenario() throws {
        let strategy = APIKeyStrategy.hybrid(defaultKey: "sk-free-tier-key")

        // Free users use default key
        let freeUserKey = try strategy.resolveKey(for: .anthropic, clientKey: nil)

        // Premium users use their own key
        let premiumUserKey = try strategy.resolveKey(for: .anthropic, clientKey: "sk-premium-user-key")

        #expect(freeUserKey == "sk-free-tier-key")
        #expect(premiumUserKey == "sk-premium-user-key")
        #expect(freeUserKey != premiumUserKey)
    }

    @Test("Scenario: Multi-provider app with separate billing")
    func testMultiProviderScenario() throws {
        let strategy = APIKeyStrategy.perProvider([
            .anthropic: "sk-anthropic-billing-account",
            .openai: "sk-openai-billing-account",
            .cohere: "sk-cohere-billing-account"
        ])

        // Each provider uses its own billing account
        let anthropicKey = try strategy.resolveKey(for: .anthropic, clientKey: nil)
        let openaiKey = try strategy.resolveKey(for: .openai, clientKey: nil)
        let cohereKey = try strategy.resolveKey(for: .cohere, clientKey: nil)

        #expect(anthropicKey == "sk-anthropic-billing-account")
        #expect(openaiKey == "sk-openai-billing-account")
        #expect(cohereKey == "sk-cohere-billing-account")
    }
}
