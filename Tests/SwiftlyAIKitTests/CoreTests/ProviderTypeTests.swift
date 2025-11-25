import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for ProviderType enum
@Suite("ProviderType Tests")
struct ProviderTypeTests {
    // MARK: - Enum Conformance

    @Test("ProviderType is CaseIterable")
    func testCaseIterable() {
        let allCases = ProviderType.allCases
        #expect(allCases.count == 6) // anthropic, openai, google, perplexity, mistral, cohere
        #expect(allCases.contains(.openai))
        #expect(allCases.contains(.anthropic))
        #expect(allCases.contains(.google))
        #expect(allCases.contains(.perplexity))
        #expect(allCases.contains(.mistral))
        #expect(allCases.contains(.cohere))
    }

    @Test("ProviderType has correct raw values")
    func testRawValues() {
        #expect(ProviderType.openai.rawValue == "openai")
        #expect(ProviderType.anthropic.rawValue == "anthropic")
        #expect(ProviderType.google.rawValue == "google")
        #expect(ProviderType.cohere.rawValue == "cohere")
        #expect(ProviderType.mistral.rawValue == "mistral")
    }

    @Test("ProviderType can be initialized from raw value")
    func testRawValueInit() {
        #expect(ProviderType(rawValue: "openai") == .openai)
        #expect(ProviderType(rawValue: "anthropic") == .anthropic)
        #expect(ProviderType(rawValue: "google") == .google)
        #expect(ProviderType(rawValue: "cohere") == .cohere)
        #expect(ProviderType(rawValue: "mistral") == .mistral)
    }

    @Test("ProviderType returns nil for invalid raw value")
    func testInvalidRawValue() {
        #expect(ProviderType(rawValue: "invalid") == nil)
        #expect(ProviderType(rawValue: "gemini") == nil)
        #expect(ProviderType(rawValue: "") == nil)
    }

    // MARK: - Display Names

    @Test("All providers have human-readable display names")
    func testDisplayNames() {
        #expect(ProviderType.openai.displayName == "OpenAI")
        #expect(ProviderType.anthropic.displayName == "Anthropic")
        #expect(ProviderType.google.displayName == "Google AI")
        #expect(ProviderType.cohere.displayName == "Cohere")
        #expect(ProviderType.mistral.displayName == "Mistral AI")
    }

    @Test("Display names are properly capitalized")
    func testDisplayNamesCapitalization() {
        for provider in ProviderType.allCases {
            let name = provider.displayName
            #expect(!name.isEmpty, "Provider \(provider) should have a display name")
            #expect(name.first?.isUppercase == true, "Display name '\(name)' should start with uppercase")
        }
    }

    @Test("Display names differ from raw values")
    func testDisplayNamesDifferFromRaw() {
        // Display names should be human-friendly, not just raw values
        #expect(ProviderType.openai.displayName != ProviderType.openai.rawValue)
        #expect(ProviderType.google.displayName != ProviderType.google.rawValue)
    }

    // MARK: - Base URLs

    @Test("All providers have valid base URLs")
    func testBaseURLs() {
        #expect(ProviderType.openai.baseURL == "https://api.openai.com/v1")
        #expect(ProviderType.anthropic.baseURL == "https://api.anthropic.com/v1")
        #expect(ProviderType.google.baseURL == "https://generativelanguage.googleapis.com/v1")
        #expect(ProviderType.cohere.baseURL == "https://api.cohere.ai/v1")
        #expect(ProviderType.mistral.baseURL == "https://api.mistral.ai/v1")
    }

    @Test("Base URLs use HTTPS")
    func testBaseURLsHTTPS() {
        for provider in ProviderType.allCases {
            #expect(provider.baseURL.hasPrefix("https://"), "Provider \(provider) should use HTTPS")
        }
    }

    @Test("Base URLs are well-formed")
    func testBaseURLsWellFormed() {
        for provider in ProviderType.allCases {
            let url = provider.baseURL
            #expect(!url.isEmpty, "Provider \(provider) should have a base URL")
            #expect(url.contains("://"), "Base URL should contain protocol separator")
            #expect(!url.hasSuffix("/"), "Base URL should not end with slash")
        }
    }

    @Test("Base URLs contain version suffix")
    func testBaseURLsVersion() {
        for provider in ProviderType.allCases {
            // Perplexity doesn't use /v1 suffix
            if provider == .perplexity {
                continue
            }
            #expect(provider.baseURL.hasSuffix("/v1"), "Provider \(provider) base URL should end with /v1")
        }
    }

