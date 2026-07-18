import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for ``ElevenLabsVoiceProvider``.
///
/// Following the SDK convention, these tests drive the provider's internal helpers and decode
/// canned fixtures — there is no `MockHTTPClient`, so no network is touched.
@Suite("ElevenLabsVoiceProvider Tests")
struct ElevenLabsProviderTests {
    // MARK: - 1. Speech Request Body

    @Test("buildSpeechRequestBody encodes text, model_id, and voice_settings.speed")
    func testBuildSpeechRequestBody() throws {
        let provider = ElevenLabsVoiceProvider()
        let request = SpeechSynthesisRequest(
            text: "Hello, world.",
            model: "eleven_multilingual_v2",
            voice: "21m00Tcm4TlvDq8ikWAM",
            format: .mp3,
            speed: 1.15
        )

        let body = try provider.buildSpeechRequestBody(from: request)
        let json = try #require(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        )

        #expect(json["text"] as? String == "Hello, world.")
        #expect(json["model_id"] as? String == "eleven_multilingual_v2")

        let voiceSettings = try #require(json["voice_settings"] as? [String: Any])
        #expect(voiceSettings["speed"] as? Double == 1.15)
    }

    @Test("buildSpeechRequestBody omits voice_settings when speed is nil")
    func testBuildSpeechRequestBodyNoSpeed() throws {
        let provider = ElevenLabsVoiceProvider()
        let request = SpeechSynthesisRequest(text: "Hi", model: "eleven_turbo_v2_5")

        let body = try provider.buildSpeechRequestBody(from: request)
        let json = try #require(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        )

        #expect(json["text"] as? String == "Hi")
        #expect(json["voice_settings"] == nil)
    }

    // MARK: - 2. Output Format Mapping

    @Test("outputFormat maps supported formats and throws for flac/aac")
    func testOutputFormatMapping() throws {
        let provider = ElevenLabsVoiceProvider()

        #expect(try provider.outputFormat(for: .mp3) == "mp3_44100_128")
        #expect(try provider.outputFormat(for: .wav) == "wav_44100")
        #expect(try provider.outputFormat(for: .pcm) == "pcm_44100")
        #expect(try provider.outputFormat(for: .opus) == "opus_48000_128")

        #expect(throws: AIError.self) { try provider.outputFormat(for: .flac) }
        #expect(throws: AIError.self) { try provider.outputFormat(for: .aac) }
    }

    // MARK: - 3. Headers

    @Test("buildHeaders uses xi-api-key and never Authorization")
    func testBuildHeaders() {
        let provider = ElevenLabsVoiceProvider()
        let headers = provider.buildHeaders(apiKey: "sk-test-key")

        #expect(headers.contains { $0.0 == "xi-api-key" && $0.1 == "sk-test-key" })
        #expect(!headers.contains { $0.0.lowercased() == "authorization" })
        #expect(headers.contains { $0.0 == "Content-Type" && $0.1 == "application/json" })
    }

    // MARK: - 4. TTS URL

    @Test("ttsURL builds one-shot and streaming paths with output_format query")
    func testTTSURL() {
        let provider = ElevenLabsVoiceProvider()
        let voiceID = "21m00Tcm4TlvDq8ikWAM"

        let oneShot = provider.ttsURL(voiceID: voiceID, outputFormat: "mp3_44100_128", streaming: false)
        #expect(oneShot == "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)?output_format=mp3_44100_128")

        let stream = provider.ttsURL(voiceID: voiceID, outputFormat: "mp3_44100_128", streaming: true)
        #expect(stream == "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)/stream?output_format=mp3_44100_128")
        #expect(stream.contains("/stream"))
    }

    // MARK: - 5. Transcription Mapping

    @Test("mapTranscription maps text, language, and word timing from a Scribe response")
    func testMapTranscription() throws {
        let provider = ElevenLabsVoiceProvider()
        let decoded = try JSONDecoder().decode(
            ElevenLabsTranscriptionResponse.self,
            from: MockElevenLabsAPI.responseAsData(MockElevenLabsAPI.transcriptionResponse)
        )

        let result = provider.mapTranscription(decoded)

        #expect(result.text == "Hello world.")
        #expect(result.language == "en")

        // Only "word"-typed tokens with timing survive: "Hello", "world", "." (spacing +
        // audio_event dropped).
        let words = try #require(result.words)
        #expect(words.count == 3)
        #expect(words.first?.word == "Hello")
        #expect(words.first?.startSeconds == 0.0)
        #expect(words.first?.endSeconds == 0.5)
        #expect(!words.contains { $0.word == " " })
    }

    // MARK: - 6. Multipart Body

    @Test("buildMultipartBody includes boundary, text field, and file part with filename")
    func testBuildMultipartBody() throws {
        let provider = ElevenLabsVoiceProvider()
        let boundary = "test-boundary-123"
        let audio = Data([0x01, 0x02, 0x03, 0x04])

        let body = provider.buildMultipartBody(
            fields: [(name: "model_id", value: "scribe_v1")],
            files: [ElevenLabsVoiceProvider.MultipartFile(
                name: "file", filename: "audio.mp3", mimeType: "audio/mpeg", data: audio
            )],
            boundary: boundary
        )

        let bodyString = try #require(String(data: body, encoding: .utf8))

        #expect(bodyString.contains("--\(boundary)"))
        #expect(bodyString.contains("--\(boundary)--"))
        #expect(bodyString.contains("name=\"model_id\""))
        #expect(bodyString.contains("scribe_v1"))
        #expect(bodyString.contains("name=\"file\""))
        #expect(bodyString.contains("filename=\"audio.mp3\""))
        #expect(bodyString.contains("Content-Type: audio/mpeg"))
    }

    // MARK: - 7. Voice Capabilities Registry

    @Test("VoiceCapabilities exposes ElevenLabs support, models, and voice IDs")
    func testVoiceCapabilities() {
        #expect(VoiceCapabilities.ttsSupported(by: .elevenLabs) == true)
        #expect(VoiceCapabilities.sttSupported(by: .elevenLabs) == true)

        #expect(VoiceCapabilities.ttsModels(for: .elevenLabs).contains("eleven_multilingual_v2"))
        #expect(VoiceCapabilities.sttModels(for: .elevenLabs).contains("scribe_v2"))
        #expect(VoiceCapabilities.voices(for: .elevenLabs).contains("21m00Tcm4TlvDq8ikWAM"))
    }

    // MARK: - 8. Provider Capability Surface

    @Test("Provider advertises TTS and STT support with non-empty model lists")
    func testProviderCapabilitySurface() {
        let provider = ElevenLabsVoiceProvider()

        #expect(provider.supportsTextToSpeech == true)
        #expect(provider.supportsSpeechToText == true)
        #expect(!provider.textToSpeechModels.isEmpty)
        #expect(!provider.speechToTextModels.isEmpty)
    }
}
