import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for AIError types
@Suite("AIError Tests")
struct AIErrorTests {
    // MARK: - Authentication Errors

    @Test("Missing API key error has correct description")
    func testMissingAPIKeyDescription() {
        let error = SampleErrors.missingAPIKey
        #expect(error.localizedDescription.contains("API key"))
        #expect(error.localizedDescription.contains("Anthropic"))
    }

    @Test("Missing API key is not retryable")
    func testMissingAPIKeyNotRetryable() {
        let error = SampleErrors.missingAPIKey
        #expect(!error.isRetryable)
    }

    @Test("Invalid API key error has correct description")
    func testInvalidAPIKeyDescription() {
        let error = SampleErrors.invalidAPIKey
        #expect(error.localizedDescription.contains("Invalid"))
        #expect(error.statusCode == 401)
    }

    @Test("Invalid API key is not retryable")
    func testInvalidAPIKeyNotRetryable() {
        let error = SampleErrors.invalidAPIKey
        #expect(!error.isRetryable)
    }

    @Test("Permission denied error has correct properties")
    func testPermissionDenied() {
        let error = SampleErrors.permissionDenied
        #expect(error.localizedDescription.contains("permission"))
        #expect(error.statusCode == 403)
        #expect(!error.isRetryable)
    }

    // MARK: - Network Errors

    @Test("Network error is retryable")
    func testNetworkErrorRetryable() {
        let error = SampleErrors.networkError
        #expect(error.isRetryable)
        #expect(error.localizedDescription.contains("Network"))
    }

    @Test("Timeout error properties")
    func testTimeoutError() {
        let error = SampleErrors.timeout
        #expect(error.isRetryable)
        #expect(error.localizedDescription.contains("timeout"))
    }

    @Test("Invalid URL error")
    func testInvalidURL() {
        let error = SampleErrors.invalidURL
        #expect(!error.isRetryable)
        #expect(error.localizedDescription.contains("Invalid URL"))
    }

    @Test("Connection failed is retryable")
    func testConnectionFailed() {
        let error = SampleErrors.connectionFailed
        #expect(error.isRetryable)
        #expect(error.localizedDescription.contains("Connection"))
    }

    // MARK: - Validation Errors

    @Test("Invalid request error")
    func testInvalidRequest() {
        let error = SampleErrors.invalidRequest
        #expect(!error.isRetryable)
        #expect(error.statusCode == 400)
        #expect(error.localizedDescription.contains("Invalid"))
    }

    @Test("Missing parameter error")
    func testMissingParameter() {
        let error = SampleErrors.missingParameter
        #expect(!error.isRetryable)
        #expect(error.localizedDescription.contains("messages"))
    }

    @Test("Invalid model error")
    func testInvalidModel() {
        let error = SampleErrors.invalidModel
        #expect(!error.isRetryable)
        #expect(error.localizedDescription.contains("invalid-model-name"))
    }

    @Test("Request too large error")
    func testRequestTooLarge() {
        let error = SampleErrors.requestTooLarge
        #expect(!error.isRetryable)
        #expect(error.statusCode == 413)
        #expect(error.localizedDescription.contains("too large"))
    }

    @Test("Invalid content type error")
    func testInvalidContentType() {
        let error = SampleErrors.invalidContentType
        #expect(!error.isRetryable)
        #expect(error.localizedDescription.contains("content type"))
    }

    // MARK: - Rate Limiting Errors

    @Test("Rate limit exceeded is retryable")
    func testRateLimitRetryable() {
        let error = SampleErrors.rateLimitExceeded
        #expect(error.isRetryable)
        #expect(error.statusCode == 429)
    }

    @Test("Rate limit without retry time")
    func testRateLimitNoRetryTime() {
        let error = SampleErrors.rateLimitNoRetry
        #expect(error.isRetryable)
        #expect(error.localizedDescription.contains("Rate limit"))
    }

