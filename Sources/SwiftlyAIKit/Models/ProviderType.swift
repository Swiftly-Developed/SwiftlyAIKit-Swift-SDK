import Foundation

/// Represents the supported AI provider types
///
/// Each case corresponds to a specific AI provider that implements the ``ProviderProtocol``.
///
/// ## Overview
///
/// SwiftlyAIKit supports 9 AI providers:
/// - ``openai`` - OpenAI GPT models
/// - ``anthropic`` - Anthropic Claude models
/// - ``google`` - Google Gemini models
/// - ``perplexity`` - Perplexity AI with web search
/// - ``cohere`` - Cohere models optimized for RAG
/// - ``mistral`` - Mistral AI models (EU-hosted)
/// - ``deepseek`` - DeepSeek models (cost-optimized)
/// - ``grok`` - xAI Grok models
/// - ``appleIntelligence`` - Apple on-device models
///
/// ## Usage
///
/// ```swift
/// // Explicit provider selection
/// let response = try await gateway.sendMessage(request, to: .anthropic)
///
/// // Use provider's display name
/// print(ProviderType.anthropic.displayName) // "Anthropic"
///
/// // Get base URL
/// print(ProviderType.anthropic.baseURL) // "https://api.anthropic.com/v1"
/// ```
///
/// ## Topics
///
/// ### Providers
/// - ``openai``
/// - ``anthropic``
/// - ``google``
/// - ``perplexity``
/// - ``cohere``
/// - ``mistral``
/// - ``deepseek``
/// - ``grok``
/// - ``appleIntelligence``
///
/// ### Properties
/// - ``displayName``
/// - ``baseURL``
///
/// ### Related Types
/// - ``ProviderProtocol``
/// - ``AIGateway``
/// - ``Configuration``
///
/// ## See Also
/// - <doc:ProvidersOverview>
/// - <doc:ChoosingAProvider>
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

    /// Apple Intelligence (on-device Foundation Models and Image Playground)
    /// Note: Requires iOS 26+/macOS 26+ for Foundation Models, iOS 18.4+/macOS 15.4+ for Image Playground
    case appleIntelligence

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
        case .appleIntelligence: return "Apple Intelligence"
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
        case .appleIntelligence:
            // Apple Intelligence runs on-device, no external API
            return ""
        }
    }
}
