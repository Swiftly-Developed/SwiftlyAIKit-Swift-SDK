import Foundation

/// Unified speech-to-text request
///
/// This request type works across all speech-to-text providers (Deepgram, OpenAI, …) that
/// conform to ``SpeechToText``.
///
/// ## Overview
///
/// Transcribe recorded audio into text. Supply the raw audio bytes and the model to use;
/// optionally hint the spoken language and the audio's MIME type.
///
/// ## Basic Usage
///
/// ```swift
/// let request = TranscriptionRequest(
///     audio: recordedData,
///     model: "some-stt-model",
///     language: "en",
///     mimeType: "audio/wav"
/// )
///
/// let response = try await provider.transcribe(request, apiKey: key)
/// print(response.text)
/// ```
///
/// ## Topics
///
/// ### Creating Requests
/// - ``init(audio:model:language:mimeType:)``
///
/// ### Request Properties
/// - ``audio``
/// - ``model``
/// - ``language``
/// - ``mimeType``
///
/// ### Related Types
/// - ``TranscriptionResponse``
/// - ``TranscriptionChunk``
///
/// ## See Also
/// - ``SpeechToText``
public struct TranscriptionRequest: Sendable {
    /// The audio bytes to transcribe
    public let audio: Data

    /// The model to use for transcription
    public let model: String

    /// BCP-47 language hint (e.g. `"en"`, `"fr-BE"`), if known
    ///
    /// When `nil`, providers that support it will auto-detect the language.
    public let language: String?

    /// MIME type of ``audio`` (e.g. `"audio/wav"`), if known
    public let mimeType: String?

    /// Initialize a speech-to-text request
    ///
    /// - Parameters:
    ///   - audio: The audio bytes to transcribe
    ///   - model: The model to use for transcription
    ///   - language: BCP-47 language hint (default: nil, auto-detect)
    ///   - mimeType: MIME type of `audio` (default: nil)
    public init(
        audio: Data,
        model: String,
        language: String? = nil,
        mimeType: String? = nil
    ) {
        self.audio = audio
        self.model = model
        self.language = language
        self.mimeType = mimeType
    }
}
