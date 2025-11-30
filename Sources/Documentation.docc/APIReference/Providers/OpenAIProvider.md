# ``OpenAIProvider``

Complete API reference for OpenAI GPT integration.

## Overview

The `OpenAIProvider` gives you access to GPT-4o, GPT-4o Mini, GPT-4 Turbo, and other OpenAI models with powerful language understanding and generation capabilities.

**Key Features:**
- ✅ Chat Completions API (create, stream)
- ✅ Vision support (image URLs and base64)
- ✅ Tool/function calling
- ✅ Streaming with Server-Sent Events
- ✅ System prompts and message history

**Context Window**: 128K tokens | **Models**: 5+ variants | **Vision**: ✓

## Topics

### Provider Implementation
- ``OpenAIProvider``

### Request Types
- ``OpenAIRequest``
- ``OpenAIMessage``
- ``OpenAIMessageRole``
- ``OpenAIMessageContent``

### Response Types
- ``OpenAIResponse``
- ``OpenAIChoice``
- ``OpenAIUsage``
- ``OpenAIFinishReason``

### Streaming Types
- ``OpenAIStreamChunk``
- ``OpenAIStreamDelta``
- ``OpenAIStreamChoice``

### Tool Calling
- ``OpenAITool``
- ``OpenAIToolCall``
- ``OpenAIToolType``
- ``OpenAIFunction``

### Batch Processing
- ``OpenAIBatch``
- ``OpenAIBatchRequest``
- ``OpenAIBatchStatus``

### Models & Configuration
- <doc:OpenAIGuide>
