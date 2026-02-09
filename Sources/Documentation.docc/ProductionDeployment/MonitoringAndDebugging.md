# Monitoring and Debugging

Monitor AI operations and debug issues in production.

## Overview

Effective monitoring helps you:
- Detect issues before users report them
- Understand usage patterns and costs
- Optimize performance
- Debug production problems

## Logging

### Enable Framework Logging

```swift
let config = Configuration.development(
    companyKey: apiKey,
    provider: .anthropic
)

// Configure logging
config.configureLogging(logLevel: .debug)
```

**Log levels:**
- `.debug` - Verbose (development only)
- `.info` - Important events
- `.warning` - Potential issues
- `.error` - Failures

### Custom Logger

```swift
import Logging

class ProductionLogger: AILogger {
    private let logger: Logger

    init() {
        var l = Logger(label: "com.myapp.ai")
        l.logLevel = .info
        self.logger = l
    }

    func log(level: LogLevel, message: String, metadata: [String: String]?, file: String, function: String, line: UInt) {
        let level: Logger.Level = switch level {
            case .debug: .debug
            case .info: .info
            case .warning: .warning
            case .error: .error
        }

        logger.log(
            level: level,
            "\(message)",
            metadata: metadata?.reduce(into: Logger.Metadata()) { $0[$1.key] = .string($1.value) }
        )
    }
}

let config = Configuration.withCompanyKey(apiKey)
config.configureLogging(logger: ProductionLogger())
```

### Log Structured Data

```swift
func sendWithLogging(_ request: AIRequest) async throws -> AIResponse {
    let requestId = UUID().uuidString

    logger.info("AI request started", metadata: [
        "request_id": requestId,
        "model": request.model,
        "message_count": "\(request.messages.count)"
    ])

    let start = Date()

    do {
        let response = try await gateway.sendMessage(request)
        let duration = Date().timeIntervalSince(start)

        logger.info("AI request completed", metadata: [
            "request_id": requestId,
            "duration_ms": "\(Int(duration * 1000))",
            "input_tokens": "\(response.usage?.inputTokens ?? 0)",
            "output_tokens": "\(response.usage?.outputTokens ?? 0)"
        ])

        return response

    } catch {
        let duration = Date().timeIntervalSince(start)

        logger.error("AI request failed", metadata: [
            "request_id": requestId,
            "duration_ms": "\(Int(duration * 1000))",
            "error": "\(error)"
        ])

        throw error
    }
}
```

## Metrics Collection

### Track Key Metrics

```swift
public actor MetricsCollector {
    struct Metrics {
        var totalRequests: Int = 0
        var successfulRequests: Int = 0
        var failedRequests: Int = 0

        var totalInputTokens: Int = 0
        var totalOutputTokens: Int = 0
        var totalCost: Double = 0

        var requestDurations: [TimeInterval] = []

        var errorsByType: [String: Int] = [:]
        var requestsByProvider: [ProviderType: Int] = [:]
        var requestsByModel: [String: Int] = [:]
    }

    private var metrics = Metrics()

    public func recordRequest(
        model: String,
        provider: ProviderType,
        duration: TimeInterval,
        response: AIResponse?,
        error: Error?
    ) {
        metrics.totalRequests += 1
        metrics.requestDurations.append(duration)
        metrics.requestsByProvider[provider, default: 0] += 1
        metrics.requestsByModel[model, default: 0] += 1

        if let response = response {
            metrics.successfulRequests += 1

            if let usage = response.usage {
                metrics.totalInputTokens += usage.inputTokens
                metrics.totalOutputTokens += usage.outputTokens
                metrics.totalCost += estimateCost(usage, provider: provider)
            }
        } else if let error = error {
            metrics.failedRequests += 1

            let errorType = String(describing: type(of: error))
            metrics.errorsByType[errorType, default: 0] += 1
        }
    }

    public func getMetrics() -> Metrics {
        metrics
    }

    public func reset() {
        metrics = Metrics()
    }

    private func estimateCost(_ usage: AIUsage, provider: ProviderType) -> Double {
        // Simplified cost calculation
        let inputCost = Double(usage.inputTokens) * 0.000003
        let outputCost = Double(usage.outputTokens) * 0.000015
        return inputCost + outputCost
    }
}

// Usage
let metrics = MetricsCollector()

let start = Date()
let response = try? await gateway.sendMessage(request, to: .anthropic)
let duration = Date().timeIntervalSince(start)

await metrics.recordRequest(
    model: request.model,
    provider: .anthropic,
    duration: duration,
    response: response,
    error: nil
)
```

### Export Metrics

