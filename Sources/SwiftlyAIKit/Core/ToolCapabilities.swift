import Foundation

/// Helper to check tool / function-calling capabilities by provider type
///
/// Mirrors ``ImageGenerationCapabilities``: a static, ``ProviderType``-keyed lookup that lets
/// callers detect whether a provider can act on ``AIRequest/tools`` **without** instantiating the
/// provider. For an instance-level check, use ``ProviderProtocol/supportsTools``.
///
/// ## Overview
///
/// Most providers support tool calling. The exceptions are:
/// - **Perplexity** — the Sonar API is a pure search/answer API with no function calling.
/// - **Apple Intelligence** — tool calling is not wired through this SDK.
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
        case .openai, .anthropic, .google, .grok, .cohere, .mistral, .deepseek:
            return true
        case .perplexity, .appleIntelligence:
            return false
        }
    }
}
