# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftlyAIKit is an AI Model Gateway framework built for server-side Swift and Vapor applications. It provides a unified interface for interacting with multiple AI providers (OpenAI, Anthropic, Google AI, Cohere, Mistral). The project uses Swift 6.2 and requires macOS 13.0+.

## Build and Test Commands

**Build the package:**
```bash
swift build
```

**Run all tests:**
```bash
swift test
```

**Run a specific test:**
```bash
swift test --filter SwiftlyAIKitTests.<TestName>
```

**Clean build artifacts:**
```bash
swift package clean
```

**Update dependencies:**
```bash
swift package update
```

## Architecture

### Core Components

The framework is organized into five main directories under `Sources/SwiftlyAIKit/`:

1. **Models/** - Core data structures
   - `AIRequest`, `AIResponse`, `AIMessage` - Request/response types
   - `AIError` - Framework-specific errors
   - `ModelProvider`, `ProviderType` - Provider identification

2. **Providers/** - AI provider implementations
   - `ProviderProtocol` - Interface all providers must implement
   - Provider implementations: OpenAI, Anthropic, Cohere, Google, Mistral
   - Each provider handles API-specific request/response formatting

3. **Core/** - Framework core logic
   - `AIGateway` - Main actor coordinating provider calls
   - `APIKeyStrategy` - Key management strategies (company vs client keys)
   - `Configuration` - Framework configuration options

4. **Extensions/** - Vapor integration
   - `Request+AI.swift` - Vapor Request extensions for gateway access
   - `Application+AI.swift` - Application lifecycle and registration

5. **Utilities/** - Helper functionality
   - `HTTPClientManager` - AsyncHTTPClient wrapper
   - `JSONHelpers` - JSON encoding/decoding utilities

### Design Patterns

- **Actor-based concurrency**: `AIGateway` uses Swift actors for thread-safe coordination
- **Protocol-oriented**: All providers conform to `ProviderProtocol`
- **Async/await**: All async operations use modern Swift concurrency
- **Vapor integration**: Native Request/Application extensions for seamless usage

### Testing Framework

This project uses the Swift Testing framework (imported as `Testing`), not XCTest:
- Use `@Test` annotation for test functions
- Use `#expect(...)` for assertions (not XCTAssert)
- Use `async throws` for asynchronous test methods
- Import with `@testable import SwiftlyAIKit` to access internal APIs

Tests are organized in `Tests/SwiftlyAIKitTests/`:
- `CoreTests/` - Tests for gateway and core functionality
- `ProviderTests/` - Tests for individual provider implementations

## Dependencies

- **Vapor** (4.99.0+) - Web framework integration
- **AsyncHTTPClient** (1.19.0+) - HTTP client for provider API calls

## Development Guidelines

- Keep provider implementations independent and focused
- Use actors for shared mutable state
- Document public APIs with DocC-style comments
- Follow Swift API Design Guidelines
- Maintain backwards compatibility within major versions
