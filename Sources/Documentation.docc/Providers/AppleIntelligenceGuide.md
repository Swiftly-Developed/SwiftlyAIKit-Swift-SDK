# Apple Intelligence Guide

Complete guide to using Apple Intelligence with SwiftlyAIKit.

## Overview

Apple Intelligence is unique among AI providers:
- **100% on-device** - Never leaves your Mac/iPhone
- **Perfect privacy** - No data sent to servers
- **No API costs** - Completely free
- **No network required** - Works offline
- **Native integration** - Built into Apple platforms

**Requirements:**
- macOS 15+ with Apple Silicon (M1/M2/M3/M4)
- iOS 18+ with A17 Pro or newer

Perfect for: Privacy-critical apps, offline functionality, zero API costs

## Getting Started

### No API Key Needed

Unlike cloud providers, Apple Intelligence runs entirely on-device and requires no API key:

```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("") // Empty key is fine
let gateway = AIGateway(configuration: config)

let request = AIRequest(
    model: .appleIntelligence(.default),
    prompt: "Summarize this text"
)

let response = try await gateway.sendMessage(request, to: .appleIntelligence)
// Processed entirely on your device!
```

## Available Models

### Apple Intelligence Default

**Model:** `.appleIntelligence(.default)`

**Specifications:**
- **Context:** Limited (device-dependent)
- **Pricing:** FREE (no API costs)
- **Speed:** Fast (local processing)
- **Privacy:** Perfect (never leaves device)
- **Network:** Not required

**Best for:**
- Privacy-sensitive applications
- Offline functionality
- Zero-cost AI features
- Personal data processing

## Key Differences from Cloud Providers

### Capabilities

| Feature | Apple Intelligence | Cloud Providers |
|---------|-------------------|-----------------|
| **Privacy** | Perfect (on-device) | Sent to servers |
| **Cost** | Free | Paid |
| **Network** | Not required | Required |
| **Context** | Limited | Large (64K-2M) |
| **Vision** | Not supported | Supported |
| **Tools** | Not supported | Supported |
| **Streaming** | Supported | Supported |
| **Quality** | Good | Excellent |

### Advantages

✅ **Perfect Privacy**
```swift
// Process sensitive data without ever sending to cloud
let privateData = user.medicalRecords

let request = AIRequest(
    model: .appleIntelligence(.default),
    prompt: "Summarize: \(privateData)"
)
// Never leaves the device!
```

✅ **Zero Costs**
```swift
// Unlimited usage, no billing
for i in 1...1000 {
    let request = AIRequest(
        model: .appleIntelligence(.default),
        prompt: "Process item \(i)"
    )
    _ = try await gateway.sendMessage(request, to: .appleIntelligence)
}
// Cost: $0.00
```

✅ **Offline Functionality**
```swift
// Works without internet
if !isConnectedToInternet {
    // Use Apple Intelligence instead
    let request = AIRequest(
        model: .appleIntelligence(.default),
        prompt: prompt
    )
    return try await gateway.sendMessage(request, to: .appleIntelligence)
}
```

### Limitations

❌ **Limited Context**
- Smaller context window than cloud models
- Not suitable for very long documents

❌ **No Vision**
- Cannot analyze images
- Text-only processing

❌ **No Tools**
- Function calling not supported
- No external integrations

❌ **Device Requirements**
- Requires Apple Silicon
- Not available on Intel Macs or older iPhones

## Hybrid Deployment Pattern

Combine Apple Intelligence with cloud providers:

```swift
class HybridAIService {
    let gateway: AIGateway

    func ask(_ prompt: String, sensitive: Bool) async throws -> AIResponse {
        if sensitive {
            // Use on-device for privacy
            let request = AIRequest(
                model: .appleIntelligence(.default),
                prompt: prompt
            )
            return try await gateway.sendMessage(request, to: .appleIntelligence)
        } else {
            // Use cloud for better quality
            let request = AIRequest(
                model: .claude(.sonnet4_5),
                prompt: prompt
            )
            return try await gateway.sendMessage(request, to: .anthropic)
        }
    }
}

// Usage
let service = HybridAIService(gateway: gateway)

// Sensitive data - stays on device
let privateResponse = try await service.ask(
    "Summarize my medical records",
    sensitive: true
)

// General query - use cloud for better quality
let generalResponse = try await service.ask(
    "Explain quantum physics",
    sensitive: false
)
```

