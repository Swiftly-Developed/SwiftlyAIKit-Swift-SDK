import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for `DeepgramVoiceProvider`.
///
/// Mirrors the Ollama test conventions: decode JSON fixtures and exercise the internal pure
/// helpers (URL/header/body building, response transformation, chunk wrapping) directly — no
/// HTTP client injection.
@Suite("Deepgram Voice Provider Tests")
struct DeepgramVoiceProviderTests {
    // MARK: - Speech-to-Text Transformation

    @Test("transcribe decodes nested channels/alternatives to TranscriptionResponse.text")
    func testTransformListenResponse() throws {
        let decoded = try JSONDecoder().decode(
            DeepgramListenResponse.self,
            from: MockDeepgramAPI.responseAsData(MockDeepgramAPI.listenResponse)
        )

        let response = try DeepgramVoiceProvider().transformListenResponse(decoded)

        #expect(response.text == "hello world")
        #expect(response.words?.count == 2)
        // Words prefer the punctuated display form.
        #expect(response.words?.first?.word == "Hello")
        #expect(response.words?.last?.word == "world.")
        #expect(response.words?.first?.startSeconds == 0.16)
        #expect(response.durationSeconds == 3.48)
        #expect(response.language == "en")
        #expect(response.segments == nil)
    }

    @Test("transformListenResponse throws on empty alternatives")
    func testTransformListenResponseThrowsOnEmpty() {
        let empty = DeepgramListenResponse(
            metadata: DeepgramMetadata(duration: 1.0),
            results: DeepgramResults(channels: [])
        )

        #expect(throws: AIError.self) {
            _ = try DeepgramVoiceProvider().transformListenResponse(empty)
        }
    }

    // MARK: - Headers

    @Test("STT headers use \"Authorization: Token\" (not Bearer)")
    func testListenHeaders() {
        let headers = DeepgramVoiceProvider().buildListenHeaders(apiKey: "test-key", mimeType: "audio/wav")

        let auth = headers.first { $0.0 == "Authorization" }
        #expect(auth?.1 == "Token test-key")
        #expect(auth?.1.hasPrefix("Bearer") == false)

        let contentType = headers.first { $0.0 == "Content-Type" }
        #expect(contentType?.1 == "audio/wav")
    }

    @Test("STT headers default Content-Type to octet-stream when MIME type absent")
    func testListenHeadersDefaultContentType() {
        let headers = DeepgramVoiceProvider().buildListenHeaders(apiKey: "test-key", mimeType: nil)

        let contentType = headers.first { $0.0 == "Content-Type" }
        #expect(contentType?.1 == "application/octet-stream")
    }

    @Test("TTS headers use Token + application/json")
    func testSpeakHeaders() {
        let headers = DeepgramVoiceProvider().buildSpeakHeaders(apiKey: "test-key")

        let auth = headers.first { $0.0 == "Authorization" }
        #expect(auth?.1 == "Token test-key")

        let contentType = headers.first { $0.0 == "Content-Type" }
        #expect(contentType?.1 == "application/json")
    }

    // MARK: - Text-to-Speech

    @Test("synthesize wraps audio Data into a SpeechSynthesisResponse")
    func testMakeSynthesisResponse() {
        let request = SpeechSynthesisRequest(text: "hi", model: "aura-2-thalia-en")
        let response = DeepgramVoiceProvider().makeSynthesisResponse(
            audio: Data([0x01, 0x02, 0x03]),
            request: request
        )

        #expect(response.audio == Data([0x01, 0x02, 0x03]))
        #expect(response.format == .mp3)
        #expect(response.model == "aura-2-thalia-en")
    }

    @Test("buildSpeakBody encodes the text as JSON")
    func testBuildSpeakBody() throws {
        let request = SpeechSynthesisRequest(text: "Hello, world.", model: "aura-2-thalia-en")
        let body = try DeepgramVoiceProvider().buildSpeakBody(from: request)

        let decoded = try JSONDecoder().decode(DeepgramSpeakRequest.self, from: body)
        #expect(decoded.text == "Hello, world.")
    }

    @Test("streamSynthesize wraps each Data chunk into a SpeechAudioChunk")
    func testMakeAudioChunkStream() async throws {
        let chunks = [Data([0xAA, 0xBB]), Data([0xCC, 0xDD])]
        let dataStream = AsyncThrowingStream<Data, Error> { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }

        var collected: [SpeechAudioChunk] = []
        for try await chunk in DeepgramVoiceProvider().makeAudioChunkStream(from: dataStream) {
            collected.append(chunk)
        }

        #expect(collected.count == 2)
        #expect(collected.first?.audio == Data([0xAA, 0xBB]))
        #expect(collected.last?.audio == Data([0xCC, 0xDD]))
    }

    // MARK: - URL Building

    @Test("listenURL and speakURL contain the model and expected params")
    func testURLBuilding() {
        let provider = DeepgramVoiceProvider()

        let listenURL = provider.listenURL(for: TranscriptionRequest(audio: Data(), model: "nova-3"))
        #expect(listenURL.contains("model=nova-3"))
        #expect(listenURL.contains("smart_format=true"))
        #expect(listenURL.contains("punctuate=true"))

        let listenWithLang = provider.listenURL(
            for: TranscriptionRequest(audio: Data(), model: "nova-3", language: "en")
        )
        #expect(listenWithLang.contains("language=en"))

        let speakURL = provider.speakURL(for: SpeechSynthesisRequest(text: "hi", model: "aura-2-thalia-en"))
        #expect(speakURL.contains("model=aura-2-thalia-en"))

        let wavURL = provider.speakURL(
            for: SpeechSynthesisRequest(text: "hi", model: "aura-2-thalia-en", format: .wav)
        )
        #expect(wavURL.contains("container=wav"))
        #expect(wavURL.contains("encoding=linear16"))
        #expect(wavURL.contains("sample_rate=24000"))
    }

    // MARK: - Streaming STT (unsupported)

    @Test("streamTranscribe finishes with unsupportedFeature")
    func testStreamTranscribeThrows() async {
        let provider = DeepgramVoiceProvider()
        let request = TranscriptionRequest(audio: Data([0x00, 0x01]), model: "nova-3")
        let stream = provider.streamTranscribe(request, apiKey: "test-key")

        await #expect(throws: AIError.self) {
            for try await _ in stream {
                // The Deepgram provider never yields a live-STT chunk.
            }
        }
    }

    // MARK: - Capabilities

    @Test("provider reports its voice capability flags and models")
    func testCapabilityFlags() {
        let provider = DeepgramVoiceProvider()

        #expect(provider.supportsSpeechToText)
        #expect(provider.supportsTextToSpeech)
        #expect(provider.speechToTextModels.contains("nova-3"))
        #expect(provider.textToSpeechModels.contains("aura-2-thalia-en"))
    }
}
