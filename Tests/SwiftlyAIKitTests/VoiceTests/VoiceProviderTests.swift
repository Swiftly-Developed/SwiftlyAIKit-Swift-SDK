import Testing
import Foundation
@testable import SwiftlyAIKit

/// A bare conformer that implements neither protocol's methods, exercising the
/// default (unsupported) implementations. It is not a chat `ProviderProtocol`, so the
/// default error identity falls back to `.openai`.
private struct StubVoiceProvider: TextToSpeech, SpeechToText {}

/// Tests for the ``TextToSpeech`` / ``SpeechToText`` protocol defaults
@Suite("Voice Provider Protocol Tests")
struct VoiceProviderTests {
    // MARK: - Default Capability Flags

    @Test("TextToSpeech defaults to unsupported with no models")
    func testTextToSpeechDefaults() {
        let stub = StubVoiceProvider()
        #expect(stub.supportsTextToSpeech == false)
        #expect(stub.textToSpeechModels.isEmpty)
    }

    @Test("SpeechToText defaults to unsupported with no models")
    func testSpeechToTextDefaults() {
        let stub = StubVoiceProvider()
        #expect(stub.supportsSpeechToText == false)
        #expect(stub.speechToTextModels.isEmpty)
    }

    // MARK: - Default One-Shot Methods Throw

    @Test("Default synthesize throws unsupportedFeature")
    func testSynthesizeThrowsUnsupported() async {
        let stub = StubVoiceProvider()
        let request = SpeechSynthesisRequest(text: "Hello", model: "m")

        await #expect(throws: AIError.unsupportedFeature(feature: "text-to-speech", provider: .openai)) {
            _ = try await stub.synthesize(request, apiKey: "key")
        }
    }

    @Test("Default transcribe throws unsupportedFeature")
    func testTranscribeThrowsUnsupported() async {
        let stub = StubVoiceProvider()
        let request = TranscriptionRequest(audio: Data([0x00, 0x01]), model: "m")

        await #expect(throws: AIError.unsupportedFeature(feature: "speech-to-text", provider: .openai)) {
            _ = try await stub.transcribe(request, apiKey: "key")
        }
    }

    // MARK: - Default Streaming Methods Finish Throwing

    @Test("Default streamSynthesize finishes with unsupportedFeature")
    func testStreamSynthesizeThrowsUnsupported() async {
        let stub = StubVoiceProvider()
        let request = SpeechSynthesisRequest(text: "Hello", model: "m")
        let stream = stub.streamSynthesize(request, apiKey: "key")

        await #expect(throws: AIError.unsupportedFeature(feature: "text-to-speech", provider: .openai)) {
            for try await _ in stream {
                // No chunks are ever produced by the default implementation.
            }
        }
    }

    @Test("Default streamTranscribe finishes with unsupportedFeature")
    func testStreamTranscribeThrowsUnsupported() async {
        let stub = StubVoiceProvider()
        let request = TranscriptionRequest(audio: Data([0x00, 0x01]), model: "m")
        let stream = stub.streamTranscribe(request, apiKey: "key")

        await #expect(throws: AIError.unsupportedFeature(feature: "speech-to-text", provider: .openai)) {
            for try await _ in stream {
                // No chunks are ever produced by the default implementation.
            }
        }
    }
}
