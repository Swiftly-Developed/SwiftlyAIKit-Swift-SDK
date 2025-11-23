import Foundation

/// Framework configuration for SwiftlyAIKit
///
/// Defines settings for AI gateway operation, including:
/// - API key management strategy
/// - Provider-specific configurations
/// - HTTP client settings
/// - Logging and debugging options
public struct Configuration: Sendable {
    /// API key management strategy
    public let keyStrategy: APIKeyStrategy

    /// Provider-specific API keys (when using perProvider strategy)
    public let providerKeys: [ProviderType: String]

    /// Request timeout in seconds
    public let timeout: Int

    /// Maximum retry attempts for failed requests
    public let maxRetries: Int

    /// Enable request/response logging
    public let enableLogging: Bool

    /// Beta features to enable per provider
    public let betaFeatures: [ProviderType: [String]]

    /// Custom base URLs for providers (optional overrides)
    public let customBaseURLs: [ProviderType: String]

    /// Default provider to use if not specified
    public let defaultProvider: ProviderType

    /// Initialize with full configuration
    ///
    /// - Parameters:
    ///   - keyStrategy: API key management strategy
    ///   - providerKeys: Provider-specific keys (default: empty)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxRetries: Maximum retry attempts (default: 3)
    ///   - enableLogging: Enable logging (default: false)
    ///   - betaFeatures: Beta features per provider (default: empty)
    ///   - customBaseURLs: Custom base URLs (default: empty)
    ///   - defaultProvider: Default provider (default: .anthropic)
    public init(
        keyStrategy: APIKeyStrategy,
        providerKeys: [ProviderType: String] = [:],
        timeout: Int = 60,
        maxRetries: Int = 3,
        enableLogging: Bool = false,
        betaFeatures: [ProviderType: [String]] = [:],
        customBaseURLs: [ProviderType: String] = [:],
        defaultProvider: ProviderType = .anthropic
    ) {
        self.keyStrategy = keyStrategy
        self.providerKeys = providerKeys
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.enableLogging = enableLogging
        self.betaFeatures = betaFeatures
        self.customBaseURLs = customBaseURLs
        self.defaultProvider = defaultProvider
    }

    /// Create a configuration with a single company key
    ///
    /// - Parameters:
    ///   - companyKey: API key for all providers
    ///   - provider: Which provider to use (default: .anthropic)
    ///   - enableLogging: Enable logging (default: false)
    /// - Returns: Configuration with company key strategy
    public static func withCompanyKey(
        _ companyKey: String,
        provider: ProviderType = .anthropic,
        enableLogging: Bool = false
    ) -> Configuration {
        Configuration(
            keyStrategy: .companyKey(companyKey),
            enableLogging: enableLogging,
            defaultProvider: provider
        )
    }

    /// Create a configuration that requires client keys
    ///
    /// - Parameters:
    ///   - provider: Which provider to use (default: .anthropic)
    ///   - enableLogging: Enable logging (default: false)
    /// - Returns: Configuration with client key strategy
    public static func withClientKeys(
        provider: ProviderType = .anthropic,
        enableLogging: Bool = false
    ) -> Configuration {
        Configuration(
            keyStrategy: .clientKey,
            enableLogging: enableLogging,
            defaultProvider: provider
        )
    }

    /// Create a configuration with hybrid key strategy
    ///
    /// - Parameters:
    ///   - defaultKey: Fallback API key
    ///   - provider: Which provider to use (default: .anthropic)
    ///   - enableLogging: Enable logging (default: false)
    /// - Returns: Configuration with hybrid key strategy
    public static func withHybridKeys(
        defaultKey: String,
        provider: ProviderType = .anthropic,
        enableLogging: Bool = false
    ) -> Configuration {
        Configuration(
            keyStrategy: .hybrid(defaultKey: defaultKey),
            enableLogging: enableLogging,
            defaultProvider: provider
        )
    }

    /// Create a configuration with different keys per provider
    ///
    /// - Parameters:
    ///   - providerKeys: Dictionary of provider keys
    ///   - defaultProvider: Default provider (default: .anthropic)
    ///   - enableLogging: Enable logging (default: false)
    /// - Returns: Configuration with per-provider keys
    public static func withProviderKeys(
        _ providerKeys: [ProviderType: String],
        defaultProvider: ProviderType = .anthropic,
        enableLogging: Bool = false
    ) -> Configuration {
        Configuration(
            keyStrategy: .perProvider(providerKeys),
            providerKeys: providerKeys,
            enableLogging: enableLogging,
            defaultProvider: defaultProvider
        )
    }

    /// Create a development configuration with logging enabled
    ///
    /// - Parameters:
    ///   - companyKey: API key
    ///   - provider: Provider to use (default: .anthropic)
    /// - Returns: Configuration optimized for development
    public static func development(
        companyKey: String,
        provider: ProviderType = .anthropic
    ) -> Configuration {
        Configuration(
            keyStrategy: .companyKey(companyKey),
            timeout: 120, // Longer timeout for debugging
            maxRetries: 1, // Fewer retries for faster feedback
            enableLogging: true,
            defaultProvider: provider
        )
    }

    /// Create a production configuration
    ///
    /// - Parameters:
    ///   - keyStrategy: Key management strategy
    ///   - provider: Default provider (default: .anthropic)
    /// - Returns: Configuration optimized for production
    public static func production(
        keyStrategy: APIKeyStrategy,
        provider: ProviderType = .anthropic
    ) -> Configuration {
        Configuration(
            keyStrategy: keyStrategy,
            timeout: 60,
            maxRetries: 3,
            enableLogging: false,
            defaultProvider: provider
        )
    }
}
