import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for the ``VoiceCapabilities`` metadata registry
///
/// The registry is seeded empty in the foundation; each vendor integration fills its own arm.
/// ElevenLabs is now populated, so these tests pin the ElevenLabs arm to its populated values and
/// pin every *other* provider to the still-seeded (false/empty) state. Iterating every case also
/// guarantees the switches remain exhaustive and total across all ``VoiceProviderType`` values.
@Suite("VoiceCapabilities Tests")
struct VoiceCapabilitiesTests {
    /// Providers whose arms remain seeded (empty/false) — i.e. everything except ElevenLabs.
    private var seededProviders: [VoiceProviderType] {
        VoiceProviderType.allCases.filter { $0 != .elevenLabs }
    }

    // MARK: - Seeded State (non-ElevenLabs providers)

    @Test("ttsSupported is seeded false for every non-ElevenLabs provider")
    func testTTSSupportedSeed() {
        for provider in seededProviders {
            #expect(VoiceCapabilities.ttsSupported(by: provider) == false)
        }
    }

    @Test("sttSupported is seeded false for every non-ElevenLabs provider")
    func testSTTSupportedSeed() {
        for provider in seededProviders {
            #expect(VoiceCapabilities.sttSupported(by: provider) == false)
        }
    }

    @Test("ttsModels is seeded empty for every non-ElevenLabs provider")
    func testTTSModelsSeed() {
        for provider in seededProviders {
            #expect(VoiceCapabilities.ttsModels(for: provider).isEmpty)
        }
    }

    @Test("sttModels is seeded empty for every non-ElevenLabs provider")
    func testSTTModelsSeed() {
        for provider in seededProviders {
            #expect(VoiceCapabilities.sttModels(for: provider).isEmpty)
        }
    }

    @Test("voices is seeded empty for every non-ElevenLabs provider")
    func testVoicesSeed() {
        for provider in seededProviders {
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
