import Foundation

/// AI Gateway - Main coordinator for multi-provider AI operations
///
/// The AIGateway is a thread-safe actor that:
/// - Manages multiple AI provider implementations
/// - Resolves API keys based on configured strategy
/// - Routes requests to appropriate providers
/// - Handles provider registration and lifecycle
///
/// Usage:
/// ```swift
/// let config = Configuration.withCompanyKey("sk-...")
/// let gateway = AIGateway(configuration: config)
///
/// let request = AIRequest(model: "claude-sonnet-4-5", prompt: "Hello!")
/// let response = try await gateway.sendMessage(request)
/// ```
public actor AIGateway {
    /// Framework configuration
    private let configuration: Configuration

    /// Registered providers
    private var providers: [ProviderType: ProviderProtocol]

    /// Initialize with configuration
    ///
    /// - Parameter configuration: Framework configuration
    public init(configuration: Configuration) {
        self.configuration = configuration
        self.providers = Self.createDefaultProviders(configuration: configuration)
    }

    /// Initialize with custom providers
    ///
    /// - Parameters:
    ///   - configuration: Framework configuration
    ///   - providers: Custom provider implementations
    public init(
        configuration: Configuration,
        providers: [ProviderType: ProviderProtocol]
    ) {
        self.configuration = configuration
        self.providers = providers
    }

    // MARK: - Provider Management

    /// Register a provider implementation
    ///
    /// - Parameters:
    ///   - provider: Provider implementation
    ///   - type: Provider type
    public func registerProvider(_ provider: ProviderProtocol, for type: ProviderType) {
        providers[type] = provider
    }

    /// Get registered provider
    ///
    /// - Parameter type: Provider type
    /// - Returns: Provider implementation
    /// - Throws: AIError.providerNotRegistered if not found
    private func getProvider(_ type: ProviderType) throws -> ProviderProtocol {
        guard let provider = providers[type] else {
            throw AIError.providerNotRegistered(type)
        }
        return provider
    }

    // MARK: - Message Operations

    /// Send a message to an AI provider
    ///
    /// - Parameters:
    ///   - request: AI request
    ///   - provider: Provider to use (defaults to configuration default)
    ///   - clientAPIKey: Optional client-provided API key
    /// - Returns: AI response
    /// - Throws: AIError on failure
    public func sendMessage(
        _ request: AIRequest,
        to provider: ProviderType? = nil,
        clientAPIKey: String? = nil
    ) async throws -> AIResponse {
        let providerType = provider ?? configuration.defaultProvider
        let providerImpl = try getProvider(providerType)
        let apiKey = try resolveAPIKey(for: providerType, clientKey: clientAPIKey)

        return try await providerImpl.sendMessage(request, apiKey: apiKey)
    }

    /// Stream a message from an AI provider
    ///
    /// - Parameters:
    ///   - request: AI request
    ///   - provider: Provider to use (defaults to configuration default)
    ///   - clientAPIKey: Optional client-provided API key
    /// - Returns: AsyncThrowingStream of responses
    public func streamMessage(
        _ request: AIRequest,
        to provider: ProviderType? = nil,
        clientAPIKey: String? = nil
    ) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let providerType = provider ?? self.configuration.defaultProvider
                    let providerImpl = try self.getProvider(providerType)
                    let apiKey = try self.resolveAPIKey(for: providerType, clientKey: clientAPIKey)

                    let stream = providerImpl.streamMessage(request, apiKey: apiKey)

                    for try await response in stream {
                        continuation.yield(response)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Count tokens in a request
    ///
    /// - Parameters:
    ///   - request: AI request
    ///   - provider: Provider to use (defaults to configuration default)
    ///   - clientAPIKey: Optional client-provided API key
    /// - Returns: Token count (nil if provider doesn't support)
    /// - Throws: AIError on failure
    public func countTokens(
        _ request: AIRequest,
        for provider: ProviderType? = nil,
        clientAPIKey: String? = nil
    ) async throws -> Int? {
        let providerType = provider ?? configuration.defaultProvider
        let providerImpl = try getProvider(providerType)
        let apiKey = try resolveAPIKey(for: providerType, clientKey: clientAPIKey)

        return try await providerImpl.countTokens(request, apiKey: apiKey)
    }

    // MARK: - Batch Operations

    /// Create a batch of messages
    ///
    /// - Parameters:
    ///   - requests: Array of requests
    ///   - provider: Provider to use (defaults to configuration default)
    ///   - clientAPIKey: Optional client-provided API key
    /// - Returns: Batch ID
    /// - Throws: AIError on failure
    public func createBatch(
        _ requests: [AIRequest],
        for provider: ProviderType? = nil,
        clientAPIKey: String? = nil
    ) async throws -> String {
        let providerType = provider ?? configuration.defaultProvider
        let providerImpl = try getProvider(providerType)
        let apiKey = try resolveAPIKey(for: providerType, clientKey: clientAPIKey)

        return try await providerImpl.createBatch(requests, apiKey: apiKey)
    }

    /// Retrieve batch status
    ///
    /// - Parameters:
    ///   - batchId: Batch identifier
    ///   - provider: Provider to use (defaults to configuration default)
    ///   - clientAPIKey: Optional client-provided API key
    /// - Returns: Batch status
    /// - Throws: AIError on failure
    public func retrieveBatch(
        _ batchId: String,
        from provider: ProviderType? = nil,
        clientAPIKey: String? = nil
    ) async throws -> BatchStatus {
        let providerType = provider ?? configuration.defaultProvider
        let providerImpl = try getProvider(providerType)
        let apiKey = try resolveAPIKey(for: providerType, clientKey: clientAPIKey)

        return try await providerImpl.retrieveBatch(batchId, apiKey: apiKey)
    }

    /// Cancel a batch
    ///
    /// - Parameters:
    ///   - batchId: Batch identifier
    ///   - provider: Provider to use (defaults to configuration default)
    ///   - clientAPIKey: Optional client-provided API key
    /// - Returns: Updated batch status
    /// - Throws: AIError on failure
    public func cancelBatch(
        _ batchId: String,
        from provider: ProviderType? = nil,
        clientAPIKey: String? = nil
    ) async throws -> BatchStatus {
        let providerType = provider ?? configuration.defaultProvider
        let providerImpl = try getProvider(providerType)
        let apiKey = try resolveAPIKey(for: providerType, clientKey: clientAPIKey)

        return try await providerImpl.cancelBatch(batchId, apiKey: apiKey)
    }

    /// List batches
    ///
    /// - Parameters:
    ///   - limit: Maximum number of results
    ///   - afterId: Pagination cursor
    ///   - provider: Provider to use (defaults to configuration default)
    ///   - clientAPIKey: Optional client-provided API key
    /// - Returns: Array of batch statuses
    /// - Throws: AIError on failure
    public func listBatches(
        limit: Int? = nil,
        afterId: String? = nil,
        from provider: ProviderType? = nil,
        clientAPIKey: String? = nil
    ) async throws -> [BatchStatus] {
        let providerType = provider ?? configuration.defaultProvider
        let providerImpl = try getProvider(providerType)
        let apiKey = try resolveAPIKey(for: providerType, clientKey: clientAPIKey)

        return try await providerImpl.listBatches(limit: limit, afterId: afterId, apiKey: apiKey)
    }

    /// Get batch results
    ///
    /// - Parameters:
    ///   - batchId: Batch identifier
    ///   - provider: Provider to use (defaults to configuration default)
    ///   - clientAPIKey: Optional client-provided API key
    /// - Returns: Stream of batch results
    public func getBatchResults(
        _ batchId: String,
        from provider: ProviderType? = nil,
        clientAPIKey: String? = nil
    ) -> AsyncThrowingStream<BatchResult, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let providerType = provider ?? self.configuration.defaultProvider
                    let providerImpl = try self.getProvider(providerType)
                    let apiKey = try self.resolveAPIKey(for: providerType, clientKey: clientAPIKey)

                    let stream = providerImpl.getBatchResults(batchId, apiKey: apiKey)

                    for try await result in stream {
                        continuation.yield(result)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Methods

    /// Resolve API key based on strategy
    ///
    /// - Parameters:
    ///   - provider: Provider type
    ///   - clientKey: Optional client-provided key
    /// - Returns: Resolved API key
    /// - Throws: AIError.missingAPIKey if key cannot be resolved
    private func resolveAPIKey(for provider: ProviderType, clientKey: String?) throws -> String {
        return try configuration.keyStrategy.resolveKey(for: provider, clientKey: clientKey)
    }

    /// Create default provider implementations
    private static func createDefaultProviders(configuration: Configuration) -> [ProviderType: ProviderProtocol] {
        var providers: [ProviderType: ProviderProtocol] = [:]

        // Register Anthropic provider
        let anthropicProvider = AnthropicProvider(
            apiVersion: "2023-06-01",
            timeout: configuration.timeout,
            maxRetries: configuration.maxRetries,
            enableLogging: configuration.enableLogging,
            enableBetaFeatures: configuration.betaFeatures[.anthropic] ?? []
        )
        providers[.anthropic] = anthropicProvider

        // Register placeholder providers (will throw unsupported error)
        providers[.openai] = OpenAIProvider()
        providers[.google] = GoogleProvider()
        providers[.cohere] = CohereProvider()
        providers[.mistral] = MistralProvider()
        providers[.deepseek] = DeepSeekProvider()

        return providers
    }

    // MARK: - Convenience Methods

    /// Get configuration
    public var config: Configuration {
        configuration
    }

    /// Get list of registered providers
    public var registeredProviders: [ProviderType] {
        Array(providers.keys)
    }

    /// Check if a provider is registered
    ///
    /// - Parameter type: Provider type
    /// - Returns: True if registered
    public func isProviderRegistered(_ type: ProviderType) -> Bool {
        providers[type] != nil
    }
}