    @Test("Base URLs are unique per provider")
    func testBaseURLsUnique() {
        let urls = ProviderType.allCases.map { $0.baseURL }
        let uniqueURLs = Set(urls)
        #expect(urls.count == uniqueURLs.count, "Each provider should have a unique base URL")
    }

    // MARK: - Hashable Conformance

    @Test("ProviderType is Hashable")
    func testHashable() {
        let provider1 = ProviderType.anthropic
        let provider2 = ProviderType.anthropic
        let provider3 = ProviderType.openai

        #expect(provider1.hashValue == provider2.hashValue)
        #expect(provider1.hashValue != provider3.hashValue)
    }

    @Test("ProviderType can be used in Set")
    func testUsableInSet() {
        let providers: Set<ProviderType> = [.anthropic, .openai, .anthropic]
        #expect(providers.count == 2)
        #expect(providers.contains(.anthropic))
        #expect(providers.contains(.openai))
        #expect(!providers.contains(.google))
    }

    @Test("ProviderType can be used as Dictionary key")
    func testUsableAsDictionaryKey() {
        let apiKeys: [ProviderType: String] = [
            .anthropic: "sk-ant-123",
            .openai: "sk-openai-456",
            .cohere: "sk-cohere-789"
        ]

        #expect(apiKeys[.anthropic] == "sk-ant-123")
        #expect(apiKeys[.openai] == "sk-openai-456")
        #expect(apiKeys[.cohere] == "sk-cohere-789")
        #expect(apiKeys[.google] == nil)
    }

    // MARK: - Codable Conformance

    @Test("ProviderType is Codable (encode)")
    func testCodableEncode() throws {
        let provider = ProviderType.anthropic
        let data = try JSONEncoder().encode(provider)
        let decoded = String(data: data, encoding: .utf8)

        #expect(decoded?.contains("anthropic") == true)
    }

    @Test("ProviderType is Codable (decode)")
    func testCodableDecode() throws {
        let json = "\"anthropic\"".data(using: .utf8)!
        let provider = try JSONDecoder().decode(ProviderType.self, from: json)

        #expect(provider == .anthropic)
    }

    @Test("ProviderType encodes to JSON string")
    func testEncodesToString() throws {
        let provider = ProviderType.openai
        let encoder = JSONEncoder()
        let data = try encoder.encode(provider)
        let string = String(data: data, encoding: .utf8)

        #expect(string == "\"openai\"")
    }

    @Test("ProviderType can be decoded from all raw values")
    func testDecodeAllRawValues() throws {
        for provider in ProviderType.allCases {
            let json = "\"\(provider.rawValue)\"".data(using: .utf8)!
            let decoded = try JSONDecoder().decode(ProviderType.self, from: json)
            #expect(decoded == provider)
        }
    }

    @Test("ProviderType in struct is Codable")
    func testCodableInStruct() throws {
        struct TestConfig: Codable {
            let provider: ProviderType
            let apiKey: String
        }

        let config = TestConfig(provider: .anthropic, apiKey: "sk-123")
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestConfig.self, from: data)

