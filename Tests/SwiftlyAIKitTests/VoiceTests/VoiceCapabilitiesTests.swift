import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for the ``VoiceCapabilities`` metadata registry
///
/// Each vendor integration fills its own arm. These tests pin the state of the arms that are
/// still seeded empty (ElevenLabs, Deepgram, OpenAI), assert the filled Cartesia arm, and — by
/// iterating every case — guarantee the switches remain exhaustive and total across all
/// ``VoiceProviderType`` values.
@Suite("VoiceCapabilities Tests")
struct VoiceCapabilitiesTests {
    /// Providers whose arms are still seeded empty pending their own integration.
    private static let unseededProviders: [VoiceProviderType] = [.elevenLabs, .deepgram, .openai]

    // MARK: - Seeded (empty) State

    @Test("ttsSupported is seeded false for providers pending integration")
    func testTTSSupportedSeed() {
        for provider in Self.unseededProviders {
            #expect(VoiceCapabilities.ttsSupported(by: provider) == false)
        }
    }

    @Test("sttSupported is seeded false for providers pending integration")
    func testSTTSupportedSeed() {
        for provider in Self.unseededProviders {
            #expect(VoiceCapabilities.sttSupported(by: provider) == false)
        }
    }

    @Test("ttsModels is seeded empty for providers pending integration")
    func testTTSModelsSeed() {
        for provider in Self.unseededProviders {
            #expect(VoiceCapabilities.ttsModels(for: provider).isEmpty)
        }
    }

    @Test("sttModels is seeded empty for providers pending integration")
    func testSTTModelsSeed() {
        for provider in Self.unseededProviders {
            #expect(VoiceCapabilities.sttModels(for: provider).isEmpty)
        }
    }

    @Test("voices is empty for every provider (voice catalogs are fetched at runtime)")
    func testVoicesSeed() {
        for provider in VoiceProviderType.allCases {
            #expect(VoiceCapabilities.voices(for: provider).isEmpty)
        }
    }

    // MARK: - Cartesia Arm

    @Test("Cartesia arm advertises TTS + STT support with its model lists")
    func testCartesiaArmFilled() {
        #expect(VoiceCapabilities.ttsSupported(by: .cartesia))
        #expect(VoiceCapabilities.sttSupported(by: .cartesia))
        #expect(VoiceCapabilities.ttsModels(for: .cartesia).contains("sonic-3"))
        #expect(VoiceCapabilities.sttModels(for: .cartesia) == ["ink-whisper"])
    }

    // MARK: - Totality

    @Test("All registry lookups are total over every provider")
    func testRegistryIsTotal() {
        // Exercising each accessor for every case proves the exhaustive switches compile
        // and never trap for any current or future-seeded provider.
        for provider in VoiceProviderType.allCases {
            _ = VoiceCapabilities.ttsSupported(by: provider)
            _ = VoiceCapabilities.sttSupported(by: provider)
            _ = VoiceCapabilities.ttsModels(for: provider)
            _ = VoiceCapabilities.sttModels(for: provider)
            _ = VoiceCapabilities.voices(for: provider)
        }
    }
}
