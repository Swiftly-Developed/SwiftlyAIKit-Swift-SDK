# API Key Management

Secure your AI provider API keys in development and production.

## Overview

API keys are sensitive credentials that grant access to paid AI services. Improper key management can lead to:
- **Security breaches** - Keys exposed in client apps
- **Unexpected costs** - Keys abused by unauthorized users
- **Service disruption** - Keys leaked and revoked

This guide covers secure API key management for SwiftlyAIKit across different environments and deployment patterns.

## Golden Rules

### ❌ NEVER

1. **Commit API keys to source control**
   ```swift
   // ❌ NEVER DO THIS
   let config = Configuration.withCompanyKey("sk-ant-api03-xxxxx...")
   ```

2. **Embed keys in client applications**
   ```swift
   // ❌ NEVER in iOS/macOS apps
   let hardcodedKey = "sk-ant-api03-xxxxx..."
   ```

3. **Log API keys**
   ```swift
   // ❌ NEVER
   print("Using key: \(apiKey)")
   ```

4. **Share keys between environments**
   ```swift
   // ❌ Use separate keys for dev, staging, production
   ```

### ✅ ALWAYS

1. **Use environment variables**
   ```swift
   // ✅ Good
   guard let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
       fatalError("API key not set")
   }
   ```

2. **Use server-side proxies for production apps**
   ```swift
   // ✅ iOS app → Your server → AI provider
   // Keys stay on your server, never on device
   ```

3. **Rotate keys regularly**
   ```swift
   // ✅ Generate new keys monthly
   // Revoke old keys
   ```

4. **Monitor key usage**
   ```swift
   // ✅ Track API calls, set alerts for unusual activity
   ```

## API Key Strategies

SwiftlyAIKit supports four key management patterns through ``APIKeyStrategy``:

### 1. Company Key (Server-Managed)

**Use for:** Server applications, internal tools, trusted environments

```swift
let config = Configuration.withCompanyKey(
    ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]!
)
let gateway = AIGateway(configuration: config)
```

**Security:**
- ✅ Key stored server-side only
- ✅ Full cost control
- ✅ Easy to rotate
- ❌ All users share one key

**Best practices:**
- Store in environment variables, never code
- Use different keys for dev/staging/production
- Monitor usage per user via logging
- Implement rate limiting

### 2. Client Key (User-Provided)

**Use for:** SaaS apps where users bring their own keys

```swift
let config = Configuration.withClientKeys()
let gateway = AIGateway(configuration: config)

// User provides their own key
let userKey = userSettings.apiKey
let response = try await gateway.sendMessage(request, clientAPIKey: userKey)
```

**Security:**
- ✅ No keys on your server
- ✅ Users pay their own costs
- ✅ No shared rate limits
- ❌ Requires user to have API key

**Best practices:**
- Validate key format before storing
- Encrypt keys in user database
- Don't log user keys
- Provide key validation feedback

### 3. Hybrid Key (Optional Client Keys)

**Use for:** Freemium models, premium features

```swift
let companyKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]!
let config = Configuration.withHybridKeys(defaultKey: companyKey)
let gateway = AIGateway(configuration: config)

// Free tier (uses company key)
let freeResponse = try await gateway.sendMessage(request)

// Premium tier (user's own key)
if let userKey = user.premiumAPIKey {
    let premiumResponse = try await gateway.sendMessage(request, clientAPIKey: userKey)
}
```

**Security:**
- ✅ Flexible billing
- ✅ Easy upgrade path
- ✅ Fall back to company key
- ❌ Still need to protect company key

**Best practices:**
- Rate limit free tier aggressively
- Verify user keys before upgrading
- Track which users use which keys

### 4. Per-Provider Keys

**Use for:** Multi-provider apps, separate billing

```swift
let config = Configuration.withProviderKeys([
    .anthropic: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]!,
    .openai: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!,
    .google: ProcessInfo.processInfo.environment["GOOGLE_API_KEY"]!
])
let gateway = AIGateway(configuration: config)

// Each provider uses its own key automatically
let claudeResponse = try await gateway.sendMessage(request, to: .anthropic)
let gptResponse = try await gateway.sendMessage(request, to: .openai)
```

**Security:**
- ✅ Separate billing per provider
- ✅ Isolate key compromise
- ✅ Different access levels
- ❌ More keys to manage

## Development Environment Setup

