import Foundation

/// Framework-specific errors for AI operations
///
/// Comprehensive error types covering authentication, network, validation,
/// provider-specific errors, and rate limiting scenarios.
///
/// ## Overview
///
/// `AIError` provides typed errors for all failure modes in SwiftlyAIKit. Handle specific
/// cases to provide better user experience and implement appropriate retry logic.
///
/// ## Common Error Handling
///
/// ```swift
/// do {
///     let response = try await gateway.sendMessage(request)
/// } catch AIError.invalidAPIKey(let provider, _) {
///     print("Bad API key for \(provider)")
/// } catch AIError.rateLimitExceeded(let provider, let retryAfter) {
///     print("Rate limited. Retry after \(retryAfter ?? 60)s")
/// } catch AIError.networkError(let message) {
///     print("Network issue: \(message)")
/// } catch {
///     print("Other error: \(error)")
/// }
/// ```
///
/// ## Topics
///
/// ### Authentication Errors
/// - ``missingAPIKey(provider:)``
/// - ``invalidAPIKey(provider:message:)``
/// - ``permissionDenied(provider:message:)``
///
/// ### Network Errors
/// - ``networkError(underlying:)``
/// - ``timeout``
/// - ``invalidURL(_:)``
/// - ``connectionFailed(_:)``
///
/// ### Validation Errors
/// - ``invalidRequest(message:)``
/// - ``missingParameter(name:)``
/// - ``invalidModel(model:provider:)``
/// - ``requestTooLarge(size:limit:)``
/// - ``invalidContentType(expected:got:)``
///
/// ### Rate Limiting
/// - ``rateLimitExceeded(provider:retryAfter:)``
/// - ``quotaExceeded(provider:)``
///
/// ### Provider Errors
/// - ``providerError(provider:statusCode:message:)``
/// - ``serviceUnavailable(provider:)``
/// - ``internalError(provider:message:)``
/// - ``overloaded(provider:)``
///
/// ### Response Errors
/// - ``decodingError(message:)``
/// - ``emptyResponse``
/// - ``invalidResponse(message:)``
/// - ``streamingError(message:)``
///
/// ### Unsupported Operations
/// - ``notFound(resource:provider:)``
/// - ``unsupportedFeature(feature:provider:)``
/// - ``providerNotRegistered(_:)``
///
/// ## See Also
/// - <doc:ErrorHandling>
/// - <doc:CommonPitfalls>
/// - ``AIGateway``
public enum AIError: LocalizedError, Sendable, Equatable {
    // MARK: - Authentication Errors

    /// API key is missing or not provided
    case missingAPIKey(provider: ProviderType)

    /// API key is invalid or authentication failed
    case invalidAPIKey(provider: ProviderType, message: String?)

    /// Permission denied for the requested operation
    case permissionDenied(provider: ProviderType, message: String?)

    // MARK: - Network Errors

    /// Network request failed
    case networkError(underlying: String)

    /// Request timeout
    case timeout

    /// Invalid URL or endpoint
    case invalidURL(String)

    /// Connection failed
    case connectionFailed(String)

    // MARK: - Validation Errors

    /// Invalid request parameters
    case invalidRequest(message: String)

    /// Required parameter is missing
    case missingParameter(name: String)

    /// Invalid model specified
    case invalidModel(model: String, provider: ProviderType)

    /// Request payload too large
    case requestTooLarge(size: Int, limit: Int)

    /// Invalid content type
    case invalidContentType(expected: String, got: String)

    // MARK: - Rate Limiting

    /// Rate limit exceeded
    case rateLimitExceeded(provider: ProviderType, retryAfter: Int?)

    /// Quota exceeded
    case quotaExceeded(provider: ProviderType)

    // MARK: - Provider Errors

    /// Provider-specific error
    case providerError(provider: ProviderType, statusCode: Int, message: String)

    /// Provider service unavailable
    case serviceUnavailable(provider: ProviderType)

    /// Provider internal error
    case internalError(provider: ProviderType, message: String?)

    /// Provider overloaded
    case overloaded(provider: ProviderType)

    // MARK: - Response Errors

    /// Failed to decode response
    case decodingError(message: String)

    /// Empty response received
    case emptyResponse

    /// Invalid response format
    case invalidResponse(message: String)

    /// Streaming error
    case streamingError(message: String)

    // MARK: - Not Found

