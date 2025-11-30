# Anthropic Claude

Complete integration with Anthropic's Claude AI models.

## Overview

Anthropic Claude offers industry-leading context windows (200K tokens) and advanced reasoning capabilities through the Messages API. SwiftlyAIKit provides full support for all Claude features including prompt caching, batch processing, tool use, and vision.

**Key Capabilities:**
- 200K token context window across all models
- Prompt caching for 90% cost reduction
- Batch API for async bulk processing
- Extended thinking mode for complex reasoning
- Tool use for function calling
- Vision support with image and PDF analysis

**Available Models:**
- Claude Sonnet 4.5 - Latest flagship model
- Claude Haiku 4 - Fast, cost-effective
- Claude Opus 4 - Most capable
- Claude Sonnet 3.5 - Previous generation flagship
- Claude Haiku 3.5 - Previous generation fast model
- Claude Opus 3 - Previous generation most capable

## Topics

### Getting Started
- <doc:AnthropicGuide>

### Provider Implementation
- ``AnthropicProvider``

### Request & Response
- ``AnthropicRequest``
- ``AnthropicResponse``
- ``AnthropicMessage``
- ``AnthropicUsage``

### Content Types
- ``AnthropicContentBlock``
- ``AnthropicTextBlock``
- ``AnthropicImageBlock``
- ``AnthropicDocumentBlock``
- ``AnthropicSystemPrompt``

### Tool Calling
- ``AnthropicToolDefinition``
- ``AnthropicToolUse``
- ``AnthropicToolResult``
- ``AnthropicToolChoice``

### Batch Processing
- ``AnthropicBatch``
- ``AnthropicBatchRequest``
- ``AnthropicBatchStatus``
- ``AnthropicBatchRequestCounts``
- ``AnthropicBatchResult``

### Advanced Features
- ``AnthropicCacheControl``
- ``AnthropicThinkingConfig``
- ``AnthropicTokenCountResponse``
- ``AnthropicMetadata``

### Streaming
- ``AnthropicStreamEvent``

### Error Handling
- ``AnthropicErrorResponse``
