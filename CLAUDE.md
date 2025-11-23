# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftlyAIKit is an AI Model Gateway framework built for server-side Swift and Vapor applications. It provides a unified interface for interacting with multiple AI providers (OpenAI, Anthropic, Google AI, Cohere, Mistral). The project uses Swift 6.2 and requires macOS 13.0+.

**Repository Structure:**
- This is part of a larger Xcode workspace: `SwiftlyAI.xcworkspace`
- Main package: `SwiftlyAIKit/` (Swift Package)
- The workspace may contain additional projects/packages
- Focus development work in `SwiftlyAIKit/` directory

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
# Run a specific test suite
swift test --filter SwiftlyAIKitTests.CoreTests

# Run a specific test file
swift test --filter SwiftlyAIKitTests.AIGatewayTests

# Run a specific test function
swift test --filter SwiftlyAIKitTests.AIGatewayTests.testSendMessage
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
   - `Models/Anthropic/` - Anthropic-specific types (AnthropicModels.swift with ~700 lines of API types)

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
  - `HTTPClientManager` is also an actor for safe HTTP operations
  - All mocks (MockProvider, MockHTTPClient) are actors
  - Be mindful of actor isolation when calling cross-actor methods
- **Protocol-oriented**: All providers conform to `ProviderProtocol`
  - Protocol provides default implementations for batch operations
  - Providers can override defaults for custom behavior
- **Async/await**: All async operations use modern Swift concurrency
  - All providers implement `async throws` methods
  - Streaming uses AsyncThrowingStream
- **Vapor Storage pattern**: Framework uses Vapor's storage system for dependency injection
  - `Application.storage[AIGatewayKey.self]` stores the gateway instance
  - Access via `app.ai` or `req.ai` for convenient usage
  - Storage keys are type-safe and provide clear error messages if not initialized
- **Error mapping**: HTTPClientManager maps HTTP status codes to specific AIError types
  - 401/403 → authentication errors
  - 429 → rate limiting
  - 400/422 → validation errors
  - 500+ → provider errors
  - Network errors → connectivity issues

### Testing Framework

This project uses the Swift Testing framework (imported as `Testing`), not XCTest:
- Use `@Test` annotation for test functions
- Use `#expect(...)` for assertions (not XCTAssert)
- Use `async throws` for asynchronous test methods
- Import with `@testable import SwiftlyAIKit` to access internal APIs

Tests are organized in `Tests/SwiftlyAIKitTests/`:
- `CoreTests/` - AIGateway, Configuration, APIKeyStrategy, ModelProvider, ProviderType tests
- `ModelTests/` - AIRequest, AIResponse, AIMessage, AIError tests
- `ProviderTests/` - ProviderProtocol and provider implementation tests
- `Mocks/` - Test infrastructure (MockHTTPClient, MockProvider, MockAnthropicAPI)
  - `TestData/` - Sample requests, responses, and errors for testing

## Dependencies

- **Vapor** (4.99.0+) - Web framework integration
- **AsyncHTTPClient** (1.19.0+) - HTTP client for provider API calls

## Development Guidelines

- Keep provider implementations independent and focused
- Use actors for shared mutable state
- Document public APIs with DocC-style comments
- Follow Swift API Design Guidelines
- Maintain backwards compatibility within major versions

### Swift 6 Concurrency Safety

This project uses Swift 6 with strict concurrency checking:
- All shared state must be in actors or use Sendable types
- Use `@unchecked Sendable` sparingly and only when necessary (e.g., AnyCodable)
- Mark structs/enums as Sendable when they contain only Sendable properties
- Avoid mixing actors and global actors (e.g., @MainActor)
- Test mocks must also be actors for thread safety

### Adding New Providers

When implementing a new provider (e.g., OpenAI, Google, Cohere):
1. Create provider-specific models in `Models/[Provider]/` directory (see `Models/Anthropic/AnthropicModels.swift`)
2. Implement `ProviderProtocol` in `Providers/[Provider]Provider.swift`
3. Add provider-specific error mapping to `HTTPClientManager`
4. Create mock responses in `Tests/.../Mocks/Mock[Provider]API.swift`
5. Add comprehensive tests following the 7-suite pattern (see TESTING.md)
6. Update ModelProvider enum with new models
7. Reference: See `OPENAI_IMPLEMENTATION_PLAN.md` for detailed implementation guidance

### Request/Response Flow

