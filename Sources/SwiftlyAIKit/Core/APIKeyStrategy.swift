import Foundation

/// Defines key management strategies for AI provider API keys
///
/// `APIKeyStrategy` determines how SwiftlyAIKit authenticates with AI providers. Choose a
/// strategy based on your security requirements, billing preferences, and architecture.
///
/// ## Overview
///
/// API key management is critical for both security and cost control. SwiftlyAIKit supports
/// four strategies to handle keys:
///
/// - ``companyKey(_:)`` - Server controls a single key for all providers
/// - ``clientKey`` - Clients must provide their own keys
/// - ``hybrid(defaultKey:)`` - Client keys preferred, with company fallback
/// - ``perProvider(_:)`` - Different keys for different providers
///
/// ## Security Considerations
///
/// **Never expose API keys in client applications!** Keys embedded in client code can be
/// extracted and abused. For production iOS/macOS apps:
///
/// ✅ **Recommended:** Use ``clientKey`` strategy with your own server proxy
/// ✅ **Recommended:** Use ``hybrid(defaultKey:)`` with server-side rate limiting
/// ❌ **Not Recommended:** Embedding keys directly in Swift code
///
/// ## Usage Examples
///
/// ### Company Key (Server-Managed)
///
/// Best for: Server-side applications, internal tools, centralized billing
///
/// ```swift
/// let strategy = APIKeyStrategy.companyKey("sk-ant-...")
/// let config = Configuration(keyStrategy: strategy)
/// let gateway = AIGateway(configuration: config)
///
/// // All requests use the company key automatically
/// let response = try await gateway.sendMessage(request)
/// ```
///
/// ### Client Key (User-Provided)
///
/// Best for: SaaS applications, cost pass-through to users, zero key storage
///
/// ```swift
/// let strategy = APIKeyStrategy.clientKey
/// let config = Configuration(keyStrategy: strategy)
/// let gateway = AIGateway(configuration: config)
///
/// // Client must provide key with each request
/// let userKey = getUserAPIKey() // From user's account settings
/// let response = try await gateway.sendMessage(request, clientAPIKey: userKey)
/// ```
///
/// ### Hybrid (Optional Client Keys)
///
/// Best for: Freemium models, premium features, flexible billing
///
/// ```swift
/// let strategy = APIKeyStrategy.hybrid(defaultKey: "sk-ant-...")
/// let config = Configuration(keyStrategy: strategy)
/// let gateway = AIGateway(configuration: config)
///
/// // Free tier users (no key provided)
/// let freeResponse = try await gateway.sendMessage(request)
///
/// // Premium users (provide their own key for higher limits)
/// let premiumResponse = try await gateway.sendMessage(request, clientAPIKey: premiumUserKey)
/// ```
///
/// ### Per-Provider Keys
///
/// Best for: Multi-provider applications, separate billing accounts
///
/// ```swift
/// let strategy = APIKeyStrategy.perProvider([
///     .anthropic: "sk-ant-...",
///     .openai: "sk-...",
///     .google: "..."
/// ])
/// let config = Configuration(keyStrategy: strategy)
/// let gateway = AIGateway(configuration: config)
///
/// // Each provider uses its own key automatically
/// let claudeResponse = try await gateway.sendMessage(request, to: .anthropic)
/// let gptResponse = try await gateway.sendMessage(request, to: .openai)
/// ```
///
/// ## Topics
///
/// ### Strategy Cases
/// - ``companyKey(_:)``
/// - ``clientKey``
/// - ``hybrid(defaultKey:)``
/// - ``perProvider(_:)``
///
/// ### Resolving Keys
/// - ``resolveKey(for:clientKey:)``
///
/// ### Strategy Properties
/// - ``requiresClientKey``
/// - ``acceptsClientKey``
///
/// ### Related Types
/// - ``Configuration``
/// - ``ProviderType``
/// - ``AIError``
///
/// ## See Also
/// - <doc:APIKeyManagement>
/// - <doc:ConfigurationSystem>
/// - <doc:ChoosingDeploymentPattern>
public enum APIKeyStrategy: Sendable {
    /// Server manages a single API key for all requests to all providers
    ///
    /// Use this when you want to:
    /// - Control all AI costs centrally
    /// - Simplify client implementation
    /// - Track usage at the server level
    ///
    /// - Parameter key: The API key to use for all provider requests
    case companyKey(String)

    /// Clients must provide their own API key with each request
    ///
    /// Use this when you want to:
    /// - Pass AI costs directly to clients
    /// - Allow clients to use their own provider accounts
    /// - Avoid storing any API keys on the server
    ///
    /// The gateway will extract the key from request headers:
    /// - `X-API-Key` header
    /// - `Authorization` header (Bearer token)
    case clientKey

    /// Use client key if provided, otherwise fall back to a default company key
    ///
    /// Use this when you want to:
    /// - Support both client and company-funded requests
    /// - Provide a seamless experience with optional client keys
    /// - Offer premium features with client keys
    ///
    /// - Parameter defaultKey: The fallback API key when client doesn't provide one
    case hybrid(defaultKey: String)

    /// Use different company keys for different providers
    ///
    /// Use this when you want to:
    /// - Separate billing across providers
    /// - Use different accounts for different providers
    /// - Apply different rate limits per provider
    ///
    /// - Parameter keys: Dictionary mapping provider types to their API keys
    case perProvider([ProviderType: String])

    /// Resolve the API key to use for a given provider and optional client key
    ///
    /// - Parameters:
    ///   - provider: The AI provider to get the key for
    ///   - clientKey: Optional client-provided API key
    /// - Returns: The resolved API key to use
    /// - Throws: `AIError.missingAPIKey` if no valid key can be resolved
    public func resolveKey(for provider: ProviderType, clientKey: String?) throws -> String {
        switch self {
        case .companyKey(let key):
            return key

        case .clientKey:
            guard let key = clientKey, !key.isEmpty else {
                throw AIError.missingAPIKey(provider: provider)
            }
            return key

        case .hybrid(let defaultKey):
            if let key = clientKey, !key.isEmpty {
                return key
            }
            return defaultKey

        case .perProvider(let keys):
            // First try client key if provided
            if let key = clientKey, !key.isEmpty {
                return key
            }

            // Fall back to provider-specific key
            guard let key = keys[provider] else {
                throw AIError.missingAPIKey(provider: provider)
            }
            return key
        }
    }

    /// Check if this strategy requires a client key
    public var requiresClientKey: Bool {
        if case .clientKey = self {
            return true
        }
        return false
    }

    /// Check if this strategy accepts client keys
    public var acceptsClientKey: Bool {
        switch self {
        case .companyKey:
            return false
        case .clientKey, .hybrid, .perProvider:
            return true
        }
    }
}
