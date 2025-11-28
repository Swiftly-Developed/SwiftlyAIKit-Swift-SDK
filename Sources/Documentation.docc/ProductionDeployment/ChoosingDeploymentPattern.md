# Choosing a Deployment Pattern

Select the right architecture for your AI-powered application.

## Overview

SwiftlyAIKit supports three deployment patterns, each with different trade-offs for security, complexity, and cost control.

## The Three Patterns

### Pattern 1: Client → Server → Providers (Recommended)

```
iOS/macOS App (SwiftlyAIClient)
    ↓ [Client API key]
Your Vapor/Hummingbird Server (SwiftlyAIServerKit)
    ↓ [Provider API keys]
AI Providers (Anthropic, OpenAI, etc.)
```

**How it works:**
1. iOS app calls YOUR server
2. Your server calls AI providers
3. Provider API keys stay on server

**Security:** ✅ Excellent (keys never on device)
**Cost Control:** ✅ Full control (rate limiting, quotas)
**Complexity:** ⚠️ Medium (need to run server)

#### Code Example

**Server (Vapor):**
```swift
import Vapor
import SwiftlyAIServerKit

func configure(_ app: Application) throws {
    // Provider keys stay on server
    let config = Configuration.withCompanyKey(
        Environment.get("ANTHROPIC_API_KEY")!
    )

    try app.ai.initialize(with: config)
}

// Route
app.post("chat") { req async throws -> AIResponse in
    let request = try req.content.decode(AIRequest.self)
    return try await req.ai.sendMessage(request)
}
```

**Client (iOS):**
```swift
import SwiftlyAIClient

let client = SwiftlyClient(
    serverURL: URL(string: "https://api.yourserver.com")!,
    apiKey: "your-client-api-key" // NOT the provider key!
)

let response = try await client.chat(
    model: "claude-sonnet-4-5",
    messages: messages
)
```

#### When to Use

✅ **Perfect for:**
- Production iOS/macOS apps
- Apps with many users
- When API key security is critical
- When you need centralized control
- SaaS applications

❌ **Not ideal for:**
- Quick prototypes
- Internal tools (only you use)
- When you can't run a server

### Pattern 2: Client → Providers (Direct)

```
iOS/macOS App (SwiftlyAIKit)
    ↓ [Provider API keys]
AI Providers
```

**How it works:**
1. iOS app calls providers directly
2. API keys stored on device (Keychain)

**Security:** ⚠️ Keys on device (user must trust app)
**Cost Control:** ❌ Limited (per-user rate limits only)
**Complexity:** ✅ Simple (no server needed)

#### Code Example

```swift
import SwiftlyAIKit

// Load user's API key from Keychain
let userKey = try KeychainManager.retrieve(for: "anthropic")

let config = Configuration.withCompanyKey(userKey)
let gateway = AIGateway(configuration: config)

let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Hello")
let response = try await gateway.sendMessage(request)
```

#### When to Use

✅ **Perfect for:**
- Prototypes and MVPs
- Internal company tools
- Development and testing
- When users bring their own API keys
- When you can't run a server

❌ **Not ideal for:**
- Production consumer apps
- When API key security is critical
- When you need central cost control
- Large-scale deployments

### Pattern 3: Hybrid (Local + Server)

```
iOS/macOS App (SwiftlyAIClient)
    ├─ Apple Intelligence (on-device)
    └─ Your Server (cloud providers)
```

**How it works:**
1. Privacy-sensitive: Apple Intelligence (on-device)
2. Complex tasks: Cloud providers via your server

**Security:** ✅ Excellent (best of both)
**Cost Control:** ✅ Flexible (free for simple, paid for complex)
**Complexity:** ⚠️ Medium (hybrid logic needed)

#### Code Example

```swift
import SwiftlyAIClient

class HybridAIService {
    let client: SwiftlyClient
    let localGateway: AIGateway

    func ask(_ prompt: String, sensitive: Bool) async throws -> AIResponse {
        if sensitive {
            // Use on-device for privacy
            let request = AIRequest(
                model: .appleIntelligence(.default),
                prompt: prompt
            )
            return try await localGateway.sendMessage(request, to: .appleIntelligence)
        } else {
            // Use cloud via server
            return try await client.chat(
                model: "claude-sonnet-4-5",
                messages: [.user(prompt)]
            )
        }
    }
}
```

#### When to Use

✅ **Perfect for:**
- Privacy-conscious applications
- Cost optimization (free for simple)
- Offline functionality
- Freemium models

❌ **Not ideal for:**
- Simple apps (overengineered)
- When privacy isn't a concern

## Decision Matrix

| Factor | Pattern 1 (Server) | Pattern 2 (Direct) | Pattern 3 (Hybrid) |
|--------|-------------------|-------------------|-------------------|
| **Security** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Cost Control** | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐⭐⭐ |
| **Simplicity** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **Privacy** | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Offline** | ❌ | ❌ | ✅ (partial) |
| **Setup Time** | Days | Hours | Days |

## Migration Paths

### Start Simple, Scale Up

```
Phase 1: Direct (Pattern 2)
    ↓ Add server as app grows
Phase 2: Server-based (Pattern 1)
    ↓ Add privacy features
Phase 3: Hybrid (Pattern 3)
```

### Example Migration

**Week 1 (Direct):**
```swift
// Quick prototype
let config = Configuration.withCompanyKey(devAPIKey)
let gateway = AIGateway(configuration: config)
```

**Month 1 (Add Server):**
```swift
// Move to server for security
let client = SwiftlyClient(serverURL: serverURL, apiKey: clientKey)
```

**Month 3 (Add Hybrid):**
```swift
// Add on-device for privacy
if userPreferredPrivacy {
    useAppleIntelligence()
} else {
    useCloudViaServer()
}
```

## Cost Comparison

### Scenario: 10,000 users, 100 requests/user/month

**Pattern 1 (Server):**
- Cost: Provider API costs + server hosting (~$100/month)
- Control: Full control over spending
- Scale: Predictable costs

**Pattern 2 (Direct):**
- Cost: Each user pays their own API costs
- Control: No control over user spending
- Scale: Distributed costs

**Pattern 3 (Hybrid):**
- Cost: Mix of free (on-device) and paid (cloud)
- Control: Partial (cloud only)
- Scale: Most cost-effective

## Security Comparison

| Risk | Pattern 1 | Pattern 2 | Pattern 3 |
|------|-----------|-----------|-----------|
| **API Key Exposure** | None | High | None |
| **Data Privacy** | Medium | Medium | High |
| **Cost Abuse** | Low | High | Low |
| **Service Disruption** | Low | Medium | Low |

## See Also

- <doc:APIKeyManagement>
- <doc:PerformanceOptimization>
- <doc:ProductionChecklist>
