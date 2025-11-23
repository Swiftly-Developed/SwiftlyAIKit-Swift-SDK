import Foundation
@testable import SwiftlyAIKit

/// Sample AI errors for testing
public enum SampleErrors {
    // MARK: - Authentication Errors

    /// Missing API key
    public static let missingAPIKey = AIError.missingAPIKey(
        provider: .anthropic
    )

    /// Invalid API key
    public static let invalidAPIKey = AIError.invalidAPIKey(
        provider: .anthropic,
        message: "Invalid API key provided"
    )

    /// Permission denied
    public static let permissionDenied = AIError.permissionDenied(
        provider: .anthropic,
        message: "Your API key does not have permission to use the specified model"
    )

    // MARK: - Network Errors

    /// Network error
    public static let networkError = AIError.networkError(
        underlying: "Connection to internet lost"
    )

    /// Timeout error
    public static let timeout = AIError.timeout

    /// Invalid URL
    public static let invalidURL = AIError.invalidURL("htp://invalid-url")

    /// Connection failed
    public static let connectionFailed = AIError.connectionFailed(
        "Connection to api.anthropic.com refused"
    )

    // MARK: - Validation Errors

    /// Invalid request
    public static let invalidRequest = AIError.invalidRequest(
        message: "Missing required field 'model'"
    )

    /// Missing parameter
    public static let missingParameter = AIError.missingParameter(
        name: "messages"
    )

    /// Invalid model
    public static let invalidModel = AIError.invalidModel(
        model: "invalid-model-name",
        provider: .anthropic
    )

    /// Request too large
    public static let requestTooLarge = AIError.requestTooLarge(
        size: 10_000_000,
        limit: 5_000_000
    )

    /// Invalid content type
    public static let invalidContentType = AIError.invalidContentType(
        expected: "application/json",
        got: "text/plain"
    )

    // MARK: - Rate Limiting Errors

    /// Rate limit exceeded
    public static let rateLimitExceeded = AIError.rateLimitExceeded(
        provider: .anthropic,
        retryAfter: 60
    )

    /// Rate limit without retry time
    public static let rateLimitNoRetry = AIError.rateLimitExceeded(
        provider: .anthropic,
        retryAfter: nil
    )

    /// Quota exceeded
    public static let quotaExceeded = AIError.quotaExceeded(
        provider: .anthropic
    )

    /// Quota without reset date
    public static let quotaNoReset = AIError.quotaExceeded(
        provider: .anthropic
    )

    // MARK: - Provider Errors

    /// Provider error with status code
    public static let providerError = AIError.providerError(
        provider: .anthropic,
        statusCode: 502,
        message: "Bad Gateway"
    )

    /// Service unavailable
    public static let serviceUnavailable = AIError.serviceUnavailable(
        provider: .anthropic
    )

    /// Internal error
    public static let internalError = AIError.internalError(
        provider: .anthropic,
        message: "Internal server error occurred"
    )

    /// Overloaded
    public static let overloaded = AIError.overloaded(
        provider: .anthropic
    )

    // MARK: - Response Errors

    /// Decoding error
    public static let decodingError = AIError.decodingError(
        message: "Invalid JSON format"
    )

    /// Empty response
    public static let emptyResponse = AIError.emptyResponse

    /// Invalid response
    public static let invalidResponse = AIError.invalidResponse(
        message: "Response missing required field 'id'"
    )

    /// Streaming error
    public static let streamingError = AIError.streamingError(
        message: "SSE connection closed unexpectedly"
    )

    // MARK: - Not Found Errors

    /// Resource not found
    public static let notFound = AIError.notFound(
        resource: "batch",
        provider: .anthropic
    )

    /// Model not found
    public static let modelNotFound = AIError.notFound(
        resource: "model: claude-invalid-model",
        provider: .anthropic
    )

    // MARK: - Unsupported Errors

    /// Unsupported feature
    public static let unsupportedFeature = AIError.unsupportedFeature(
        feature: "batch processing",
        provider: .openai
    )

