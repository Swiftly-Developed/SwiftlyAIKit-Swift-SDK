import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for ``OpenAIVoiceProvider``.
///
/// Following repo convention, there is NO `MockHTTPClient` and NO real network access:
/// providers take a *concrete* `HTTPClientManager` actor. These tests exercise
/// (a) pure helper functions, (b) fixture-decoding of inline JSON into the Codable wire types,
/// (c) direct construction of neutral value types, and (d) the model-gate on streamTranscribe.
/// The injecting-init test simply passes a real `HTTPClientManager()` and asserts identity.
@Suite("OpenAIVoiceProvider Tests")
struct OpenAIVoiceProviderTests {
    // MARK: - Initialization

    @Test("Default init reports the OpenAI voice identity and base URL")
    func testDefaultInit() {
        let provider = OpenAIVoiceProvider()
        #expect(provider.voiceProviderType == .openai)
        #expect(provider.speechURL == "https://api.openai.com/v1/audio/speech")
        #expect(provider.transcriptionsURL == "https://api.openai.com/v1/audio/transcriptions")
    }

    @Test("Injecting init accepts a concrete HTTPClientManager")
    func testInjectingInit() {
        let provider = OpenAIVoiceProvider(httpClient: HTTPClientManager())
        #expect(provider.voiceProviderType == .openai)
        #expect(provider.speechURL == "https://api.openai.com/v1/audio/speech")
    }

    @Test("Custom base URL flows into the endpoints")
    func testCustomBaseURL() {
        let provider = OpenAIVoiceProvider(baseURL: "https://proxy.example.com/v1")
        #expect(provider.speechURL == "https://proxy.example.com/v1/audio/speech")
        #expect(provider.transcriptionsURL == "https://proxy.example.com/v1/audio/transcriptions")
    }

    // MARK: - Capability Flags

    @Test("Reports TTS and STT support with seeded model lists")
    func testCapabilityFlags() {
        let provider = OpenAIVoiceProvider()
        #expect(provider.supportsTextToSpeech)
        #expect(provider.supportsSpeechToText)

        #expect(!provider.textToSpeechModels.isEmpty)
        #expect(provider.textToSpeechModels.contains("tts-1"))
        #expect(provider.textToSpeechModels.contains("gpt-4o-mini-tts"))

        #expect(!provider.speechToTextModels.isEmpty)
        #expect(provider.speechToTextModels.contains("whisper-1"))
        #expect(provider.speechToTextModels.contains("gpt-4o-transcribe"))
    }

    @Test("Registries carry expected seeds")
    func testRegistries() {
        #expect(OpenAIVoiceProvider.ttsModels == ["tts-1", "tts-1-hd", "gpt-4o-mini-tts"])
        #expect(OpenAIVoiceProvider.sttModels == ["whisper-1", "gpt-4o-transcribe", "gpt-4o-mini-transcribe"])
        #expect(OpenAIVoiceProvider.voices.contains("alloy"))
        #expect(OpenAIVoiceProvider.voices.contains("verse"))
        #expect(OpenAIVoiceProvider.streamingTranscriptionModels == ["gpt-4o-transcribe", "gpt-4o-mini-transcribe"])
        #expect(!OpenAIVoiceProvider.streamingTranscriptionModels.contains("whisper-1"))
    }

    // MARK: - Headers

    @Test("buildHeaders always carries the Bearer token")
    func testBuildHeadersBearer() {
        let provider = OpenAIVoiceProvider()
        let headers = provider.buildHeaders(apiKey: "sk-test", contentType: "application/json")

        #expect(headers.contains { $0 == ("Authorization", "Bearer sk-test") })
        #expect(headers.contains { $0 == ("Content-Type", "application/json") })
        // No org header, no accept header when not requested.
        #expect(!headers.contains { $0.0 == "OpenAI-Organization" })
        #expect(!headers.contains { $0.0 == "Accept" })
    }

    @Test("buildHeaders includes the org header only when configured")
    func testBuildHeadersOrg() {
        let plain = OpenAIVoiceProvider()
        #expect(!plain.buildHeaders(apiKey: "sk", contentType: "application/json")
            .contains { $0.0 == "OpenAI-Organization" })

