import Foundation

/// Defines key management strategies for AI provider API keys
///
/// SwiftlyAIKit supports multiple strategies for managing API keys, allowing flexibility
/// in how your application authenticates with AI providers.
///
/// - `companyKey`: Use a server-managed API key for all requests
/// - `clientKey`: Require clients to provide their own API key with each request
/// - `hybrid`: Use client key if provided, otherwise fall back to a default company key
/// - `perProvider`: Use different company keys for different providers
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
