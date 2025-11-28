import Foundation

/// Flexible builder for creating EnhancedConfiguration
///
/// `ConfigurationBuilder` provides a fluent, chainable API for configuring all aspects of
/// the AI gateway with advanced features like rate limiting, monitoring, and model restrictions.
///
/// ## Overview
///
/// Use the builder pattern when you need fine-grained control over gateway configuration:
/// - Rate limiting per client or globally
/// - Request/response logging
/// - Token usage monitoring
/// - Model allowlists/blocklists
/// - Custom metrics handlers
///
/// ## Basic Usage
///
/// ```swift
/// let config = ConfigurationBuilder()
///     .setProviderKey("sk-ant-...", for: .anthropic)
///     .setProviderKey("sk-...", for: .openai)
///     .timeout(120)
///     .maxRetries(5)
///     .enableLogging()
///     .build()
/// ```
///
/// ## Advanced Features
///
/// ### Rate Limiting
///
/// ```swift
/// let config = ConfigurationBuilder()
///     .setProviderKey("sk-ant-...", for: .anthropic)
///     .rateLimit(requestsPerMinute: 60, per: .perClientKey)
///     .build()
/// ```
///
/// ### Model Restrictions
///
/// ```swift
/// let config = ConfigurationBuilder()
///     .setProviderKey("sk-ant-...", for: .anthropic)
///     .allowModels("claude-3-5-sonnet-20241022", "gpt-4")
///     .defaultModel("claude-3-5-sonnet-20241022", provider: .anthropic)
///     .build()
/// ```
///
/// ### Monitoring
///
/// ```swift
/// let config = ConfigurationBuilder()
///     .setProviderKey("sk-ant-...", for: .anthropic)
///     .enableMonitoring(trackTokenUsage: true, trackErrors: true)
///     .build()
/// ```
///
/// ## Topics
///
/// ### Creating a Builder
/// - ``init()``
///
/// ### API Keys
/// - ``setProviderKey(_:for:)``
/// - ``setProviderKeys(_:)``
/// - ``keyStrategy(_:)``
///
/// ### Base Configuration
/// - ``timeout(_:)``
/// - ``maxRetries(_:)``
/// - ``defaultProvider(_:)``
/// - ``enableBetaFeatures(_:for:)``
/// - ``customBaseURL(_:for:)``
///
/// ### Model Restrictions
/// - ``allowModels(_:)-8shry``
/// - ``blockModels(_:)-9cp3w``
/// - ``defaultModel(_:provider:)``
///
/// ### Rate Limiting
/// - ``rateLimit(requestsPerMinute:requestsPerHour:per:storage:)``
///
/// ### Logging
/// - ``enableLogging(logRequests:logResponses:logFullBodies:redactSensitiveData:logger:)``
/// - ``enableSimpleLogging()``
/// - ``enableVerboseLogging()``
///
/// ### Monitoring
/// - ``enableMonitoring(trackTokenUsage:trackErrors:trackLatency:trackThroughput:metricsHandler:)``
/// - ``enableFullMonitoring(metricsHandler:)``
///
/// ### Building
/// - ``build()``
///
/// ### Related Types
/// - ``Configuration``
/// - ``EnhancedConfiguration``
/// - ``APIKeyStrategy``
/// - ``RateLimitConfig``
/// - ``LoggingConfig``
/// - ``MonitoringConfig``
///
/// ## See Also
/// - <doc:ConfigurationSystem>
/// - ``Configuration``
public class ConfigurationBuilder {
    // Base configuration properties
    private var keyStrategy: APIKeyStrategy?
    private var providerKeys: [ProviderType: String] = [:]
    private var timeout: Int = 60
    private var maxRetries: Int = 3
    private var baseEnableLogging: Bool = false
    private var betaFeatures: [ProviderType: [String]] = [:]
    private var customBaseURLs: [ProviderType: String] = [:]
    private var defaultProvider: ProviderType = .anthropic