        let withOrg = OpenAIVoiceProvider(organizationId: "org-123")
        let headers = withOrg.buildHeaders(apiKey: "sk", contentType: "application/json")
        #expect(headers.contains { $0 == ("OpenAI-Organization", "org-123") })
    }

    @Test("buildHeaders includes Accept when provided")
    func testBuildHeadersAccept() {
        let provider = OpenAIVoiceProvider()
        let headers = provider.buildHeaders(
            apiKey: "sk",
            contentType: "multipart/form-data; boundary=x",
            accept: "text/event-stream"
        )
        #expect(headers.contains { $0 == ("Accept", "text/event-stream") })
    }

    // MARK: - Speech Request Mapping

    @Test("makeSpeechRequest maps fields and defaults the voice to alloy")
    func testMakeSpeechRequestDefaults() throws {
        let provider = OpenAIVoiceProvider()
        let request = SpeechSynthesisRequest(text: "Hello world", model: "tts-1", format: .mp3)
        let mapped = provider.makeSpeechRequest(request)

        #expect(mapped.model == "tts-1")
        #expect(mapped.input == "Hello world")
        #expect(mapped.voice == "alloy")
        #expect(mapped.responseFormat == "mp3")
        #expect(mapped.speed == nil)
    }

    @Test("makeSpeechRequest encodes to the expected snake_case JSON")
    func testMakeSpeechRequestEncoding() throws {
        let provider = OpenAIVoiceProvider()
        let request = SpeechSynthesisRequest(
            text: "Speak this",
            model: "gpt-4o-mini-tts",
            voice: "verse",
            format: .wav,
            speed: 1.25
        )
        let data = try JSONEncoder().encode(provider.makeSpeechRequest(request))
        let dict = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(dict["model"] as? String == "gpt-4o-mini-tts")
        #expect(dict["input"] as? String == "Speak this")
        #expect(dict["voice"] as? String == "verse")
        #expect(dict["response_format"] as? String == "wav")
        #expect(dict["speed"] as? Double == 1.25)
    }

    @Test("response_format follows AudioFormat rawValue", arguments: [
        (AudioFormat.mp3, "mp3"),
        (AudioFormat.wav, "wav"),
        (AudioFormat.pcm, "pcm"),
        (AudioFormat.opus, "opus"),
        (AudioFormat.flac, "flac"),
        (AudioFormat.aac, "aac")
    ])
    func testResponseFormatMapping(format: AudioFormat, expected: String) {
        let provider = OpenAIVoiceProvider()
        let request = SpeechSynthesisRequest(text: "x", model: "tts-1", format: format)
        #expect(provider.makeSpeechRequest(request).responseFormat == expected)
    }

    // MARK: - Multipart Body

    @Test("multipartContentType embeds the boundary")
    func testMultipartContentType() {
        let provider = OpenAIVoiceProvider()
        #expect(provider.multipartContentType(boundary: "abc123") == "multipart/form-data; boundary=abc123")
    }

    @Test("buildMultipartBody carries file, model, and boundary parts")
    func testBuildMultipartBody() throws {
        let provider = OpenAIVoiceProvider()
        let request = TranscriptionRequest(
            audio: Data([0x01, 0x02, 0x03]),
            model: "whisper-1",
            language: "en",
            mimeType: "audio/wav"
        )
        let boundary = "test-boundary"
        let body = provider.buildMultipartBody(request, boundary: boundary, stream: false)
        let rendered = String(decoding: body, as: UTF8.self)

        #expect(rendered.contains("name=\"file\""))
        #expect(rendered.contains("filename=\"audio.wav\""))
        #expect(rendered.contains("Content-Type: audio/wav"))
        #expect(rendered.contains("name=\"model\""))
        #expect(rendered.contains("whisper-1"))
        #expect(rendered.contains("name=\"language\""))
        #expect(rendered.contains("en"))
        #expect(rendered.contains("name=\"response_format\""))
        #expect(rendered.contains("--test-boundary"))
        #expect(rendered.contains("--test-boundary--"))
        // Non-streaming body must NOT carry the stream field.
        #expect(!rendered.contains("name=\"stream\""))
    }

    @Test("buildMultipartBody stream variant carries stream=true")
    func testBuildMultipartBodyStream() {
        let provider = OpenAIVoiceProvider()
        let request = TranscriptionRequest(audio: Data([0xAA]), model: "gpt-4o-transcribe")
        let body = provider.buildMultipartBody(request, boundary: "b", stream: true)
        let rendered = String(decoding: body, as: UTF8.self)

        #expect(rendered.contains("name=\"stream\""))
        #expect(rendered.contains("true"))
    }

    @Test("buildMultipartBody omits language when absent and defaults filename")
    func testBuildMultipartBodyNoLanguage() {
        let provider = OpenAIVoiceProvider()
        let request = TranscriptionRequest(audio: Data([0x00]), model: "whisper-1")
        let body = provider.buildMultipartBody(request, boundary: "b", stream: false)
        let rendered = String(decoding: body, as: UTF8.self)

        #expect(!rendered.contains("name=\"language\""))
        // Default MIME → octet-stream, default filename extension → wav.
        #expect(rendered.contains("Content-Type: application/octet-stream"))
        #expect(rendered.contains("filename=\"audio.wav\""))
    }

    @Test("fileExtension derives extensions from common MIME types")
    func testFileExtension() {
        #expect(OpenAIVoiceProvider.fileExtension(forMimeType: "audio/wav") == "wav")
        #expect(OpenAIVoiceProvider.fileExtension(forMimeType: "audio/mpeg") == "mp3")
        #expect(OpenAIVoiceProvider.fileExtension(forMimeType: "audio/mp4") == "m4a")
        #expect(OpenAIVoiceProvider.fileExtension(forMimeType: "audio/flac") == "flac")
        #expect(OpenAIVoiceProvider.fileExtension(forMimeType: nil) == "wav")
        #expect(OpenAIVoiceProvider.fileExtension(forMimeType: "application/unknown") == "wav")
    }

    // MARK: - Transcription Response Decoding

    @Test("Decodes a plain json transcription response")
    func testDecodePlainTranscription() throws {
        let json = #"{"text":"hello world"}"#.data(using: .utf8) ?? Data()
        let decoded = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: json)
        let mapped = OpenAIVoiceProvider.mapTranscription(decoded)

        #expect(mapped.text == "hello world")
        #expect(mapped.segments == nil)
        #expect(mapped.words == nil)
        #expect(mapped.language == nil)
        #expect(mapped.durationSeconds == nil)
    }

    @Test("Decodes a verbose_json transcription response with segments and words")
    func testDecodeVerboseTranscription() throws {
        let json = """
        {
          "text": "hello world",
          "language": "english",
          "duration": 1.75,
          "segments": [
            {"text": "hello world", "start": 0.0, "end": 1.75}
          ],
          "words": [
            {"word": "hello", "start": 0.0, "end": 0.8},
            {"word": "world", "start": 0.9, "end": 1.75}
          ]
        }
        """.data(using: .utf8) ?? Data()
        let decoded = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: json)
        let mapped = OpenAIVoiceProvider.mapTranscription(decoded)

        #expect(mapped.text == "hello world")
        #expect(mapped.language == "english")
        #expect(mapped.durationSeconds == 1.75)
        #expect(mapped.segments?.count == 1)
        #expect(mapped.segments?.first?.text == "hello world")
        #expect(mapped.segments?.first?.startSeconds == 0.0)
        #expect(mapped.segments?.first?.endSeconds == 1.75)
        #expect(mapped.words?.count == 2)
        #expect(mapped.words?.first?.word == "hello")
        #expect(mapped.words?.last?.word == "world")
        #expect(mapped.words?.last?.endSeconds == 1.75)
    }

    // MARK: - Streaming Event Decoding

    @Test("Decodes a transcript.text.delta SSE event")
    func testDecodeDeltaEvent() throws {
        let json = #"{"type":"transcript.text.delta","delta":"hel"}"#.data(using: .utf8) ?? Data()
        let event = try JSONDecoder().decode(OpenAITranscriptionStreamEvent.self, from: json)

        #expect(event.type == "transcript.text.delta")
        #expect(event.delta == "hel")
        #expect(event.text == nil)
    }

    @Test("Decodes a transcript.text.done SSE event")
    func testDecodeDoneEvent() throws {
        let json = #"{"type":"transcript.text.done","text":"hello world"}"#.data(using: .utf8) ?? Data()
        let event = try JSONDecoder().decode(OpenAITranscriptionStreamEvent.self, from: json)

        #expect(event.type == "transcript.text.done")
        #expect(event.text == "hello world")
        #expect(event.delta == nil)
    }

    // MARK: - Streaming Transcription Model Gate

    @Test("streamTranscribe with whisper-1 finishes throwing unsupportedFeature")
    func testStreamTranscribeWhisperUnsupported() async {
        let provider = OpenAIVoiceProvider()
        let request = TranscriptionRequest(audio: Data([0x00, 0x01]), model: "whisper-1")
        let stream = provider.streamTranscribe(request, apiKey: "sk-test")

        await #expect(throws: AIError.unsupportedFeature(feature: "streaming-transcription", provider: .openai)) {
            for try await _ in stream {
                // The model gate finishes the stream before any chunk is produced.
            }
        }
    }

    // MARK: - Neutral Value Types

    @Test("SpeechSynthesisResponse wraps audio, format, and model")
    func testSpeechResponseConstruction() {
        let response = SpeechSynthesisResponse(audio: Data([0x01, 0x02]), format: .mp3, model: "tts-1")
        #expect(response.audio == Data([0x01, 0x02]))
        #expect(response.format == .mp3)
        #expect(response.model == "tts-1")
    }
}
