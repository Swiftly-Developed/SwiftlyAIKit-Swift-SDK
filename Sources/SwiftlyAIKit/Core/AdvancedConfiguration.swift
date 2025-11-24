import Foundation

// MARK: - Rate Limiting

/// Rate limiting configuration
public struct RateLimitConfig: Sendable {
    /// Maximum requests per minute
    public let requestsPerMinute: Int?

    /// Maximum requests per hour
    public let requestsPerHour: Int?

    /// Scope of rate limiting
    public let scope: RateLimitScope

    /// Storage mechanism for rate limit tracking
    public let storage: RateLimitStorage

    public init(
        requestsPerMinute: Int? = nil,
        requestsPerHour: Int? = nil,
        scope: RateLimitScope = .perClientKey,
        storage: RateLimitStorage = .memory
    ) {
        self.requestsPerMinute = requestsPerMinute
        self.requestsPerHour = requestsPerHour
        self.scope = scope
        self.storage = storage
    }
}

/// Scope for applying rate limits
public enum RateLimitScope: Sendable {
    /// Global rate limit across all clients
    case global

    /// Per client API key
    case perClientKey

    /// Per IP address
    case perIP
}

/// Storage mechanism for rate limit tracking
public enum RateLimitStorage: Sendable {
    /// In-memory storage (lost on restart)
    case memory

    /// Redis storage (persistent, distributed)
    case redis(url: String)

    /// Custom storage implementation (must be Sendable)
    case custom(@Sendable () -> any RateLimitStorageProtocol)
}

/// Protocol for custom rate limit storage implementations
public protocol RateLimitStorageProtocol: Sendable {
    func incrementCounter(key: String, window: TimeInterval) async throws -> Int
    func resetCounter(key: String) async throws
}

// MARK: - Logging Configuration

/// Logging configuration
public struct LoggingConfig: Sendable {
    /// Log incoming requests
    public let logRequests: Bool

    /// Log outgoing responses
    public let logResponses: Bool

    /// Log full request/response bodies (may contain sensitive data)
    public let logFullBodies: Bool

    /// Redact sensitive information from logs
    public let redactSensitiveData: Bool

    /// Custom logger instance
    public let logger: (any LoggerProtocol)?

    public init(
        logRequests: Bool = true,
        logResponses: Bool = true,
        logFullBodies: Bool = false,
        redactSensitiveData: Bool = true,
        logger: (any LoggerProtocol)? = nil
    ) {
        self.logRequests = logRequests
        self.logResponses = logResponses
        self.logFullBodies = logFullBodies
        self.redactSensitiveData = redactSensitiveData
        self.logger = logger
    }
}

/// Protocol for custom logger implementations
public protocol LoggerProtocol: Sendable {
    func log(level: LogLevel, message: String, metadata: [String: String]?)
}

/// Log levels
public enum LogLevel: String, Sendable {
    case debug, info, warning, error
}

// MARK: - Monitoring Configuration

/// Monitoring and metrics configuration
public struct MonitoringConfig: Sendable {
    /// Track token usage per request
    public let trackTokenUsage: Bool

    /// Track errors and failure rates
    public let trackErrors: Bool

    /// Track request latency
    public let trackLatency: Bool

    /// Track request throughput
    public let trackThroughput: Bool

    /// Custom metrics handler
    public let metricsHandler: (any MetricsHandlerProtocol)?

    public init(
        trackTokenUsage: Bool = true,
        trackErrors: Bool = true,
        trackLatency: Bool = true,
        trackThroughput: Bool = false,
        metricsHandler: (any MetricsHandlerProtocol)? = nil
    ) {
        self.trackTokenUsage = trackTokenUsage
        self.trackErrors = trackErrors
        self.trackLatency = trackLatency
        self.trackThroughput = trackThroughput
        self.metricsHandler = metricsHandler
    }
}

/// Protocol for custom metrics handlers
public protocol MetricsHandlerProtocol: Sendable {
    func recordTokenUsage(provider: ProviderType, model: String, tokens: Int)
    func recordError(provider: ProviderType, error: Error)
    func recordLatency(provider: ProviderType, duration: TimeInterval)
    func recordRequest(provider: ProviderType, model: String)
}

// MARK: - Model Restrictions

/// Model restriction configuration
public struct ModelRestrictions: Sendable {
    /// Set of allowed models (nil = all allowed)
    public let allowedModels: Set<String>?

    /// Set of blocked models
    public let blockedModels: Set<String>

    /// Default model to use if client doesn't specify
    public let defaultModel: String?

    /// Default provider for the default model
    public let defaultModelProvider: ProviderType?

    public init(
        allowedModels: Set<String>? = nil,
        blockedModels: Set<String> = [],
        defaultModel: String? = nil,
        defaultModelProvider: ProviderType? = nil
    ) {
        self.allowedModels = allowedModels
        self.blockedModels = blockedModels
        self.defaultModel = defaultModel
        self.defaultModelProvider = defaultModelProvider
    }

    /// Check if a model is allowed
    public func isModelAllowed(_ model: String) -> Bool {
        // Check if explicitly blocked
        if blockedModels.contains(model) {
            return false
        }

        // If allowlist exists, must be in it
        if let allowed = allowedModels {
            return allowed.contains(model)
        }

        // No restrictions = allowed
        return true
    }
}

// MARK: - Enhanced Configuration

/// Enhanced configuration with advanced features
public struct EnhancedConfiguration: Sendable {
    /// Base configuration
    public let base: Configuration

    /// Rate limiting settings
    public let rateLimits: RateLimitConfig?

    /// Logging settings
    public let logging: LoggingConfig?

    /// Monitoring settings
    public let monitoring: MonitoringConfig?

    /// Model restrictions
    public let modelRestrictions: ModelRestrictions?

    public init(
        base: Configuration,
        rateLimits: RateLimitConfig? = nil,
        logging: LoggingConfig? = nil,
        monitoring: MonitoringConfig? = nil,
        modelRestrictions: ModelRestrictions? = nil
    ) {
        self.base = base
        self.rateLimits = rateLimits
        self.logging = logging
        self.monitoring = monitoring
        self.modelRestrictions = modelRestrictions
    }
}