Understanding the data flow through the framework:
1. Vapor request comes in with user data
2. `Request+AI` extension extracts client API key from headers (if present)
3. `AIGateway` resolves which API key to use based on `APIKeyStrategy`
4. Gateway routes request to appropriate `ProviderProtocol` implementation
5. Provider transforms `AIRequest` into provider-specific format (e.g., Anthropic.MessageRequest)
6. `HTTPClientManager` sends HTTP request with retry logic
7. Provider transforms provider-specific response back to `AIResponse`
8. Response flows back through gateway to Vapor route handler

### Vapor Integration Patterns

**Initialization in configure.swift:**
```swift
import Vapor
import SwiftlyAIKit

func configure(_ app: Application) async throws {
    // Company key strategy - simplest approach
    let config = Configuration.withCompanyKey("sk-ant-...")
    app.ai.initialize(with: config)

    // OR client key strategy - for multi-tenant apps
    let config = Configuration.withClientKeys()
    app.ai.initialize(with: config)

    // OR hybrid strategy - best of both worlds
    let config = Configuration.withHybridKeys(defaultKey: "sk-ant-...")
    app.ai.initialize(with: config)
}
```

**Using in route handlers:**
```swift
// Method 1: Via app.ai (direct gateway access)
app.get("ai", "chat") { req async throws -> AIResponse in
    let request = AIRequest(model: "claude-sonnet-4-5", prompt: "Hello!")
    return try await req.application.ai.sendMessage(request)
}

// Method 2: Via req.ai (with automatic client key extraction)
app.post("ai", "chat") { req async throws -> AIResponse in
    let input = try req.content.decode(ChatInput.self)
    let request = AIRequest(model: input.model, prompt: input.prompt)
    // Automatically extracts API key from X-API-Key header if present
    return try await req.ai.sendMessage(request)
}

// Method 3: Streaming responses
app.post("ai", "stream") { req async throws -> Response in
    let request = AIRequest(model: "claude-sonnet-4-5", prompt: "Tell me a story")
    return try await req.ai.streamMessage(request)
}
```

**Client API Key Headers:**
- Send client API keys via `X-API-Key` header
- `Request+AI` automatically extracts and uses when strategy allows
- Works with `clientKey`, `hybrid`, and `perProvider` strategies

## Current Implementation Status

### Fully Implemented Providers

**Anthropic (Claude)**
- ✅ Complete Messages API (create, stream)
- ✅ Complete Batch API (create, retrieve, cancel, list, results)
- ✅ Token counting support
- ✅ Advanced features: prompt caching, extended thinking, tool use, vision, PDF processing
- ✅ Server-Sent Events (SSE) streaming
- Implementation: `Sources/SwiftlyAIKit/Providers/AnthropicProvider.swift` (~620 lines)
- Models: `Sources/SwiftlyAIKit/Models/Anthropic/AnthropicModels.swift` (~700 lines)

**OpenAI (GPT)**
- ✅ Chat Completions API (create, stream)
- ✅ Server-Sent Events (SSE) streaming with delta accumulation
- ✅ Vision support (image URLs and base64 data URLs)
- ✅ System prompt handling (prepended to messages array)
- ✅ Support for GPT-4o, GPT-4o Mini, GPT-4 Turbo, GPT-4, GPT-3.5 Turbo
- ✅ Context windows: 128K tokens (GPT-4o/Mini/Turbo), 16K (GPT-3.5), 8K (GPT-4)
- ✅ Bearer token authentication with organization ID support
- ⏸️ Batch API (models defined, implementation deferred)
- ⏸️ Tool/function calling (models defined, mapping deferred)
- Implementation: `Sources/SwiftlyAIKit/Providers/OpenAIProvider.swift` (~324 lines)
- Models: `Sources/SwiftlyAIKit/Models/OpenAI/OpenAIModels.swift` (~639 lines)

**Google Gemini**
- ✅ GenerateContent API (create, stream)
- ✅ Server-Sent Events (SSE) streaming with text accumulation
- ✅ Token counting support via countTokens endpoint
- ✅ Multimodal support (text, images via base64, documents via base64/fileUri)
- ✅ Safety settings configuration (4 harm categories with thresholds)
- ✅ Function calling with JSON Schema tool declarations
- ✅ Structured output via responseMimeType and responseSchema
- ✅ Generation config (temperature, topP, topK, maxOutputTokens, stopSequences)
- ✅ Support for Gemini 2.5 Pro, 2.5 Flash, 2.0 Flash Exp, 1.5 Pro, 1.5 Flash
- ✅ Context windows: 2M tokens (Pro models), 1M tokens (Flash models)
- ✅ Output limits: 65K tokens (2.5 Pro), 8K tokens (other models)
- ✅ API key authentication via query parameter
- ⏸️ Batch API (not yet available in Gemini API)
- ⏸️ Image URLs (only base64 supported, no external URLs)
- Implementation: `Sources/SwiftlyAIKit/Providers/GeminiProvider.swift` (~335 lines)
- Models: `Sources/SwiftlyAIKit/Models/Gemini/GeminiModels.swift` (~451 lines)

