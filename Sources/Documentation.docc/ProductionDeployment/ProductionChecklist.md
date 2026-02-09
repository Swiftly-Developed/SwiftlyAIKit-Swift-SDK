# Production Checklist

Ensure your SwiftlyAIKit integration is production-ready.

## Overview

Before deploying to production, verify all critical aspects of your integration. This checklist covers security, performance, monitoring, and user experience.

## Security ✅

### API Key Management

- [ ] API keys loaded from environment variables (never hardcoded)
- [ ] `.env` files in `.gitignore`
- [ ] Separate keys for dev/staging/production
- [ ] Keys rotated regularly (every 30-90 days)
- [ ] User keys stored in Keychain (if applicable)
- [ ] No keys logged or exposed in errors
- [ ] HTTPS/TLS enforced for all API calls

**Verify:**
```swift
// ✅ Good
let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]!

// ❌ Bad
let key = "sk-ant-hardcoded-key"
```

### Access Control

- [ ] Rate limiting implemented
- [ ] Authentication on your server endpoints
- [ ] Authorization checks before AI calls
- [ ] Input validation (max length, content filtering)
- [ ] Output sanitization if needed

## Error Handling ✅

### Comprehensive Coverage

- [ ] All ``AIError`` cases handled
- [ ] User-friendly error messages (no raw errors)
- [ ] Retry logic for transient failures
- [ ] Circuit breaker for cascading failures
- [ ] Error logging with context
- [ ] Fallback behavior defined

**Test:**
```swift
@Test
func testErrorHandling() async throws {
    // Test each error case
    let badConfig = Configuration.withCompanyKey("invalid")
    let gateway = AIGateway(configuration: badConfig)

    do {
        _ = try await gateway.sendMessage(request)
        Issue.record("Should throw error")
    } catch AIError.authenticationFailed {
        // ✅ Handled properly
    }
}
```

### Rate Limit Handling

- [ ] Exponential backoff implemented
- [ ] Retry-After header respected
- [ ] User notified of rate limits
- [ ] Graceful degradation

## Performance ✅

### Response Times

- [ ] Streaming enabled for long responses
- [ ] Appropriate timeouts set (30-120s)
- [ ] Parallel requests where appropriate
- [ ] Response caching for repeated queries
- [ ] Target < 3s for simple requests
- [ ] Target < 10s for complex requests

**Measure:**
```swift
let start = Date()
let response = try await gateway.sendMessage(request)
let duration = Date().timeIntervalSince(start)

// Alert if too slow
if duration > 5.0 {
    alertSlowResponse(duration)
}
```

### Cost Optimization

- [ ] Using cheapest sufficient model
- [ ] Prompt caching enabled where applicable
- [ ] Batch processing for bulk operations
- [ ] maxTokens set appropriately
- [ ] Cost monitoring and alerts
- [ ] Budget limits enforced

## Monitoring ✅

### Logging

- [ ] Request/response logging in development
- [ ] Error logging in production
- [ ] Token usage tracked
- [ ] Cost per request monitored
- [ ] User actions logged (privacy-safe)
- [ ] Performance metrics collected

### Alerting

- [ ] High cost alerts (> $X per hour)
- [ ] High error rate alerts (> Y%)
- [ ] Slow response alerts (> Zs)
- [ ] Unusual usage patterns detected
- [ ] Provider outages monitored

**Example:**
```swift
if totalCost > 100.0 {
    sendAlert("AI costs exceeded $100/hour!")
}

if errorRate > 0.05 {
    sendAlert("AI error rate above 5%!")
}
```

## User Experience ✅

### Loading States

- [ ] Loading indicators during AI calls
- [ ] Streaming for better perceived performance
- [ ] Progress feedback for long operations
- [ ] Cancellation option provided
- [ ] Timeout communicated to users

### Error Messages

- [ ] User-friendly (not technical)
- [ ] Actionable (tell users what to do)
- [ ] Contextual (explain what failed)
- [ ] Recoverable (offer retry/alternatives)

❌ **Bad:**
```
Error: AIError.rateLimitExceeded(retryAfter: 60)
```

✅ **Good:**
```
Too many requests. Please wait 60 seconds and try again.
```

## Testing ✅

### Test Coverage

- [ ] Unit tests for all critical paths
- [ ] Integration tests with mock providers
- [ ] Error handling tests
- [ ] Streaming tests
- [ ] Timeout tests
- [ ] Cancellation tests
- [ ] Target > 80% code coverage

**Example:**
```swift
@Test
func testStreamingCancellation() async throws {
    let task = Task {
        let stream = try await gateway.streamMessage(request)
        for try await _ in stream {
            // Processing
        }
    }

    // Cancel after 1 second
    try await Task.sleep(nanoseconds: 1_000_000_000)
    task.cancel()

    // Verify cancellation worked
}
```

### Load Testing

