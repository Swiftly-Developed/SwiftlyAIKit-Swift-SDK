# ``AIResponse``

Unified response types from AI operations.

## Overview

The `AIResponse` type provides a unified interface for responses from all AI providers. It abstracts provider-specific response formats while preserving important metadata like token usage, stop reasons, and tool calls.

**Key Information:**
- Generated message content
- Token usage statistics
- Stop reason (completed, length limit, tool use, etc.)
- Tool calls requested by the AI
- Provider-specific metadata
- Request ID for tracking

## Topics

### Response Types
- ``AIResponse``
- ``AIUsage``
- ``AIStopReason``
- ``AIFinishReason``

### Tool Responses
- ``AIToolCall``
- ``AIToolUse``

### Error Handling
- ``AIError``
- ``AIErrorType``
- ``AIErrorCode``

### Metadata
- ``AnyCodable``
