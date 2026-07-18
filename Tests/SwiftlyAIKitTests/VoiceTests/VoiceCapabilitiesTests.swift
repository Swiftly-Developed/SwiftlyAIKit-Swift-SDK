import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for the ``VoiceCapabilities`` metadata registry
///
/// Each vendor integration fills its own arm. ElevenLabs and Cartesia are now populated; Deepgram
/// and OpenAI remain seeded empty pending their own integrations. These tests pin the seeded arms,
/// assert the populated ElevenLabs and Cartesia arms, and — by iterating every case — guarantee the
/// switches remain exhaustive and total across all ``VoiceProviderType`` values.
@Suite("VoiceCapabilities Tests")
struct VoiceCapabilitiesTests {
    /// Providers whose arms are still seeded empty (no TTS/STT support) pending their own integration.
    private static let unseededProviders: [VoiceProviderType] = [.deepgram, .openai]

    /// Providers that expose no static voice catalog (either unintegrated, or fetching voices at
    /// runtime like Cartesia). ElevenLabs is the only provider that seeds a static voice list.
    private static let providersWithoutStaticVoices: [VoiceProviderType] = [.deepgram, .openai, .cartesia]

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

    @Test("voices is empty for every provider except ElevenLabs (others fetch at runtime)")
    func testVoicesSeed() {
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