### Xcode Environment Variables

**For iOS/macOS apps during development:**

1. Edit your scheme (Product → Scheme → Edit Scheme)
2. Select "Run" → "Arguments"
3. Add environment variables:
   ```
   ANTHROPIC_API_KEY = sk-ant-api03-xxxxx...
   OPENAI_API_KEY = sk-xxxxx...
   ```

4. Use in code:
   ```swift
   let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]!
   let config = Configuration.withCompanyKey(key)
   ```

**⚠️ Important:** Environment variables in Xcode are NOT committed to git.

### .env Files (Server Development)

**For Vapor/server applications:**

1. Create `.env` file in project root:
   ```bash
   ANTHROPIC_API_KEY=sk-ant-api03-xxxxx...
   OPENAI_API_KEY=sk-xxxxx...
   GOOGLE_API_KEY=xxxxx...
   ```

2. Add to `.gitignore`:
   ```
   .env
   .env.*
   ```

3. Load in your app:
   ```swift
   import Vapor

   // Vapor loads .env automatically
   let anthropicKey = Environment.get("ANTHROPIC_API_KEY")!
   ```

4. Create `.env.example` (commit this):
   ```bash
   ANTHROPIC_API_KEY=your_key_here
   OPENAI_API_KEY=your_key_here
   ```

### Keychain (Persistent Storage)

**For storing user-provided keys securely:**

```swift
import Security

class KeychainManager {
    static func save(key: String, for service: String) throws {
        let data = key.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unableToSave
        }
    }

    static func retrieve(for service: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.notFound
        }

        return key
    }
}

enum KeychainError: Error {
    case unableToSave, notFound
}

// Usage
try KeychainManager.save(key: userAPIKey, for: "anthropic")
let key = try KeychainManager.retrieve(for: "anthropic")
```

## Production Server Setup

### Environment Variables (Recommended)

**For Vapor production deployments:**

```swift
// configure.swift
public func configure(_ app: Application) throws {
    // Load from environment
    guard let anthropicKey = Environment.get("ANTHROPIC_API_KEY"),
          !anthropicKey.isEmpty else {
        app.logger.critical("ANTHROPIC_API_KEY not set!")
        throw ConfigurationError.missingAPIKey
    }

    // Configure SwiftlyAIKit
    let config = Configuration.withCompanyKey(anthropicKey)
    try app.ai.initialize(with: config)
}
```

**Set on server:**
```bash
# Linux/macOS server
export ANTHROPIC_API_KEY="sk-ant-..."

# Docker
docker run -e ANTHROPIC_API_KEY="sk-ant-..." myapp

# Kubernetes secret
kubectl create secret generic ai-keys \
    --from-literal=anthropic-key=sk-ant-...
```

### Secrets Manager (Enterprise)

**For AWS, Google Cloud, Azure:**

```swift
import AWSSecretsManager // Example

func loadAPIKeys() async throws -> Configuration {
    let client = SecretsManagerClient(region: "us-east-1")

    let anthropicKey = try await client.getSecretValue(secretId: "prod/anthropic/apikey")
    let openaiKey = try await client.getSecretValue(secretId: "prod/openai/apikey")

    return Configuration.withProviderKeys([
        .anthropic: anthropicKey,
        .openai: openaiKey
    ])
}
```

### Docker Secrets

```yaml
# docker-compose.yml
services:
  api:
    image: myapp
    secrets:
      - anthropic_key
      - openai_key
    environment:
      ANTHROPIC_API_KEY_FILE: /run/secrets/anthropic_key
      OPENAI_API_KEY_FILE: /run/secrets/openai_key

secrets:
  anthropic_key:
    external: true
  openai_key:
    external: true
```

```swift
// Load from Docker secret files
func loadKey(from path: String) throws -> String {
    let key = try String(contentsOfFile: path, encoding: .utf8)
    return key.trimmingCharacters(in: .whitespacesAndNewlines)
}

let anthropicKey = try loadKey(
    from: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY_FILE"]!
)
```

## Client-Side Key Storage

### For Apps with User-Provided Keys

