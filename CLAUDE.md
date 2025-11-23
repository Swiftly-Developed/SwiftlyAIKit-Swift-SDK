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
