import Foundation

// MARK: - Text-to-Speech Request DTOs

/// Cartesia `/tts/bytes` and `/tts/sse` request body.
///
/// Cartesia keys are `snake_case`; the neutral ``SpeechSynthesisRequest`` is mapped onto this
/// wire shape by ``CartesiaVoiceProvider``.
struct CartesiaTTSRequest: Encodable {
    /// TTS model identifier, e.g. `"sonic-3"`.
    let modelID: String

    /// The text to synthesize.
    let transcript: String

    /// Voice selector (`{ "mode": "id", "id": "…" }`).
    let voice: CartesiaVoiceSpecifier

    /// Desired container / encoding / sample rate.
    let outputFormat: CartesiaOutputFormat

    /// Optional ISO-639-1 language hint.
    let language: String?

    enum CodingKeys: String, CodingKey {
        case modelID = "model_id"
        case transcript
        case voice
        case outputFormat = "output_format"
        case language
    }
}

/// Cartesia voice selector — the SDK always selects a voice by id.
struct CartesiaVoiceSpecifier: Encodable {
    /// Selection mode; always `"id"` for SwiftlyAIKit.
    let mode: String

    /// The Cartesia voice id.
    let id: String
}

/// Cartesia `output_format` object.
///
/// `encoding` and `bit_rate` are optional on the wire — the synthesized `Encodable`
/// omits them when `nil` (`encodeIfPresent`), which is exactly what Cartesia expects for
/// containers that don't use them.
struct CartesiaOutputFormat: Encodable {
    /// Container: `"raw"`, `"wav"`, or `"mp3"`.
    let container: String

    /// PCM encoding (e.g. `"pcm_s16le"`) — required for `raw`/`wav`, omitted for `mp3`.
    let encoding: String?

    /// Output sample rate in Hz.
    let sampleRate: Int

    /// Bit rate in bps — used by the `mp3` container only.
    let bitRate: Int?

    enum CodingKeys: String, CodingKey {
        case container
        case encoding
        case sampleRate = "sample_rate"
        case bitRate = "bit_rate"
    }
}

// MARK: - Streaming (SSE) Event DTO

/// A single decoded Cartesia SSE event from `/tts/sse`.
///
/// Cartesia frames each event as `data: {json}` where the JSON carries a `type` discriminator.
/// A `"chunk"` event holds base64 audio in `data`; a `"done"` event terminates the stream; an
/// `"error"` event carries a message. `"timestamps"` / `"phoneme_timestamps"` events are ignored
/// by the audio stream.
struct CartesiaSSEEvent: Decodable {
    /// Event discriminator: `"chunk"`, `"done"`, `"error"`, `"timestamps"`, …
    let type: String

    /// Base64-encoded audio bytes, present on `"chunk"` events.
    let data: String?

    /// Whether this event terminates the stream.
    let done: Bool?

    /// Error message, present on `"error"` events.
    let error: String?

    enum CodingKeys: String, CodingKey {
        case type
        case data
        case done
        case error
    }
}

// MARK: - Speech-to-Text Response DTOs

/// Cartesia Ink-Whisper `/stt` batch transcription response.
struct CartesiaTranscriptionResponse: Decodable {
    /// Always `"transcript"` for a successful batch response.
    let type: String?

    /// Unique request identifier.
    let requestID: String?

    /// The full transcribed text.
    let text: String

    /// Detected / requested language (ISO-639-1).
    let language: String?

    /// Audio duration in seconds.
    let duration: Double?

    /// Per-word timing, present when `timestamp_granularities[]=word` is requested.
    let words: [CartesiaTranscriptionWord]?

    enum CodingKeys: String, CodingKey {
        case type
        case requestID = "request_id"
        case text
        case language
        case duration
        case words
    }
}

/// A single word with start/end offsets (seconds) from Ink-Whisper.
struct CartesiaTranscriptionWord: Decodable {
    let word: String
    let start: Double
    let end: Double
}

// MARK: - Voices

/// Cartesia `GET /voices` response envelope (`{ "data": [...], "has_more": …, "next_page": … }`).
struct CartesiaVoicesResponse: Decodable {
    let data: [CartesiaVoice]
}

/// A Cartesia voice as returned by `GET /voices`.
///
/// Voice ids are fetched at runtime via ``CartesiaVoiceProvider/listVoices(apiKey:)`` rather than
/// hardcoded, so ``VoiceCapabilities/voices(for:)`` reports an empty catalog for Cartesia.
public struct CartesiaVoice: Sendable, Codable, Identifiable {
    /// The Cartesia voice id, usable as ``SpeechSynthesisRequest/voice``.
    public let id: String

    /// Human-readable voice name.
    public let name: String

    /// Optional description of the voice.
    public let description: String?

    /// Optional primary language (ISO-639-1).
    public let language: String?

    /// Initialize a Cartesia voice.
    public init(id: String, name: String, description: String? = nil, language: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.language = language
    }
}
