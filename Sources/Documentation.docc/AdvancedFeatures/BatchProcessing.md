# Batch Processing

Process large volumes of AI requests asynchronously with cost savings.

## Overview

Batch processing allows you to:
- **Process thousands of requests** asynchronously
- **Save 50% on costs** (Anthropic)
- **Avoid rate limits** (batches have separate limits)
- **Process within 24 hours** (not real-time)

**Supported providers:**
- Anthropic Claude (full support)

## When to Use Batching

### ✅ Perfect For

- Bulk document summarization
- Dataset labeling/classification
- Content generation at scale
- Offline processing tasks
- Cost-sensitive bulk operations

### ❌ Not For

- Real-time user interactions
- Time-sensitive operations
- Single requests
- Interactive applications

## Basic Batch Operations

### Create a Batch

```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("sk-ant-...")
let gateway = AIGateway(configuration: config)

// Prepare multiple requests
let requests = [
    AIRequest(model: .claude(.sonnet4_5), prompt: "Summarize document 1"),
    AIRequest(model: .claude(.sonnet4_5), prompt: "Summarize document 2"),
    AIRequest(model: .claude(.sonnet4_5), prompt: "Summarize document 3")
    // ... up to 10,000 requests
]

// Submit batch
let batchId = try await gateway.createBatch(requests, for: .anthropic)
print("Batch created: \(batchId)")
```

### Monitor Batch Status

```swift
// Check status periodically
let status = try await gateway.retrieveBatch(batchId, from: .anthropic)

print("Status: \(status.status)")
// "processing", "completed", "failed", "cancelled"

print("Progress: \(status.requestsProcessed)/\(status.requestsTotal)")
```

### Retrieve Results

```swift
// Once completed, stream results
let results = try await gateway.getBatchResults(batchId, from: .anthropic)

for try await result in results {
    if let response = result.response {
        print("Request \(result.customId): \(response.message.content)")
    } else if let error = result.error {
        print("Request \(result.customId) failed: \(error)")
    }
}
```

## Complete Example

### Batch Document Processor

```swift
class BatchDocumentProcessor {
    let gateway: AIGateway

    func processDocuments(_ documents: [Document]) async throws -> [ProcessedDocument] {
        // 1. Create requests
        let requests = documents.map { doc in
            AIRequest(
                model: .claude(.sonnet4_5),
                systemPrompt: "You are a document summarizer",
                messages: [.user("Summarize: \(doc.content)")],
                metadata: ["document_id": doc.id]
            )
        }

        // 2. Submit batch
        print("Submitting batch of \(requests.count) requests...")
        let batchId = try await gateway.createBatch(requests, for: .anthropic)

        // 3. Poll for completion
        var status: BatchStatus
        repeat {
            try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds

            status = try await gateway.retrieveBatch(batchId, from: .anthropic)
            print("Progress: \(status.requestsProcessed)/\(status.requestsTotal)")

        } while status.status == "processing"

        // 4. Collect results
        var processed: [ProcessedDocument] = []

        let results = try await gateway.getBatchResults(batchId, from: .anthropic)

        for try await result in results {
            if let response = result.response {
                let doc = ProcessedDocument(
                    id: result.customId,
                    summary: response.message.content,
                    tokens: response.usage?.totalTokens ?? 0
                )
                processed.append(doc)
            }
        }

        return processed
    }
}

struct Document {
    let id: String
    let content: String
}

struct ProcessedDocument {
    let id: String
    let summary: String
    let tokens: Int
}
```

## Batch Lifecycle

### Status Progression

```
queued → processing → completed
                    ↘ failed
                    ↘ cancelled
```

### Status Details

```swift
public struct BatchStatus {
    let id: String
    let status: String            // Current status
    let requestsTotal: Int        // Total requests in batch
    let requestsProcessed: Int    // Completed so far
    let requestsSucceeded: Int    // Successful requests
    let requestsFailed: Int       // Failed requests
    let createdAt: Date           // When batch was created
    let processingStartedAt: Date? // When processing began
    let completedAt: Date?        // When batch finished
}
```

## Cost Savings

### Pricing Comparison

**Anthropic Batch API:**
- **50% discount** vs standard API
- Input: $1.50/M (vs $3.00/M)
- Output: $7.50/M (vs $15.00/M)

**Example:**
```swift
// 1,000 requests, 10K tokens input + 2K tokens output each

// Standard API:
let standardCost = 1000 * ((10_000 * 0.000003) + (2_000 * 0.000015))
// = $60.00

// Batch API:
let batchCost = 1000 * ((10_000 * 0.0000015) + (2_000 * 0.0000075))
// = $30.00

// Savings: $30.00 (50% reduction)
```

## Advanced Patterns

### Batch with Progress Tracking

```swift
@MainActor
class BatchProcessor: ObservableObject {
    @Published var progress: Double = 0
    @Published var isProcessing = false

    let gateway: AIGateway

    func processBatch(_ requests: [AIRequest]) async throws {
        isProcessing = true

        let batchId = try await gateway.createBatch(requests, for: .anthropic)

        // Poll for progress
        while isProcessing {
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds

            let status = try await gateway.retrieveBatch(batchId, from: .anthropic)

            progress = Double(status.requestsProcessed) / Double(status.requestsTotal)

            if status.status == "completed" || status.status == "failed" {
                isProcessing = false
            }
        }
    }
}

// SwiftUI
struct BatchProgressView: View {
    @StateObject var processor: BatchProcessor

    var body: some View {
        VStack {
            ProgressView(value: processor.progress)
            Text("\(Int(processor.progress * 100))% Complete")
        }
    }
}
```

### Cancel Long-Running Batch

```swift
func cancelBatchIfTooSlow(_ batchId: String) async throws {
    try await Task.sleep(nanoseconds: 3600_000_000_000) // 1 hour

    let status = try await gateway.retrieveBatch(batchId, from: .anthropic)

    if status.status == "processing" {
        print("Batch taking too long, cancelling...")
        let cancelled = try await gateway.cancelBatch(batchId, from: .anthropic)
        print("Cancelled: \(cancelled.status)")
    }
}
```

### List All Batches

```swift
let batches = try await gateway.listBatches(
    limit: 100,
    afterId: nil,
    from: .anthropic
)

for batch in batches {
    print("Batch \(batch.id): \(batch.status)")
    print("  Progress: \(batch.requestsProcessed)/\(batch.requestsTotal)")
}
```

## Error Handling

```swift
func processBatchWithRetry(_ requests: [AIRequest]) async throws -> String {
    do {
        let batchId = try await gateway.createBatch(requests, for: .anthropic)
        return batchId
    } catch AIError.validationError(let message) {
        print("Invalid batch: \(message)")
        // Check request format
        throw BatchError.invalidRequests
    } catch AIError.rateLimitExceeded(let retryAfter) {
        print("Batch rate limit. Retry after \(retryAfter)s")
        try await Task.sleep(nanoseconds: UInt64(retryAfter) * 1_000_000_000)
        return try await gateway.createBatch(requests, for: .anthropic)
    } catch {
        throw error
    }
}
```

## Limitations

**Anthropic batch limits:**
- Maximum 10,000 requests per batch
- 24-hour processing window
- Results available for 7 days
- Cannot update running batch

## See Also

- <doc:AnthropicGuide>
- <doc:PerformanceOptimization>
- ``AIGateway/createBatch(_:for:clientAPIKey:)``
- ``AIGateway/retrieveBatch(_:from:clientAPIKey:)``
- ``AIGateway/getBatchResults(_:from:clientAPIKey:)``
- ``BatchStatus``
- ``BatchResult``
