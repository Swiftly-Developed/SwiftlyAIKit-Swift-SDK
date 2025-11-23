import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for ProviderProtocol and supporting types
@Suite("ProviderProtocol Tests")
struct ProviderProtocolTests {
    // MARK: - BatchStatus Tests

    @Test("BatchStatus can be created with all fields")
    func testBatchStatusFull() {
        let now = Date()
        let later = Date(timeIntervalSinceNow: 3600)

        let counts = BatchStatus.RequestCounts(total: 100, completed: 75, failed: 5)
        let status = BatchStatus(
            id: "batch_123",
            status: "in_progress",
            createdAt: now,
            completedAt: nil,
            failedAt: nil,
            expiresAt: later,
            requestCounts: counts
        )

        #expect(status.id == "batch_123")
        #expect(status.status == "in_progress")
        #expect(status.createdAt == now)
        #expect(status.completedAt == nil)
        #expect(status.expiresAt == later)
        #expect(status.requestCounts?.total == 100)
        #expect(status.requestCounts?.completed == 75)
        #expect(status.requestCounts?.failed == 5)
    }

    @Test("BatchStatus can be created with minimal fields")
    func testBatchStatusMinimal() {
        let now = Date()
        let status = BatchStatus(
            id: "batch_456",
            status: "completed",
            createdAt: now
        )

        #expect(status.id == "batch_456")
        #expect(status.status == "completed")
        #expect(status.completedAt == nil)
        #expect(status.failedAt == nil)
        #expect(status.expiresAt == nil)
        #expect(status.requestCounts == nil)
    }

    @Test("BatchStatus is Codable")
    func testBatchStatusCodable() throws {
        let original = BatchStatus(
            id: "batch_789",
            status: "completed",
            createdAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BatchStatus.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.status == original.status)
    }

    @Test("RequestCounts tracks batch progress")
    func testRequestCounts() {
        let counts = BatchStatus.RequestCounts(total: 100, completed: 80, failed: 10)

        #expect(counts.total == 100)
        #expect(counts.completed == 80)
        #expect(counts.failed == 10)

        // Verify progress calculation
        let pending = counts.total - counts.completed - counts.failed
        #expect(pending == 10)
    }

    @Test("RequestCounts all completed")
    func testRequestCountsAllCompleted() {
        let counts = BatchStatus.RequestCounts(total: 50, completed: 50, failed: 0)

        #expect(counts.total == counts.completed)
        #expect(counts.failed == 0)
    }

    @Test("RequestCounts all failed")
    func testRequestCountsAllFailed() {
        let counts = BatchStatus.RequestCounts(total: 20, completed: 0, failed: 20)

        #expect(counts.total == counts.failed)
        #expect(counts.completed == 0)
    }

    @Test("RequestCounts is Codable")
    func testRequestCountsCodable() throws {
        let original = BatchStatus.RequestCounts(total: 100, completed: 50, failed: 10)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BatchStatus.RequestCounts.self, from: data)

