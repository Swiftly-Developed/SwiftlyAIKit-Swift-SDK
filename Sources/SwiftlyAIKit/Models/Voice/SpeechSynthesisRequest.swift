import Foundation

/// Unified text-to-speech request
///
/// This request type works across all text-to-speech providers (ElevenLabs, Cartesia,
/// OpenAI, …) that conform to ``TextToSpeech``.
///
/// ## Overview
///
/// Synthesize spoken audio from text. The neutral shape carries the common parameters;
/// provider-specific tuning is left to each conformer.
///
/// ## Basic Usage
///
/// ```swift
/// let request = SpeechSynthesisRequest(
///     text: "The quick brown fox jumps over the lazy dog.",
///     model: "some-tts-model",
///     voice: "narrator",
///     format: .mp3
/// )
///
/// let response = try await provider.synthesize(request, apiKey: key)
/// ```
///
/// ## Topics
///
/// ### Creating Requests
/// - ``init(text:model:voice:format:speed:sampleRate:)``
///
/// ### Request Properties
/// - ``text``
/// - ``voice``
/// - ``model``
/// - ``format``
/// - ``speed``
/// - ``sampleRate``
///
/// ### Related Types
/// - ``SpeechSynthesisResponse``
/// - ``SpeechAudioChunk``
/// - ``AudioFormat``
///
/// ## See Also
/// - ``TextToSpeech``
public struct SpeechSynthesisRequest: Sendable {
    /// The text to synthesize into speech
    public let text: String

    /// Identifier of the voice to use, if the provider supports voice selection
    ///
    /// Voice identifiers are provider-specific. Discover them via
    /// ``VoiceCapabilities/voices(for:)``.
    public let voice: String?

    /// The model to use for synthesis
    public let model: String

    /// Desired output audio format
    public let format: AudioFormat

    /// Playback speed multiplier (e.g. `1.0` = normal), if supported
    public let speed: Double?

    /// Desired output sample rate in Hz (e.g. `24000`), if supported
    public let sampleRate: Int?

    /// Initialize a text-to-speech request
    ///
    /// - Parameters:
    ///   - text: The text to synthesize into speech
    ///   - model: The model to use for synthesis
    ///   - voice: Identifier of the voice to use (default: nil)
    ///   - format: Desired output audio format (default: mp3)
    ///   - speed: Playback speed multiplier (default: nil)
    ///   - sampleRate: Desired output sample rate in Hz (default: nil)
    public init(
        text: String,
        model: String,
        voice: String? = nil,
        format: AudioFormat = .mp3,
        speed: Double? = nil,
        sampleRate: Int? = nil
    ) {
        self.text = text
        self.model = model
        self.voice = voice
        self.format = format
        self.speed = speed
        self.sampleRate = sampleRate
    }
}
