import Foundation

/// Protocol that all AI providers must conform to
///
/// `ProviderProtocol` defines the standard interface for AI providers in SwiftlyAIKit. Every
/// provider (Anthropic, OpenAI, Gemini, etc.) implements this protocol to handle provider-specific
/// request/response formatting and API communication.
///
/// ## Overview
///
/// This protocol abstracts away provider differences, allowing ``AIGateway`` to work with any
/// AI provider through a unified interface. Providers handle:
/// - Transforming ``AIRequest`` to provider-specific format
/// - Making HTTP calls to the provider's API
/// - Parsing responses back into ``AIResponse``
/// - Handling streaming, batching, and token counting
///
/// ## Implementing a Custom Provider
///
/// To add support for a new AI provider:
///
/// ```swift
/// public struct CustomProvider: ProviderProtocol {
///     public let providerType: ProviderType = .custom("MyProvider")
///
///     public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
///         // 1. Transform AIRequest to provider format
///         let providerRequest = transformRequest(request)
///
///         // 2. Make HTTP request
///         let response = try await httpClient.post(url, body: providerRequest)
///
///         // 3. Transform response to AIResponse
///         return try parseResponse(response)
///     }
///
///     public func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
///         AsyncThrowingStream { continuation in
///             Task {
///                 // Stream implementation
///             }
///         }
///     }
/// }
/// ```
///
/// ## Required Methods
///
/// All providers must implement:
/// - ``sendMessage(_:apiKey:)`` - Send a single message
/// - ``streamMessage(_:apiKey:)`` - Stream responses in real-time
///
/// ## Optional Methods
///
/// Providers can optionally implement:
/// - ``countTokens(_:apiKey:)`` - Count tokens without making a request
/// - ``createBatch(_:apiKey:)`` - Create asynchronous batch operations
/// - ``retrieveBatch(_:apiKey:)`` - Check batch status
/// - ``cancelBatch(_:apiKey:)`` - Cancel a running batch
/// - ``listBatches(limit:afterId:apiKey:)`` - List all batches
/// - ``getBatchResults(_:apiKey:)`` - Stream batch results
///
/// ## Topics
///
/// ### Provider Identity
/// - ``providerType``
///
/// ### Core Operations
/// - ``sendMessage(_:apiKey:)``
/// - ``streamMessage(_:apiKey:)``
/// - ``countTokens(_:apiKey:)``
///
/// ### Batch Operations
/// - ``createBatch(_:apiKey:)``
/// - ``retrieveBatch(_:apiKey:)``
/// - ``cancelBatch(_:apiKey:)``
/// - ``listBatches(limit:afterId:apiKey:)``
/// - ``getBatchResults(_:apiKey:)``
///
/// ### Supporting Types
/// - ``BatchStatus``
/// - ``BatchResult``
///
/// ### Related Types
/// - ``AIRequest``
/// - ``AIResponse``
/// - ``AIError``
/// - ``ProviderType``
/// - ``AIGateway``
///
/// ## See Also
/// - <doc:ArchitectureOverview>
/// - <doc:ProviderProtocolGuide>
/// - <doc:ExtensibilityPoints>
public protocol ProviderProtocol: Sendable {
    /// The type of provider this implementation represents
    var providerType: ProviderType { get }

    // MARK: - Core Message Operations

    /// Send a single message request to the AI provider
    ///
    /// - Parameters:
    ///   - request: Provider-agnostic AI request
    ///   - apiKey: API key for authentication
    /// - Returns: Provider-agnostic AI response
    /// - Throws: AIError on failure
    func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse

    /// Stream a message request to the AI provider
    ///
    /// - Parameters:
    ///   - request: Provider-agnostic AI request
    ///   - apiKey: API key for authentication
    /// - Returns: AsyncThrowingStream of incremental responses
    func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error>

    // MARK: - Optional Advanced Operations

    /// Count tokens in a request without making an API call
    ///
    /// Not all providers support this. Default implementation returns nil.
    ///
    /// - Parameters:
    ///   - request: The request to count tokens for
    ///   - apiKey: API key for authentication
    /// - Returns: Token count, or nil if not supported
    func countTokens(_ request: AIRequest, apiKey: String) async throws -> Int?

    // MARK: - Batch Operations (Optional)