**Perplexity AI**
- ✅ Chat Completions API with real-time web search
- ✅ SSE streaming support with text accumulation
- ✅ Citation support for web search results
- ✅ Domain filtering (search_domain_filter)
- ✅ Recency filtering (day, week, month, year)
- ✅ JSON Schema structured outputs via response_format
- ✅ Support for Sonar, Sonar Pro, Sonar Reasoning models
- ✅ Context windows: 127K tokens (Sonar/Reasoning), 200K tokens (Sonar Pro)
- ✅ Output limits: 4K tokens for all models
- ✅ Bearer token authentication
- ✅ Type-safe PerplexityOptions helper for provider-specific features
- Implementation: `Sources/SwiftlyAIKit/Providers/PerplexityProvider.swift` (~235 lines)
- Models: `Sources/SwiftlyAIKit/Models/Perplexity/PerplexityModels.swift` (~316 lines)

**Mistral AI**
- ✅ Chat Completions API (create, stream)
- ✅ Server-Sent Events (SSE) streaming with delta accumulation
- ✅ Vision support (image URLs and base64 data URLs)
- ✅ Tool/function calling infrastructure (OpenAI-compatible)
- ✅ System prompt handling (prepended to messages array)
- ✅ Support for 11 models: Large 2.1, Medium 3, Small 3.1, Codestral, Magistral Small/Medium, Ministral 3B/8B
- ✅ Context windows: 128K tokens (most models), 32K tokens (Codestral)
- ✅ Output limits: 8K tokens (most models), 32K tokens (Magistral models)
- ✅ Bearer token authentication (OpenAI-compatible)
- ✅ Unique features: safe_prompt, random_seed, reasoning mode
- ⏸️ Batch API (models defined, implementation deferred)
- Implementation: `Sources/SwiftlyAIKit/Providers/MistralProvider.swift` (~353 lines)
- Models: `Sources/SwiftlyAIKit/Models/Mistral/MistralModels.swift` (~641 lines)

**Cohere AI**
- ✅ Chat API v2 (create, stream)
- ✅ Server-Sent Events (SSE) streaming with typed events (message-start, content-delta, message-end)
- ✅ Token counting via dedicated tokenize endpoint
- ✅ RAG (Retrieval Augmented Generation) with document support and citations
- ✅ Tool/function calling infrastructure (CohereTool, CohereToolCall)
- ✅ Structured JSON outputs with optional JSON Schema validation
- ✅ Safety modes (NONE, CONTEXTUAL, STRICT) for content filtering
- ✅ Vision support for Command A Vision model (base64 and URL images)
- ✅ System prompt handling via system role in messages array
- ✅ Support for 11 models: Command A (4 variants), Command R (5 variants), Command legacy (2 models)
- ✅ Context windows: 256K tokens (A/R families), 16K tokens (A Translate), 4K tokens (legacy)
- ✅ Output limits: 8K tokens for all models
- ✅ Bearer token authentication
- ✅ Unique features: RAG with citations, safety_mode, response_format with JSON Schema
- Implementation: `Sources/SwiftlyAIKit/Providers/CohereProvider.swift` (~465 lines)
- Models: `Sources/SwiftlyAIKit/Models/Cohere/CohereModels.swift` (~454 lines)

## Key Implementation Notes

### AnyCodable Helper

The framework includes an `AnyCodable` type for handling arbitrary JSON in provider-specific responses:
- Used for `AIMessage.metadata` and `AIResponse.providerData`
- Supports basic JSON types: String, Int, Bool, Double, Dictionary, Array
- Conforms to `@unchecked Sendable` for Swift 6 compatibility
- Located in `Models/AIMessage.swift`

### HTTPClientManager Retry Logic