    @Test("Quota exceeded is not retryable")
    func testQuotaExceeded() {
        let error = SampleErrors.quotaExceeded
        #expect(!error.isRetryable)
        #expect(error.localizedDescription.contains("Quota"))
    }

    @Test("Quota without reset date")
    func testQuotaNoResetDate() {
        let error = SampleErrors.quotaNoReset
        #expect(!error.isRetryable)
    }

    // MARK: - Provider Errors

    @Test("Provider error properties")
    func testProviderError() {
        let error = SampleErrors.providerError
        #expect(!error.isRetryable)
        #expect(error.statusCode == 502)
        #expect(error.localizedDescription.contains("Bad Gateway"))
    }

    @Test("Service unavailable is retryable")
    func testServiceUnavailable() {
        let error = SampleErrors.serviceUnavailable
        #expect(error.isRetryable)
        #expect(error.statusCode == 503)
    }

    @Test("Internal error is retryable")
    func testInternalError() {
        let error = SampleErrors.internalError
        #expect(error.isRetryable)
        #expect(error.statusCode == 500)
    }

    @Test("Overloaded error is retryable")
    func testOverloaded() {
        let error = SampleErrors.overloaded
        #expect(error.isRetryable)
        #expect(error.statusCode == 529)
    }

    // MARK: - Response Errors

    @Test("Decoding error")
    func testDecodingError() {
        let error = SampleErrors.decodingError
        #expect(!error.isRetryable)
        #expect(error.localizedDescription.contains("decode"))
    }

    @Test("Empty response error")
    func testEmptyResponse() {
        let error = SampleErrors.emptyResponse
        #expect(!error.isRetryable)
        #expect(error.localizedDescription.contains("Empty"))
    }

    @Test("Invalid response error")
    func testInvalidResponse() {
        let error = SampleErrors.invalidResponse
        #expect(!error.isRetryable)
        #expect(error.localizedDescription.contains("missing"))
    }

    @Test("Streaming error")
    func testStreamingError() {
        let error = SampleErrors.streamingError
        #expect(!error.isRetryable)
        #expect(error.localizedDescription.contains("SSE"))
    }

    // MARK: - Not Found Error

    @Test("Not found error")
    func testNotFound() {
        let error = SampleErrors.notFound
        #expect(!error.isRetryable)
        #expect(error.statusCode == 404)
        #expect(error.localizedDescription.contains("batch"))
    }

    // MARK: - Unsupported Errors

    @Test("Unsupported feature error")
    func testUnsupportedFeature() {
        let error = SampleErrors.unsupportedFeature
        #expect(!error.isRetryable)
        #expect(error.localizedDescription.contains("batch processing"))
        #expect(error.localizedDescription.contains("OpenAI"))
    }

    @Test("Provider not registered error")
    func testProviderNotRegistered() {
        let error = SampleErrors.providerNotRegistered
        #expect(!error.isRetryable)
        #expect(error.localizedDescription.contains("Mistral"))
    }

    // MARK: - Unknown Error

    @Test("Unknown error")
    func testUnknownError() {
        let error = SampleErrors.unknown
        #expect(!error.isRetryable)
        #expect(error.localizedDescription.contains("unexpected"))
    }

    // MARK: - Equatable Conformance

    @Test("Same errors are equal")
    func testErrorEquality() {
        let error1 = AIError.timeout
        let error2 = AIError.timeout
        #expect(error1 == error2)
    }

    @Test("Different errors are not equal")
    func testErrorInequality() {
        let error1 = AIError.timeout
        let error2 = AIError.invalidAPIKey(provider: .anthropic, message: "test")
        #expect(error1 != error2)
    }

    @Test("Same error type with different values are not equal")
    func testErrorInequalityDifferentValues() {
        let error1 = AIError.invalidAPIKey(provider: .anthropic, message: "test1")
        let error2 = AIError.invalidAPIKey(provider: .anthropic, message: "test2")
        #expect(error1 != error2)
    }

