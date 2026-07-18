import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for ``CartesiaVoiceProvider`` — TTS request mapping, SSE streaming assembly,
/// STT decoding, and the always-present authentication headers.
///
/// The SDK has no HTTP-mock injection, so these tests drive the provider's internal helpers
/// (request builders, the SSE stream parser, response mappers) against canned fixtures with
/// zero network — the same convention the chat provider suites use.
@Suite("CartesiaVoiceProvider Tests")
struct CartesiaVoiceProviderTests {
    // MARK: - Helpers

    private func provider() -> CartesiaVoiceProvider { CartesiaVoiceProvider() }

    private func dataStream(_ chunks: [Data]) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            for chunk in chunks { continuation.yield(chunk) }
            continuation.finish()
        }
    }

    private func collectAudio(_ networkChunks: [Data]) async throws -> [SpeechAudioChunk] {
        var out: [SpeechAudioChunk] = []
        for try await chunk in provider().makeAudioChunkStream(from: dataStream(networkChunks)) {
            out.append(chunk)
        }
        return out
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Headers (both required on every call)

    @Test("authHeaders always include X-API-Key and Cartesia-Version")
    func testAuthHeadersCarryBothRequiredHeaders() {
        let headers = provider().authHeaders(apiKey: "sk_car_test")
        let dict = Dictionary(uniqueKeysWithValues: headers)

        #expect(dict["X-API-Key"] == "sk_car_test")
        #expect(dict["Cartesia-Version"] == CartesiaVoiceProvider.defaultAPIVersion)
    }

    @Test("jsonHeaders (TTS path) include X-API-Key, Cartesia-Version and JSON content type")
    func testJSONHeadersSupersetOfAuth() {
        let headers = provider().jsonHeaders(apiKey: "sk_car_test")
        let dict = Dictionary(uniqueKeysWithValues: headers)

        #expect(dict["X-API-Key"] == "sk_car_test")
        #expect(dict["Cartesia-Version"] == CartesiaVoiceProvider.defaultAPIVersion)
        #expect(dict["Content-Type"] == "application/json")
    }

    @Test("A custom Cartesia-Version propagates to every request's headers")
    func testCustomAPIVersionPropagates() {
        let custom = CartesiaVoiceProvider(apiVersion: "2099-01-01")
        let auth = Dictionary(uniqueKeysWithValues: custom.authHeaders(apiKey: "k"))
        let json = Dictionary(uniqueKeysWithValues: custom.jsonHeaders(apiKey: "k"))

        #expect(auth["Cartesia-Version"] == "2099-01-01")
        #expect(json["Cartesia-Version"] == "2099-01-01")
    }

    // MARK: - synthesize: request body mapping

    @Test("makeTTSRequest maps the neutral request onto the Cartesia body")
    func testTTSRequestMapping() throws {
        let request = SpeechSynthesisRequest(
            text: "Hello there.",
            model: "sonic-3",
            voice: "voice-123",
            format: .mp3,
            sampleRate: 24_000
        )

        let data = try provider().makeTTSRequestData(from: request)
        let json = try jsonObject(data)

        #expect(json["model_id"] as? String == "sonic-3")
        #expect(json["transcript"] as? String == "Hello there.")

        let voice = try #require(json["voice"] as? [String: Any])
        #expect(voice["mode"] as? String == "id")
        #expect(voice["id"] as? String == "voice-123")

        let format = try #require(json["output_format"] as? [String: Any])
        #expect(format["container"] as? String == "mp3")
        #expect(format["sample_rate"] as? Int == 24_000)
        #expect(format["bit_rate"] as? Int == CartesiaVoiceProvider.defaultMP3BitRate)
    }

    @Test("makeTTSRequest requires a voice id")
    func testTTSRequestRequiresVoice() {
        let request = SpeechSynthesisRequest(text: "Hi", model: "sonic-3", voice: nil)
        #expect(throws: AIError.missingParameter(name: "voice")) {
            _ = try provider().makeTTSRequest(from: request)
        }
    }

    @Test("output format maps wav and pcm to Cartesia containers with PCM encoding")
    func testOutputFormatContainers() throws {
        let wav = try CartesiaVoiceProvider.outputFormat(for: .wav, sampleRate: nil)
        #expect(wav.container == "wav")
        #expect(wav.encoding == "pcm_s16le")
        #expect(wav.sampleRate == CartesiaVoiceProvider.defaultSampleRate)

        let pcm = try CartesiaVoiceProvider.outputFormat(for: .pcm, sampleRate: 16_000)
        #expect(pcm.container == "raw")
        #expect(pcm.encoding == "pcm_s16le")
        #expect(pcm.sampleRate == 16_000)
    }

    @Test("output format rejects containers Cartesia cannot produce")
    func testOutputFormatRejectsUnsupported() {
        for format in [AudioFormat.opus, .flac, .aac] {
            #expect(throws: (any Error).self) {
                _ = try CartesiaVoiceProvider.outputFormat(for: format, sampleRate: nil)
            }
        }
    }

    // MARK: - streamSynthesize: SSE assembly

    @Test("streamSynthesize assembles base64 audio chunks and stops on done")
    func testStreamAssemblesChunks() async throws {
        let audio1 = Data([0x01, 0x02, 0x03])
        let audio2 = Data([0x04, 0x05, 0x06, 0x07])

        let networkChunks: [Data] = [
            Data(MockCartesiaAPI.chunkFrame(audio1).utf8),
            Data(MockCartesiaAPI.timestampsFrame.utf8),   // must be ignored
            Data(MockCartesiaAPI.chunkFrame(audio2).utf8),
            Data(MockCartesiaAPI.doneFrame.utf8)
        ]

        let chunks = try await collectAudio(networkChunks)

        #expect(chunks.count == 2)
        #expect(chunks[0].audio == audio1)
        #expect(chunks[1].audio == audio2)
    }

    @Test("streamSynthesize reassembles SSE frames split across network chunks")
    func testStreamReassemblesSplitFrames() async throws {
        let audio1 = Data([0xAA, 0xBB, 0xCC, 0xDD, 0xEE])
        let audio2 = Data([0x11, 0x22, 0x33])

        // One contiguous SSE byte stream, then cut at an arbitrary mid-frame offset so a
        // `data:` line straddles the network-chunk boundary.
        let full = Data((MockCartesiaAPI.chunkFrame(audio1)
            + MockCartesiaAPI.chunkFrame(audio2)
            + MockCartesiaAPI.doneFrame).utf8)
        let cut = full.count / 2
        let networkChunks = [full.prefix(cut), full.suffix(from: cut)].map { Data($0) }

        let chunks = try await collectAudio(networkChunks)

        #expect(chunks.count == 2)
        #expect(chunks[0].audio == audio1)
        #expect(chunks[1].audio == audio2)
    }

    @Test("streamSynthesize surfaces an error event as a streaming error")
    func testStreamSurfacesErrorEvent() async {
        let networkChunks = [Data(MockCartesiaAPI.errorFrame("bad voice").utf8)]

        await #expect(throws: AIError.streamingError(message: "bad voice")) {
            _ = try await collectAudio(networkChunks)
        }
    }

    // MARK: - transcribe: STT decoding + multipart

    @Test("transcribe decodes an Ink-Whisper response into the neutral transcript")
    func testTranscriptionDecoding() throws {
        let data = Data(MockCartesiaAPI.transcriptionResponse.utf8)
        let decoded = try JSONDecoder().decode(CartesiaTranscriptionResponse.self, from: data)
        let mapped = provider().mapTranscription(decoded)

        #expect(mapped.text == "Hello world")
        #expect(mapped.language == "en")
        #expect(mapped.durationSeconds == 1.25)

        let words = try #require(mapped.words)
        #expect(words.count == 2)
        #expect(words[0].word == "Hello")
        #expect(words[0].startSeconds == 0.0)
        #expect(words[1].word == "world")
        #expect(words[1].endSeconds == 1.0)
    }

    @Test("multipart body carries the model, audio bytes, and word-timestamp field")
    func testMultipartBody() throws {
        let audio = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let request = TranscriptionRequest(
            audio: audio,
            model: "ink-whisper",
            language: "en",
            mimeType: "audio/wav"
        )

        let boundary = "TESTBOUNDARY"
        let body = provider().makeMultipartBody(from: request, boundary: boundary)

        // The body embeds raw (non-UTF-8) audio. Latin-1 maps every byte 0–255 to a character
        // losslessly, so the whole body decodes and substring checks stay simple.
        let text = try #require(String(data: body, encoding: .isoLatin1))
        let audioLatin1 = try #require(String(data: audio, encoding: .isoLatin1))

        #expect(text.contains("--TESTBOUNDARY\r\n"))
        #expect(text.contains("name=\"model\"\r\n\r\nink-whisper\r\n"))
        #expect(text.contains("name=\"language\"\r\n\r\nen\r\n"))
        #expect(text.contains("name=\"timestamp_granularities[]\"\r\n\r\nword\r\n"))
        #expect(text.contains("name=\"file\"; filename=\"audio.wav\""))
        #expect(text.contains("Content-Type: audio/wav"))
        #expect(text.contains("--TESTBOUNDARY--\r\n"))
        // The raw audio bytes must be embedded verbatim.
        #expect(text.contains(audioLatin1))
    }

    // MARK: - Voices

    @Test("listVoices decoding reads the data envelope")
    func testVoicesDecoding() throws {
        let data = Data(MockCartesiaAPI.voicesResponse.utf8)
        let decoded = try JSONDecoder().decode(CartesiaVoicesResponse.self, from: data)

        #expect(decoded.data.count == 1)
        #expect(decoded.data[0].id == "a0e99841-438c-4a64-b679-ae501e7d6091")
        #expect(decoded.data[0].name == "Barbershop Man")
        #expect(decoded.data[0].language == "en")
    }

    // MARK: - Capabilities

    @Test("Provider advertises Cartesia TTS and STT support")
    func testProviderCapabilityFlags() {
        let provider = provider()
        #expect(provider.supportsTextToSpeech)
        #expect(provider.supportsSpeechToText)
        #expect(provider.textToSpeechModels.contains("sonic-3"))
        #expect(provider.speechToTextModels == ["ink-whisper"])
    }
}