`HTTPClientManager` implements exponential backoff with configurable retry:
- Default: 3 retries with exponential backoff
- Only retries on network errors and 5xx server errors
- Does NOT retry on 4xx client errors (authentication, validation)
- Timeout: 60 seconds default (configurable)
- Actor-based for thread safety

### Streaming with Server-Sent Events (SSE)

The framework supports SSE streaming for real-time responses:
- `streamMessage()` returns `AsyncThrowingStream<AIResponse, Error>`
- `streamPost()` in HTTPClientManager handles SSE parsing
- Each SSE event is transformed into an AIResponse chunk
- Stream ends with `[DONE]` message
- Used by AnthropicProvider for real-time Claude responses

### Batch Processing Patterns

Batch operations use a consistent pattern across providers:
- `createBatch()` - Submit array of requests, returns batch ID
- `retrieveBatch()` - Get batch status with request counts
- `listBatches()` - List all batches with optional limit
- `getBatchResults()` - Stream results as AsyncThrowingStream of BatchResult
- Results are JSONL format (one JSON object per line)
- See `ProviderProtocol` for default implementations

## Git Workflow

**IMPORTANT: Always make small, focused commits**

When working on this repository, follow these commit practices:

- **Make small, atomic commits**: Each commit should represent a single logical change
- **Commit frequently**: Don't wait until everything is complete to commit
- **One feature per commit**: If adding multiple features, break them into separate commits
- **Test before committing**: Ensure `swift build` passes before making a commit
- **Write clear commit messages**: Use descriptive messages that explain what and why
- **Example workflow**:
  ```bash
  # Add a single feature
  git add Sources/SwiftlyAIKit/Models/NewModel.swift
  git commit -m "Add NewModel struct for X functionality"

  # Add tests for that feature
  git add Tests/SwiftlyAIKitTests/NewModelTests.swift
  git commit -m "Add tests for NewModel"

  # Update documentation
  git add README.md
  git commit -m "Update README with NewModel usage examples"
  ```

**Bad practice**: Committing 19 files with 3,667 lines changed in one commit
**Good practice**: Breaking that work into 10-15 smaller commits, each focused on one component

### Maintaining the Changelog

**IMPORTANT: Always update CHANGELOG.md for significant changes**

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format:

- **Update CHANGELOG.md** when adding features, making changes, or fixing bugs
- Add entries to the `[Unreleased]` section during development
- When releasing a version, create a new dated section (e.g., `[0.2.0] - 2025-11-23`)
- Categorize changes under:
  - **Added** - New features or functionality
  - **Changed** - Modifications to existing features
  - **Deprecated** - Features that will be removed in future versions
  - **Removed** - Features that have been removed
  - **Fixed** - Bug fixes
  - **Security** - Security vulnerability fixes

**Example workflow**:
```bash
# After implementing a feature
git add Sources/SwiftlyAIKit/Core/NewFeature.swift
git commit -m "Add NewFeature for X functionality"

# Update changelog for that feature
git add CHANGELOG.md
git commit -m "Update CHANGELOG.md with NewFeature entry"
```

**When to update CHANGELOG.md**:
- ✅ Adding new API endpoints or providers
- ✅ Changing public APIs or behavior
- ✅ Fixing bugs that affect users
- ✅ Adding new configuration options
- ❌ Internal refactoring without user-facing changes
- ❌ Fixing typos in comments (unless in public documentation)

### Creating Version Tags

**IMPORTANT: Create Git tags when releasing versions**

Git tags are required for CHANGELOG.md links to work properly. Tags mark specific commits as releases.

**When to create tags**:
- After completing a version's changes and updating CHANGELOG.md
- When you're ready to release a new version to users
- Tags should match the version numbers in CHANGELOG.md (e.g., `v0.2.0`)

**How to create and push tags**:
```bash
# Create an annotated tag for the current commit
git tag -a v0.2.0 -m "Release v0.2.0: Complete Anthropic Claude API integration"

# Or tag a specific commit
git tag -a v0.1.0 96b0b91 -m "Release v0.1.0: Initial project structure"

# Push tags to GitHub
git push origin --tags

# Verify tags were created
git tag -l
```

**Tag naming convention**:
- Use semantic versioning: `v<major>.<minor>.<patch>`
- Examples: `v0.1.0`, `v0.2.0`, `v1.0.0`
- Always prefix with `v`

**Why tags matter**:
- CHANGELOG.md links rely on tags to show version comparisons
- GitHub releases are created from tags
- Users can checkout specific versions using tags
- Tags provide permanent markers in Git history