    // MARK: - Status Code Mapping

    @Test("All status codes are correctly mapped")
    func testStatusCodeMapping() {
        #expect(SampleErrors.invalidRequest.statusCode == 400)
        #expect(SampleErrors.invalidAPIKey.statusCode == 401)
        #expect(SampleErrors.permissionDenied.statusCode == 403)
        #expect(SampleErrors.notFound.statusCode == 404)
        #expect(SampleErrors.requestTooLarge.statusCode == 413)
        #expect(SampleErrors.rateLimitExceeded.statusCode == 429)
        #expect(SampleErrors.internalError.statusCode == 500)
        #expect(SampleErrors.serviceUnavailable.statusCode == 503)
        #expect(SampleErrors.overloaded.statusCode == 529)
    }

    // MARK: - Retryable Classification

    @Test("Retryable errors are correctly classified")
    func testRetryableErrors() {
        for error in SampleErrors.retryableErrors {
            #expect(error.isRetryable, "Error should be retryable: \(error)")
        }
    }

    @Test("Non-retryable errors are correctly classified")
    func testNonRetryableErrors() {
        for error in SampleErrors.nonRetryableErrors {
            #expect(!error.isRetryable, "Error should not be retryable: \(error)")
        }
    }

    // MARK: - Error Categories

    @Test("All authentication errors have proper properties")
    func testAuthenticationErrors() {
        for error in SampleErrors.authenticationErrors {
            #expect(!error.isRetryable, "Auth errors should not be retryable")
            #expect(!error.localizedDescription.isEmpty, "Should have description")
        }
    }

    @Test("All network errors are retryable")
    func testNetworkErrors() {
        for error in SampleErrors.networkErrors {
            if case .invalidURL = error {
                #expect(!error.isRetryable, "Invalid URL should not be retryable")
            } else {
                #expect(error.isRetryable, "Network errors should be retryable")
            }
        }
    }

    @Test("All validation errors are not retryable")
    func testValidationErrors() {
        for error in SampleErrors.validationErrors {
            #expect(!error.isRetryable, "Validation errors should not be retryable")
        }
    }

    @Test("Rate limiting errors have appropriate retry behavior")
    func testRateLimitingErrors() {
        for error in SampleErrors.rateLimitingErrors {
            if case .quotaExceeded = error {
                #expect(!error.isRetryable, "Quota exceeded should not be retryable")
            } else {
                #expect(error.isRetryable, "Rate limit should be retryable")
            }
        }
    }

    // MARK: - Comprehensive Coverage

    @Test("All errors have non-empty descriptions")
    func testAllErrorsHaveDescriptions() {
        for error in SampleErrors.allErrors {
            #expect(!error.localizedDescription.isEmpty, "Error should have description: \(error)")
        }
    }

    @Test("All errors are Equatable")
    func testAllErrorsEquatable() {
        for error in SampleErrors.allErrors {
            let errorCopy = error
            #expect(error == errorCopy, "Error should equal itself")
        }
    }

    // MARK: - LocalizedError Conformance

    @Test("errorDescription matches localizedDescription")
    func testErrorDescriptionMatchesLocalizedDescription() {
        for error in SampleErrors.allErrors {
            #expect(error.errorDescription == error.localizedDescription)
        }
    }

    @Test("any Error localizedDescription does not leak the ordinal description")
    func testAnyErrorDoesNotLeakOrdinal() {
        // Via the `any Error` / NSError bridge, `localizedDescription` must be the readable
        // message, not the "(SwiftlyAIKit.AIError error N.)" ordinal (Darwin and Linux).
        for error in SampleErrors.allErrors {
            let anyError: any Error = error
            #expect(anyError.localizedDescription == error.localizedDescription)
            #expect(!anyError.localizedDescription.contains("AIError error"))
        }
    }
}
