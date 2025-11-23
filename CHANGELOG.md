# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Restructured codebase to provider-centric organization**
  - Moved all provider-specific models from `Models/[Provider]/` to `Providers/[Provider]/`
  - Moved `ProviderProtocol.swift` from `Providers/` to `Core/` directory
  - Eliminated 6 single-file directories in Models/ (Anthropic, OpenAI, Gemini, Perplexity, Mistral, Cohere)
  - Each provider directory now contains 2-3 files (provider + models + options where applicable)
  - Test structure reorganized to mirror source structure with provider subdirectories
  - Mock API files moved from `Mocks/` to `ProviderTests/[Provider]/` directories
  - Updated CLAUDE.md documentation with new folder structure
  - **Benefits**: Improved code cohesion, easier navigation, better scalability, clearer module boundaries

## [0.6.0] - 2025-11-23

### Added
- **Complete Cohere AI integration** (~2,000 lines total)
  - CohereModels.swift with full type definitions (454 lines) for Cohere v2 API
  - CohereProvider implementation (465 lines) with sendMessage, streamMessage, and countTokens
  - Support for 11 Cohere models: Command A family (4 models), Command R family (5 models), legacy Command (2 models)
  - RAG (Retrieval Augmented Generation) with document support and citations
  - Function/tool calling infrastructure with CohereTool and CohereToolCall types
  - Token counting via dedicated tokenize endpoint
  - Structured JSON outputs with optional JSON Schema validation
  - Safety modes (NONE, CONTEXTUAL, STRICT) for content filtering
  - Vision support for Command A Vision model (base64 and URL images)
  - SSE streaming support with typed events (message-start, content-delta, message-end, citation-start)
  - Complete request/response mapping between AIRequest and Cohere's chat format
  - Bearer token authentication
  - Context windows: 256K tokens (A/R families), 16K tokens (A Translate), 4K tokens (legacy)
  - Output limits: 8K tokens for all models
  - Cohere-specific features: response_format for JSON mode, documents for RAG, safety_mode configuration
- **Comprehensive Cohere test coverage** (48 tests)
  - MockCohereAPI.swift with sample responses for all Cohere endpoints (30+ mock responses)
  - CohereProviderTests (48 tests) covering initialization, request/response mapping, streaming, RAG, tool calling, tokenization, error handling, and model support
  - Updated ModelProviderTests and ProviderTypeTests for Cohere models
  - All tests passing (464+ total tests, 100% pass rate)
- **Cohere implementation documentation**
  - COHERE_IMPLEMENTATION_PLAN.md (624 lines) with comprehensive API specs, streaming event types, model specifications, and usage examples
  - Complete RAG documentation with document structure and citation handling
  - Tool/function calling documentation with type definitions
  - JSON structured output documentation with schema examples
  - Updated CLAUDE.md with Cohere provider information

### Changed
- Updated ModelProvider enum to include 11 Cohere models (total now 60 models: 22 Claude + 8 GPT + 5 Gemini + 3 Perplexity + 11 Mistral + 11 Cohere)
- Updated ProviderType enum (total now 7 providers: Anthropic, OpenAI, Google, Perplexity, Mistral, Cohere, Other)
- CohereProvider.swift replaced placeholder implementation with full functionality
- Updated all test assertions to reflect new model and provider counts

## [0.5.0] - 2025-11-23

### Added
- **Complete Mistral AI integration** (~1,700 lines total)
  - MistralModels.swift with full type definitions (641 lines) for Mistral API
  - MistralProvider implementation (353 lines) with sendMessage and streamMessage
  - Support for 11 Mistral models: Large 2.1, Medium 3, Small 3.1, Codestral, Magistral Small/Medium, Ministral 3B/8B
  - OpenAI-compatible API format for straightforward integration
  - SSE streaming support with delta accumulation for real-time responses
  - Vision support via image URLs and base64 data URLs (Large, Medium, Small models)
  - Tool/function calling infrastructure (OpenAI-compatible format)
  - Complete request/response mapping between AIRequest and Mistral's chat completion format
  - Bearer token authentication (same as OpenAI)
  - Context windows: 128K tokens (most models), 32K tokens (Codestral)
  - Output limits: 8K tokens (most models), 32K tokens (Magistral models)
  - Unique features: safe_prompt for security, random_seed for determinism, reasoning mode for Magistral models
- **Comprehensive Mistral test coverage** (30+ tests)
  - MockMistralAPI.swift with sample responses, streaming events, and error responses
  - MistralProviderTests (30 tests) covering initialization, request/response mapping, streaming, error handling, vision, and tool support
  - Updated ModelProviderTests and ProviderTypeTests for Mistral models
  - All tests passing (416+ total tests, 100% pass rate)
- **Mistral implementation documentation**
  - MISTRAL_IMPLEMENTATION_PLAN.md with comprehensive API specs, usage examples, and technical details
  - Updated CLAUDE.md with Mistral provider information

### Changed
- Updated ModelProvider enum to include 11 Mistral models (total now 49 models: 22 Claude + 8 GPT + 5 Gemini + 3 Perplexity + 11 Mistral)
- Updated ProviderType enum to include .mistral (total now 7 providers: Anthropic, OpenAI, Google, Perplexity, Mistral, Cohere, Other)
- MistralProvider.swift replaced placeholder implementation with full functionality
- Updated all test assertions to reflect new model and provider counts

## [0.4.1] - 2025-11-23

### Added
- **PerplexityOptions type-safe helper** (~147 lines)
  - Type-safe convenience API for Perplexity-specific provider options
  - Support for search domain filtering, recency filtering, citations, and images
  - Support for ResponseFormat with JSON Schema structured outputs
  - `toProviderOptions()` method converts to `[String: AnyCodable]` for AIRequest
  - `webSearch()` convenience initializer for search-focused requests
  - `jsonSchema()` convenience initializer for structured output requests
  - Comprehensive documentation with usage examples