**Example: Releasing v0.2.0**:
```bash
# 1. Update CHANGELOG.md with version and date
git add CHANGELOG.md
git commit -m "Update CHANGELOG.md for version 0.2.0"

# 2. Create the tag
git tag -a v0.2.0 -m "Release v0.2.0: Complete Anthropic Claude API integration"

# 3. Push everything
git push origin main
git push origin --tags
```

## Quick Reference

### Most Important Files

**Core Framework (5 files, ~1,250 lines):**
- `Sources/SwiftlyAIKit/Core/AIGateway.swift` (318 lines) - Main coordinator actor
- `Sources/SwiftlyAIKit/Core/Configuration.swift` (178 lines) - Framework configuration
- `Sources/SwiftlyAIKit/Core/APIKeyStrategy.swift` (110 lines) - Key management strategies
- `Sources/SwiftlyAIKit/Utilities/HTTPClientManager.swift` (255 lines) - HTTP client with retry
- `Sources/SwiftlyAIKit/Providers/ProviderProtocol.swift` (189 lines) - Provider interface

**Anthropic Implementation (2 files, ~1,300 lines):**
- `Sources/SwiftlyAIKit/Models/Anthropic/AnthropicModels.swift` (679 lines) - All Anthropic types
- `Sources/SwiftlyAIKit/Providers/AnthropicProvider.swift` (623 lines) - Complete implementation

**OpenAI Implementation (2 files, ~963 lines):**
- `Sources/SwiftlyAIKit/Models/OpenAI/OpenAIModels.swift` (639 lines) - All OpenAI types
- `Sources/SwiftlyAIKit/Providers/OpenAIProvider.swift` (324 lines) - Core implementation

**Gemini Implementation (2 files, ~787 lines):**
- `Sources/SwiftlyAIKit/Models/Gemini/GeminiModels.swift` (451 lines) - All Gemini types
- `Sources/SwiftlyAIKit/Providers/GeminiProvider.swift` (335 lines) - Core implementation

**Perplexity Implementation (3 files, ~698 lines):**
- `Sources/SwiftlyAIKit/Models/Perplexity/PerplexityModels.swift` (316 lines) - All Perplexity types
- `Sources/SwiftlyAIKit/Models/Perplexity/PerplexityOptions.swift` (147 lines) - Type-safe options helper
- `Sources/SwiftlyAIKit/Providers/PerplexityProvider.swift` (235 lines) - Core implementation

**Mistral Implementation (2 files, ~994 lines):**
- `Sources/SwiftlyAIKit/Models/Mistral/MistralModels.swift` (641 lines) - All Mistral types
- `Sources/SwiftlyAIKit/Providers/MistralProvider.swift` (353 lines) - Core implementation

**Cohere Implementation (2 files, ~919 lines):**
- `Sources/SwiftlyAIKit/Models/Cohere/CohereModels.swift` (454 lines) - All Cohere types
- `Sources/SwiftlyAIKit/Providers/CohereProvider.swift` (465 lines) - Core implementation

**Vapor Integration (2 files, ~413 lines):**
- `Sources/SwiftlyAIKit/Extensions/Application+AI.swift` (173 lines) - App lifecycle
- `Sources/SwiftlyAIKit/Extensions/Request+AI.swift` (240 lines) - Request helpers

**Testing Infrastructure (3 files, ~1,000 lines):**
- `Tests/SwiftlyAIKitTests/Mocks/MockHTTPClient.swift` (278 lines)
- `Tests/SwiftlyAIKitTests/Mocks/MockProvider.swift` (377 lines)
- `Tests/SwiftlyAIKitTests/Mocks/MockAnthropicAPI.swift` (374 lines)

**Documentation:**
- `CLAUDE.md` - This file (you are here)
- `TESTING.md` - Comprehensive testing guide with test details
- `CHANGELOG.md` - Version history following Keep a Changelog format
- `Documentation/OPENAI_IMPLEMENTATION_PLAN.md` - OpenAI provider implementation guide
- `Documentation/GEMINI_IMPLEMENTATION_PLAN.md` - Gemini provider implementation guide
- `Documentation/PERPLEXITY_IMPLEMENTATION_PLAN.md` - Perplexity provider implementation guide
- `Documentation/MISTRAL_IMPLEMENTATION_PLAN.md` - Mistral provider implementation guide
- `Documentation/COHERE_IMPLEMENTATION_PLAN.md` - Cohere provider implementation guide
- `README.md` - Public-facing documentation
