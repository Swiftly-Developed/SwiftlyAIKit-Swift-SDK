import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for the ``VoiceProviderType`` enum
@Suite("VoiceProviderType Tests")
struct VoiceProviderTypeTests {
    // MARK: - Enum Conformance

    @Test("VoiceProviderType is CaseIterable with four providers")
    func testCaseIterable() {
        let allCases = VoiceProviderType.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.elevenLabs))
        #expect(allCases.contains(.deepgram))
        #expect(allCases.contains(.cartesia))
        #expect(allCases.contains(.openai))
    }

    @Test("VoiceProviderType has correct raw values")
    func testRawValues() {
        #expect(VoiceProviderType.elevenLabs.rawValue == "elevenlabs")
        #expect(VoiceProviderType.deepgram.rawValue == "deepgram")
        #expect(VoiceProviderType.cartesia.rawValue == "cartesia")
        #expect(VoiceProviderType.openai.rawValue == "openai")
    }

    @Test("VoiceProviderType can be initialized from raw value")
    func testRawValueInit() {
        #expect(VoiceProviderType(rawValue: "elevenlabs") == .elevenLabs)
        #expect(VoiceProviderType(rawValue: "deepgram") == .deepgram)
        #expect(VoiceProviderType(rawValue: "cartesia") == .cartesia)
        #expect(VoiceProviderType(rawValue: "openai") == .openai)
        // The camelCased case name is NOT a valid raw value.
        #expect(VoiceProviderType(rawValue: "elevenLabs") == nil)
        #expect(VoiceProviderType(rawValue: "invalid") == nil)
    }

    // MARK: - Display Names

    @Test("All voice providers have human-readable display names")
    func testDisplayNames() {
        #expect(VoiceProviderType.elevenLabs.displayName == "ElevenLabs")
        #expect(VoiceProviderType.deepgram.displayName == "Deepgram")
        #expect(VoiceProviderType.cartesia.displayName == "Cartesia")
        #expect(VoiceProviderType.openai.displayName == "OpenAI")
    }

    @Test("Display names are non-empty")
    func testDisplayNamesNonEmpty() {
        for provider in VoiceProviderType.allCases {
            #expect(!provider.displayName.isEmpty, "Provider \(provider) should have a display name")
        }
    }

    // MARK: - Base URLs

    @Test("All voice providers have correct base URLs")
    func testBaseURLs() {
        #expect(VoiceProviderType.elevenLabs.baseURL == "https://api.elevenlabs.io/v1")
        #expect(VoiceProviderType.deepgram.baseURL == "https://api.deepgram.com/v1")
        #expect(VoiceProviderType.cartesia.baseURL == "https://api.cartesia.ai")
        #expect(VoiceProviderType.openai.baseURL == "https://api.openai.com/v1")
    }

    @Test("Base URLs use HTTPS and are well-formed")
    func testBaseURLsWellFormed() {
        for provider in VoiceProviderType.allCases {
            let url = provider.baseURL
            #expect(url.hasPrefix("https://"), "Provider \(provider) should use HTTPS")
            #expect(!url.hasSuffix("/"), "Base URL should not end with a slash")
        }
    }

    // MARK: - Separation From Chat ProviderType

    @Test("openai voice token reuses the OpenAI key/base but is its own type")
    func testOpenAISharesOpenAIBase() {
        // Same underlying OpenAI host, but a distinct enum from the chat axis.
        #expect(VoiceProviderType.openai.baseURL == ProviderType.openai.baseURL)
        #expect(VoiceProviderType.openai.rawValue == ProviderType.openai.rawValue)
    }

    // MARK: - Codable Conformance

    @Test("VoiceProviderType round-trips through Codable")
    func testCodableRoundTrip() throws {
        for provider in VoiceProviderType.allCases {
            let data = try JSONEncoder().encode(provider)
            let decoded = try JSONDecoder().decode(VoiceProviderType.self, from: data)
            #expect(decoded == provider)
        }
    }

    @Test("VoiceProviderType encodes to its raw value string")
    func testEncodesToRawValueString() throws {
        let data = try JSONEncoder().encode(VoiceProviderType.elevenLabs)
        let string = String(data: data, encoding: .utf8)
        #expect(string == "\"elevenlabs\"")
    }

    // MARK: - Hashable Conformance

    @Test("VoiceProviderType is usable as a Set / Dictionary key")
    func testHashable() {
        let set: Set<VoiceProviderType> = [.elevenLabs, .deepgram, .elevenLabs]
        #expect(set.count == 2)

        let keys: [VoiceProviderType: String] = [.cartesia: "c", .openai: "o"]
        #expect(keys[.cartesia] == "c")
        #expect(keys[.deepgram] == nil)
    }

    // MARK: - Exhaustiveness

    @Test("VoiceProviderType works in exhaustive switch")
    func testSwitchExhaustiveness() {
        for provider in VoiceProviderType.allCases {
            let label: String
            switch provider {
            case .elevenLabs: label = "elevenLabs"
            case .deepgram: label = "deepgram"
            case .cartesia: label = "cartesia"
            case .openai: label = "openai"
            }
            #expect(!label.isEmpty)
        }
    }
}
