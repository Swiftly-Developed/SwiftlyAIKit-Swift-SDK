import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for the ``VoiceCapabilities`` metadata registry
///
/// Each vendor integration fills its own arm. ElevenLabs, Cartesia, and Deepgram are now populated;
/// only OpenAI remains seeded empty pending its own integration. These tests pin the seeded arm,
/// assert the populated ElevenLabs/Cartesia/Deepgram arms, and — by iterating every case — guarantee
/// the switches remain exhaustive and total across all ``VoiceProviderType`` values.
@Suite("VoiceCapabilities Tests")
struct VoiceCapabilitiesTests {
    /// Providers whose arms are still seeded empty (no TTS/STT support) pending their own integration.
    private static let unseededProviders: [VoiceProviderType] = [.openai]

    /// Providers that expose no static voice catalog (either unintegrated, or fetching voices at
    /// runtime like Cartesia). ElevenLabs and Deepgram seed static voice lists.
    private static let providersWithoutStaticVoices: [VoiceProviderType] = [.openai, .cartesia]

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

    @Test("voices is empty for the providers whose catalogs are fetched at runtime")
    func testVoicesSeed() {
        // ElevenLabs and Deepgram seed static voice lists; Cartesia and OpenAI do not.
        for provider in Self.providersWithoutStaticVoices {
            #expect(VoiceCapabilities.voices(for: provider).isEmpty)
        }
    }

    // MARK: - ElevenLabs Arm (populated)

    @Test("ElevenLabs supports both text-to-speech and speech-to-text")
    func testElevenLabsSupported() {
        #expect(VoiceCapabilities.ttsSupported(by: .elevenLabs) == true)
        #expect(VoiceCapabilities.sttSupported(by: .elevenLabs) == true)
    }

    @Test("ElevenLabs advertises its TTS models")
    func testElevenLabsTTSModels() {
        let models = VoiceCapabilities.ttsModels(for: .elevenLabs)
        #expect(models.contains("eleven_multilingual_v2"))
        #expect(models.contains("eleven_turbo_v2_5"))
        #expect(models.contains("eleven_flash_v2_5"))
    }

    @Test("ElevenLabs advertises its Scribe STT models")
    func testElevenLabsSTTModels() {
        let models = VoiceCapabilities.sttModels(for: .elevenLabs)
        #expect(models.contains("scribe_v2"))
        #expect(models.contains("scribe_v1"))
    }

    @Test("ElevenLabs seeds a stable set of premade voice IDs")
    func testElevenLabsVoices() {
        let voices = VoiceCapabilities.voices(for: .elevenLabs)
        #expect(!voices.isEmpty)
        // Rachel (default) and Adam premade IDs.
        #expect(voices.contains("21m00Tcm4TlvDq8ikWAM"))
        #expect(voices.contains("pNInz6obpgDQGcFmaJgB"))
    }

    // MARK: - Cartesia Arm (populated)

    @Test("Cartesia arm advertises TTS + STT support with its model lists")
    func testCartesiaArmFilled() {
        #expect(VoiceCapabilities.ttsSupported(by: .cartesia))
        #expect(VoiceCapabilities.sttSupported(by: .cartesia))
        #expect(VoiceCapabilities.ttsModels(for: .cartesia).contains("sonic-3"))
        #expect(VoiceCapabilities.sttModels(for: .cartesia) == ["ink-whisper"])
    }

    // MARK: - Deepgram Arm (populated)

    @Test("Deepgram arm advertises TTS + STT support with its model lists")
    func testDeepgramArmFilled() {
        #expect(VoiceCapabilities.ttsSupported(by: .deepgram))
        #expect(VoiceCapabilities.sttSupported(by: .deepgram))
        #expect(VoiceCapabilities.sttModels(for: .deepgram) == ["nova-3", "nova-2"])
        #expect(VoiceCapabilities.ttsModels(for: .deepgram).contains("aura-2-thalia-en"))
        #expect(VoiceCapabilities.voices(for: .deepgram).contains("aura-2-thalia-en"))
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
