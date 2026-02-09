# ``CohereProvider``

Complete API reference for Cohere AI integration.

## Overview

The `CohereProvider` gives you access to Command A, Command R, and Command legacy models with RAG optimization, citation support, and enterprise features.

**Key Features:**
- ✅ Chat API v2 (create, stream)
- ✅ Token counting via tokenize endpoint
- ✅ RAG with document support and citations
- ✅ Tool/function calling
- ✅ Structured JSON outputs with JSON Schema
- ✅ Safety modes (NONE, CONTEXTUAL, STRICT)
- ✅ Vision support (Command A Vision)

**Context Window**: 256K tokens | **Models**: 11 variants | **RAG**: ✓

## Topics

### Provider Implementation
- ``CohereProvider``

### Request Types
- ``CohereRequest``
- ``CohereMessage``
- ``CohereMessageRole``
- ``CohereDocument``

### Response Types
- ``CohereResponse``
- ``CohereUsage``
- ``CohereCitation``
- ``CohereFinishReason``

### Tool Calling
- ``CohereTool``
- ``CohereToolCall``
- ``CohereToolResult``

### Safety & Configuration
- ``CohereSafetyMode``
- ``CohereResponseFormat``

### Streaming
- ``CohereStreamEvent``
- ``CohereStreamEventType``

### Token Counting
- ``CohereTokenizeRequest``
- ``CohereTokenizeResponse``

### Models & Configuration
- <doc:CohereGuide>
