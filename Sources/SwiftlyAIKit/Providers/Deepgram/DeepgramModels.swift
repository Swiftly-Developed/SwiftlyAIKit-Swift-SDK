import Foundation

/// Deepgram API Models
///
/// Provider-specific types for Deepgram's voice endpoints: the Nova speech-to-text
/// `POST /listen` response and the Aura-2 text-to-speech `POST /speak` request.
///
/// Deepgram nests its transcription result several levels deep: a response carries
/// `results.channels[]`, each channel carries `alternatives[]`, and the best alternative
/// carries the `transcript` plus an optional per-`words` array. Timing metadata (the audio
/// `duration`) rides on a top-level `metadata` object. Field names on the wire are snake_case
/// (`detected_language`, `punctuated_word`), so every type declares explicit
/// `CodingKeys` — the decoder is never configured with `.convertFromSnakeCase`.
///
/// ## See Also
/// - ``DeepgramVoiceProvider``

// MARK: - Speech-to-Text Response Models

/// Deepgram Nova listen response (`POST /listen`)
public struct DeepgramListenResponse: Codable, Sendable {
    /// Top-level metadata (audio duration, …), when present
    public let metadata: DeepgramMetadata?

    /// The transcription results, grouped by audio channel
    public let results: DeepgramResults

    public init(metadata: DeepgramMetadata? = nil, results: DeepgramResults) {
        self.metadata = metadata
        self.results = results
    }

    private enum CodingKeys: String, CodingKey {
        case metadata
        case results
    }
}

/// Deepgram response metadata
public struct DeepgramMetadata: Codable, Sendable {
    /// Duration of the transcribed audio in seconds
    public let duration: Double?

    public init(duration: Double? = nil) {
        self.duration = duration
    }

    private enum CodingKeys: String, CodingKey {
        case duration
    }
}

/// Deepgram transcription results container
public struct DeepgramResults: Codable, Sendable {
    /// One entry per audio channel (mono audio yields a single channel)
    public let channels: [DeepgramChannel]

    public init(channels: [DeepgramChannel]) {
        self.channels = channels
    }

    private enum CodingKeys: String, CodingKey {
        case channels
    }
}

/// Deepgram per-channel transcription
public struct DeepgramChannel: Codable, Sendable {
    /// Ranked transcript alternatives (the first is the best)
    public let alternatives: [DeepgramAlternative]

    /// The detected language as a BCP-47 tag, when language detection ran
    public let detectedLanguage: String?

    public init(alternatives: [DeepgramAlternative], detectedLanguage: String? = nil) {
        self.alternatives = alternatives
        self.detectedLanguage = detectedLanguage
    }

    private enum CodingKeys: String, CodingKey {
        case alternatives
        case detectedLanguage = "detected_language"
    }
}

/// Deepgram transcript alternative
public struct DeepgramAlternative: Codable, Sendable {
    /// The full transcript for this alternative
    public let transcript: String

    /// Overall confidence for this alternative (0...1)
    public let confidence: Double?

    /// Per-word timing detail, when requested
    public let words: [DeepgramWord]?

    public init(transcript: String, confidence: Double? = nil, words: [DeepgramWord]? = nil) {
        self.transcript = transcript
        self.confidence = confidence
        self.words = words
    }

    private enum CodingKeys: String, CodingKey {
        case transcript
        case confidence
        case words
    }
}

/// Deepgram time-stamped word
///
/// `punctuated_word` carries the display form (capitalization + punctuation) when smart
/// formatting is enabled; `word` is the raw normalized token.
public struct DeepgramWord: Codable, Sendable {
    /// The raw normalized word token
    public let word: String

    /// Start offset of this word within the audio, in seconds
    public let start: Double

    /// End offset of this word within the audio, in seconds
    public let end: Double

    /// Confidence for this word (0...1)
    public let confidence: Double?

    /// The display form with capitalization and punctuation, when smart formatting ran
    public let punctuatedWord: String?

    public init(
        word: String,
        start: Double,
        end: Double,
        confidence: Double? = nil,
        punctuatedWord: String? = nil
    ) {
        self.word = word
        self.start = start
        self.end = end
        self.confidence = confidence
        self.punctuatedWord = punctuatedWord
    }

    private enum CodingKeys: String, CodingKey {
        case word
        case start
        case end
        case confidence
        case punctuatedWord = "punctuated_word"
    }
}

// MARK: - Text-to-Speech Request Models

/// Deepgram Aura-2 speak request body (`POST /speak`)
///
/// The synthesis body is a minimal `{"text": "..."}`; the voice model, encoding, container,
/// and sample rate are all carried as query parameters on the request URL.
public struct DeepgramSpeakRequest: Codable, Sendable {
    /// The text to synthesize into speech
    public let text: String

    public init(text: String) {
        self.text = text
    }

    private enum CodingKeys: String, CodingKey {
        case text
    }
}
