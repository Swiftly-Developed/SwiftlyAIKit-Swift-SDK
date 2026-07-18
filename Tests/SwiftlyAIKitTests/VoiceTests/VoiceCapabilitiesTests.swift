import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for the ``VoiceCapabilities`` metadata registry
///
/// The registry is seeded empty in the foundation; each vendor integration fills its own arm.
/// The OpenAI integration fills the ``VoiceProviderType/openai`` arm — these tests pin that
/// filled state while confirming the three unseeded arms stay empty/false, and — by iterating
/// every case — guarantee the switches remain exhaustive and total across all
/// ``VoiceProviderType`` values.
@Suite("VoiceCapabilities Tests")
struct VoiceCapabilitiesTests {
    /// Voice providers whose arms are still seeded empty/false (everything except `.openai`).
    private static let unseededProviders: [VoiceProviderType] =
        VoiceProviderType.allCases.filter { $0 != .openai }

    // MARK: - Seeded State (unseeded arms stay empty/false)

    @Test("ttsSupported is false for every unseeded provider")
    func testTTSSupportedSeed() {
        for provider in Self.unseededProviders {
            #expect(VoiceCapabilities.ttsSupported(by: provider) == false)
        }
    }

    @Test("sttSupported is false for every unseeded provider")
    func testSTTSupportedSeed() {
        for provider in Self.unseededProviders {
            #expect(VoiceCapabilities.sttSupported(by: provider) == false)
        }
    }

    @Test("ttsModels is empty for every unseeded provider")
    func testTTSModelsSeed() {
        for provider in Self.unseededProviders {
            #expect(VoiceCapabilities.ttsModels(for: provider).isEmpty)
        }
    }

    @Test("sttModels is empty for every unseeded provider")
    func testSTTModelsSeed() {
        for provider in Self.unseededProviders {
            #expect(VoiceCapabilities.sttModels(for: provider).isEmpty)
        }
    }

    @Test("voices is empty for every unseeded provider")
    func testVoicesSeed() {
        for provider in Self.unseededProviders {
            #expect(VoiceCapabilities.voices(for: provider).isEmpty)
        }
    }

    // MARK: - OpenAI Arm (filled)

    @Test("OpenAI arm reports TTS and STT support with non-empty registries")
    func testOpenAIArmFilled() {
        #expect(VoiceCapabilities.ttsSupported(by: .openai))
        #expect(VoiceCapabilities.sttSupported(by: .openai))
        #expect(VoiceCapabilities.ttsModels(for: .openai) == OpenAIVoiceProvider.ttsModels)
        #expect(VoiceCapabilities.sttModels(for: .openai) == OpenAIVoiceProvider.sttModels)
        #expect(VoiceCapabilities.voices(for: .openai) == OpenAIVoiceProvider.voices)
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
