import Foundation

/// Unified text-to-speech response
///
/// Contains the synthesized audio produced by any ``TextToSpeech`` provider.
///
/// ## Overview
///
/// After a one-shot ``TextToSpeech/synthesize(_:apiKey:)`` call you receive the complete
/// audio buffer together with the format it was encoded in and the model that produced it.
///
/// ## Accessing Synthesized Audio
///
/// ```swift
/// let response = try await provider.synthesize(request, apiKey: key)
/// let fileURL = URL.temporaryDirectory.appendingPathComponent("speech.\(response.format.rawValue)")
/// try response.audio.write(to: fileURL)
/// ```
///
/// ## Topics
///
/// ### Response Properties
/// - ``audio``
/// - ``format``
/// - ``model``
///
/// ### Related Types
/// - ``SpeechSynthesisRequest``
/// - ``SpeechAudioChunk``
///
/// ## See Also
/// - ``TextToSpeech``
public struct SpeechSynthesisResponse: Sendable {
    /// The synthesized audio, encoded in ``format``
    public let audio: Data

    /// The audio format of ``audio``
    public let format: AudioFormat

    /// The model used for synthesis
    public let model: String

    /// Initialize a text-to-speech response
    ///
    /// - Parameters:
    ///   - audio: The synthesized audio data
    ///   - format: The audio format of `audio`
    ///   - model: The model used for synthesis
    public init(
        audio: Data,
        format: AudioFormat,
        model: String
    ) {
        self.audio = audio
        self.format = format
        self.model = model
    }
}

/// A single incremental chunk of synthesized audio
///
/// Emitted by ``TextToSpeech/streamSynthesize(_:apiKey:)`` as audio is produced. Concatenate
/// each chunk's ``audio`` in arrival order to reconstruct the full stream.
public struct SpeechAudioChunk: Sendable {
    /// A contiguous slice of encoded audio bytes
    public let audio: Data

    /// Initialize a synthesized audio chunk
    ///
    /// - Parameter audio: A contiguous slice of encoded audio bytes
    public init(audio: Data) {
        self.audio = audio
    }
}
