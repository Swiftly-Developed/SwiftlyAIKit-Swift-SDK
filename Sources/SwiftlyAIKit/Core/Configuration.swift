import Foundation

/// Framework configuration for SwiftlyAIKit
///
/// `Configuration` defines all settings for the AI gateway, including API key management,
/// HTTP client behavior, logging, and provider-specific options.
///
/// ## Overview
///
/// Configuration is the foundation of SwiftlyAIKit. It determines:
/// - How API keys are managed and resolved (``APIKeyStrategy``)
/// - HTTP request timeouts and retry behavior
/// - Which provider is used by default
/// - Whether logging is enabled for debugging
/// - Provider-specific beta features and custom endpoints
///
/// ## Quick Start
///
/// The simplest configuration uses a single API key for all providers:
///
/// ```swift
/// let config = Configuration.withCompanyKey("sk-ant-...")
/// let gateway = AIGateway(configuration: config)
/// ```
///
/// ## API Key Strategies
///
/// SwiftlyAIKit supports four key management strategies:
///
/// ### Company Key (Server-Managed)
/// ```swift
/// let config = Configuration.withCompanyKey(
///     "sk-ant-...",
///     provider: .anthropic,
///     enableLogging: false
/// )
/// ```
///
/// ### Client Keys (User-Provided)
/// ```swift
/// let config = Configuration.withClientKeys(
///     provider: .anthropic,
///     enableLogging: false
/// )
/// // Clients pass their key with each request
/// let response = try await gateway.sendMessage(request, clientAPIKey: userKey)
/// ```
///
/// ### Hybrid Keys (Optional Client Keys)
/// ```swift
/// let config = Configuration.withHybridKeys(
///     defaultKey: "sk-ant-...",
///     provider: .anthropic
/// )
/// // Uses client key if provided, falls back to default
/// ```
///
/// ### Per-Provider Keys
/// ```swift
/// let config = Configuration.withProviderKeys([
///     .anthropic: "sk-ant-...",
///     .openai: "sk-...",
///     .google: "..."
/// ])
/// ```
///
/// ## Development vs Production
///
/// Use pre-configured environments:
///
/// ```swift
/// // Development: verbose logging, longer timeouts
/// let devConfig = Configuration.development(
///     companyKey: "sk-ant-...",
///     provider: .anthropic
/// )
///
/// // Production: minimal logging, aggressive retries
/// let prodConfig = Configuration.production(
///     keyStrategy: .companyKey("sk-ant-..."),
///     provider: .anthropic
/// )
/// ```
///
/// ## Advanced Configuration
///
/// For fine-grained control, use the full initializer:
///
/// ```swift
/// let config = Configuration(
///     keyStrategy: .companyKey("sk-ant-..."),
///     timeout: 120,           // 2 minute timeout
///     maxRetries: 5,          // Retry 5 times
///     enableLogging: true,
///     betaFeatures: [
///         .anthropic: ["prompt-caching-2024-07-31"]
///     ],
///     customBaseURLs: [
///     .anthropic: "https://api.anthropic.com"
///     ],
///     defaultProvider: .anthropic
/// )
/// ```
///
/// ## Topics
///
/// ### Creating Configurations
/// - ``init(keyStrategy:providerKeys:timeout:maxRetries:enableLogging:betaFeatures:customBaseURLs:defaultProvider:)``
/// - ``withCompanyKey(_:provider:enableLogging:)``
/// - ``withClientKeys(provider:enableLogging:)``
/// - ``withHybridKeys(defaultKey:provider:enableLogging:)``
/// - ``withProviderKeys(_:defaultProvider:enableLogging:)``
///
/// ### Environment Presets
/// - ``development(companyKey:provider:)``
/// - ``production(keyStrategy:provider:)``
///
/// ### Configuration Properties
/// - ``keyStrategy``
/// - ``providerKeys``
/// - ``timeout``
/// - ``maxRetries``
/// - ``enableLogging``
/// - ``betaFeatures``
/// - ``customBaseURLs``
/// - ``defaultProvider``
///
/// ### Logging Configuration
/// - ``configureLogging(logger:logLevel:)``
///
/// ### Related Types
/// - ``APIKeyStrategy``
/// - ``ProviderType``
/// - ``AIGateway``
///
/// ## See Also
/// - <doc:QuickStart>
/// - <doc:APIKeyManagement>
/// - <doc:ConfigurationSystem>
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
    ) -> Self {
        Self(
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
    ) -> Self {
        Self(
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
    ) -> Self {
        Self(
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
    ) -> Self {
        Self(
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
    ) -> Self {
        Self(
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
    ) -> Self {
        Self(
            keyStrategy: keyStrategy,
            timeout: 60,
            maxRetries: 3,
            enableLogging: false,
            defaultProvider: provider
        )
    }

    /// Configure logging for this configuration
    ///
    /// This method sets up the global LoggingManager with the appropriate
    /// logger implementation based on the platform (OSLog on Apple, PrintLogger elsewhere).
    ///
    /// - Parameters:
    ///   - logger: Custom logger implementation (optional, uses platform default if nil)
    ///   - logLevel: Minimum log level to output (default: .debug)
    /// - Returns: The same configuration (logging is configured globally)
    @discardableResult
    public func configureLogging(
        logger: AILogger? = nil,
        logLevel: LogLevel = .debug
    ) -> Self {
        let effectiveLogger: AILogger
        #if canImport(OSLog)
        effectiveLogger = logger ?? OSLogLogger()
        #else
        effectiveLogger = logger ?? PrintLogger.shared
        #endif

        Task {
            await LoggingManager.shared.configure(
                logger: effectiveLogger,
                minimumLevel: logLevel,
                enabled: enableLogging
            )
        }

        return self
    }
}