## Image Generation

Apple Intelligence supports image generation (on-device):

```swift
let request = ImageGenerationRequest(
    prompt: "A peaceful landscape",
    model: "apple-image-playground",
    numberOfImages: 1
)

let response = try await gateway.generateImage(request, using: .appleIntelligence)
// Image generated on-device, no cost!
```

## Streaming

Apple Intelligence supports streaming:

```swift
let request = AIRequest(
    model: .appleIntelligence(.default),
    prompt: "Write a short story"
)

let stream = try await gateway.streamMessage(request, to: .appleIntelligence)

for try await chunk in stream {
    print(chunk.message.content, terminator: "")
}
```

## Use Cases

### Privacy-First Chat

```swift
class PrivateChatApp {
    let gateway: AIGateway

    func chat(_ message: String) async throws -> String {
        // All processing on-device
        let request = AIRequest(
            model: .appleIntelligence(.default),
            messages: conversationHistory + [.user(message)]
        )

        let response = try await gateway.sendMessage(request, to: .appleIntelligence)

        return response.message.content
        // User's conversation never leaves their device
    }
}
```

### Offline Text Processing

```swift
class OfflineTextProcessor {
    let gateway: AIGateway

    func summarize(_ text: String) async throws -> String {
        let request = AIRequest(
            model: .appleIntelligence(.default),
            prompt: "Summarize in 3 sentences: \(text)"
        )

        return try await gateway.sendMessage(request, to: .appleIntelligence).message.content
    }

    func translate(_ text: String, to language: String) async throws -> String {
        let request = AIRequest(
            model: .appleIntelligence(.default),
            prompt: "Translate to \(language): \(text)"
        )

        return try await gateway.sendMessage(request, to: .appleIntelligence).message.content
    }
}
// Works without internet connection!
```

### Cost-Free Development

```swift
// Perfect for development and testing - no API costs!
let testGateway = AIGateway(configuration: Configuration.withCompanyKey(""))

// Test your app logic without spending money
for testCase in testCases {
    let request = AIRequest(
        model: .appleIntelligence(.default),
        prompt: testCase.prompt
    )

    let response = try await testGateway.sendMessage(request, to: .appleIntelligence)
    verify(response, matches: testCase.expected)
}
// Total cost: $0.00
```

## Availability Checking

```swift
func isAppleIntelligenceAvailable() -> Bool {
    #if os(macOS)
    if #available(macOS 15.0, *) {
        // Check for Apple Silicon
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        return machine?.contains("arm64") ?? false
    }
    #elseif os(iOS)
    if #available(iOS 18.0, *) {
        // Check for A17 Pro or newer
        return true // Simplified check
    }
    #endif
    return false
}

// Use in your app
if isAppleIntelligenceAvailable() {
    // Offer on-device AI option
} else {
    // Fall back to cloud providers
}
```

## Best Practices

### ✅ Do

- Use for privacy-sensitive data
- Use for offline functionality
- Use for development/testing (free!)
- Combine with cloud providers in hybrid pattern
- Leverage for cost-free features

### ❌ Don't

- Expect cloud provider quality
- Try to use vision features
- Use for very long context
- Expect tool calling support
- Rely on it for mission-critical tasks (less proven)

## Hybrid Pattern Example

```swift
@MainActor
class SmartAIService: ObservableObject {
    @Published var useOnDevice = true
    let gateway: AIGateway

    func sendMessage(_ prompt: String) async throws -> AIResponse {
        let request = AIRequest(
            model: useOnDevice ? .appleIntelligence(.default) : .claude(.sonnet4_5),
            prompt: prompt
        )

        let provider: ProviderType = useOnDevice ? .appleIntelligence : .anthropic

        return try await gateway.sendMessage(request, to: provider)
    }
}

// SwiftUI Toggle
Toggle("Use On-Device AI (Private)", isOn: $service.useOnDevice)
```

## See Also

- ``AppleIntelligenceProvider``
- <doc:ProvidersOverview>
- <doc:ChoosingDeploymentPattern>
- <doc:APIKeyManagement>
