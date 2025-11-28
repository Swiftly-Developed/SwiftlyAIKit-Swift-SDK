# Configuration System

Deep dive into SwiftlyAIKit's configuration system.

## Overview

The configuration system controls how SwiftlyAIKit authenticates, makes requests, and handles responses. Understanding configuration is key to building production-ready applications.

This guide covers:
- Configuration components
- API key strategies in detail
- Advanced configuration options
- Environment-specific setups
- Best practices

## Configuration Components

``Configuration`` consists of several key components:

```swift
public struct Configuration {
    let keyStrategy: APIKeyStrategy        // How API keys are managed
    let providerKeys: [ProviderType: String]  // Provider-specific keys
    let timeout: Int                       // Request timeout
    let maxRetries: Int                    // Retry attempts
    let enableLogging: Bool                // Debug logging
    let betaFeatures: [ProviderType: [String]]  // Beta flags
    let customBaseURLs: [ProviderType: String]  // Custom endpoints
    let defaultProvider: ProviderType      // Default provider
}
```

## API Key Strategies Explained

### Strategy 1: Company Key

**Use when:** You control all API costs centrally

```swift
let config = Configuration.withCompanyKey(
    "sk-ant-...",
    provider: .anthropic,
    enableLogging: false
)
```

**How it works:**
1. You provide one API key at initialization
2. All requests use this key
3. You pay for all usage
4. Simple, centralized billing

**Security considerations:**
- Store key in environment variables
- Never commit to source control
- Rotate regularly
- Monitor usage

### Strategy 2: Client Key

**Use when:** Users bring their own API keys

```swift
let config = Configuration.withClientKeys(
    provider: .anthropic,
    enableLogging: false
)

// Client must provide key with each request
let response = try await gateway.sendMessage(request, clientAPIKey: userProvidedKey)
```

**How it works:**
1. No default key stored
2. Client provides key with each request
3. Each user pays their own costs
4. No shared rate limits

**Security considerations:**
- Validate key format before using
- Store user keys in keychain
- Never log user keys
- Handle missing key errors gracefully

### Strategy 3: Hybrid

**Use when:** Freemium model with optional user keys

```swift
let config = Configuration.withHybridKeys(
    defaultKey: "sk-ant-...",
    provider: .anthropic
)

// Free tier (uses company key)
let freeResponse = try await gateway.sendMessage(request)

// Premium tier (uses user's key)
let premiumResponse = try await gateway.sendMessage(request, clientAPIKey: premiumUserKey)
```

**How it works:**
1. Company key as fallback
2. Client can optionally provide their own key
3. Flexible billing model
4. Easy upgrade path

**Business logic:**
```swift
func sendMessage(_ request: AIRequest, user: User) async throws -> AIResponse {
    if user.isPremium, let userKey = user.apiKey {
        // Premium users use their own key (higher/no limits)
        return try await gateway.sendMessage(request, clientAPIKey: userKey)
    } else {
        // Free users use company key (with rate limits)
        if await rateLimiter.isAllowed(user.id) {
            return try await gateway.sendMessage(request)
        } else {
            throw AppError.rateLimited
        }
    }
}
```

### Strategy 4: Per-Provider

**Use when:** Different keys for different providers

```swift
let config = Configuration.withProviderKeys([
    .anthropic: "sk-ant-...",
    .openai: "sk-...",
    .google: "...",
    .perplexity: "pplx-..."
])

// Each provider uses its designated key automatically
let claude = try await gateway.sendMessage(request, to: .anthropic) // Uses Anthropic key
let gpt = try await gateway.sendMessage(request, to: .openai)       // Uses OpenAI key
```

**How it works:**
1. Provide a dictionary of keys
2. Gateway routes to correct key automatically
3. Can mix company and client keys

**Use cases:**
- Separate billing per provider
- Different spending limits
- Isolate key compromise
- Multiple accounts

## Advanced Configuration

### Full Initializer

For complete control:

```swift
let config = Configuration(
    keyStrategy: .companyKey("sk-ant-..."),
    providerKeys: [:],
    timeout: 120,              // 2 minute timeout
    maxRetries: 5,             // Retry 5 times
    enableLogging: true,       // Verbose logging
    betaFeatures: [
        .anthropic: ["prompt-caching-2024-07-31"],
        .deepseek: ["prompt-caching-enabled"]
    ],
    customBaseURLs: [
        .openai: "https://custom-proxy.example.com"
    ],
    defaultProvider: .anthropic
)
```

### Environment Presets

SwiftlyAIKit provides pre-configured environments:

#### Development Configuration

```swift
let devConfig = Configuration.development(
    companyKey: "sk-ant-...",
    provider: .anthropic
)
```

**Optimized for debugging:**
- Logging enabled by default
- Longer timeout (120s) for debugging
- Fewer retries (1) for faster feedback
- Verbose error messages

#### Production Configuration