        #expect(decoded.provider == .anthropic)
        #expect(decoded.apiKey == "sk-123")
    }

    @Test("ProviderType array is Codable")
    func testCodableArray() throws {
        let providers: [ProviderType] = [.anthropic, .openai, .google]
        let data = try JSONEncoder().encode(providers)
        let decoded = try JSONDecoder().decode([ProviderType].self, from: data)

        #expect(decoded.count == 3)
        #expect(decoded[0] == .anthropic)
        #expect(decoded[1] == .openai)
        #expect(decoded[2] == .google)
    }

    // MARK: - Sendable Conformance

    @Test("ProviderType is Sendable")
    func testSendable() async {
        // This test verifies that ProviderType can be safely used across actor boundaries
        let provider = ProviderType.anthropic

        await Task {
            // Should compile without warnings
            _ = provider.displayName
            _ = provider.baseURL
        }.value
    }

    // MARK: - Equatable Conformance

    @Test("Same providers are equal")
    func testEquality() {
        let provider1 = ProviderType.anthropic
        let provider2 = ProviderType.anthropic

        #expect(provider1 == provider2)
    }

    @Test("Different providers are not equal")
    func testInequality() {
        let provider1 = ProviderType.anthropic
        let provider2 = ProviderType.openai

        #expect(provider1 != provider2)
    }

    @Test("All providers are distinct")
    func testAllDistinct() {
        let providers = ProviderType.allCases
        for i in 0..<providers.count {
            for j in (i+1)..<providers.count {
                #expect(providers[i] != providers[j], "\(providers[i]) should not equal \(providers[j])")
            }
        }
    }

    // MARK: - Provider Properties

    @Test("All providers have required properties")
    func testAllProvidersComplete() {
        for provider in ProviderType.allCases {
            // Should not crash or return empty
            #expect(!provider.displayName.isEmpty, "Provider \(provider) missing display name")
            #expect(!provider.baseURL.isEmpty, "Provider \(provider) missing base URL")
            #expect(!provider.rawValue.isEmpty, "Provider \(provider) missing raw value")
        }
    }

    // MARK: - Real-World Scenarios

    @Test("Scenario: Configure multiple providers with API keys")
    func testMultiProviderConfiguration() {
        let config: [ProviderType: String] = [
            .anthropic: "sk-ant-production-key",
            .openai: "sk-openai-production-key",
            .cohere: "sk-cohere-production-key"
        ]

        #expect(config.keys.count == 3)
        #expect(config[.anthropic] != nil)
        #expect(config[.openai] != nil)
        #expect(config[.cohere] != nil)
    }

    @Test("Scenario: Iterate over all supported providers")
    func testIterateProviders() {
        var displayNames: [String] = []

        for provider in ProviderType.allCases {
            displayNames.append(provider.displayName)
        }

        #expect(displayNames.count == 6)
        #expect(displayNames.contains("Anthropic"))
        #expect(displayNames.contains("OpenAI"))
    }

    @Test("Scenario: Build request URL for provider")
    func testBuildRequestURL() {
        let provider = ProviderType.anthropic
        let endpoint = "/messages"
        let fullURL = provider.baseURL + endpoint

        #expect(fullURL == "https://api.anthropic.com/v1/messages")
    }

    @Test("Scenario: Store provider preferences in user settings")
    func testUserSettingsStorage() throws {
        struct UserSettings: Codable {
            let preferredProvider: ProviderType
            let fallbackProviders: [ProviderType]
        }

        let settings = UserSettings(
            preferredProvider: .anthropic,
            fallbackProviders: [.openai, .cohere]
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(UserSettings.self, from: data)

        #expect(decoded.preferredProvider == .anthropic)
        #expect(decoded.fallbackProviders.count == 2)
    }

    @Test("Scenario: Filter providers by feature support")
    func testFilterProviders() {
        // Example: filter providers that have "AI" in their display name
        let aiProviders = ProviderType.allCases.filter {
            $0.displayName.contains("AI")
        }

        #expect(aiProviders.contains(.google))
        #expect(aiProviders.contains(.mistral))
    }

    @Test("Scenario: Map providers to their base URLs")
    func testMapToBaseURLs() {
        let urlMapping = Dictionary(
            uniqueKeysWithValues: ProviderType.allCases.map { ($0, $0.baseURL) }
        )

        #expect(urlMapping.count == 6)
        #expect(urlMapping[.anthropic] == "https://api.anthropic.com/v1")
        #expect(urlMapping[.openai] == "https://api.openai.com/v1")
    }

    // MARK: - Edge Cases

    @Test("Raw value is lowercase")
    func testRawValueLowercase() {
        for provider in ProviderType.allCases {
            #expect(provider.rawValue == provider.rawValue.lowercased(),
                   "Raw value should be lowercase: \(provider.rawValue)")
        }
    }

    @Test("Provider type works in switch statements")
    func testSwitchExhaustiveness() {
        let provider = ProviderType.anthropic

        let result: String
        switch provider {
        case .openai:
            result = "openai"
        case .anthropic:
            result = "anthropic"
        case .google:
            result = "google"
        case .perplexity:
            result = "perplexity"
        case .cohere:
            result = "cohere"
        case .mistral:
            result = "mistral"
        case .deepseek:
            result = "deepseek"
        case .grok:
            result = "grok"
        }

        #expect(result == "anthropic")
    }

    @Test("Can create Set of all providers")
    func testSetOfAllProviders() {
        let allProviders = Set(ProviderType.allCases)
        #expect(allProviders.count == 8)
    }

    @Test("Dictionary with provider keys maintains insertion")
    func testDictionaryKeyOrder() {
        var config: [ProviderType: String] = [:]
        config[.anthropic] = "key1"
        config[.openai] = "key2"
        config[.anthropic] = "key1-updated"

        #expect(config.count == 2)
        #expect(config[.anthropic] == "key1-updated")
    }
}
