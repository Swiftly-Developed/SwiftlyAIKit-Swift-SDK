import Foundation

/// Unified speech-to-text response
///
/// Contains the transcript produced by any ``SpeechToText`` provider, plus optional
/// timing detail when the provider returns it.
///
/// ## Overview
///
/// Every response carries the full ``text``. Providers that return timing detail also
/// populate ``segments`` and/or ``words``, the detected ``language``, and the audio's
/// ``durationSeconds``.
///
/// ## Accessing the Transcript
///
/// ```swift
/// let response = try await provider.transcribe(request, apiKey: key)
/// print(response.text)
///
/// for segment in response.segments ?? [] {
///     print("[\(segment.startSeconds)–\(segment.endSeconds)] \(segment.text)")
/// }
/// ```
///
/// ## Topics
///
/// ### Response Properties
/// - ``text``
/// - ``segments``
/// - ``words``
/// - ``language``
/// - ``durationSeconds``
///
/// ### Detail Types
/// - ``TranscriptionSegment``
/// - ``TranscriptionWord``
///
/// ### Related Types
/// - ``TranscriptionRequest``
/// - ``TranscriptionChunk``
///
/// ## See Also
/// - ``SpeechToText``
public struct TranscriptionResponse: Sendable {
    /// The full transcribed text
    public let text: String

    /// Time-stamped transcript segments, if the provider returned them
    public let segments: [TranscriptionSegment]?

    /// Time-stamped individual words, if the provider returned them
    public let words: [TranscriptionWord]?

    /// The detected (or requested) language as a BCP-47 tag, if available
    public let language: String?

    /// Duration of the transcribed audio in seconds, if available
    public let durationSeconds: Double?

    /// Initialize a speech-to-text response
    ///
    /// - Parameters:
    ///   - text: The full transcribed text
    ///   - segments: Time-stamped transcript segments (default: nil)
    ///   - words: Time-stamped individual words (default: nil)
    ///   - language: Detected/requested language as a BCP-47 tag (default: nil)
    ///   - durationSeconds: Duration of the transcribed audio in seconds (default: nil)
    public init(
        text: String,
        segments: [TranscriptionSegment]? = nil,
        words: [TranscriptionWord]? = nil,
        language: String? = nil,
        durationSeconds: Double? = nil
    ) {
        self.text = text
        self.segments = segments
        self.words = words
        self.language = language
        self.durationSeconds = durationSeconds
    }
}

/// A time-stamped span of transcribed text
public struct TranscriptionSegment: Sendable {
    /// The text of this segment
    public let text: String

    /// Start offset of this segment within the audio, in seconds
    public let startSeconds: Double

    /// End offset of this segment within the audio, in seconds
    public let endSeconds: Double

    /// Initialize a transcript segment
    ///
    /// - Parameters:
    ///   - text: The text of this segment
    ///   - startSeconds: Start offset within the audio, in seconds
    ///   - endSeconds: End offset within the audio, in seconds
    public init(
        text: String,
        startSeconds: Double,
        endSeconds: Double
    ) {
        self.text = text
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
    }
}

/// A single time-stamped word in a transcript
public struct TranscriptionWord: Sendable {
    /// The word text
    public let word: String

    /// Start offset of this word within the audio, in seconds
    public let startSeconds: Double

    /// End offset of this word within the audio, in seconds
    public let endSeconds: Double

    /// Initialize a transcript word
    ///
    /// - Parameters:
    ///   - word: The word text
    ///   - startSeconds: Start offset within the audio, in seconds
    ///   - endSeconds: End offset within the audio, in seconds
    public init(
        word: String,
        startSeconds: Double,
        endSeconds: Double
    ) {
        self.word = word
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
    }
}

/// A single incremental chunk of a streaming transcript
///
/// Emitted by ``SpeechToText/streamTranscribe(_:apiKey:)`` as audio is transcribed. A chunk
/// with ``isFinal`` set to `true` marks a stabilized (non-revisable) portion of the transcript;
/// interim chunks (`isFinal == false`) may be superseded by later results.
public struct TranscriptionChunk: Sendable {
    /// The partial transcript text carried by this chunk
    public let text: String

    /// Whether this chunk represents a finalized (non-revisable) result
    public let isFinal: Bool

    /// Initialize a streaming transcript chunk
    ///
    /// - Parameters:
    ///   - text: The partial transcript text
    ///   - isFinal: Whether this chunk is a finalized result (default: false)
    public init(text: String, isFinal: Bool = false) {
        self.text = text
        self.isFinal = isFinal
    }
}