    /// Create a batch of messages to process asynchronously
    ///
    /// Not all providers support batch processing. Default implementation throws unsupported error.
    ///
    /// - Parameters:
    ///   - requests: Array of requests to process
    ///   - apiKey: API key for authentication
    /// - Returns: Batch ID for tracking
    func createBatch(_ requests: [AIRequest], apiKey: String) async throws -> String

    /// Retrieve the status and metadata of a batch
    ///
    /// - Parameters:
    ///   - batchId: The batch identifier
    ///   - apiKey: API key for authentication
    /// - Returns: Batch status information
    func retrieveBatch(_ batchId: String, apiKey: String) async throws -> BatchStatus

    /// Cancel a running batch operation
    ///
    /// - Parameters:
    ///   - batchId: The batch identifier
    ///   - apiKey: API key for authentication
    /// - Returns: Updated batch status
    func cancelBatch(_ batchId: String, apiKey: String) async throws -> BatchStatus

    /// List all batches with optional pagination
    ///
    /// - Parameters:
    ///   - limit: Maximum number of results
    ///   - afterId: Cursor for pagination
    ///   - apiKey: API key for authentication
    /// - Returns: Array of batch statuses
    func listBatches(
        limit: Int?,
        afterId: String?,
        apiKey: String
    ) async throws -> [BatchStatus]

    /// Retrieve results from a completed batch
    ///
    /// - Parameters:
    ///   - batchId: The batch identifier
    ///   - apiKey: API key for authentication
    /// - Returns: Stream of batch results
    func getBatchResults(
        _ batchId: String,
        apiKey: String
    ) -> AsyncThrowingStream<BatchResult, Error>
}

// MARK: - Supporting Types

/// Batch processing status
public struct BatchStatus: Codable, Sendable {
    public let id: String
    public let status: String
    public let createdAt: Date
    public let completedAt: Date?
    public let failedAt: Date?
    public let expiresAt: Date?
    public let requestCounts: RequestCounts?

    public struct RequestCounts: Codable, Sendable {
        public let total: Int
        public let completed: Int
        public let failed: Int
    }

    public init(
        id: String,
        status: String,
        createdAt: Date,
        completedAt: Date? = nil,
        failedAt: Date? = nil,
        expiresAt: Date? = nil,
        requestCounts: RequestCounts? = nil
    ) {
        self.id = id
        self.status = status
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.failedAt = failedAt
        self.expiresAt = expiresAt
        self.requestCounts = requestCounts
    }
}

/// Result from a batch operation
public struct BatchResult: Codable, Sendable {
    public let requestId: String
    public let response: AIResponse?
    public let error: String?

    public init(requestId: String, response: AIResponse? = nil, error: String? = nil) {
        self.requestId = requestId
        self.response = response
        self.error = error
    }
}

// MARK: - Default Implementations

extension ProviderProtocol {
    /// Default implementation returns nil (not supported)
    public func countTokens(_ request: AIRequest, apiKey: String) async throws -> Int? {
        nil
    }

    /// Default implementation throws unsupported error
    public func createBatch(_ requests: [AIRequest], apiKey: String) async throws -> String {
        throw AIError.unsupportedFeature(feature: "batch processing", provider: providerType)
    }

    /// Default implementation throws unsupported error
    public func retrieveBatch(_ batchId: String, apiKey: String) async throws -> BatchStatus {
        throw AIError.unsupportedFeature(feature: "batch processing", provider: providerType)
    }

    /// Default implementation throws unsupported error
    public func cancelBatch(_ batchId: String, apiKey: String) async throws -> BatchStatus {
        throw AIError.unsupportedFeature(feature: "batch processing", provider: providerType)
    }

    /// Default implementation throws unsupported error
    public func listBatches(
        limit: Int?,
        afterId: String?,
        apiKey: String
    ) async throws -> [BatchStatus] {
        throw AIError.unsupportedFeature(feature: "batch processing", provider: providerType)
    }

    /// Default implementation throws unsupported error
    public func getBatchResults(
        _ batchId: String,
        apiKey: String
    ) -> AsyncThrowingStream<BatchResult, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.unsupportedFeature(
                feature: "batch processing",
                provider: providerType
            ))
        }
    }
}