```swift
import SwiftUI
import SwiftlyAIKit

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var apiKey: String = ""

    private let keychainService = "com.yourapp.apikeys"

    init() {
        // Load from keychain on init
        if let savedKey = try? KeychainManager.retrieve(for: keychainService) {
            apiKey = savedKey
        }
    }

    func saveAPIKey() throws {
        // Validate key format
        guard apiKey.hasPrefix("sk-ant-") || apiKey.hasPrefix("sk-") else {
            throw ValidationError.invalidKeyFormat
        }

        // Save to keychain
        try KeychainManager.save(key: apiKey, for: keychainService)
    }

    func deleteAPIKey() throws {
        apiKey = ""
        // Delete from keychain
        try KeychainManager.delete(for: keychainService)
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            Section("API Key") {
                SecureField("API Key", text: $viewModel.apiKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()

                Button("Save") {
                    try? viewModel.saveAPIKey()
                }

                Text("Your API key is stored securely in the Keychain")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

## Key Rotation

### Server-Side Rotation

```swift
class APIKeyRotator {
    func rotateKeys() async throws {
        // 1. Generate new key from provider
        let newKey = try await createNewAnthropicKey()

        // 2. Update environment/secrets manager
        try await updateSecret(name: "anthropic-key", value: newKey)

        // 3. Wait for deployment to pick up new key
        try await Task.sleep(nanoseconds: 60_000_000_000) // 60s

        // 4. Revoke old key from provider
        try await revokeOldKey()

        print("Key rotation complete")
    }
}
```

### Zero-Downtime Rotation

```swift
// Use hybrid strategy during rotation
let oldKey = ProcessInfo.processInfo.environment["OLD_ANTHROPIC_KEY"]!
let newKey = ProcessInfo.processInfo.environment["NEW_ANTHROPIC_KEY"]!

// Phase 1: Add new key as hybrid default
let config = Configuration.withHybridKeys(defaultKey: newKey)

// Phase 2: Both keys work (old as client key if needed)

// Phase 3: After verification, remove old key
```

## Validation

### Validate Key Format

```swift
func isValidAPIKey(_ key: String, for provider: ProviderType) -> Bool {
    switch provider {
    case .anthropic:
        return key.hasPrefix("sk-ant-api")
    case .openai:
        return key.hasPrefix("sk-") && !key.hasPrefix("sk-ant")
    case .google:
        return key.count == 39 // Google keys are 39 chars
    case .perplexity:
        return key.hasPrefix("pplx-")
    case .mistral:
        return key.count == 32 // Mistral keys are 32 chars
    case .cohere:
        return key.count >= 40
    case .deepseek:
        return key.hasPrefix("sk-")
    case .grok:
        return key.hasPrefix("xai-")
    case .appleIntelligence:
        return true // No key needed
    }
}
```

### Test Key Validity

```swift
func validateAPIKey(_ key: String, for provider: ProviderType) async -> Bool {
    let config = Configuration.withCompanyKey(key)
    let gateway = AIGateway(configuration: config)

    let testRequest = AIRequest(
        model: .custom("test-model"),
        prompt: "Hello",
        maxTokens: 1 // Minimal request
    )

    do {
        _ = try await gateway.sendMessage(testRequest, to: provider)
        return true
    } catch AIError.authenticationFailed {
        return false
    } catch {
        // Other errors mean key is valid but request failed
        return true
    }
}
```

## Deployment Patterns

### Pattern 1: Client → Server → Providers (Recommended)

**Architecture:**
```
iOS App (SwiftlyAIClient)
    ↓ [No API keys]
Your Server (SwiftlyAIServerKit)
    ↓ [API keys in env vars]
