import Foundation

// MARK: - Audio Format

/// Audio container / encoding format for voice operations
///
/// Used by ``SpeechSynthesisRequest`` to request a specific output encoding and by
/// ``SpeechSynthesisResponse`` to report the encoding of the returned audio. Different
/// providers support different subsets — each vendor conformer advertises what it accepts.
///
/// ## Overview
///
/// Available formats:
/// - ``mp3`` - MPEG audio layer III (widely supported, lossy)
/// - ``wav`` - Waveform audio (uncompressed PCM in a RIFF container)
/// - ``pcm`` - Raw little-endian PCM samples (no container)
/// - ``opus`` - Opus (low-latency, streaming-friendly, lossy)
/// - ``flac`` - Free Lossless Audio Codec
/// - ``aac`` - Advanced Audio Coding (lossy)
///
/// ## Usage
///
/// ```swift
/// let request = SpeechSynthesisRequest(
///     text: "Hello, world.",
///     model: "some-tts-model",
///     format: .mp3
/// )
///
/// print(AudioFormat.mp3.mimeType) // "audio/mpeg"
/// ```
///
/// ## Topics
///
/// ### Formats
/// - ``mp3``
/// - ``wav``
/// - ``pcm``
/// - ``opus``
/// - ``flac``
/// - ``aac``
///
/// ### Properties
/// - ``mimeType``
///
/// ## See Also
/// - ``SpeechSynthesisRequest``
/// - ``SpeechSynthesisResponse``
public enum AudioFormat: String, Codable, Sendable, CaseIterable {
    /// MPEG audio layer III (lossy, widely supported)
    case mp3

    /// Waveform audio — uncompressed PCM in a RIFF/WAV container
    case wav

    /// Raw little-endian PCM samples with no container
    case pcm

    /// Opus — low-latency, streaming-friendly, lossy
    case opus

    /// Free Lossless Audio Codec
    case flac

    /// Advanced Audio Coding (lossy)
    case aac

    /// Best-effort MIME type for this format
    ///
    /// Useful when building `Content-Type`/`Accept` headers or writing audio to disk.
    public var mimeType: String {
        switch self {
        case .mp3: return "audio/mpeg"
        case .wav: return "audio/wav"
        case .pcm: return "audio/L16"
        case .opus: return "audio/opus"
        case .flac: return "audio/flac"
        case .aac: return "audio/aac"
        }
    }
}
