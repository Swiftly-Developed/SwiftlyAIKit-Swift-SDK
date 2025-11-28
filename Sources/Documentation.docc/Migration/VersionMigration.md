# Version Migration Guide

Upgrade between SwiftlyAIKit versions.

## Overview

This guide helps you upgrade SwiftlyAIKit to the latest version, covering breaking changes and new features.

## Version 0.10.0 (Current)

**Released:** January 2025

**New Features:**
- Apple Intelligence provider (on-device)
- Enhanced provider support (all 9 providers complete)
- Comprehensive DocC documentation
- Improved error handling
- Better streaming support

**Breaking Changes:**
- None (fully backward compatible from 0.9.0)

**Migration:**
```swift
// Update Package.swift
.package(url: "https://github.com/Swiftly-Developed/SwiftlyAIKit.git", from: "0.10.0")

// No code changes required from 0.9.0
```

## Version 0.9.0

**Released:** November 2024

**New Features:**
- xAI Grok provider
- DeepSeek provider
- Cohere provider
- Mistral provider
- Perplexity provider
- Batch processing (Anthropic)
- Prompt caching support

**Breaking Changes:**
- Provider registration changes

**Migration:**
```swift
// Old (0.8.0)
let anthropic = AnthropicProvider(apiKey: "sk-ant-...")

// New (0.9.0+)
let config = Configuration.withCompanyKey("sk-ant-...")
let gateway = AIGateway(configuration: config)
// Providers auto-registered
```

## Version 0.8.0

**Initial multi-provider release**

## Best Practices

### Stay Updated

```bash
swift package update
```

### Test After Upgrading

```bash
swift test
```

### Review Changelog

Check `CHANGELOG.md` for detailed changes.

## See Also

- <doc:QuickStart>
- ``AIGateway``
- ``Configuration``