- **Comprehensive test coverage for provider options** (36 new tests)
  - PerplexityOptionsTests (28 tests) covering all helper methods and conversions
  - Integration tests in PerplexityProviderTests (8 tests) for options extraction
  - Tests for `toProviderOptions()` conversion for all option types
  - Tests for `webSearch()` and `jsonSchema()` convenience initializers
  - Tests for integration with AIRequest.providerOptions field
- **Perplexity sample requests** (6 new examples)
  - perplexityWebSearch: Basic web search with recency filter
  - perplexityDomainFilter: Academic research with domain filtering
  - perplexityJsonSchema: Structured output with JSON Schema
  - perplexityFullOptions: All search options demonstration
  - perplexityAcademicResearch: Research-focused query example
  - perplexityBasic: Simple query without special options

### Changed
- Updated PerplexityProvider extraction functions to use AIRequest.providerOptions
- Resolved 5 critical TODOs in PerplexityProvider (providerOptions extraction)
- Updated test counts to reflect new tests (386+ total tests, 100% pass rate)

## [0.4.0] - 2025-11-23

### Added
- **Complete Perplexity AI integration** (~800 lines total)
  - PerplexityModels.swift with full type definitions (316 lines) for all Perplexity API features
  - PerplexityProvider implementation (235 lines) with sendMessage and streamMessage
  - Support for Sonar, Sonar Pro, and Sonar Reasoning models
  - Real-time web search capabilities with citation support
  - Domain filtering for search results (search_domain_filter)
  - Recency filtering for time-based searches (day, week, month, year)
  - JSON Schema structured outputs via response_format
  - SSE streaming support with text accumulation for real-time responses
  - Complete request/response mapping between AIRequest and Perplexity's chat completion format
  - Bearer token authentication
  - Context windows: 127K tokens (Sonar/Reasoning), 200K tokens (Sonar Pro)
  - Output limits: 4K tokens for all models
- **Comprehensive Perplexity test coverage** (27+ tests)
  - MockPerplexityAPI.swift with sample responses for all Perplexity endpoints
  - PerplexityProviderTests (27 tests) covering initialization, request/response mapping, error handling, search features, streaming, and model support
  - Updated ModelProviderTests and ProviderTypeTests for Perplexity models
  - Updated test counts across all test suites (330+ total tests, 100% pass rate)

### Changed
- Updated ModelProvider enum to include 3 Perplexity models (total now 38 models: 22 Claude + 8 GPT + 5 Gemini + 3 Perplexity)
- Updated ProviderType enum to include .perplexity (total now 6 providers)
- Updated all test assertions to reflect new model and provider counts

## [0.3.0] - 2025-11-23

### Added
- **Complete Google Gemini API integration** (~787 lines total)
  - GeminiModels.swift with full type definitions (451 lines) for all Gemini API features
  - GeminiProvider implementation (335 lines) with sendMessage, streamMessage, and countTokens
  - Support for Gemini 2.5 Pro, 2.5 Flash, 2.0 Flash Exp, 1.5 Pro, and 1.5 Flash models
  - Complete request/response mapping between AIRequest and Gemini's generateContent format
  - SSE streaming support with text accumulation for real-time responses
  - Multimodal support: text, images (base64), documents (PDFs via base64 or fileUri)
  - Safety settings configuration with 4 harm categories and thresholds
  - Function calling support with JSON Schema-based tool declarations
  - Structured output support via responseMimeType and responseSchema
  - Generation config: temperature, topP, topK, maxOutputTokens, stopSequences
  - Token counting support via countTokens endpoint
  - Context windows: 2M tokens for Pro models, 1M tokens for Flash models
  - Output limits: 65K tokens for 2.5 Pro, 8K tokens for other models
  - API key authentication via query parameter (x-goog-api-key)
- **Comprehensive Gemini test coverage** (46 tests)
  - MockGeminiAPI.swift with sample responses for all Gemini endpoints
  - GeminiProviderTests (38 tests) covering initialization, request/response mapping, error handling, safety settings, function calling, token counting, streaming, and model support
  - ModelProviderTests updates (8 tests) for Gemini model properties
  - Updated TESTING.md documentation (323 total tests, 100% pass rate)

### Changed
- Updated ModelProvider enum to include 5 Gemini models (total now 35 models: 22 Claude + 8 GPT + 5 Gemini)
- Updated CLAUDE.md with Gemini implementation status (moved from placeholder to fully implemented)
- Updated test count in TESTING.md from 277 to 323 tests

## [0.2.0] - 2025-11-23

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
  - ModelProviderTests (55 tests) - All 30 models with feature support and token limits
  - ProviderTypeTests (36 tests) - All 5 providers with conformances and base URLs
  - AIModelsTests (38 tests) - All message/request/response types with integration tests
  - ProviderProtocolTests (32 tests) - Batch operations, protocol conformance, streaming
  - TESTING.md comprehensive testing documentation
  - Guidelines for test contributions and CI/CD integration
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

[Unreleased]: https://github.com/SwiftlyWorkspace/SwiftlyAIKit/compare/v0.4.1...HEAD
[0.4.1]: https://github.com/SwiftlyWorkspace/SwiftlyAIKit/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/SwiftlyWorkspace/SwiftlyAIKit/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/SwiftlyWorkspace/SwiftlyAIKit/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/SwiftlyWorkspace/SwiftlyAIKit/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/SwiftlyWorkspace/SwiftlyAIKit/releases/tag/v0.1.0
