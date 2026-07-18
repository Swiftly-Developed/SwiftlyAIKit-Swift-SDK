import Foundation

/// AI Gateway - Main coordinator for multi-provider AI operations
///
/// The AIGateway is a thread-safe actor that coordinates all AI operations across multiple
/// providers. It provides a unified interface for sending messages, streaming responses,
/// managing batches, and generating images.
///
/// ## Overview
///
/// `AIGateway` acts as the central hub for all AI operations in SwiftlyAIKit. It:
/// - Manages multiple AI provider implementations (Anthropic, OpenAI, Gemini, etc.)
/// - Resolves API keys based on your configured ``APIKeyStrategy``
/// - Routes requests to the appropriate provider automatically
/// - Handles provider registration and lifecycle
/// - Supports streaming, batching, and image generation
///
/// ## Quick Start
///
/// ```swift
/// import SwiftlyAIKit
///
/// // Create configuration with your API key
/// let config = Configuration.withCompanyKey("sk-ant-...")
/// let gateway = AIGateway(configuration: config)
///
/// // Send a message
/// let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Hello!")
/// let response = try await gateway.sendMessage(request)
/// print(response.message.content)
/// ```
///
/// ## Streaming Responses
///
/// For real-time responses (like ChatGPT), use streaming:
///
/// ```swift
/// let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Write a story")
/// let stream = try await gateway.streamMessage(request)
///
/// for try await chunk in stream {
///     print(chunk.message.content, terminator: "")
/// }
/// ```
///
/// ## Multi-Provider Support
///
/// Switch between providers easily by specifying the provider parameter:
///
/// ```swift
/// // Use Claude
/// let claudeResponse = try await gateway.sendMessage(request, to: .anthropic)
///
/// // Use GPT-4
/// let gptResponse = try await gateway.sendMessage(request, to: .openai)
///
/// // Use Gemini
/// let geminiResponse = try await gateway.sendMessage(request, to: .google)
/// ```
///
/// ## Topics
///
/// ### Creating a Gateway
/// - ``init(configuration:)``
/// - ``init(configuration:providers:)``
/// - ``Configuration``
///
/// ### Sending Messages
/// - ``sendMessage(_:to:clientAPIKey:)``
/// - ``streamMessage(_:to:clientAPIKey:)``
/// - ``countTokens(_:for:clientAPIKey:)``
///
/// ### Batch Operations
/// - ``createBatch(_:for:clientAPIKey:)``
/// - ``retrieveBatch(_:from:clientAPIKey:)``
/// - ``cancelBatch(_:from:clientAPIKey:)``
/// - ``listBatches(limit:afterId:from:clientAPIKey:)``
/// - ``getBatchResults(_:from:clientAPIKey:)``
///
/// ### Image Generation
/// - ``generateImage(_:using:clientAPIKey:)``
/// - ``supportsImageGeneration(for:)``
/// - ``imageGenerationModels(for:)``
///
/// ### Provider Management
/// - ``registerProvider(_:for:)``
/// - ``isProviderRegistered(_:)``
/// - ``registeredProviders``
/// - ``config``
///
/// ### Related Types
/// - ``AIRequest``
/// - ``AIResponse``
/// - ``AIMessage``
/// - ``AIError``
/// - ``ProviderType``
/// - ``ImageGenerationRequest``
/// - ``ImageGenerationResponse``
/// - ``BatchStatus``
/// - ``BatchResult``
///
/// ## See Also
/// - <doc:QuickStart>
/// - <doc:StreamingResponses>
/// - <doc:ErrorHandling>
/// - <doc:ChoosingAProvider>
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

        let context = LogContext(
            provider: providerType.rawValue,
            model: request.model,
            operation: "sendMessage"
        )

        await aiLog(.info, "Starting AI request", context: context, metadata: [
            "provider": providerType.rawValue,
            "model": request.model,
            "messageCount": "\(request.messages.count)"
        ])

        let providerImpl: ProviderProtocol
        do {
            providerImpl = try getProvider(providerType)
        } catch {
            await aiLog(.error, "Provider not registered", context: context, metadata: [
                "provider": providerType.rawValue
            ])
            throw error
        }

        let apiKey: String
        do {
            apiKey = try resolveAPIKey(for: providerType, clientKey: clientAPIKey)
            await aiLog(.debug, "API key resolved", context: context, metadata: [
                "keySource": clientAPIKey != nil ? "client" : "configuration"
            ])
        } catch {
            await aiLog(.error, "Failed to resolve API key", context: context, metadata: [
                "provider": providerType.rawValue,
                "hasClientKey": "\(clientAPIKey != nil)"
            ])
            throw error
        }

        await aiLog(.debug, "Routing to provider", context: context)

        do {
            let response = try await providerImpl.sendMessage(request, apiKey: apiKey)

            await aiLog(.info, "AI request completed", context: context, metadata: [
                "hasMessage": "\(!response.message.content.isEmpty)",
                "stopReason": response.stopReason?.rawValue ?? "unknown"
            ])

            return response
        } catch {
            await aiLog(.error, "AI request failed", context: context, metadata: [
                "error": String(describing: error),
                "errorType": String(describing: type(of: error))
            ])
            throw error
        }
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
        let providerType = provider ?? self.configuration.defaultProvider

        let context = LogContext(
            provider: providerType.rawValue,
            model: request.model,
            operation: "streamMessage"
        )

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    await aiLog(.info, "Starting AI streaming request", context: context, metadata: [
                        "provider": providerType.rawValue,
                        "model": request.model,
                        "messageCount": "\(request.messages.count)"
                    ])

                    let providerImpl = try self.getProvider(providerType)
                    let apiKey = try self.resolveAPIKey(for: providerType, clientKey: clientAPIKey)

                    await aiLog(.debug, "API key resolved, starting stream", context: context, metadata: [
                        "keySource": clientAPIKey != nil ? "client" : "configuration"
                    ])

                    let stream = providerImpl.streamMessage(request, apiKey: apiKey)

                    var chunkCount = 0
                    for try await response in stream {
                        chunkCount += 1
                        continuation.yield(response)
                    }

                    await aiLog(.info, "AI streaming request completed", context: context, metadata: [
                        "chunks": "\(chunkCount)"
                    ])

                    continuation.finish()
                } catch {
                    await aiLog(.error, "AI streaming request failed", context: context, metadata: [
                        "error": String(describing: error),
                        "errorType": String(describing: type(of: error))
                    ])
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

    // MARK: - Image Generation

    /// Generate images from a text prompt
    ///
    /// - Parameters:
    ///   - request: Image generation request
    ///   - provider: Provider to use (if not specified, determined from request model)
    ///   - clientAPIKey: Optional client-provided API key
    /// - Returns: Image generation response
    /// - Throws: AIError on failure
    ///
    /// ## Usage
    /// ```swift
    /// // Using convenience initializer
    /// let request = ImageGenerationRequest.dallE3(prompt: "A sunset over mountains")
    /// let response = try await gateway.generateImage(request)
    ///
    /// // Using explicit provider
    /// let request = ImageGenerationRequest(prompt: "A sunset", model: "dall-e-3")
    /// let response = try await gateway.generateImage(request, using: .openai)
    /// ```
    public func generateImage(
        _ request: ImageGenerationRequest,
        using provider: ProviderType? = nil,
        clientAPIKey: String? = nil
    ) async throws -> ImageGenerationResponse {
        // Determine provider from request model if not specified
        let providerType = provider ?? determineImageProvider(for: request.model)

        let context = LogContext(
            provider: providerType.rawValue,
            model: request.model,
            operation: "generateImage"
        )

        await aiLog(.info, "Starting image generation request", context: context, metadata: [
            "provider": providerType.rawValue,
            "model": request.model,
            "numberOfImages": "\(request.numberOfImages)"
        ])

        // Get provider and verify it supports image generation
        let providerImpl = try getProvider(providerType)

        guard let imageProvider = providerImpl as? ImageGenerationProvider,
              imageProvider.supportsImageGeneration else {
            throw AIError.unsupportedFeature(feature: "image generation", provider: providerType)
        }

        let apiKey = try resolveAPIKey(for: providerType, clientKey: clientAPIKey)

        let response = try await imageProvider.generateImage(request, apiKey: apiKey)

        await aiLog(.info, "Image generation completed", context: context, metadata: [
            "imagesGenerated": "\(response.images.count)"
        ])

        return response
    }

    /// Check if a provider supports image generation
    ///
    /// - Parameter provider: Provider type to check
    /// - Returns: True if the provider supports image generation
    public func supportsImageGeneration(for provider: ProviderType) -> Bool {
        guard let providerImpl = providers[provider] else {
            return false
        }

        if let imageProvider = providerImpl as? ImageGenerationProvider {
            return imageProvider.supportsImageGeneration
        }

        return false
    }

    /// Get available image generation models for a provider
    ///
    /// - Parameter provider: Provider type
    /// - Returns: Array of available model identifiers
    public func imageGenerationModels(for provider: ProviderType) -> [String] {
        guard let providerImpl = providers[provider] else {
            return []
        }

        if let imageProvider = providerImpl as? ImageGenerationProvider {
            return imageProvider.imageGenerationModels
        }

        return []
    }

    /// Determine the appropriate provider for an image model
    ///
    /// - Parameter model: Model identifier
    /// - Returns: Provider type
    private func determineImageProvider(for model: String) -> ProviderType {
        let lowercased = model.lowercased()

        if lowercased.contains("dall-e") || lowercased.contains("dalle") {
            return .openai
        } else if lowercased.contains("grok") {
            return .grok
        } else if lowercased.contains("apple") || lowercased.contains("image-playground") {
            return .appleIntelligence
        }

        // Default to OpenAI for image generation
        return .openai
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
        // Apple Intelligence runs on-device and doesn't need an API key
        if provider == .appleIntelligence {
            return ""
        }
        return try configuration.keyStrategy.resolveKey(for: provider, clientKey: clientKey)
    }

    /// Create default provider implementations
    ///
    /// Exposed as `internal` (rather than `private`) so the default provider wiring
    /// — e.g. that `.google` routes to a real ``GeminiProvider`` — can be verified in tests.
    static func createDefaultProviders(configuration: Configuration) -> [ProviderType: ProviderProtocol] {
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

        // Register other providers
        providers[.openai] = OpenAIProvider()
        // Route .google to the real Gemini implementation (config-aware, mirroring Anthropic).
        // GoogleProvider was an unimplemented stub that threw `unsupportedFeature`.
        providers[.google] = GeminiProvider(
            timeout: configuration.timeout,
            maxRetries: configuration.maxRetries,
            enableLogging: configuration.enableLogging
        )
        providers[.cohere] = CohereProvider()
        providers[.mistral] = MistralProvider()
        providers[.deepseek] = DeepSeekProvider()
        providers[.perplexity] = PerplexityProvider()
        providers[.grok] = GrokProvider()
        providers[.groq] = GroqProvider()

        // Register Apple Intelligence provider (on-device, no API key required)
        providers[.appleIntelligence] = AppleIntelligenceProvider()

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