```swift
extension MetricsCollector {
    public func exportPrometheus() -> String {
        let m = metrics

        return """
        # AI Gateway Metrics
        ai_requests_total \(m.totalRequests)
        ai_requests_successful \(m.successfulRequests)
        ai_requests_failed \(m.failedRequests)
        ai_tokens_input_total \(m.totalInputTokens)
        ai_tokens_output_total \(m.totalOutputTokens)
        ai_cost_total \(m.totalCost)
        ai_latency_avg \(m.requestDurations.reduce(0, +) / Double(m.requestDurations.count))
        """
    }
}
```

## Debugging

### Enable Verbose Logging

```swift
// Development
let config = Configuration.development(
    companyKey: apiKey,
    provider: .anthropic
)
// Automatically enables verbose logging

// Production (conditional)
let shouldLog = ProcessInfo.processInfo.environment["ENABLE_AI_LOGGING"] == "true"

let prodConfig = Configuration(
    keyStrategy: .companyKey(apiKey),
    enableLogging: shouldLog
)
```

### Inspect Requests and Responses

```swift
func debugRequest(_ request: AIRequest) {
    print("🔍 Request Debug")
    print("  Model: \(request.model)")
    print("  Messages: \(request.messages.count)")
    print("  Temperature: \(request.temperature ?? 1.0)")
    print("  MaxTokens: \(request.maxTokens ?? -1)")

    for (i, message) in request.messages.enumerated() {
        print("  Message \(i): [\(message.role)] \(message.content.prefix(50))...")
    }
}

func debugResponse(_ response: AIResponse) {
    print("🔍 Response Debug")
    print("  Content: \(response.message.content.prefix(100))...")
    print("  Stop Reason: \(response.stopReason?.rawValue ?? "unknown")")

    if let usage = response.usage {
        print("  Tokens: \(usage.inputTokens) in, \(usage.outputTokens) out")
    }

    if let toolCalls = response.toolCalls {
        print("  Tool Calls: \(toolCalls.map { $0.name })")
    }
}
```

### Network Debugging

```swift
// Inspect HTTP traffic
let config = Configuration(
    keyStrategy: .companyKey(apiKey),
    enableLogging: true // Logs HTTP requests/responses
)
```

## Health Checks

### Gateway Health Check

```swift
func checkGatewayHealth() async -> Bool {
    let testRequest = AIRequest(
        model: .claude(.haiku3_5),
        prompt: "test",
        maxTokens: 1
    )

    do {
        _ = try await gateway.sendMessage(testRequest)
        return true
    } catch {
        logger.error("Health check failed: \(error)")
        return false
    }
}

// Use in server health endpoint
app.get("health") { req async throws -> HTTPStatus in
    let healthy = await checkGatewayHealth()
    return healthy ? .ok : .serviceUnavailable
}
```

## Alerting

### Set Up Alerts

```swift
actor AlertManager {
    func checkAndAlert(metrics: MetricsCollector.Metrics) {
        // High error rate
        let errorRate = Double(metrics.failedRequests) / Double(metrics.totalRequests)
        if errorRate > 0.05 { // 5%
            sendAlert("AI error rate: \(Int(errorRate * 100))%")
        }

        // High costs
        if metrics.totalCost > 100.0 {
            sendAlert("AI costs: $\(String(format: "%.2f", metrics.totalCost))")
        }

        // Slow responses
        let avgDuration = metrics.requestDurations.reduce(0, +) / Double(metrics.requestDurations.count)
        if avgDuration > 5.0 {
            sendAlert("Slow AI responses: \(String(format: "%.1f", avgDuration))s average")
        }
    }

    private func sendAlert(_ message: String) {
        // Send to Slack, PagerDuty, email, etc.
        print("🚨 ALERT: \(message)")
    }
}
```

## Debugging Common Issues

### Authentication Failures

```swift
// Check API key is valid
let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
print("Key prefix: \(key?.prefix(10) ?? "MISSING")")
print("Key length: \(key?.count ?? 0)")

// Test key with minimal request
let testRequest = AIRequest(
    model: .claude(.haiku3_5),
    prompt: "test",
    maxTokens: 1
)

do {
    _ = try await gateway.sendMessage(testRequest)
    print("✅ Key is valid")
} catch {
    print("❌ Key error: \(error)")
}
```

### Slow Responses

```swift
// Add timeout logging
let start = Date()
let response = try await gateway.sendMessage(request)
let duration = Date().timeIntervalSince(start)

if duration > 5.0 {
    logger.warning("Slow response", metadata: [
        "duration": "\(duration)",
        "model": request.model,
        "tokens": "\(response.usage?.totalTokens ?? 0)"
    ])
}
```

### Memory Leaks

```swift
// Check for retention cycles
weak var weakGateway = gateway

gateway = nil

#expect(weakGateway == nil) // Should be deallocated
```

## See Also

- <doc:ErrorHandling>
- <doc:PerformanceOptimization>
- <doc:ProductionChecklist>
- <doc:Testing>
