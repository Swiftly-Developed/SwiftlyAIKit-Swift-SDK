import Foundation

/// Represents the supported AI provider types
///
/// Each case corresponds to a specific AI provider that implements the `ProviderProtocol`.
public enum ProviderType: String, Codable, Sendable, Hashable, CaseIterable {
    /// OpenAI (GPT models)
    case openai

    /// Anthropic (Claude models)
    case anthropic

    /// Google AI (Gemini and PaLM models)
    case google

    /// Perplexity AI (Sonar models with real-time search)
    case perplexity

    /// Cohere (Command and embedding models)
    case cohere

    /// Mistral AI (Mistral models)
    case mistral

    /// DeepSeek (DeepSeek models with reasoning)
    case deepseek

    /// xAI (Grok models)
    case grok

    /// Human-readable name for the provider
    public var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .google: return "Google AI"
        case .perplexity: return "Perplexity AI"
        case .cohere: return "Cohere"
        case .mistral: return "Mistral AI"
        case .deepseek: return "DeepSeek"
        case .grok: return "xAI Grok"
        }
    }

    /// Base API URL for the provider
    public var baseURL: String {
        switch self {
        case .openai:
            return "https://api.openai.com/v1"
        case .anthropic:
            return "https://api.anthropic.com/v1"
        case .google:
            return "https://generativelanguage.googleapis.com/v1"
        case .perplexity:
            return "https://api.perplexity.ai"
        case .cohere:
            return "https://api.cohere.ai/v1"
        case .mistral:
            return "https://api.mistral.ai/v1"
        case .deepseek:
            return "https://api.deepseek.com"
        case .grok:
            return "https://api.x.ai/v1"
        }
    }
}