    // Advanced configuration properties
    private var rateLimitConfig: RateLimitConfig?
    private var loggingConfig: LoggingConfig?
    private var monitoringConfig: MonitoringConfig?
    private var modelRestrictionsConfig: ModelRestrictions?

    public init() {}

    // MARK: - Base Configuration

    /// Set API key for a specific provider
    @discardableResult
    public func setProviderKey(_ key: String, for provider: ProviderType) -> Self {
        providerKeys[provider] = key
        return self
    }

    /// Set multiple provider keys at once
    @discardableResult
    public func setProviderKeys(_ keys: [ProviderType: String]) -> Self {
        providerKeys.merge(keys) { _, new in new }
        return self
    }

    /// Set the key strategy explicitly
    @discardableResult
    public func keyStrategy(_ strategy: APIKeyStrategy) -> Self {
        self.keyStrategy = strategy
        return self
    }

    /// Set request timeout
    @discardableResult
    public func timeout(_ seconds: Int) -> Self {
        self.timeout = seconds
        return self
    }

    /// Set maximum retry attempts
    @discardableResult
    public func maxRetries(_ count: Int) -> Self {
        self.maxRetries = count
        return self
    }

    /// Set default provider
    @discardableResult
    public func defaultProvider(_ provider: ProviderType) -> Self {
        self.defaultProvider = provider
        return self
    }

    /// Enable beta features for a provider
    @discardableResult
    public func enableBetaFeatures(_ features: [String], for provider: ProviderType) -> Self {
        betaFeatures[provider] = features
        return self
    }

    /// Set custom base URL for a provider
    @discardableResult
    public func customBaseURL(_ url: String, for provider: ProviderType) -> Self {
        customBaseURLs[provider] = url
        return self
    }

    // MARK: - Model Restrictions

    /// Set allowed models (allowlist approach)
    @discardableResult
    public func allowModels(_ models: String...) -> Self {
        return allowModels(Set(models))
    }

    /// Set allowed models from a set
    @discardableResult
    public func allowModels(_ models: Set<String>) -> Self {
        if var existing = modelRestrictionsConfig {
            existing = ModelRestrictions(
                allowedModels: models,
                blockedModels: existing.blockedModels,
                defaultModel: existing.defaultModel,
                defaultModelProvider: existing.defaultModelProvider
            )
            modelRestrictionsConfig = existing
        } else {
            modelRestrictionsConfig = ModelRestrictions(allowedModels: models)
        }
        return self
    }

    /// Block specific models
    @discardableResult
    public func blockModels(_ models: String...) -> Self {
        return blockModels(Set(models))
    }

    /// Block specific models from a set
    @discardableResult
    public func blockModels(_ models: Set<String>) -> Self {
        if var existing = modelRestrictionsConfig {
            existing = ModelRestrictions(
                allowedModels: existing.allowedModels,
                blockedModels: models,
                defaultModel: existing.defaultModel,
                defaultModelProvider: existing.defaultModelProvider
            )
            modelRestrictionsConfig = existing
        } else {
            modelRestrictionsConfig = ModelRestrictions(blockedModels: models)
        }
        return self
    }

    /// Set default model
    @discardableResult
    public func defaultModel(_ model: String, provider: ProviderType) -> Self {
        if var existing = modelRestrictionsConfig {
            existing = ModelRestrictions(
                allowedModels: existing.allowedModels,
                blockedModels: existing.blockedModels,
                defaultModel: model,
                defaultModelProvider: provider
            )
            modelRestrictionsConfig = existing
        } else {
            modelRestrictionsConfig = ModelRestrictions(
                defaultModel: model,
                defaultModelProvider: provider
            )
        }
        return self
    }

    // MARK: - Rate Limiting

    /// Enable rate limiting
    @discardableResult
    public func rateLimit(
        requestsPerMinute: Int? = nil,
        requestsPerHour: Int? = nil,
        per scope: RateLimitScope = .perClientKey,
        storage: RateLimitStorage = .memory
    ) -> Self {
        rateLimitConfig = RateLimitConfig(
            requestsPerMinute: requestsPerMinute,
            requestsPerHour: requestsPerHour,
            scope: scope,
            storage: storage
        )
        return self
    }

