import Foundation

// MARK: - Text-to-Speech Request

/// Request body for ElevenLabs text-to-speech (`POST /text-to-speech/{voice_id}`).
///
/// Encoded with explicit snake_case `CodingKeys` and a plain `JSONEncoder` (never
/// `.convertToSnakeCase`), matching the rest of the SDK's provider models.
struct ElevenLabsSpeechRequest: Encodable {
    /// The text to synthesize into speech.
    let text: String

    /// The ElevenLabs model identifier (e.g. `eleven_multilingual_v2`).
    let modelID: String

    /// Optional voice tuning; sent only when the neutral request carries a value.
    let voiceSettings: ElevenLabsVoiceSettings?

    enum CodingKeys: String, CodingKey {
        case text
        case modelID = "model_id"
        case voiceSettings = "voice_settings"
    }
}

/// Voice tuning parameters for a synthesis request.
///
/// Intentionally extensible; today only `speed` is mapped from the neutral request.
struct ElevenLabsVoiceSettings: Encodable {
    /// Playback speed multiplier, if the neutral request specified one.
    let speed: Double?

    enum CodingKeys: String, CodingKey {
        case speed
    }
}

// MARK: - Speech-to-Text Response (Scribe)

/// Response body for ElevenLabs Scribe speech-to-text (`POST /speech-to-text`).
struct ElevenLabsTranscriptionResponse: Decodable {
    /// The full transcribed text.
    let text: String

    /// Detected (or requested) language as a BCP-47 tag, if returned.
    let languageCode: String?

    /// Model confidence in the detected language (0–1), if returned.
    let languageProbability: Double?

    /// Per-word timing detail, if returned.
    let words: [ElevenLabsTranscriptionWord]?

    enum CodingKeys: String, CodingKey {
        case text
        case languageCode = "language_code"
        case languageProbability = "language_probability"
        case words
    }
}

/// A single timed token in a Scribe transcript.
///
/// Scribe returns spacing and audio-event tokens alongside words; `start`/`end` are absent
/// on some of these, so both are optional and consumers must be defensive.
struct ElevenLabsTranscriptionWord: Decodable {
    /// The token text.
    let text: String

    /// Start offset within the audio, in seconds, if present.
    let start: Double?

    /// End offset within the audio, in seconds, if present.
    let end: Double?

    /// Token kind (`"word"`, `"spacing"`, `"audio_event"`, …), if present.
    let type: String?

    enum CodingKeys: String, CodingKey {
        case text
        case start
        case end
        case type
    }
}

// MARK: - Voices

/// Response body for the voices list endpoint (`GET /voices`).
struct ElevenLabsVoicesResponse: Decodable {
    /// The account's available voices.
    let voices: [ElevenLabsVoiceDTO]

    enum CodingKeys: String, CodingKey {
        case voices
    }
}

/// A single voice entry from the voices list endpoint.
struct ElevenLabsVoiceDTO: Decodable {
    /// The voice identifier used in synthesis requests.
    let voiceID: String

    /// Human-readable voice name.
    let name: String

    /// Voice category (`"premade"`, `"cloned"`, …), if returned.
    let category: String?

    enum CodingKeys: String, CodingKey {
        case voiceID = "voice_id"
        case name
        case category
    }
}

/// Response body for the add-voice / clone endpoint (`POST /voices/add`).
struct ElevenLabsAddVoiceResponse: Decodable {
    /// The identifier of the newly created voice.
    let voiceID: String

    enum CodingKeys: String, CodingKey {
        case voiceID = "voice_id"
    }
}

// MARK: - Public Voice Info

/// A voice discovered via ``ElevenLabsVoiceProvider/listVoices(apiKey:)``.
///
/// The public, neutral projection of ``ElevenLabsVoiceDTO`` returned to callers.
public struct ElevenLabsVoiceInfo: Sendable, Equatable {
    /// The voice identifier usable in `SpeechSynthesisRequest.voice`.
    public let id: String

    /// Human-readable voice name.
    public let name: String

    /// Voice category (`"premade"`, `"cloned"`, …), if known.
    public let category: String?

    /// Initialize a voice info value.
    ///
    /// - Parameters:
    ///   - id: The voice identifier.
    ///   - name: Human-readable voice name.
    ///   - category: Voice category, if known (default: nil).
    public init(id: String, name: String, category: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
    }
}
