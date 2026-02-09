# ``MistralProvider``

Complete API reference for Mistral AI integration.

## Overview

The `MistralProvider` gives you access to Mistral Large, Medium, Small, Codestral, Magistral, and Ministral models with European hosting and cost-effective pricing.

**Key Features:**
- ✅ Chat Completions API (create, stream)
- ✅ Vision support (image URLs and base64)
- ✅ Tool/function calling
- ✅ Reasoning mode for complex tasks
- ✅ Safe prompt mode
- ✅ Deterministic generation (random_seed)

**Context Window**: 128K tokens | **Models**: 11 variants | **Vision**: ✓

## Topics

### Provider Implementation
- ``MistralProvider``

### Request Types
- ``MistralRequest``
- ``MistralMessage``
- ``MistralMessageRole``
- ``MistralMessageContent``

### Response Types
- ``MistralResponse``
- ``MistralChoice``
- ``MistralUsage``
- ``MistralFinishReason``

### Streaming Types
- ``MistralStreamChunk``
- ``MistralStreamDelta``
- ``MistralStreamChoice``

### Tool Calling
- ``MistralTool``
- ``MistralToolCall``
- ``MistralToolType``
- ``MistralFunction``

### Batch Processing
- ``MistralBatch``
- ``MistralBatchRequest``
- ``MistralBatchStatus``

### Models & Configuration
- <doc:MistralGuide>