    /// Resource not found
    case notFound(resource: String, provider: ProviderType)

    // MARK: - Unsupported Operation

    /// Feature not supported by provider
    case unsupportedFeature(feature: String, provider: ProviderType)

    /// Provider not registered
    case providerNotRegistered(ProviderType)

    // MARK: - Unknown

    /// Unknown or unexpected error
    case unknown(message: String)

    // MARK: - Public Properties

    /// Human-readable error description
    public var localizedDescription: String {
        switch self {
        case .missingAPIKey(let provider):
            return "Missing API key for \(provider.displayName)"

        case .invalidAPIKey(let provider, let message):
            let msg = message.map { ": \($0)" } ?? ""
            return "Invalid API key for \(provider.displayName)\(msg)"

        case .permissionDenied(let provider, let message):
            let msg = message.map { ": \($0)" } ?? ""
            return "Permission denied for \(provider.displayName)\(msg)"

        case .networkError(let underlying):
            return "Network error: \(underlying)"

        case .timeout:
            return "Request timeout"

        case .invalidURL(let url):
            return "Invalid URL: \(url)"

        case .connectionFailed(let message):
            return "Connection failed: \(message)"

        case .invalidRequest(let message):
            return "Invalid request: \(message)"

        case .missingParameter(let name):
            return "Missing required parameter: \(name)"

        case .invalidModel(let model, let provider):
            return "Invalid model '\(model)' for \(provider.displayName)"

        case .requestTooLarge(let size, let limit):
            return "Request too large: \(size) bytes (limit: \(limit) bytes)"

        case .invalidContentType(let expected, let got):
            return "Invalid content type: expected \(expected), got \(got)"

        case .rateLimitExceeded(let provider, let retryAfter):
            let retry = retryAfter.map { " Retry after \($0) seconds." } ?? ""
            return "Rate limit exceeded for \(provider.displayName).\(retry)"

        case .quotaExceeded(let provider):
            return "Quota exceeded for \(provider.displayName)"

        case .providerError(let provider, let statusCode, let message):
            return "Provider error from \(provider.displayName) (HTTP \(statusCode)): \(message)"

        case .serviceUnavailable(let provider):
            return "Service unavailable for \(provider.displayName)"

        case .internalError(let provider, let message):
            let msg = message.map { ": \($0)" } ?? ""
            return "Internal error from \(provider.displayName)\(msg)"

        case .overloaded(let provider):
            return "Provider overloaded: \(provider.displayName)"

        case .decodingError(let message):
            return "Failed to decode response: \(message)"

        case .emptyResponse:
            return "Empty response received"

        case .invalidResponse(let message):
            return "Invalid response: \(message)"

        case .streamingError(let message):
            return "Streaming error: \(message)"

        case .notFound(let resource, let provider):
            return "Resource not found: \(resource) (\(provider.displayName))"

        case .unsupportedFeature(let feature, let provider):
            return "Feature '\(feature)' not supported by \(provider.displayName)"

        case .providerNotRegistered(let provider):
            return "Provider not registered: \(provider.displayName)"

        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }

    /// `LocalizedError` conformance so that `(error as Error).localizedDescription`
    /// returns the human-readable message on both Darwin and Linux.
    ///
    /// Without this, an `AIError` surfaced through the `any Error` path bridges to an
    /// `NSError` whose default description is the useless ordinal
    /// `"(SwiftlyAIKit.AIError error N.)"`, which would otherwise leak to end users.
    public var errorDescription: String? {
        localizedDescription
    }

    /// Check if error is retryable
    public var isRetryable: Bool {
        switch self {
        case .rateLimitExceeded, .timeout, .serviceUnavailable, .overloaded, .connectionFailed:
            return true
        case .networkError, .internalError:
            return true
        default:
            return false
        }
    }

    /// HTTP status code if applicable
    public var statusCode: Int? {
        switch self {
        case .invalidAPIKey:
            return 401
        case .permissionDenied:
            return 403
        case .notFound:
            return 404
        case .invalidRequest, .missingParameter, .invalidModel, .invalidContentType:
            return 400
        case .requestTooLarge:
            return 413
        case .rateLimitExceeded:
            return 429
        case .providerError(_, let code, _):
            return code
        case .serviceUnavailable:
            return 503
        case .internalError:
            return 500
        case .overloaded:
            return 529
        default:
            return nil
        }
    }
}
