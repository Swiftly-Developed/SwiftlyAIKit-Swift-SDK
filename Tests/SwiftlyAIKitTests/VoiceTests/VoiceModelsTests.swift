import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for the neutral voice value types
@Suite("Voice Models Tests")
struct VoiceModelsTests {
    // MARK: - AudioFormat

    @Test("AudioFormat is CaseIterable and covers the expected formats")
    func testAudioFormatCases() {
        let all = AudioFormat.allCases
        #expect(all.contains(.mp3))
        #expect(all.contains(.wav))
        #expect(all.contains(.pcm))
        #expect(all.contains(.opus))
        #expect(all.contains(.flac))
        #expect(all.contains(.aac))
    }

    @Test("AudioFormat exposes a MIME type for every case")
    func testAudioFormatMimeTypes() {
        #expect(AudioFormat.mp3.mimeType == "audio/mpeg")
        #expect(AudioFormat.wav.mimeType == "audio/wav")
        #expect(AudioFormat.flac.mimeType == "audio/flac")
        for format in AudioFormat.allCases {
            #expect(format.mimeType.hasPrefix("audio/"), "\(format) should have an audio/* MIME type")
        }
    }

    @Test("AudioFormat round-trips through Codable")
    func testAudioFormatCodable() throws {
        for format in AudioFormat.allCases {
            let data = try JSONEncoder().encode(format)
            let decoded = try JSONDecoder().decode(AudioFormat.self, from: data)
            #expect(decoded == format)
        }
    }

    // MARK: - SpeechSynthesisRequest

    @Test("SpeechSynthesisRequest applies defaults")
    func testSynthesisRequestDefaults() {
        let request = SpeechSynthesisRequest(text: "Hello", model: "tts-1")
        #expect(request.text == "Hello")
        #expect(request.model == "tts-1")
        #expect(request.voice == nil)
        #expect(request.format == .mp3)
        #expect(request.speed == nil)
        #expect(request.sampleRate == nil)
    }

    @Test("SpeechSynthesisRequest preserves all fields")
    func testSynthesisRequestFull() {
        let request = SpeechSynthesisRequest(
            text: "Hello",
            model: "tts-1",
            voice: "narrator",
            format: .wav,
            speed: 1.25,
            sampleRate: 24_000
        )
        #expect(request.voice == "narrator")
        #expect(request.format == .wav)
        #expect(request.speed == 1.25)
        #expect(request.sampleRate == 24_000)
    }

    // MARK: - SpeechSynthesisResponse / SpeechAudioChunk

    @Test("SpeechSynthesisResponse carries audio, format and model")
    func testSynthesisResponse() {
        let audio = Data([0x01, 0x02, 0x03])
        let response = SpeechSynthesisResponse(audio: audio, format: .mp3, model: "tts-1")
        #expect(response.audio == audio)
        #expect(response.format == .mp3)
        #expect(response.model == "tts-1")
    }

    @Test("SpeechAudioChunk wraps audio bytes")
    func testAudioChunk() {
        let bytes = Data([0xAA, 0xBB])
        let chunk = SpeechAudioChunk(audio: bytes)
        #expect(chunk.audio == bytes)
    }

    // MARK: - TranscriptionRequest

    @Test("TranscriptionRequest applies defaults")
    func testTranscriptionRequestDefaults() {
        let audio = Data([0x00, 0x01])
        let request = TranscriptionRequest(audio: audio, model: "stt-1")
        #expect(request.audio == audio)
        #expect(request.model == "stt-1")
        #expect(request.language == nil)
        #expect(request.mimeType == nil)
    }

    @Test("TranscriptionRequest preserves all fields")
    func testTranscriptionRequestFull() {
        let request = TranscriptionRequest(
            audio: Data([0x00]),
            model: "stt-1",
            language: "fr-BE",
            mimeType: "audio/wav"
        )
        #expect(request.language == "fr-BE")
        #expect(request.mimeType == "audio/wav")
    }

    // MARK: - TranscriptionResponse and detail types

    @Test("TranscriptionResponse defaults optional detail to nil")
    func testTranscriptionResponseMinimal() {
        let response = TranscriptionResponse(text: "hello world")
        #expect(response.text == "hello world")
        #expect(response.segments == nil)
        #expect(response.words == nil)
        #expect(response.language == nil)
        #expect(response.durationSeconds == nil)
    }

    @Test("TranscriptionResponse carries segments, words and timing")
    func testTranscriptionResponseFull() {
        let segment = TranscriptionSegment(text: "hello", startSeconds: 0.0, endSeconds: 0.5)
        let word = TranscriptionWord(word: "hello", startSeconds: 0.0, endSeconds: 0.5)
        let response = TranscriptionResponse(
            text: "hello",
            segments: [segment],
            words: [word],
            language: "en",
            durationSeconds: 0.5
        )
        #expect(response.segments?.count == 1)
        #expect(response.segments?.first?.text == "hello")
        #expect(response.words?.first?.word == "hello")
        #expect(response.language == "en")
        #expect(response.durationSeconds == 0.5)
    }

    // MARK: - TranscriptionChunk

    @Test("TranscriptionChunk defaults to interim (not final)")
    func testTranscriptionChunkDefault() {
        let chunk = TranscriptionChunk(text: "partial")
        #expect(chunk.text == "partial")
        #expect(chunk.isFinal == false)
    }

    @Test("TranscriptionChunk can mark a finalized result")
    func testTranscriptionChunkFinal() {
        let chunk = TranscriptionChunk(text: "done", isFinal: true)
        #expect(chunk.isFinal == true)
    }
}
