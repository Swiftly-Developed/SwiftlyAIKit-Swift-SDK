import Foundation

/// Represents the supported voice provider types
///
/// Voice is a **separate capability axis** from chat. This enum is intentionally distinct
/// from ``ProviderType`` so that the chat providers' exhaustive `switch` statements
/// (``AIGateway``, ``ImageGenerationCapabilities``, `baseURL`) are untouched by voice vendors.
///
/// ## Overview
///
/// SwiftlyAIKit's voice axis targets these providers:
/// - ``elevenLabs`` - ElevenLabs (text-to-speech)
/// - ``deepgram`` - Deepgram (speech-to-text)
/// - ``cartesia`` - Cartesia (low-latency text-to-speech)
/// - ``openai`` - OpenAI audio (text-to-speech and speech-to-text)
///
/// - Note: ``openai`` reuses the OpenAI key and base URL, but is its own voice token —
///   distinct from the chat ``ProviderType/openai``.
///
/// ## Usage
///
/// ```swift
/// print(VoiceProviderType.elevenLabs.displayName) // "ElevenLabs"
/// print(VoiceProviderType.elevenLabs.baseURL)     // "https://api.elevenlabs.io/v1"
/// ```
///
/// ## Topics
///
/// ### Providers
/// - ``elevenLabs``
/// - ``deepgram``
/// - ``cartesia``
/// - ``openai``
///
/// ### Properties
/// - ``displayName``
/// - ``baseURL``
///
/// ### Related Types
/// - ``TextToSpeech``
/// - ``SpeechToText``
/// - ``VoiceCapabilities``
public enum VoiceProviderType: String, Codable, Sendable, Hashable, CaseIterable {
    /// ElevenLabs (text-to-speech)
    ///
    /// Note: the explicit raw value `"elevenlabs"` is required — the implicit String raw
    /// value of `elevenLabs` would be the camelCased case name `"elevenLabs"`, but the
    /// provider token is the lowercased `"elevenlabs"`.
    case elevenLabs = "elevenlabs"

    /// Deepgram (speech-to-text)
    case deepgram

    /// Cartesia (low-latency text-to-speech)
    case cartesia

    /// OpenAI audio (text-to-speech and speech-to-text)
    ///
    /// Reuses the OpenAI key and base URL, but is a distinct voice token from the chat
    /// ``ProviderType/openai``.
    case openai

    /// Human-readable name for the voice provider
    public var displayName: String {
        switch self {
        case .elevenLabs: return "ElevenLabs"
        case .deepgram: return "Deepgram"
        case .cartesia: return "Cartesia"
        case .openai: return "OpenAI"
        }
    }

    /// Base API URL for the voice provider
    public var baseURL: String {
        switch self {
        case .elevenLabs:
            return "https://api.elevenlabs.io/v1"
        case .deepgram:
            return "https://api.deepgram.com/v1"
        case .cartesia:
            return "https://api.cartesia.ai"
        case .openai:
            return "https://api.openai.com/v1"
        }
    }
}