    /// Provider not registered
    public static let providerNotRegistered = AIError.providerNotRegistered(
        .mistral
    )

    // MARK: - Unknown Errors

    /// Unknown error with message
    public static let unknown = AIError.unknown(
        message: "An unexpected error occurred"
    )

    /// Unknown error generic
    public static let unknownGeneric = AIError.unknown(
        message: "Unknown error"
    )

    // MARK: - Error Collections

    /// All authentication errors
    public static let authenticationErrors: [AIError] = [
        missingAPIKey,
        invalidAPIKey,
        permissionDenied
    ]

    /// All network errors
    public static let networkErrors: [AIError] = [
        networkError,
        timeout,
        invalidURL,
        connectionFailed
    ]

    /// All validation errors
    public static let validationErrors: [AIError] = [
        invalidRequest,
        missingParameter,
        invalidModel,
        requestTooLarge,
        invalidContentType
    ]

    /// All rate limiting errors
    public static let rateLimitingErrors: [AIError] = [
        rateLimitExceeded,
        rateLimitNoRetry,
        quotaExceeded,
        quotaNoReset
    ]

    /// All provider errors
    public static let providerErrors: [AIError] = [
        providerError,
        serviceUnavailable,
        internalError,
        overloaded
    ]

    /// All response errors
    public static let responseErrors: [AIError] = [
        decodingError,
        emptyResponse,
        invalidResponse,
        streamingError
    ]

    /// All retryable errors
    public static let retryableErrors: [AIError] = [
        timeout,
        rateLimitExceeded,
        serviceUnavailable,
        internalError,
        overloaded,
        connectionFailed
    ]

    /// All non-retryable errors
    public static let nonRetryableErrors: [AIError] = [
        invalidAPIKey,
        permissionDenied,
        invalidRequest,
        missingParameter,
        invalidModel,
        requestTooLarge,
        notFound,
        unsupportedFeature
    ]

    /// All errors for comprehensive testing
    public static let allErrors: [AIError] = authenticationErrors
        + networkErrors
        + validationErrors
        + rateLimitingErrors
        + providerErrors
        + responseErrors
        + [notFound, unsupportedFeature, providerNotRegistered, unknown]

    // MARK: - HTTP Status Code Mapping

    /// Errors by HTTP status code
    public static let errorsByStatusCode: [Int: AIError] = [
        400: invalidRequest,
        401: invalidAPIKey,
        403: permissionDenied,
        404: notFound,
        413: requestTooLarge,
        429: rateLimitExceeded,
        500: internalError,
        502: providerError,
        503: serviceUnavailable,
        529: overloaded
    ]

    // MARK: - Provider-Specific Errors

    /// Anthropic-specific errors
    public static let anthropicErrors: [AIError] = [
        invalidAPIKey,
        permissionDenied,
        rateLimitExceeded,
        overloaded
    ]

    /// OpenAI-specific errors
    public static let openAIErrors: [AIError] = [
        AIError.unsupportedFeature(feature: "extended thinking", provider: .openai),
        AIError.invalidModel(model: "gpt-invalid", provider: .openai)
    ]

    // MARK: - Batch Processing Errors

    /// Batch not found
    public static let batchNotFound = AIError.notFound(
        resource: "batch: msgbatch_invalid",
        provider: .anthropic
    )

    /// Batch expired
    public static let batchExpired = AIError.invalidRequest(
        message: "Batch has expired"
    )

    /// Batch processing error
    public static let batchProcessingError = AIError.providerError(
        provider: .anthropic,
        statusCode: 500,
        message: "Error processing batch request"
    )

    // MARK: - Streaming Errors

    /// SSE parse error
    public static let sseParseError = AIError.streamingError(
        message: "Failed to parse SSE event"
    )

    /// Stream interrupted
    public static let streamInterrupted = AIError.streamingError(
        message: "Stream connection interrupted"
    )

    /// Invalid SSE format
    public static let invalidSSEFormat = AIError.invalidResponse(
        message: "Invalid SSE event format"
    )
}
