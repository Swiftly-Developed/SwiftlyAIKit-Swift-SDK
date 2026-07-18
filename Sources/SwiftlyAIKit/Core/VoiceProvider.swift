import Foundation

/// Protocol for providers that support text-to-speech (speech synthesis)
///
/// Voice is a **separate capability axis** from chat: conformers are *not* required to be
/// ``ProviderProtocol`` chat providers, and text-to-speech is never routed through
/// ``ProviderProtocol/sendMessage(_:apiKey:)``.
///
/// ## Overview
///
/// A text-to-speech provider turns text into spoken audio, either as a single buffer
/// (``synthesize(_:apiKey:)``) or as an incremental stream of audio chunks
/// (``streamSynthesize(_:apiKey:)``).
///
/// ## Conforming to TextToSpeech
///
/// ```swift
/// extension SomeVoiceProvider: TextToSpeech {
///     public var supportsTextToSpeech: Bool { true }
///
///     public var textToSpeechModels: [String] {
///         ["some-tts-model"]
///     }
///
///     public func synthesize(
///         _ request: SpeechSynthesisRequest,
///         apiKey: String
///     ) async throws -> SpeechSynthesisResponse {
///         // 1. Transform request to provider format
///         // 2. Make HTTP call
///         // 3. Return SpeechSynthesisResponse
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Protocol Requirements
/// - ``supportsTextToSpeech``
/// - ``textToSpeechModels``
/// - ``synthesize(_:apiKey:)``
/// - ``streamSynthesize(_:apiKey:)``
///
/// ### Helper Types
/// - ``VoiceCapabilities``
///
/// ### Related Types
/// - ``SpeechSynthesisRequest``
/// - ``SpeechSynthesisResponse``
/// - ``SpeechAudioChunk``
/// - ``VoiceProviderType``
public protocol TextToSpeech: Sendable {
    /// Whether this provider supports text-to-speech
    var supportsTextToSpeech: Bool { get }

    /// Available models for text-to-speech
    ///
    /// Returns an array of model identifiers that can be used in
    /// `SpeechSynthesisRequest.model`.
    var textToSpeechModels: [String] { get }

    /// Synthesize spoken audio from text
    ///
    /// - Parameters:
    ///   - request: The speech synthesis request
    ///   - apiKey: API key for authentication
    /// - Returns: The synthesized audio
    /// - Throws: `AIError.unsupportedFeature` if provider doesn't support text-to-speech
    func synthesize(
        _ request: SpeechSynthesisRequest,
        apiKey: String
    ) async throws -> SpeechSynthesisResponse

    /// Stream synthesized audio from text as it is produced
    ///
    /// - Parameters:
    ///   - request: The speech synthesis request
    ///   - apiKey: API key for authentication
    /// - Returns: An `AsyncThrowingStream` of incremental audio chunks
    func streamSynthesize(
        _ request: SpeechSynthesisRequest,
        apiKey: String
    ) -> AsyncThrowingStream<SpeechAudioChunk, Error>
}

// MARK: - TextToSpeech Default Implementation

extension TextToSpeech {
    /// Default: Text-to-speech not supported
    public var supportsTextToSpeech: Bool { false }

    /// Default: No text-to-speech models
    public var textToSpeechModels: [String] { [] }

    /// Default implementation throws unsupported error
    ///
    /// Providers that don't support text-to-speech will use this default,
    /// which throws an appropriate error.
    public func synthesize(
        _ request: SpeechSynthesisRequest,
        apiKey: String
    ) async throws -> SpeechSynthesisResponse {
        throw AIError.unsupportedFeature(
            feature: "text-to-speech",
            provider: voiceErrorProviderType(for: self)
        )
    }

    /// Default implementation finishes the stream with an unsupported error
    public func streamSynthesize(
        _ request: SpeechSynthesisRequest,
        apiKey: String
    ) -> AsyncThrowingStream<SpeechAudioChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.unsupportedFeature(
                feature: "text-to-speech",
                provider: voiceErrorProviderType(for: self)
            ))
        }
    }
}

/// Protocol for providers that support speech-to-text (transcription)
///
/// Voice is a **separate capability axis** from chat: conformers are *not* required to be
/// ``ProviderProtocol`` chat providers, and speech-to-text is never routed through
/// ``ProviderProtocol/sendMessage(_:apiKey:)``.
///
/// ## Overview
///
/// A speech-to-text provider turns recorded audio into text, either as a single transcript
/// (``transcribe(_:apiKey:)``) or as an incremental stream of interim/final chunks
/// (``streamTranscribe(_:apiKey:)``).
///
/// ## Conforming to SpeechToText
///
/// ```swift
/// extension SomeVoiceProvider: SpeechToText {
///     public var supportsSpeechToText: Bool { true }
///
///     public var speechToTextModels: [String] {
///         ["some-stt-model"]
///     }
///
///     public func transcribe(
///         _ request: TranscriptionRequest,
///         apiKey: String
///     ) async throws -> TranscriptionResponse {
///         // 1. Transform request to provider format
///         // 2. Make HTTP call
///         // 3. Return TranscriptionResponse
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Protocol Requirements
/// - ``supportsSpeechToText``
/// - ``speechToTextModels``
/// - ``transcribe(_:apiKey:)``
/// - ``streamTranscribe(_:apiKey:)``
///
/// ### Helper Types
/// - ``VoiceCapabilities``
///
/// ### Related Types
/// - ``TranscriptionRequest``
/// - ``TranscriptionResponse``
/// - ``TranscriptionChunk``
/// - ``VoiceProviderType``
public protocol SpeechToText: Sendable {
    /// Whether this provider supports speech-to-text
    var supportsSpeechToText: Bool { get }

