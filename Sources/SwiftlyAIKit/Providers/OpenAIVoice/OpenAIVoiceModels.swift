import Foundation

/// OpenAI Voice API wire types
///
/// Provider-specific request and response types for OpenAI's audio endpoints
/// (`/audio/speech` for text-to-speech and `/audio/transcriptions` for speech-to-text).
///
/// These are kept entirely separate from the chat ``OpenAIProvider`` wire types
/// (`OpenAIModels.swift`) and mirror that file's convention of explicit snake_case
/// `CodingKeys` — never `JSONDecoder.KeyDecodingStrategy.convertFromSnakeCase`.
///
/// ## See Also
/// - ``OpenAIVoiceProvider``

// MARK: - Speech (Text-to-Speech)

/// Request body for OpenAI's `POST /audio/speech` endpoint
public struct OpenAISpeechRequest: Encodable, Sendable {
    /// TTS model identifier (e.g. `tts-1`, `tts-1-hd`, `gpt-4o-mini-tts`)
    public let model: String

    /// The text to synthesize
    public let input: String

    /// The voice identifier (e.g. `alloy`)
    public let voice: String

    /// Output audio format (maps to ``AudioFormat/rawValue``)
    public let responseFormat: String

    /// Playback speed multiplier (0.25–4.0), if specified
    public let speed: Double?

    /// Initialize an OpenAI speech request
    ///
    /// - Parameters:
    ///   - model: TTS model identifier
    ///   - input: The text to synthesize
    ///   - voice: The voice identifier
    ///   - responseFormat: Output audio format
    ///   - speed: Playback speed multiplier (default: nil)
    public init(
        model: String,
        input: String,
        voice: String,
        responseFormat: String,
        speed: Double? = nil
    ) {
        self.model = model
        self.input = input
        self.voice = voice
        self.responseFormat = responseFormat
        self.speed = speed
    }

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case voice
        case responseFormat = "response_format"
        case speed
    }
}

// MARK: - Transcription (Speech-to-Text)

/// Response body for OpenAI's `POST /audio/transcriptions` endpoint
///
/// The `json` response format returns only ``text``. The `verbose_json` format additionally
/// returns ``language``, ``duration``, and time-stamped ``segments``/``words``.
public struct OpenAITranscriptionResponse: Decodable, Sendable {
    /// The full transcribed text
    public let text: String

    /// The detected language (verbose_json only)
    public let language: String?

    /// Duration of the audio in seconds (verbose_json only)
    public let duration: Double?

    /// Time-stamped segments (verbose_json only)
    public let segments: [Segment]?

    /// Time-stamped words (verbose_json only)
    public let words: [Word]?

    /// A time-stamped transcript segment
    public struct Segment: Decodable, Sendable {
        /// The text of this segment
        public let text: String

        /// Start offset within the audio, in seconds
        public let start: Double

        /// End offset within the audio, in seconds
        public let end: Double

        enum CodingKeys: String, CodingKey {
            case text
            case start
            case end
        }
    }

    /// A single time-stamped word
    public struct Word: Decodable, Sendable {
        /// The word text
        public let word: String

        /// Start offset within the audio, in seconds
        public let start: Double

        /// End offset within the audio, in seconds
        public let end: Double

        enum CodingKeys: String, CodingKey {
            case word
            case start
            case end
        }
    }

    enum CodingKeys: String, CodingKey {
        case text
        case language
        case duration
        case segments
        case words
    }
}

/// A single Server-Sent Event emitted by OpenAI's streaming transcription
///
/// Streaming (`stream=true`, gated to `gpt-4o-transcribe`/`gpt-4o-mini-transcribe`) emits
/// `transcript.text.delta` events carrying incremental ``delta`` text, followed by a single
/// `transcript.text.done` event carrying the full ``text``.
public struct OpenAITranscriptionStreamEvent: Decodable, Sendable {
    /// The event type (e.g. `transcript.text.delta`, `transcript.text.done`)
    public let type: String

    /// Incremental transcript text (present on `transcript.text.delta`)
    public let delta: String?

    /// Full transcript text (present on `transcript.text.done`)
    public let text: String?

    enum CodingKeys: String, CodingKey {
        case type
        case delta
        case text
    }
}
