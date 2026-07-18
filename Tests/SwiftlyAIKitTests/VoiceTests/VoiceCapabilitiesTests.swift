import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for the ``VoiceCapabilities`` metadata registry
///
/// The registry is seeded empty in the foundation; each vendor integration fills its own arm.
/// These tests pin the seeded state and — by iterating every case — guarantee the switches
/// remain exhaustive and total across all ``VoiceProviderType`` values.
@Suite("VoiceCapabilities Tests")
struct VoiceCapabilitiesTests {
    // MARK: - Seeded State

    @Test("ttsSupported is seeded false for every provider")
    func testTTSSupportedSeed() {
        for provider in VoiceProviderType.allCases {
            #expect(VoiceCapabilities.ttsSupported(by: provider) == false)
        }
    }

    @Test("sttSupported is seeded false for every provider")
    func testSTTSupportedSeed() {
        for provider in VoiceProviderType.allCases {
            #expect(VoiceCapabilities.sttSupported(by: provider) == false)
        }
    }

    @Test("ttsModels is seeded empty for every provider")
    func testTTSModelsSeed() {
        for provider in VoiceProviderType.allCases {
            #expect(VoiceCapabilities.ttsModels(for: provider).isEmpty)
        }
    }

    @Test("sttModels is seeded empty for every provider")
    func testSTTModelsSeed() {
        for provider in VoiceProviderType.allCases {
            #expect(VoiceCapabilities.sttModels(for: provider).isEmpty)
        }
    }

    @Test("voices is seeded empty for every provider")
    func testVoicesSeed() {
        for provider in VoiceProviderType.allCases {
            #expect(VoiceCapabilities.voices(for: provider).isEmpty)
        }
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