AI Providers
```

**Server code:**
```swift
// configure.swift
let config = Configuration.withCompanyKey(
    Environment.get("ANTHROPIC_API_KEY")!
)
try app.ai.initialize(with: config)
```

**Client code:**
```swift
// iOS app
let client = SwiftlyClient(
    serverURL: URL(string: "https://api.yourserver.com")!,
    apiKey: "your-client-api-key" // NOT the provider key!
)
```

**Security:** ✅ Provider API keys never leave server

### Pattern 2: Client → Providers (Direct)

**Architecture:**
```
iOS App (SwiftlyAIKit)
    ↓ [User's API key in Keychain]
AI Providers
```

**Code:**
```swift
// Load from keychain
let userKey = try KeychainManager.retrieve(for: "anthropic")

let config = Configuration.withCompanyKey(userKey)
let gateway = AIGateway(configuration: config)
```

**Security:** ⚠️ User's key on device (use keychain, not UserDefaults)

### Pattern 3: Hybrid (Optional Client Keys)

**Architecture:**
```
iOS App → Server with hybrid strategy
    ├─ Free tier: Company key
    └─ Premium tier: User's key
```

**Server code:**
```swift
let companyKey = Environment.get("ANTHROPIC_API_KEY")!
let config = Configuration.withHybridKeys(defaultKey: companyKey)
try app.ai.initialize(with: config)
```

**Client code:**
```swift
// Free tier user
let response = try await client.chat(messages: messages)

// Premium tier user
let response = try await client.chat(messages: messages, apiKey: userKey)
```

**Security:** ✅ Flexible, server-controlled

## Security Checklist

Before deploying to production, verify:

### Server-Side
- [ ] API keys loaded from environment variables
- [ ] No keys committed to git
- [ ] `.env` files in `.gitignore`
- [ ] Separate keys for dev/staging/production
- [ ] Keys rotated regularly (monthly)
- [ ] Usage monitored and alerted
- [ ] Rate limiting implemented
- [ ] Logging doesn't expose keys

### Client-Side
- [ ] No hardcoded keys in code
- [ ] User keys stored in Keychain (not UserDefaults)
- [ ] Keys transmitted over HTTPS only
- [ ] Key validation before storage
- [ ] Key deletion on logout
- [ ] Clear instructions for users

### Infrastructure
- [ ] HTTPS/TLS enforced
- [ ] Secrets manager configured (AWS/GCP/Azure)
- [ ] Docker secrets properly mounted
- [ ] Kubernetes secrets encrypted
- [ ] Backup keys secured
- [ ] Access logs enabled

## Common Mistakes

### Mistake 1: Keys in UserDefaults

❌ **Wrong:**
```swift
UserDefaults.standard.set(apiKey, forKey: "apiKey")
```

✅ **Right:**
```swift
try KeychainManager.save(key: apiKey, for: "apiKey")
```

### Mistake 2: Logging Keys

❌ **Wrong:**
```swift
print("Request with key: \(apiKey)")
logger.debug("API Key: \(apiKey)")
```

✅ **Right:**
```swift
logger.debug("API key loaded: \(apiKey.prefix(10))...")
```

### Mistake 3: Committed .env

❌ **Wrong:**
```bash
git add .env
git commit -m "Add environment config"
```

✅ **Right:**
```bash
# .gitignore
.env
.env.*
!.env.example
```

### Mistake 4: Same Key Everywhere

❌ **Wrong:**
```swift
// Using production key in development
let key = "sk-ant-api03-PRODUCTION_KEY"
```

✅ **Right:**
```swift
let env = ProcessInfo.processInfo.environment["APP_ENV"] ?? "development"
let keyName = "ANTHROPIC_API_KEY_\(env.uppercased())"
let key = ProcessInfo.processInfo.environment[keyName]!
```

## Monitoring and Alerts

### Track Key Usage

```swift
actor KeyUsageTracker {
    private var usage: [String: Int] = [:]

    func recordUsage(key: String) {
        let keyPrefix = String(key.prefix(10))
        usage[keyPrefix, default: 0] += 1
    }

    func getUsage() -> [String: Int] {
        usage
    }
}

// In your middleware/logging
let tracker = KeyUsageTracker()

func sendWithTracking(_ request: AIRequest, key: String) async throws -> AIResponse {
    await tracker.recordUsage(key: key)

    let response = try await gateway.sendMessage(request, clientAPIKey: key)

    // Alert if unusual usage
    let count = await tracker.getUsage()[String(key.prefix(10))]
    if let count, count > 1000 {
        alertAdmin("High usage detected for key")
    }

    return response
}
```

### Set Up Alerts

```swift
// Example: Alert on provider costs
func checkCosts(response: AIResponse) {
    if let usage = response.usage {
        let inputCost = Double(usage.inputTokens) * 0.000003  // $3/M tokens
        let outputCost = Double(usage.outputTokens) * 0.000015 // $15/M tokens
        let totalCost = inputCost + outputCost

        if totalCost > 1.0 {
            alertAdmin("Expensive request: $\(totalCost)")
        }
    }
}
```

## See Also

- ``APIKeyStrategy``
- ``Configuration``
- <doc:ConfigurationSystem>
- <doc:ChoosingDeploymentPattern>
- <doc:ProductionChecklist>
- <doc:MonitoringAndDebugging>