        #expect(decoded.total == original.total)
        #expect(decoded.completed == original.completed)
        #expect(decoded.failed == original.failed)
    }

    // MARK: - BatchResult Tests

    @Test("BatchResult with successful response")
    func testBatchResultSuccess() {
        let response = SampleResponses.simpleText
        let result = BatchResult(
            requestId: "req_123",
            response: response,
            error: nil
        )

        #expect(result.requestId == "req_123")
        #expect(result.response?.id == response.id)
        #expect(result.error == nil)
    }

    @Test("BatchResult with error")
    func testBatchResultError() {
        let result = BatchResult(
            requestId: "req_456",
            response: nil,
            error: "Rate limit exceeded"
        )

        #expect(result.requestId == "req_456")
        #expect(result.response == nil)
        #expect(result.error == "Rate limit exceeded")
    }

    @Test("BatchResult is Codable")
    func testBatchResultCodable() throws {
        let original = BatchResult(
            requestId: "req_789",
            response: SampleResponses.simpleText,
            error: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BatchResult.self, from: data)

        #expect(decoded.requestId == original.requestId)
        #expect(decoded.response?.id == original.response?.id)
        #expect(decoded.error == nil)
    }

    @Test("BatchResult with both response and error")
    func testBatchResultBoth() {
        // Edge case: some providers might include partial response with error
        let result = BatchResult(
            requestId: "req_edge",
            response: SampleResponses.simpleText,
            error: "Partial failure"
        )

        #expect(result.requestId == "req_edge")
        #expect(result.response != nil)
        #expect(result.error != nil)
    }

    // MARK: - MockProvider Batch Operation Tests

    @Test("MockProvider countTokens returns configured value")
    func testMockProviderCountTokens() async throws {
        let provider = await MockProvider(providerType: .anthropic)
        await provider.setTokenCount(150)

        let request = SampleRequests.simpleText
        let count = try await provider.countTokens(request, apiKey: "sk-test")
        #expect(count == 150)
    }

    @Test("MockProvider createBatch returns configured ID")
    func testMockProviderCreateBatch() async throws {
        let provider = await MockProvider(providerType: .anthropic)
        await provider.setBatchId("batch_mock_123")

        let requests = [SampleRequests.simpleText]
        let batchId = try await provider.createBatch(requests, apiKey: "sk-test")
        #expect(batchId == "batch_mock_123")
    }

    @Test("MockProvider retrieveBatch returns configured status")
    func testMockProviderRetrieveBatch() async throws {
        let provider = await MockProvider(providerType: .anthropic)
        let status = BatchStatus(id: "batch_123", status: "in_progress", createdAt: Date())
        await provider.setBatchStatus(status)

        let retrieved = try await provider.retrieveBatch("batch_123", apiKey: "sk-test")
        #expect(retrieved.id == "batch_123")
        #expect(retrieved.status == "in_progress")
    }

    @Test("MockProvider cancelBatch returns configured status")
    func testMockProviderCancelBatch() async throws {
        let provider = await MockProvider(providerType: .anthropic)
        let status = BatchStatus(id: "batch_456", status: "canceled", createdAt: Date())
        await provider.setBatchStatus(status)

        let canceled = try await provider.cancelBatch("batch_456", apiKey: "sk-test")
        #expect(canceled.id == "batch_456")
        #expect(canceled.status == "canceled")
    }

    @Test("MockProvider listBatches returns configured statuses")
    func testMockProviderListBatches() async throws {
        let provider = await MockProvider(providerType: .anthropic)
        let status1 = BatchStatus(id: "batch_1", status: "completed", createdAt: Date())
        let status2 = BatchStatus(id: "batch_2", status: "in_progress", createdAt: Date())
        await provider.setBatchStatus(status1)
        await provider.setBatchStatus(status2)

        let batches = try await provider.listBatches(limit: 10, afterId: nil, apiKey: "sk-test")
        #expect(batches.count == 2)
    }

    @Test("MockProvider getBatchResults streams configured results")
    func testMockProviderGetBatchResults() async throws {
        let provider = await MockProvider(providerType: .anthropic)
        let results = [
            BatchResult(requestId: "req_1", response: SampleResponses.simpleText, error: nil),
            BatchResult(requestId: "req_2", response: SampleResponses.simpleText, error: nil)
        ]
        await provider.setBatchResults(results)

        let stream = provider.getBatchResults("batch_789", apiKey: "sk-test")

        var streamedResults: [BatchResult] = []
        for try await result in stream {
            streamedResults.append(result)
        }

        #expect(streamedResults.count == 2)
        #expect(streamedResults[0].requestId == "req_1")
        #expect(streamedResults[1].requestId == "req_2")
    }

    // MARK: - MockProvider Protocol Conformance Tests

    @Test("MockProvider conforms to ProviderProtocol")
    func testMockProviderConformance() async {
        let provider = await MockProvider(providerType: .anthropic)
        #expect(provider.providerType == .anthropic)
    }

    @Test("MockProvider sendMessage works")
    func testMockProviderSendMessage() async throws {
        let provider = await MockProvider(providerType: .anthropic)
        await provider.setMessageResponse(SampleResponses.simpleText)

        let request = SampleRequests.simpleText
        let response = try await provider.sendMessage(request, apiKey: "sk-test")

        #expect(response.id == SampleResponses.simpleText.id)
        #expect(response.provider == .anthropic)
    }

    @Test("MockProvider streamMessage works")
    func testMockProviderStreamMessage() async throws {
        let provider = await MockProvider(providerType: .anthropic)
        await provider.setStreamResponses(SampleResponses.streamSequence)

        let request = SampleRequests.simpleText
        let stream = provider.streamMessage(request, apiKey: "sk-test")

        var responses: [AIResponse] = []
        for try await response in stream {
            responses.append(response)
        }

        #expect(responses.count == 3)
        #expect(responses[0].id == SampleResponses.streamStart.id)
    }

    @Test("MockProvider captures API keys")
    func testMockProviderCapturesAPIKeys() async throws {
        let provider = await MockProvider(providerType: .anthropic)
        await provider.setMessageResponse(SampleResponses.simpleText)

        let request = SampleRequests.simpleText
        _ = try await provider.sendMessage(request, apiKey: "sk-captured-key")

        let capturedKeys = await provider.capturedAPIKeys
        #expect(capturedKeys.contains("sk-captured-key"))
    }

    @Test("MockProvider captures requests")
    func testMockProviderCapturesRequests() async throws {
        let provider = await MockProvider(providerType: .anthropic)
        await provider.setMessageResponse(SampleResponses.simpleText)

        let request = SampleRequests.simpleText
        _ = try await provider.sendMessage(request, apiKey: "sk-test")

        let capturedRequests = await provider.capturedRequests
        #expect(capturedRequests.count == 1)
        #expect(capturedRequests[0].request?.model == request.model)
    }

    @Test("MockProvider can return errors")
    func testMockProviderReturnsErrors() async throws {
        let provider = await MockProvider(providerType: .anthropic)
        await provider.setError(SampleErrors.rateLimitExceeded)

        let request = SampleRequests.simpleText

        do {
            _ = try await provider.sendMessage(request, apiKey: "sk-test")
            Issue.record("Expected error to be thrown")
        } catch let error as AIError {
            if case .rateLimitExceeded = error {
                // Success
            } else {
                Issue.record("Expected rateLimitExceeded, got \(error)")
            }
        }
    }

    // MARK: - Protocol Requirements Tests

    @Test("ProviderProtocol requires providerType")
    func testProtocolRequiresProviderType() async {
        let anthropic = await MockProvider(providerType: .anthropic)
        let openai = await MockProvider(providerType: .openai)

        #expect(anthropic.providerType == .anthropic)
        #expect(openai.providerType == .openai)
        #expect(anthropic.providerType != openai.providerType)
    }

    @Test("ProviderProtocol sendMessage is async throws")
    func testProtocolSendMessageSignature() async throws {
        let provider = await MockProvider(providerType: .anthropic)
        await provider.setMessageResponse(SampleResponses.simpleText)

        // Verify it's async and throws
        let request = SampleRequests.simpleText
        let _: AIResponse = try await provider.sendMessage(request, apiKey: "sk-test")
    }

    @Test("ProviderProtocol streamMessage returns AsyncThrowingStream")
    func testProtocolStreamMessageSignature() async throws {
        let provider = await MockProvider(providerType: .anthropic)
        await provider.setStreamResponses([SampleResponses.simpleText])

        let request = SampleRequests.simpleText
        let stream: AsyncThrowingStream<AIResponse, Error> = provider.streamMessage(request, apiKey: "sk-test")

        // Verify stream works
        var count = 0
        for try await _ in stream {
            count += 1
        }
        #expect(count == 1)
    }

    // MARK: - Batch Status Scenarios

    @Test("Batch in progress scenario")
    func testBatchInProgress() {
        let counts = BatchStatus.RequestCounts(total: 100, completed: 45, failed: 3)
        let status = BatchStatus(
            id: "batch_progress",
            status: "in_progress",
            createdAt: Date(),
            requestCounts: counts
        )

        #expect(status.status == "in_progress")
        #expect(status.completedAt == nil)
        #expect(status.failedAt == nil)

        let pending = counts.total - counts.completed - counts.failed
        #expect(pending == 52)
    }

    @Test("Batch completed scenario")
    func testBatchCompleted() {
        let counts = BatchStatus.RequestCounts(total: 100, completed: 95, failed: 5)
        let now = Date()
        let status = BatchStatus(
            id: "batch_complete",
            status: "completed",
            createdAt: Date(timeIntervalSinceNow: -3600),
            completedAt: now,
            requestCounts: counts
        )

        #expect(status.status == "completed")
        #expect(status.completedAt == now)
        #expect(counts.completed + counts.failed == counts.total)
    }

    @Test("Batch failed scenario")
    func testBatchFailed() {
        let now = Date()
        let status = BatchStatus(
            id: "batch_failed",
            status: "failed",
            createdAt: Date(timeIntervalSinceNow: -1800),
            failedAt: now
        )

        #expect(status.status == "failed")
        #expect(status.failedAt == now)
    }

    @Test("Batch expired scenario")
    func testBatchExpired() {
        let expiry = Date(timeIntervalSinceNow: -10)
        let status = BatchStatus(
            id: "batch_expired",
            status: "expired",
            createdAt: Date(timeIntervalSinceNow: -86400),
            expiresAt: expiry
        )

        #expect(status.status == "expired")
        #expect(status.expiresAt ?? Date() < Date())
    }

    // MARK: - Integration Tests

    @Test("Complete provider message flow")
    func testCompleteProviderFlow() async throws {
        let provider = await MockProvider(providerType: .anthropic)
        await provider.setMessageResponse(SampleResponses.simpleText)

        // Create request
        let request = AIRequest(
            model: "claude-sonnet-4-20250514",
            messages: [AIMessage(role: .user, text: "Hello")]
        )

        // Send message
        let response = try await provider.sendMessage(request, apiKey: "sk-test-key")

        // Verify response
        #expect(response.provider == .anthropic)
        #expect(!response.textContent.isEmpty)

        // Verify captured data
        let requests = await provider.capturedRequests
        let keys = await provider.capturedAPIKeys

        #expect(requests.count == 1)
        #expect(keys.contains("sk-test-key"))
    }

    @Test("Provider with multiple requests")
    func testProviderMultipleRequests() async throws {
        let provider = await MockProvider(providerType: .anthropic)

        // Set responses for each request
        for _ in 1...5 {
            await provider.setMessageResponse(SampleResponses.simpleText)
        }

        // Send multiple requests
        for i in 1...5 {
            let request = AIRequest(
                model: "claude-sonnet-4-20250514",
                messages: [AIMessage(role: .user, text: "Message \(i)")]
            )
            _ = try await provider.sendMessage(request, apiKey: "sk-test")
        }

        // Verify all captured
        let requests = await provider.capturedRequests
        #expect(requests.count == 5)
    }
}
