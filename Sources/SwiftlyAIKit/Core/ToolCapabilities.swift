import Foundation

/// Helper to check tool / function-calling capabilities by provider type
///
/// Mirrors ``ImageGenerationCapabilities``: a static, ``ProviderType``-keyed lookup that lets
/// callers detect whether a provider can act on ``AIRequest/tools`` **without** instantiating the
/// provider. For an instance-level check, use ``ProviderProtocol/supportsTools``.
///
/// ## Overview
///
/// Most providers support tool calling. The nuances are:
/// - **Perplexity** — the Sonar Chat Completions API has no function calling, but the provider
///   routes tool-bearing requests to Perplexity's **Agent API** (`/v1/responses`), so tool calling
///   is supported.
/// - **Apple Intelligence** — supported only where Foundation Models is available (iOS 26+ /
///   macOS 26+ SDK); on older SDKs it reports `false`.
///
/// ## Usage
///
/// ```swift
/// if ToolCapabilities.isSupported(by: .perplexity) {
///     request = request.withTools(myTools)
/// } else {
///     // Fall back to a plain prompt — this provider ignores tools.
/// }
/// ```
///
/// ## Topics
///
/// ### Checking Support
/// - ``isSupported(by:)``
///
/// ### Related
/// - ``ProviderProtocol/supportsTools``
public struct ToolCapabilities: Sendable {
    /// Check if a provider supports tool / function calling
    ///
    /// - Parameter provider: The provider type to check
    /// - Returns: `true` if the provider supports tool calling, `false` otherwise
    public static func isSupported(by provider: ProviderType) -> Bool {
        // Exhaustive switch (no `default`) so that adding a `ProviderType` case forces a
        // compile error here — new providers must declare their tool support explicitly.
        switch provider {
        case .openai, .anthropic, .google, .grok, .groq, .openRouter, .ollama, .cohere, .mistral, .deepseek, .perplexity:
            // Perplexity routes tool-bearing requests to its Agent API (`/v1/responses`).
            return true
        case .appleIntelligence:
            // Tool calling is wired through Foundation Models, which only exists on the
            // iOS 26+ / macOS 26+ SDK. On older SDKs the provider ignores tools.
            #if canImport(FoundationModels)
            return true
            #else
            return false
            #endif
        }
    }
}
