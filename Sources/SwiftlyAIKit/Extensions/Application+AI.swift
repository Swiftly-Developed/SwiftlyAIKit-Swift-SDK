import Vapor

/// Vapor Application extension for AI Gateway integration
///
/// Provides convenient access to the AI Gateway throughout your Vapor application.
///
/// Usage in configure.swift:
/// ```swift
/// func configure(_ app: Application) async throws {
///     let config = Configuration.withCompanyKey("sk-ant-...")
///     app.ai.initialize(with: config)
/// }
/// ```
extension Application {
    /// AI Gateway storage key
    private struct AIGatewayKey: StorageKey {
        typealias Value = AIGateway
    }

    /// Access the AI Gateway instance
    ///
    /// Usage:
    /// ```swift
    /// let response = try await app.ai.sendMessage(request)
    /// ```
    public var ai: AIGateway {
        get {
            guard let gateway = storage[AIGatewayKey.self] else {
                fatalError("""
                    AIGateway not initialized. Please call app.ai.initialize(with:) in configure.
                    Example:
                    let config = Configuration.withCompanyKey("your-api-key")
                    app.ai.initialize(with: config)
                    """)
            }
            return gateway
        }
        set {
            storage[AIGatewayKey.self] = newValue
        }
    }

    /// AI Gateway initialization helper
    public struct AIGatewayInitializer {
        let app: Application

        /// Initialize the AI Gateway with configuration
        ///
        /// - Parameter configuration: Framework configuration
        ///
        /// Usage:
        /// ```swift
        /// let config = Configuration.withCompanyKey("sk-ant-...")
        /// app.ai.initialize(with: config)
        /// ```
        public func initialize(with configuration: Configuration) {
            let gateway = AIGateway(configuration: configuration)
            app.storage[AIGatewayKey.self] = gateway
        }

        /// Initialize with custom providers
        ///
        /// - Parameters:
        ///   - configuration: Framework configuration
        ///   - providers: Custom provider implementations
        public func initialize(
            with configuration: Configuration,
            providers: [ProviderType: ProviderProtocol]
        ) {
            let gateway = AIGateway(configuration: configuration, providers: providers)
            app.storage[AIGatewayKey.self] = gateway
        }

        /// Initialize with custom gateway instance
        ///
        /// - Parameter gateway: Pre-configured gateway
        public func initialize(gateway: AIGateway) {
            app.storage[AIGatewayKey.self] = gateway
        }
    }

    /// AI Gateway initializer
    ///
    /// Provides fluent API for gateway setup:
    /// ```swift
    /// app.ai.initialize(with: Configuration.withCompanyKey("sk-ant-..."))
    /// ```
    public var aiInitializer: AIGatewayInitializer {
        AIGatewayInitializer(app: self)
    }
}

// MARK: - Convenience Configuration Methods

extension Application {
    /// Configure AI Gateway with company key (convenience)
    ///
    /// - Parameters:
    ///   - apiKey: Company API key
    ///   - provider: Default provider (default: .anthropic)
    ///   - enableLogging: Enable logging (default: false)
    ///
    /// Usage:
    /// ```swift
    /// app.configureAI(withCompanyKey: "sk-ant-...")
    /// ```
    public func configureAI(
        withCompanyKey apiKey: String,
        provider: ProviderType = .anthropic,
        enableLogging: Bool = false
    ) {
        let config = Configuration.withCompanyKey(apiKey, provider: provider, enableLogging: enableLogging)
        aiInitializer.initialize(with: config)
    }

    /// Configure AI Gateway with client keys (convenience)
    ///
    /// - Parameters:
    ///   - provider: Default provider (default: .anthropic)
    ///   - enableLogging: Enable logging (default: false)
    ///
    /// Usage:
    /// ```swift
    /// app.configureAI(withClientKeys: .anthropic)
    /// ```
    public func configureAI(
        withClientKeys provider: ProviderType = .anthropic,
        enableLogging: Bool = false
    ) {
        let config = Configuration.withClientKeys(provider: provider, enableLogging: enableLogging)
        aiInitializer.initialize(with: config)
    }

    /// Configure AI Gateway with hybrid keys (convenience)
    ///
    /// - Parameters:
    ///   - defaultKey: Fallback API key
    ///   - provider: Default provider (default: .anthropic)
    ///   - enableLogging: Enable logging (default: false)
    ///
    /// Usage:
    /// ```swift
    /// app.configureAI(withHybridKeys: "sk-ant-...")
    /// ```
    public func configureAI(
        withHybridKeys defaultKey: String,
        provider: ProviderType = .anthropic,
        enableLogging: Bool = false
    ) {
        let config = Configuration.withHybridKeys(defaultKey: defaultKey, provider: provider, enableLogging: enableLogging)
        aiInitializer.initialize(with: config)
    }

    /// Configure AI Gateway for development (convenience)
    ///
    /// - Parameters:
    ///   - apiKey: Company API key
    ///   - provider: Default provider (default: .anthropic)
    ///
    /// Usage:
    /// ```swift
    /// if app.environment == .development {
    ///     app.configureAIDevelopment(apiKey: "sk-ant-...")
    /// }
    /// ```
    public func configureAIDevelopment(
        apiKey: String,
        provider: ProviderType = .anthropic
    ) {
        let config = Configuration.development(companyKey: apiKey, provider: provider)
        aiInitializer.initialize(with: config)
    }
}