    // MARK: - Logging

    /// Enable logging with configuration
    @discardableResult
    public func enableLogging(
        logRequests: Bool = true,
        logResponses: Bool = true,
        logFullBodies: Bool = false,
        redactSensitiveData: Bool = true,
        logger: (any AILogger)? = nil
    ) -> Self {
        loggingConfig = LoggingConfig(
            logRequests: logRequests,
            logResponses: logResponses,
            logFullBodies: logFullBodies,
            redactSensitiveData: redactSensitiveData,
            logger: logger
        )
        baseEnableLogging = true
        return self
    }

    /// Enable simple logging (requests and responses only)
    @discardableResult
    public func enableSimpleLogging() -> Self {
        return enableLogging(logRequests: true, logResponses: true, logFullBodies: false)
    }

    /// Enable verbose logging (includes full bodies)
    @discardableResult
    public func enableVerboseLogging() -> Self {
        return enableLogging(logRequests: true, logResponses: true, logFullBodies: true)
    }

    // MARK: - Monitoring

    /// Enable monitoring with configuration
    @discardableResult
    public func enableMonitoring(
        trackTokenUsage: Bool = true,
        trackErrors: Bool = true,
        trackLatency: Bool = true,
        trackThroughput: Bool = false,
        metricsHandler: (any MetricsHandlerProtocol)? = nil
    ) -> Self {
        monitoringConfig = MonitoringConfig(
            trackTokenUsage: trackTokenUsage,
            trackErrors: trackErrors,
            trackLatency: trackLatency,
            trackThroughput: trackThroughput,
            metricsHandler: metricsHandler
        )
        return self
    }

    /// Enable all monitoring features
    @discardableResult
    public func enableFullMonitoring(metricsHandler: (any MetricsHandlerProtocol)? = nil) -> Self {
        return enableMonitoring(
            trackTokenUsage: true,
            trackErrors: true,
            trackLatency: true,
            trackThroughput: true,
            metricsHandler: metricsHandler
        )
    }

    // MARK: - Build

    /// Build the enhanced configuration
    ///
    /// - Returns: EnhancedConfiguration instance
    /// - Throws: ConfigurationError if configuration is invalid
    public func build() throws -> EnhancedConfiguration {
        // Determine key strategy
        let strategy: APIKeyStrategy
        if let explicitStrategy = keyStrategy {
            strategy = explicitStrategy
        } else if !providerKeys.isEmpty {
            // Use per-provider strategy if keys were set
            strategy = .perProvider(providerKeys)
        } else {
            throw ConfigurationError.missingAPIKeys
        }

        // Build base configuration
        let base = Configuration(
            keyStrategy: strategy,
            providerKeys: providerKeys,
            timeout: timeout,
            maxRetries: maxRetries,
            enableLogging: baseEnableLogging,
            betaFeatures: betaFeatures,
            customBaseURLs: customBaseURLs,
            defaultProvider: defaultProvider
        )

        // Build enhanced configuration
        return EnhancedConfiguration(
            base: base,
            rateLimits: rateLimitConfig,
            logging: loggingConfig,
            monitoring: monitoringConfig,
            modelRestrictions: modelRestrictionsConfig
        )
    }
}

// MARK: - Configuration Errors

public enum ConfigurationError: Error, CustomStringConvertible {
    case missingAPIKeys
    case invalidRateLimits
    case invalidModelRestrictions(String)

    public var description: String {
        switch self {
        case .missingAPIKeys:
            return "No API keys configured. Use setProviderKey() or keyStrategy() to configure authentication."
        case .invalidRateLimits:
            return "Invalid rate limit configuration. Must specify at least one of requestsPerMinute or requestsPerHour."
        case .invalidModelRestrictions(let message):
            return "Invalid model restrictions: \(message)"
        }
    }
}