```swift
let prodConfig = Configuration.production(
    keyStrategy: .hybrid(defaultKey: "sk-ant-..."),
    provider: .anthropic
)
```

**Optimized for reliability:**
- Logging disabled (performance)
- Standard timeout (60s)
- Aggressive retries (3)
- Minimal overhead

## Custom Base URLs

### Azure OpenAI

```swift
let config = Configuration(
    keyStrategy: .companyKey("azure-key"),
    customBaseURLs: [
        .openai: "https://your-resource.openai.azure.com"
    ]
)
```

### Self-Hosted Proxy

```swift
let config = Configuration(
    keyStrategy: .companyKey("internal-key"),
    customBaseURLs: [
        .anthropic: "https://ai-proxy.company.internal/anthropic",
        .openai: "https://ai-proxy.company.internal/openai"
    ]
)
```

## Beta Features

### Enable Provider Beta Features

```swift
let config = Configuration(
    keyStrategy: .companyKey("sk-ant-..."),
    betaFeatures: [
        .anthropic: [
            "prompt-caching-2024-07-31",
            "extended-thinking-2024-12-12"
        ]
    ]
)
```

**Available beta features:**
- **Anthropic:** prompt-caching, extended-thinking
- **DeepSeek:** prompt-caching
- Check provider documentation for latest features

## Logging Configuration

### Enable Framework Logging

```swift
let config = Configuration.withCompanyKey("sk-ant-...", enableLogging: true)

// Configure log level
config.configureLogging(logLevel: .debug)
```

### Custom Logger

```swift
import Logging

class CustomLogger: AILogger {
    func log(level: LogLevel, message: String, metadata: [String: String]?) {
        // Custom logging logic
        print("[\(level)] \(message)")
        if let metadata = metadata {
            print("  Metadata: \(metadata)")
        }
    }
}

let config = Configuration.withCompanyKey("sk-ant-...")
config.configureLogging(logger: CustomLogger(), logLevel: .info)
```

## HTTP Configuration

### Timeout Settings

```swift
// Short timeout for quick responses
let quickConfig = Configuration(
    keyStrategy: .companyKey("sk-ant-..."),
    timeout: 30  // 30 seconds
)

// Long timeout for complex tasks
let longConfig = Configuration(
    keyStrategy: .companyKey("sk-ant-..."),
    timeout: 300 // 5 minutes
)
```

### Retry Configuration

```swift
// Aggressive retries for reliability
let reliableConfig = Configuration(
    keyStrategy: .companyKey("sk-ant-..."),
    maxRetries: 5  // Retry up to 5 times
)

// No retries for fast failure
let fastFailConfig = Configuration(
    keyStrategy: .companyKey("sk-ant-..."),
    maxRetries: 0  // Fail immediately
)
```

## Environment-Based Configuration

### Load from Environment Variables

```swift
func createConfiguration() -> Configuration {
    let env = ProcessInfo.processInfo.environment

    // Determine environment
    let isProduction = env["APP_ENV"] == "production"

    // Load API keys
    guard let anthropicKey = env["ANTHROPIC_API_KEY"],
          let openaiKey = env["OPENAI_API_KEY"] else {
        fatalError("API keys not configured")
    }

    let keys: [ProviderType: String] = [
        .anthropic: anthropicKey,
        .openai: openaiKey
    ]

    return Configuration(
        keyStrategy: .perProvider(keys),
        timeout: isProduction ? 60 : 120,
        maxRetries: isProduction ? 3 : 1,
        enableLogging: !isProduction,
        defaultProvider: .anthropic
    )
}
```

### Configuration Builder Pattern

For complex setups:

```swift
let config = ConfigurationBuilder()
    .setProviderKey("sk-ant-...", for: .anthropic)
    .setProviderKey("sk-...", for: .openai)
    .timeout(90)
    .maxRetries(3)
    .defaultProvider(.anthropic)
    .enableLogging(true)
    .enableBetaFeatures(["prompt-caching-2024-07-31"], for: .anthropic)
    .build()
```

## Testing Configurations

### Mock Configuration

```swift
@Test
func testWithMockConfig() async throws {
    let mockConfig = Configuration.withCompanyKey("test-key")
    let gateway = AIGateway(configuration: mockConfig)

    // Use mock providers
    let mockProvider = MockProvider()
    await gateway.registerProvider(mockProvider, for: .anthropic)

    // Test your logic
}
```

## Best Practices

### ✅ Do

- Load keys from environment variables
- Use different configs for dev/prod
- Set appropriate timeouts for task complexity
- Enable logging in development
- Disable logging in production
- Monitor and adjust retry counts

### ❌ Don't

- Hardcode API keys
- Use production keys in development
- Set timeout too low (causes failures)
- Set maxRetries too high (slow failure)
- Enable logging in production (performance hit)
- Ignore beta features (miss cost savings)

## See Also

- ``Configuration``
- ``APIKeyStrategy``
- ``ConfigurationBuilder``
- <doc:APIKeyManagement>
- <doc:QuickStart>