- [ ] Tested with production-like load
- [ ] Concurrent request handling verified
- [ ] Rate limit behavior tested
- [ ] Memory usage under load checked
- [ ] No memory leaks detected

## Configuration ✅

### Environment-Specific

- [ ] Development configuration separate from production
- [ ] Staging environment for pre-prod testing
- [ ] Feature flags for gradual rollout
- [ ] A/B testing capability if needed

### Timeouts and Retries

- [ ] Appropriate timeout (60-120s)
- [ ] Retry count set (3 recommended)
- [ ] Exponential backoff implemented
- [ ] Maximum total retry time enforced

## Deployment ✅

### Infrastructure

- [ ] Server capacity planned (if using Pattern 1)
- [ ] Auto-scaling configured
- [ ] Health checks implemented
- [ ] Graceful shutdown handling
- [ ] Zero-downtime deployment process

### Rollback Plan

- [ ] Can quickly revert to previous version
- [ ] Database migrations are reversible
- [ ] Configuration changes are versioned
- [ ] Rollback tested in staging

## Compliance ✅

### Data Privacy

- [ ] User data handling documented
- [ ] Privacy policy updated
- [ ] GDPR compliance (if EU users)
- [ ] Data retention policy defined
- [ ] User data deletion process

### Content Policy

- [ ] Input content moderation (if needed)
- [ ] Output content filtering (if needed)
- [ ] Terms of service compliance
- [ ] Provider content policies followed

## Pre-Launch Verification

### Final Checks

Run through this before going live:

```swift
class ProductionReadinessChecker {
    func verify() async throws {
        print("🔍 Verifying production readiness...")

        // 1. API Key Check
        guard let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
              key.hasPrefix("sk-ant-") else {
            throw CheckError.invalidAPIKey
        }
        print("✅ API Key configured")

        // 2. Gateway Test
        let config = Configuration.production(
            keyStrategy: .companyKey(key),
            provider: .anthropic
        )
        let gateway = AIGateway(configuration: config)

        let testRequest = AIRequest(
            model: .claude(.sonnet4_5),
            prompt: "Hello",
            maxTokens: 10
        )

        let response = try await gateway.sendMessage(testRequest)
        print("✅ Gateway working")

        // 3. Error Handling Test
        let badRequest = AIRequest(model: .custom("invalid"), prompt: "Test")
        do {
            _ = try await gateway.sendMessage(badRequest)
            throw CheckError.errorHandlingFailed
        } catch AIError.invalidModel {
            print("✅ Error handling works")
        }

        // 4. Rate Limiting Test
        // ... test rate limiter

        // 5. Monitoring Test
        // ... verify metrics collection

        print("✅ All checks passed!")
    }
}
```

### Load Test

```swift
func loadTest() async throws {
    let gateway = AIGateway(configuration: productionConfig)

    let concurrent = 100
    let start = Date()

    try await withThrowingTaskGroup(of: Void.self) { group in
        for i in 0..<concurrent {
            group.addTask {
                let request = AIRequest(
                    model: .claude(.haiku3_5),
                    prompt: "Test \(i)"
                )
                _ = try await gateway.sendMessage(request)
            }
        }

        try await group.waitForAll()
    }

    let duration = Date().timeIntervalSince(start)
    let rps = Double(concurrent) / duration

    print("Load test: \(rps) requests/second")
    // Target: > 10 RPS for good performance
}
```

## Monitoring Dashboard

### Key Metrics to Track

```swift
struct AIMetrics {
    var totalRequests: Int = 0
    var successfulRequests: Int = 0
    var failedRequests: Int = 0

    var totalTokens: Int = 0
    var totalCost: Double = 0

    var averageLatency: TimeInterval = 0
    var p95Latency: TimeInterval = 0

    var cacheHitRate: Double = 0

    var errorsByType: [String: Int] = [:]
    var requestsByProvider: [ProviderType: Int] = [:]
}

actor MetricsCollector {
    private var metrics = AIMetrics()

    func recordRequest(
        provider: ProviderType,
        response: AIResponse?,
        error: Error?,
        duration: TimeInterval
    ) {
        metrics.totalRequests += 1

        if let response = response {
            metrics.successfulRequests += 1

            if let usage = response.usage {
                metrics.totalTokens += usage.totalTokens
                metrics.totalCost += calculateCost(usage, provider: provider)
            }
        } else if let error = error {
            metrics.failedRequests += 1

            let errorType = String(describing: type(of: error))
            metrics.errorsByType[errorType, default: 0] += 1
        }

        metrics.requestsByProvider[provider, default: 0] += 1
    }

    func getMetrics() -> AIMetrics {
        metrics
    }
}
```

## See Also

- <doc:PromptCaching>
- <doc:MonitoringAndDebugging>
- <doc:ChoosingDeploymentPattern>
- <doc:ErrorHandling>
