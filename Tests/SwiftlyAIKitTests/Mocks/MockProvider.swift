import Foundation
@testable import SwiftlyAIKit

/// Mock provider implementation for testing
///
/// Provides controllable responses for all ProviderProtocol methods.
/// Useful for testing AIGateway coordination without real HTTP calls.
public actor MockProvider: ProviderProtocol {
    // MARK: - Configuration

    public let providerType: ProviderType

    /// Configured responses for sendMessage
    private var messageResponses: [AIResponse] = []
    private var messageResponseIndex: Int = 0

    /// Configured responses for streaming
    private var streamResponses: [[AIResponse]] = []
    private var streamResponseIndex: Int = 0

    /// Configured token counts
    private var tokenCounts: [Int?] = []
    private var tokenCountIndex: Int = 0

    /// Configured batch IDs
    private var batchIds: [String] = []
    private var batchIdIndex: Int = 0

    /// Configured batch statuses
    private var batchStatuses: [BatchStatus] = []
    private var batchStatusIndex: Int = 0

    /// Configured batch results
    private var batchResults: [[BatchResult]] = []
    private var batchResultIndex: Int = 0

    /// Error to throw on next operation
    private var errorToThrow: AIError?

    /// Captured requests for verification
    private(set) var capturedRequests: [CapturedRequest] = []

    /// Captured API keys
    private(set) var capturedAPIKeys: [String] = []

    /// Captured request details
    public struct CapturedRequest {
        public let operation: String
        public let request: AIRequest?
        public let batchId: String?
        public let limit: Int?
        public let afterId: String?

        public init(
            operation: String,
            request: AIRequest? = nil,
            batchId: String? = nil,
            limit: Int? = nil,
            afterId: String? = nil
        ) {
            self.operation = operation
            self.request = request
            self.batchId = batchId
            self.limit = limit
            self.afterId = afterId
        }
    }

    // MARK: - Initialization

    public init(providerType: ProviderType = .anthropic) {
        self.providerType = providerType
    }

    // MARK: - Configuration Methods

    /// Set response for sendMessage
    public func setMessageResponse(_ response: AIResponse) {
        messageResponses.append(response)
    }

    /// Set responses for streaming
    public func setStreamResponses(_ responses: [AIResponse]) {
        streamResponses.append(responses)
    }

    /// Set token count response
    public func setTokenCount(_ count: Int?) {
        tokenCounts.append(count)
    }

    /// Set batch ID response
    public func setBatchId(_ id: String) {
        batchIds.append(id)
    }

    /// Set batch status response
    public func setBatchStatus(_ status: BatchStatus) {
        batchStatuses.append(status)
    }

    /// Set batch results
    public func setBatchResults(_ results: [BatchResult]) {
        batchResults.append(results)
    }

    /// Set error to throw on next operation
    public func setError(_ error: AIError) {
        errorToThrow = error
    }

    /// Clear all configured responses
    public func clearResponses() {
        messageResponses.removeAll()
        messageResponseIndex = 0
        streamResponses.removeAll()
        streamResponseIndex = 0
        tokenCounts.removeAll()
        tokenCountIndex = 0
        batchIds.removeAll()
        batchIdIndex = 0
        batchStatuses.removeAll()
        batchStatusIndex = 0
        batchResults.removeAll()
        batchResultIndex = 0
        errorToThrow = nil
    }

    /// Clear captured data
    public func clearCapturedData() {
        capturedRequests.removeAll()
        capturedAPIKeys.removeAll()
    }

    // MARK: - ProviderProtocol Implementation

    public func sendMessage(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        // Capture request
        capturedRequests.append(CapturedRequest(operation: "sendMessage", request: request))
        capturedAPIKeys.append(apiKey)

        // Throw error if configured
        if let error = errorToThrow {
            errorToThrow = nil
            throw error
        }

        // Return configured response
        guard messageResponseIndex < messageResponses.count else {
            throw AIError.unknown(message: "No mock response configured for sendMessage")
        }

        let response = messageResponses[messageResponseIndex]
        messageResponseIndex += 1
        return response
    }

    public nonisolated func streamMessage(_ request: AIRequest, apiKey: String) -> AsyncThrowingStream<AIResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // Capture request
                await captureStreamRequest(request: request, apiKey: apiKey)

                // Check for error
                if let error = await getAndClearError() {
                    continuation.finish(throwing: error)
                    return
                }

                // Get configured responses
                guard let responses = await getStreamResponses() else {
                    continuation.finish(throwing: AIError.unknown(message: "No mock stream responses configured"))
                    return
                }

                // Stream responses
                for response in responses {
                    continuation.yield(response)
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms between chunks
                }

                continuation.finish()
            }
        }
    }

    public func countTokens(_ request: AIRequest, apiKey: String) async throws -> Int? {
        // Capture request
        capturedRequests.append(CapturedRequest(operation: "countTokens", request: request))
        capturedAPIKeys.append(apiKey)

        // Throw error if configured
        if let error = errorToThrow {
            errorToThrow = nil
            throw error
        }

        // Return configured count
        guard tokenCountIndex < tokenCounts.count else {
            return nil // Default behavior
        }

        let count = tokenCounts[tokenCountIndex]
        tokenCountIndex += 1
        return count
    }

    public func createBatch(_ requests: [AIRequest], apiKey: String) async throws -> String {
        // Capture request
        capturedRequests.append(CapturedRequest(operation: "createBatch"))
        capturedAPIKeys.append(apiKey)

        // Throw error if configured
        if let error = errorToThrow {
            errorToThrow = nil
            throw error
        }

        // Return configured batch ID
        guard batchIdIndex < batchIds.count else {
            throw AIError.unknown(message: "No mock batch ID configured")
        }

        let id = batchIds[batchIdIndex]
        batchIdIndex += 1
        return id
    }

    public func retrieveBatch(_ batchId: String, apiKey: String) async throws -> BatchStatus {
        // Capture request
        capturedRequests.append(CapturedRequest(operation: "retrieveBatch", batchId: batchId))
        capturedAPIKeys.append(apiKey)

        // Throw error if configured
        if let error = errorToThrow {
            errorToThrow = nil
            throw error
        }

        // Return configured status
        guard batchStatusIndex < batchStatuses.count else {
            throw AIError.unknown(message: "No mock batch status configured")
        }

        let status = batchStatuses[batchStatusIndex]
        batchStatusIndex += 1
        return status
    }

    public func cancelBatch(_ batchId: String, apiKey: String) async throws -> BatchStatus {
        // Capture request
        capturedRequests.append(CapturedRequest(operation: "cancelBatch", batchId: batchId))
        capturedAPIKeys.append(apiKey)

        // Throw error if configured
        if let error = errorToThrow {
            errorToThrow = nil
            throw error
        }

        // Return configured status (should be canceled)
        guard batchStatusIndex < batchStatuses.count else {
            throw AIError.unknown(message: "No mock batch status configured")
        }

        let status = batchStatuses[batchStatusIndex]
        batchStatusIndex += 1
        return status
    }

    public func listBatches(limit: Int?, afterId: String?, apiKey: String) async throws -> [BatchStatus] {
        // Capture request
        capturedRequests.append(CapturedRequest(operation: "listBatches", limit: limit, afterId: afterId))
        capturedAPIKeys.append(apiKey)

        // Throw error if configured
        if let error = errorToThrow {
            errorToThrow = nil
            throw error
        }

        // Return all configured statuses (simplified for testing)
        return batchStatuses
    }

    public nonisolated func getBatchResults(_ batchId: String, apiKey: String) -> AsyncThrowingStream<BatchResult, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // Capture request
                await captureBatchResultsRequest(batchId: batchId, apiKey: apiKey)

                // Check for error
                if let error = await getAndClearError() {
                    continuation.finish(throwing: error)
                    return
                }

                // Get configured results
                guard let results = await getBatchResults() else {
                    continuation.finish(throwing: AIError.unknown(message: "No mock batch results configured"))
                    return
                }

                // Stream results
                for result in results {
                    continuation.yield(result)
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms between results
                }

                continuation.finish()
            }
        }
    }

    // MARK: - Helper Methods

    private func captureStreamRequest(request: AIRequest, apiKey: String) {
        capturedRequests.append(CapturedRequest(operation: "streamMessage", request: request))
        capturedAPIKeys.append(apiKey)
    }

    private func captureBatchResultsRequest(batchId: String, apiKey: String) {
        capturedRequests.append(CapturedRequest(operation: "getBatchResults", batchId: batchId))
        capturedAPIKeys.append(apiKey)
    }

    private func getAndClearError() -> AIError? {
        let error = errorToThrow
        errorToThrow = nil
        return error
    }

    private func getStreamResponses() -> [AIResponse]? {
        guard streamResponseIndex < streamResponses.count else {
            return nil
        }
        let responses = streamResponses[streamResponseIndex]
        streamResponseIndex += 1
        return responses
    }

    private func getBatchResults() -> [BatchResult]? {
        guard batchResultIndex < batchResults.count else {
            return nil
        }
        let results = batchResults[batchResultIndex]
        batchResultIndex += 1
        return results
    }

    // MARK: - Verification Helpers

    /// Get the number of requests captured
    public var requestCount: Int {
        capturedRequests.count
    }

    /// Get the last captured request
    public var lastRequest: CapturedRequest? {
        capturedRequests.last
    }

    /// Get the last captured API key
    public var lastAPIKey: String? {
        capturedAPIKeys.last
    }

    /// Check if a specific operation was called
    public func didCall(operation: String) -> Bool {
        capturedRequests.contains { $0.operation == operation }
    }

    /// Get all requests for a specific operation
    public func requests(for operation: String) -> [CapturedRequest] {
        capturedRequests.filter { $0.operation == operation }
    }
}
