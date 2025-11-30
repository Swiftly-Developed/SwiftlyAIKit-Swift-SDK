# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftlyAIKit is an AI Model Gateway framework providing unified access to multiple AI providers (Anthropic, OpenAI, Google Gemini, Perplexity, Mistral, Cohere, DeepSeek) through a single Swift API. Works on iOS, macOS, watchOS, tvOS, visionOS, and Linux servers. The project uses Swift 6.0+ and requires macOS 13.0+.

**Note:** This package has zero Vapor dependencies. For Vapor integration, see SwiftlyAIServerKit.

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

## Documentation Structure

SwiftlyAIKit uses DocC for comprehensive documentation with provider-first organization.

**Building Documentation:**
DocC documentation is built automatically when you build the package in Xcode or use Xcode's documentation tools. The documentation is organized using extension files that group types by provider and feature.

**Documentation Organization:**
- **Extension files** in `Documentation.docc/APIReference/` group types by provider and core feature
- **Provider pages**: Each of the 9 providers has a dedicated page grouping all related types together
  - `APIReference/Providers/AnthropicProvider.md` - All 22 Anthropic types
  - `APIReference/Providers/OpenAIProvider.md` - All 18 OpenAI types
  - `APIReference/Providers/GeminiProvider.md` - All Gemini types
  - Plus 6 more provider pages (Perplexity, Mistral, Cohere, DeepSeek, Grok, Apple Intelligence)
- **Core API pages**: 6 extension files organize framework-level types
  - `APIReference/Core/AIGateway.md` - Gateway actor and methods
  - `APIReference/Core/Configuration.md` - Configuration and API key strategies
  - `APIReference/Core/AIRequest.md` - Request types
  - `APIReference/Core/AIResponse.md` - Response types
  - `APIReference/Core/ImageGeneration.md` - Image generation types
  - `APIReference/Core/ModelProvider.md` - Model enums
- **Guide files**: 41 comprehensive guides covering concepts, tutorials, and platform integration
- **Root page**: `Documentation.docc/SwiftlyAIKit.md` presents provider-first navigation

**Navigation Structure:**
Documentation is organized provider-first rather than by type kind:
- Getting Started
- Core Framework (AIGateway, Configuration, etc.)
- AI Providers (Anthropic, OpenAI, Gemini, etc.)
  - Each provider shows API Reference + Complete Guide
  - Provider capabilities listed (context window, features, model count)
- Core Concepts, Advanced Features, Platform Integration, etc.

This structure makes it easy to find all Anthropic-specific or OpenAI-specific types together, rather than scattered across Protocols, Structures, and Enumerations.

## Architecture

### Core Components

The framework is organized into five main directories under `Sources/SwiftlyAIKit/`:

1. **Core/** - Framework core logic
   - `AIGateway` - Main actor coordinating provider calls
   - `APIKeyStrategy` - Key management strategies (company vs client keys)
   - `Configuration` - Framework configuration options
   - `ProviderProtocol` - Interface all providers must implement

2. **Models/** - Shared/common data structures
   - `AIRequest`, `AIResponse`, `AIMessage` - Request/response types
   - `AIError` - Framework-specific errors
   - `ModelProvider`, `ProviderType` - Provider identification

3. **Providers/** - AI provider implementations (grouped by provider)
   - `Anthropic/` - AnthropicProvider + AnthropicModels
   - `OpenAI/` - OpenAIProvider + OpenAIModels
   - `Gemini/` - GeminiProvider + GeminiModels + GoogleProvider (alias)
   - `Perplexity/` - PerplexityProvider + PerplexityModels + PerplexityOptions
   - `Mistral/` - MistralProvider + MistralModels
   - `Cohere/` - CohereProvider + CohereModels
   - `DeepSeek/` - DeepSeekProvider + DeepSeekModels
   - Each provider subdirectory contains all provider-specific code

4. **Utilities/** - Helper functionality
   - `HTTPClientManager` - AsyncHTTPClient wrapper with retry logic

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
- **Configuration builder pattern**: Framework uses builder pattern for type-safe configuration
  - `Configuration.withCompanyKey()`, `.withClientKeys()`, `.withHybridKeys()`
  - Provides clear, chainable API for setup
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
- `ProviderTests/` - ProviderProtocol and provider implementation tests (grouped by provider)
  - `ProviderProtocolTests.swift` - Protocol conformance tests
  - `Anthropic/` - MockAnthropicAPI
  - `OpenAI/` - (no tests yet)
  - `Gemini/` - GeminiProviderTests + MockGeminiAPI
  - `Perplexity/` - PerplexityProviderTests + PerplexityOptionsTests + MockPerplexityAPI
  - `Mistral/` - MistralProviderTests + MockMistralAPI
  - `Cohere/` - CohereProviderTests + MockCohereAPI
- `Mocks/` - Shared test infrastructure (MockHTTPClient, MockProvider)
  - `TestData/` - Sample requests, responses, and errors for testing

## Dependencies

- **AsyncHTTPClient** (1.19.0+) - HTTP client for provider API calls

**Note:** SwiftlyAIKit has no Vapor dependency. Vapor integration is provided by SwiftlyAIServerKit.

## Development Guidelines

- Keep provider implementations independent and focused
- Use actors for shared mutable state
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

Understanding the data flow through SwiftlyAIKit:
1. App creates `AIRequest` with model, messages, and options
2. `AIGateway` resolves which API key to use based on `APIKeyStrategy`
3. Gateway routes request to appropriate `ProviderProtocol` implementation
4. Provider transforms `AIRequest` into provider-specific format (e.g., Anthropic.MessageRequest)
5. `HTTPClientManager` sends HTTP request with retry logic
6. Provider transforms provider-specific response back to `AIResponse`
7. Response returned to caller

### Direct Usage (Device Apps)

```swift
import SwiftlyAIKit

// Create gateway with company API key
let config = Configuration.withCompanyKey("sk-ant-...")
let gateway = AIGateway(configuration: config)

// Send a message
let request = AIRequest(model: .claude(.sonnet4_5), prompt: "Hello!")
let response = try await gateway.sendMessage(request)

// Streaming
let stream = try await gateway.streamMessage(request)
for try await chunk in stream {
    print(chunk.content)
}
```

**Note:** For Vapor server integration patterns, see SwiftlyAIServerKit/CLAUDE.md.

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
- Implementation: `Sources/SwiftlyAIKit/Providers/Cohere/CohereProvider.swift` (~465 lines)
- Models: `Sources/SwiftlyAIKit/Providers/Cohere/CohereModels.swift` (~454 lines)

**DeepSeek**
- ✅ Chat Completions API (create, stream)
- ✅ Server-Sent Events (SSE) streaming
- ✅ Tool/function calling support
- ✅ Prompt caching for cost reduction
- ✅ Reasoning mode (DeepSeek-R1)
- ✅ Support for DeepSeek Chat and DeepSeek Coder models
- ✅ Bearer token authentication
- Implementation: `Sources/SwiftlyAIKit/Providers/DeepSeek/DeepSeekProvider.swift`
- Models: `Sources/SwiftlyAIKit/Providers/DeepSeek/DeepSeekModels.swift`

**xAI Grok**
- ✅ Chat Completions API (create, stream) - OpenAI-compatible
- ✅ Server-Sent Events (SSE) streaming with delta accumulation
- ✅ Reasoning tokens tracking (`AIUsage.reasoningTokens`, `completion_tokens_details.reasoning_tokens`)
- ✅ Automatic prompt caching with cached_tokens tracking
- ✅ Tool/function calling infrastructure (OpenAI-compatible format)
- ✅ Vision support for Grok 2 Vision model (image URLs and base64 data URLs)
- ✅ Token counting via dedicated `/tokenize-text` endpoint
- ✅ Live web search via `search_parameters` option
- ✅ Deferred completions for long-running requests
- ✅ Image generation with Grok 2 Image model (`generateImage` method)
- ✅ Support for 7 models: Grok 4, Grok 4 Latest, Grok 3, Grok 3 Mini, Grok 2 Vision, Grok Code Fast, Grok 2 Image
- ✅ Context windows: 1M tokens (Grok 3/3 Mini), 128K tokens (Grok 4/Vision/Code)
- ✅ Output limits: 8K tokens for all chat models
- ✅ Bearer token authentication
- Implementation: `Sources/SwiftlyAIKit/Providers/Grok/GrokProvider.swift` (~670 lines)
- Models: `Sources/SwiftlyAIKit/Providers/Grok/GrokModels.swift` (~900 lines)

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

### Creating GitHub Releases

**IMPORTANT: Create GitHub Releases after pushing tags**

GitHub Releases provide a user-friendly way to distribute versions with release notes, binary assets, and automatic archive downloads.

**Release Process**:

1. **Push your tag first**:
   ```bash
   git tag -a v0.11.0 -m "Release v0.11.0"
   git push origin v0.11.0
   ```

2. **Create the GitHub Release**:
   - Go to https://github.com/Swiftly-Developed/SwiftlyAIKit/releases
   - Click "Draft a new release"
   - Select your tag (e.g., v0.11.0)
   - Click "Generate release notes" button for automatic categorization
   - Review the generated notes and edit if needed
   - Mark as "pre-release" if version is 0.y.z
   - Click "Publish release"

3. **Automated Release Notes**:
   This repository has `.github/release.yml` configured to automatically categorize pull requests:
   - 💥 Breaking Changes (labels: breaking-change, breaking, major)
   - 🚀 New Features (labels: feature, enhancement, new-feature)
   - 🐛 Bug Fixes (labels: bug, bugfix, fix)
   - 🔒 Security (labels: security, vulnerability)
   - ⚡ Performance (labels: performance, optimization)
   - 📝 Documentation (labels: documentation, docs)
   - 🧪 Testing (labels: test, testing)
   - 🔧 Maintenance (labels: maintenance, chore, refactor, dependencies)

**Link to Latest Release**:
Users can always access the latest version at:
```
https://github.com/Swiftly-Developed/SwiftlyAIKit/releases/latest
```

**Semantic Versioning Rules**:
- **MAJOR (X.0.0)**: Breaking API changes (e.g., v0.10.0 → v1.0.0)
- **MINOR (0.X.0)**: New features, backward compatible (e.g., v0.10.0 → v0.11.0)
- **PATCH (0.0.X)**: Bug fixes, backward compatible (e.g., v0.10.0 → v0.10.1)
- **Note**: Version 0.y.z is for initial development. Version 1.0.0 defines first stable public API.

**Version Alignment**:
SwiftlyAIKit releases must be coordinated with other SwiftlyAI packages (SwiftlyAIServerKit, SwiftlyAIClient, SwiftlyAIVapor, SwiftlyAIHummingbird) to maintain version synchronization across the ecosystem. See the workspace CLAUDE.md for multi-package release procedures.

## Quick Reference

### Most Important Files

**Core Framework (5 files, ~1,250 lines):**
- `Sources/SwiftlyAIKit/Core/AIGateway.swift` (318 lines) - Main coordinator actor
- `Sources/SwiftlyAIKit/Core/Configuration.swift` (178 lines) - Framework configuration
- `Sources/SwiftlyAIKit/Core/APIKeyStrategy.swift` (110 lines) - Key management strategies
- `Sources/SwiftlyAIKit/Core/ProviderProtocol.swift` (189 lines) - Provider interface
- `Sources/SwiftlyAIKit/Utilities/HTTPClientManager.swift` (255 lines) - HTTP client with retry

**Anthropic Implementation (2 files, ~1,300 lines):**
- `Sources/SwiftlyAIKit/Providers/Anthropic/AnthropicModels.swift` (679 lines) - All Anthropic types
- `Sources/SwiftlyAIKit/Providers/Anthropic/AnthropicProvider.swift` (623 lines) - Complete implementation

**OpenAI Implementation (2 files, ~963 lines):**
- `Sources/SwiftlyAIKit/Providers/OpenAI/OpenAIModels.swift` (639 lines) - All OpenAI types
- `Sources/SwiftlyAIKit/Providers/OpenAI/OpenAIProvider.swift` (324 lines) - Core implementation

**Gemini Implementation (3 files, ~805 lines):**
- `Sources/SwiftlyAIKit/Providers/Gemini/GeminiModels.swift` (451 lines) - All Gemini types
- `Sources/SwiftlyAIKit/Providers/Gemini/GeminiProvider.swift` (335 lines) - Core implementation
- `Sources/SwiftlyAIKit/Providers/Gemini/GoogleProvider.swift` (18 lines) - Alias for GeminiProvider

**Perplexity Implementation (3 files, ~698 lines):**
- `Sources/SwiftlyAIKit/Providers/Perplexity/PerplexityModels.swift` (316 lines) - All Perplexity types
- `Sources/SwiftlyAIKit/Providers/Perplexity/PerplexityOptions.swift` (147 lines) - Type-safe options helper
- `Sources/SwiftlyAIKit/Providers/Perplexity/PerplexityProvider.swift` (235 lines) - Core implementation

**Mistral Implementation (2 files, ~994 lines):**
- `Sources/SwiftlyAIKit/Providers/Mistral/MistralModels.swift` (641 lines) - All Mistral types
- `Sources/SwiftlyAIKit/Providers/Mistral/MistralProvider.swift` (353 lines) - Core implementation

**Cohere Implementation (2 files, ~919 lines):**
- `Sources/SwiftlyAIKit/Providers/Cohere/CohereModels.swift` (454 lines) - All Cohere types
- `Sources/SwiftlyAIKit/Providers/Cohere/CohereProvider.swift` (465 lines) - Core implementation

**DeepSeek Implementation (2 files):**
- `Sources/SwiftlyAIKit/Providers/DeepSeek/DeepSeekModels.swift` - All DeepSeek types
- `Sources/SwiftlyAIKit/Providers/DeepSeek/DeepSeekProvider.swift` - Core implementation

**Grok Implementation (2 files, ~1,570 lines):**
- `Sources/SwiftlyAIKit/Providers/Grok/GrokModels.swift` (~900 lines) - All Grok types
- `Sources/SwiftlyAIKit/Providers/Grok/GrokProvider.swift` (~670 lines) - Core implementation

**Note:** Vapor integration has been moved to SwiftlyAIServerKit package.

**Testing Infrastructure (grouped by provider):**
- `Tests/SwiftlyAIKitTests/Mocks/MockHTTPClient.swift` (278 lines)
- `Tests/SwiftlyAIKitTests/Mocks/MockProvider.swift` (377 lines)
- `Tests/SwiftlyAIKitTests/ProviderTests/Anthropic/MockAnthropicAPI.swift` (374 lines)
- `Tests/SwiftlyAIKitTests/ProviderTests/Gemini/MockGeminiAPI.swift` + GeminiProviderTests
- `Tests/SwiftlyAIKitTests/ProviderTests/Perplexity/MockPerplexityAPI.swift` + PerplexityProviderTests
- `Tests/SwiftlyAIKitTests/ProviderTests/Mistral/MockMistralAPI.swift` + MistralProviderTests
- `Tests/SwiftlyAIKitTests/ProviderTests/Cohere/MockCohereAPI.swift` + CohereProviderTests
- `Tests/SwiftlyAIKitTests/ProviderTests/Grok/MockGrokAPI.swift` + GrokProviderTests

**Documentation:**
- `CLAUDE.md` - This file (you are here)
- `CHANGELOG.md` - Version history following Keep a Changelog format
- `README.md` - Public-facing documentation
- `Documentation/` - Provider implementation plans (OpenAI, Gemini, Perplexity, Mistral, Cohere)