    /// Available models for speech-to-text
    ///
    /// Returns an array of model identifiers that can be used in
    /// `TranscriptionRequest.model`.
    var speechToTextModels: [String] { get }

    /// Transcribe recorded audio into text
    ///
    /// - Parameters:
    ///   - request: The transcription request
    ///   - apiKey: API key for authentication
    /// - Returns: The transcript
    /// - Throws: `AIError.unsupportedFeature` if provider doesn't support speech-to-text
    func transcribe(
        _ request: TranscriptionRequest,
        apiKey: String
    ) async throws -> TranscriptionResponse

    /// Stream a transcript from audio as it is transcribed
    ///
    /// - Parameters:
    ///   - request: The transcription request
    ///   - apiKey: API key for authentication
    /// - Returns: An `AsyncThrowingStream` of incremental transcript chunks
    func streamTranscribe(
        _ request: TranscriptionRequest,
        apiKey: String
    ) -> AsyncThrowingStream<TranscriptionChunk, Error>
}

// MARK: - SpeechToText Default Implementation

extension SpeechToText {
    /// Default: Speech-to-text not supported
    public var supportsSpeechToText: Bool { false }

    /// Default: No speech-to-text models
    public var speechToTextModels: [String] { [] }

    /// Default implementation throws unsupported error
    ///
    /// Providers that don't support speech-to-text will use this default,
    /// which throws an appropriate error.
    public func transcribe(
        _ request: TranscriptionRequest,
        apiKey: String
    ) async throws -> TranscriptionResponse {
        throw AIError.unsupportedFeature(
            feature: "speech-to-text",
            provider: voiceErrorProviderType(for: self)
        )
    }

    /// Default implementation finishes the stream with an unsupported error
    public func streamTranscribe(
        _ request: TranscriptionRequest,
        apiKey: String
    ) -> AsyncThrowingStream<TranscriptionChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.unsupportedFeature(
                feature: "speech-to-text",
                provider: voiceErrorProviderType(for: self)
            ))
        }
    }
}

// MARK: - Error Provider Identity

/// Resolve a ``ProviderType`` identity for `AIError.unsupportedFeature`.
///
/// ``AIError`` is keyed by the chat ``ProviderType`` (voice's ``VoiceProviderType`` is a
/// separate axis). Mirroring ``ImageGenerationProvider``'s default resolution: if the
/// conformer is also a chat ``ProviderProtocol`` we report its `providerType`, otherwise
/// we fall back to `.openai`.
private func voiceErrorProviderType(for conformer: Any) -> ProviderType {
    (conformer as? ProviderProtocol)?.providerType ?? .openai
}

// MARK: - Voice Capabilities

/// Helper to check voice capabilities across voice providers
///
/// A lightweight metadata registry for the voice axis — the counterpart to
/// ``ImageGenerationCapabilities`` for chat. Each vendor arm is seeded empty here and filled
/// in by that vendor's own integration.
public struct VoiceCapabilities: Sendable {
    /// Check if a voice provider supports text-to-speech
    ///
    /// - Parameter provider: The voice provider type to check
    /// - Returns: True if the provider supports text-to-speech
    public static func ttsSupported(by provider: VoiceProviderType) -> Bool {
        switch provider {
        case .elevenLabs: return false
        case .deepgram: return false
        case .cartesia: return true
        case .openai: return false
        }
    }

    /// Check if a voice provider supports speech-to-text
    ///
    /// - Parameter provider: The voice provider type to check
    /// - Returns: True if the provider supports speech-to-text
    public static func sttSupported(by provider: VoiceProviderType) -> Bool {
        switch provider {
        case .elevenLabs: return false
        case .deepgram: return false
        case .cartesia: return true
        case .openai: return false
        }
    }

    /// Get available text-to-speech models for a voice provider
    ///
    /// - Parameter provider: The voice provider type
    /// - Returns: Array of model identifiers
    public static func ttsModels(for provider: VoiceProviderType) -> [String] {
        switch provider {
        case .elevenLabs: return []
        case .deepgram: return []
        case .cartesia: return CartesiaVoiceProvider.ttsModelIDs
        case .openai: return []
        }
    }

    /// Get available speech-to-text models for a voice provider
    ///
    /// - Parameter provider: The voice provider type
    /// - Returns: Array of model identifiers
    public static func sttModels(for provider: VoiceProviderType) -> [String] {
        switch provider {
        case .elevenLabs: return []
        case .deepgram: return []
        case .cartesia: return CartesiaVoiceProvider.sttModelIDs
        case .openai: return []
        }
    }

    /// Get available voice identifiers for a voice provider
    ///
    /// - Parameter provider: The voice provider type
    /// - Returns: Array of voice identifiers usable in `SpeechSynthesisRequest.voice`
    public static func voices(for provider: VoiceProviderType) -> [String] {
        switch provider {
        case .elevenLabs: return []
        case .deepgram: return []
        // Cartesia voice ids churn and are fetched at runtime via
        // `CartesiaVoiceProvider.listVoices(apiKey:)` rather than hardcoded here.
        case .cartesia: return []
        case .openai: return []
        }
    }
}
