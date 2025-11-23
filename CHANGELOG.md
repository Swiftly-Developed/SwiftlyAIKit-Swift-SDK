# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Complete OpenAI GPT API integration** (~963 lines total)
  - OpenAIModels.swift with full type definitions (639 lines) for all OpenAI API features
  - OpenAIProvider implementation (324 lines) with sendMessage and streaming support
  - Support for GPT-4o, GPT-4o Mini, GPT-4 Turbo, GPT-4, and GPT-3.5 Turbo models
  - Complete request/response mapping between AIRequest and OpenAI's chat completion format
  - SSE streaming support with delta accumulation for real-time responses
  - Vision support for GPT-4o models (image URLs and base64 data URLs)
  - System prompt handling (prepended to messages array per OpenAI conventions)
  - Content block mapping for text and images
  - Finish reason mapping (stop, length, content_filter, tool_calls)
  - Bearer token authentication with optional organization ID support
  - Context windows: 128K tokens for GPT-4o/Mini, 128K for GPT-4 Turbo
  - Output limits: 16K tokens for GPT-4o/Mini, 4K for others
- Comprehensive test suite with 277 tests across 7 test suites (100% pass rate)
- Mock infrastructure for testing (MockHTTPClient, MockProvider, MockAnthropicAPI)
- Test data samples (SampleRequests, SampleResponses, SampleErrors)
- AIErrorTests (42 tests) - All error types, retryability, status codes, error categories
- APIKeyStrategyTests (33 tests) - All 4 key strategies with edge cases and real-world scenarios
- ConfigurationTests (39 tests) - All 6 factory methods, beta features, custom URLs
- ModelProviderTests (55 tests) - All 25 models with feature support and token limits
- ProviderTypeTests (36 tests) - All 5 providers with conformances and base URLs
- AIModelsTests (38 tests) - All message/request/response types with integration tests
- ProviderProtocolTests (32 tests) - Batch operations, protocol conformance, streaming
- TESTING.md comprehensive testing documentation
- Guidelines for test contributions and CI/CD integration

### Changed
- MockProvider.CapturedRequest now conforms to Sendable for Swift 6 concurrency safety
- Updated CLAUDE.md with git workflow best practices (small commits, changelog maintenance, version tagging)

## [0.2.0] - 2025-11-23

### Added
- Complete Anthropic Claude API integration with full Messages and Batch API support
- APIKeyStrategy enum with 4 key management strategies (companyKey, clientKey, hybrid, perProvider)
- Configuration struct with convenience factory methods (withCompanyKey, withClientKeys, withHybridKeys, development, production)
- Thread-safe AIGateway actor for provider coordination and API key resolution
- Comprehensive AIError with 20+ specialized error types (authentication, network, validation, rate limiting, etc.)
- AnthropicModels.swift with complete type definitions (~700 lines) for all Anthropic features
- ModelProvider enum with all 27 Claude models (Opus 4.1, Sonnet 4.5, Haiku 4.5, legacy models)
- HTTPClientManager with automatic retry logic, exponential backoff, and timeout management
- ProviderProtocol with default implementations for batch operations
- Complete AnthropicProvider implementation (~620 lines) with 3 flexible initializer variants
- Full support for advanced Anthropic features: prompt caching, extended thinking, tool use, vision, PDF processing
- Complete Batch API support (create, retrieve, cancel, list, results streaming with JSONL)
- Vapor Request+AI extension with convenience methods and automatic client key extraction from headers
- Vapor Application+AI extension with fluent initialization API
- SSE (Server-Sent Events) streaming support for real-time AI responses
- Git workflow guidelines in CLAUDE.md emphasizing small, atomic commits

### Changed
- Enhanced all model structures (AIRequest, AIResponse, AIMessage) to support multi-content and Anthropic features
- Updated ProviderProtocol with batch operation methods and default implementations
- Improved HTTPClientManager with streaming support and better error mapping

### Fixed
- Sendable conformance issues with AnyCodable using @unchecked Sendable
- Actor isolation issues in HTTPClientManager (streamPost, mapHTTPError)
- Actor isolation issues in AIGateway initialization
- Configuration parameter ordering in static factory methods
- Request+AI streaming methods with proper async Task wrapping

## [0.1.0] - 2025-11-22

### Added
- Initial project structure for SwiftlyAIKit AI Gateway framework
- Package configuration with Vapor 4.99.0+ and AsyncHTTPClient 1.19.0+ dependencies
- Core directory structure (Models, Providers, Core, Extensions, Utilities)
- Placeholder implementations for all major components:
  - Model structures (AIRequest, AIResponse, AIMessage, AIError)
  - Provider protocol and implementations (OpenAI, Anthropic, Cohere, Google, Mistral)
  - Core gateway and configuration components
  - Vapor integration extensions
  - HTTP client and JSON utilities
- MIT License
- Comprehensive README with installation and usage guidelines
- Basic test structure using Swift Testing framework

[Unreleased]: https://github.com/SwiftlyWorkspace/SwiftlyAIKit/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/SwiftlyWorkspace/SwiftlyAIKit/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/SwiftlyWorkspace/SwiftlyAIKit/releases/tag/v0.1.0
