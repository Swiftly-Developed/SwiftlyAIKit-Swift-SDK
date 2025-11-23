# Cohere AI Provider Implementation Plan

## Overview

This document outlines the implementation of Cohere AI provider support in SwiftlyAIKit, including API specifications, model definitions, and implementation status.

**API Version**: v2 (Current)
**Base URL**: `https://api.cohere.com/v2`
**Authentication**: Bearer token (`Authorization: Bearer {API_KEY}`)

## API Endpoints

### Chat Endpoint

**URL**: `POST /v2/chat`

**Description**: Generate text with Cohere LLMs using a conversational interface.

**Headers**:
```
Authorization: Bearer {API_KEY}
Content-Type: application/json
Accept: application/json  (or text/event-stream for streaming)
```

### Tokenize Endpoint

**URL**: `POST /v2/tokenize`

**Description**: Tokenize text and count tokens for the specified model.

**Rate Limits**:
- Trial keys: 100 requests/minute
- Production keys: 2,000 requests/minute

## Request Format

### Chat Request Structure

```json
{
  "model": "command-r-plus-08-2024",
  "messages": [
    {
      "role": "system",
      "content": "You are a helpful assistant."
    },
    {
      "role": "user",
      "content": "Hello, how are you?"
    }
  ],
  "stream": false,
  "max_tokens": 1024,
  "temperature": 0.7,
  "top_p": 0.9,
  "top_k": 0,
  "frequency_penalty": 0.0,
  "presence_penalty": 0.0,
  "stop_sequences": [],
  "documents": [],
  "tools": [],
  "response_format": {
    "type": "text"
  },
  "safety_mode": "CONTEXTUAL"
}
```

### Message Roles

- `system`: System instructions (replaces v1 `preamble` parameter)
- `user`: User messages
- `assistant`: Assistant responses (for conversation history)
- `tool`: Tool/function call results

### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `model` | string | Yes | Model ID (e.g., "command-r-plus-08-2024") |
| `messages` | array | Yes | List of messages in chronological order |
| `stream` | boolean | No | Enable SSE streaming (default: false) |
| `max_tokens` | integer | No | Maximum tokens to generate |
| `temperature` | number | No | Randomness (0.0-1.0) |
| `top_p` | number | No | Nucleus sampling threshold |
| `top_k` | integer | No | Top-k sampling (0 = disabled) |
| `frequency_penalty` | number | No | Penalize repeated tokens |
| `presence_penalty` | number | No | Penalize token presence |
| `stop_sequences` | array | No | Sequences that stop generation |
| `documents` | array | No | Documents for RAG |
| `tools` | array | No | Available tools/functions |
| `response_format` | object | No | Output format control |
| `safety_mode` | string | No | Safety filter mode |

### Response Format Options

**Text Response** (default):
```json
{
  "type": "text"
}
```

**JSON Object Response**:
```json
{
  "type": "json_object",
  "schema": {
    "type": "object",
    "required": ["field1", "field2"],
    "properties": {
      "field1": {"type": "string"},
      "field2": {"type": "integer"}
    }
  }
}
```

**Note**: Supported on Command R, Command R+, and newer models. Schema is optional; without it, JSON can have up to 5 layers of nesting.

### Safety Modes

- `NONE`: No safety filtering
- `CONTEXTUAL`: Context-aware safety (default)
- `STRICT`: Strict safety filtering

## Response Format

### Non-Streaming Response

```json
{
  "id": "chat-abc123def456",
  "finish_reason": "COMPLETE",
  "message": {
    "role": "assistant",
    "content": [
      {
        "type": "text",
        "text": "Hello! I'm doing well, thank you for asking. How can I help you today?"
      }
    ],
    "tool_calls": []
  },
  "usage": {
    "billed_units": {
      "input_tokens": 15,
      "output_tokens": 22
    },
    "tokens": {
      "input_tokens": 15,
      "output_tokens": 22
    }
  },
  "citations": []
}
```

### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique response ID |
| `finish_reason` | string | Why generation stopped (COMPLETE, MAX_TOKENS, STOP_SEQUENCE, ERROR) |
| `message` | object | The generated message |
| `message.role` | string | Always "assistant" |
| `message.content` | array | Content blocks (text, tool_calls) |
| `message.tool_calls` | array | Tool calls requested by the model |
| `usage` | object | Token usage statistics |
| `usage.billed_units` | object | Tokens billed |
| `usage.tokens` | object | Total tokens processed |
| `citations` | array | Citations from documents (RAG) |

## Streaming Format

### Server-Sent Events (SSE)

When `stream: true` is set, response is sent as text/event-stream with multiple event types.

### Event Types

#### 1. message-start
**Emitted**: Once at the beginning
**Purpose**: Initial metadata

```
data: {"type":"message-start","id":"chat-abc123"}
```

#### 2. content-start
**Emitted**: Once before content generation
**Purpose**: Marks beginning of content block

```
data: {"type":"content-start","index":0,"content_block":{"type":"text","text":""}}
```

#### 3. content-delta
**Emitted**: Multiple times during generation
**Purpose**: Incremental text chunks

```
data: {"type":"content-delta","index":0,"delta":{"message":{"content":{"text":"Hello"}}}}
```

```
data: {"type":"content-delta","index":0,"delta":{"message":{"content":{"text":" there!"}}}}
```

#### 4. content-end
**Emitted**: Once after content generation
**Purpose**: Signals content block completion

```
data: {"type":"content-end","index":0}
```

#### 5. message-end
**Emitted**: Once at the end
**Purpose**: Final event with finish_reason and usage

```
data: {"type":"message-end","delta":{"finish_reason":"COMPLETE","usage":{"billed_units":{"input_tokens":12,"output_tokens":15},"tokens":{"input_tokens":12,"output_tokens":15}}}}
```

### RAG-Specific Events

#### citation-start
**Purpose**: Marks beginning of citation

```
data: {"type":"citation-start","index":0,"citation":{"start":0,"end":50,"text":"...","document_ids":["doc_0"]}}
```

#### citation-end
**Purpose**: Marks end of citation

```
data: {"type":"citation-end","index":0}
```

### Tool Use Events

#### tool-plan-delta
**Purpose**: Tool usage plan text

```
data: {"type":"tool-plan-delta","delta":{"message":{"tool_plan":"I will use the search tool"}}}
```

#### tool-call-start
**Purpose**: Marks beginning of tool call

```
data: {"type":"tool-call-start","index":0,"tool_call":{"id":"call_abc","type":"function","function":{"name":"search","arguments":""}}}
```

#### tool-call-delta
**Purpose**: Incremental tool call arguments

```
data: {"type":"tool-call-delta","index":0,"delta":{"tool_call":{"function":{"arguments":"{\"query\":"}}}}
```

#### tool-call-end
**Purpose**: Marks end of tool call

```
data: {"type":"tool-call-end","index":0}
```

## Error Responses

### Error Format

```json
{
  "message": "invalid api key",
  "status_code": 401
}
```

### Common Error Codes

| Status Code | Error Type | Description |
|-------------|------------|-------------|
| 400 | Bad Request | Invalid request parameters |
| 401 | Unauthorized | Invalid or missing API key |
| 403 | Forbidden | Insufficient permissions |
| 429 | Rate Limit | Too many requests |
| 500 | Server Error | Internal server error |
| 503 | Service Unavailable | Service temporarily unavailable |

## Available Models

### Command A Family (Latest - 2025)

| Model ID | Parameters | Context | Output | Features |
|----------|-----------|---------|--------|----------|
| `command-a-03-2025` | 111B | 256K | 8K | Tool use, RAG, agents, multilingual |
| `command-a-reasoning-03-2025` | 111B | 256K | 8K | Agentic workflows, complex reasoning |
| `command-a-translate-03-2025` | 111B | 16K | 8K | 23 language translation |
| `command-a-vision-03-2025` | 111B | 256K | 8K | Multimodal (text + images) |

### Command R Family (August 2024 Refresh)

| Model ID | Parameters | Context | Output | Features |
|----------|-----------|---------|--------|----------|
| `command-r-plus-08-2024` | ~104B | 256K | 8K | Complex RAG, multi-step tool use, 50% faster throughput |
| `command-r-08-2024` | ~35B | 256K | 8K | Simpler RAG, tool use, 50% faster throughput |
| `command-r7b-12-2024` | 7B | 256K | 8K | Smallest in R family, efficient RAG/tools |

### Legacy Models (Still Available)

| Model ID | Context | Output | Notes |
|----------|---------|--------|-------|
| `command-r-plus` | 128K | 4K | Older Command R+ version |
| `command-r` | 128K | 4K | Older Command R version |
| `command` | 4K | 4K | Original Command model |
| `command-light` | 4K | 4K | Lightweight Command |

### Model Capabilities

**All Command Models Support**:
- ✅ Text generation
- ✅ Conversational chat
- ✅ Multilingual (10+ languages optimized, 23+ supported)
- ✅ Tool/function calling
- ✅ RAG (Retrieval Augmented Generation)
- ✅ Structured outputs (JSON)
- ✅ Safety modes

**Command A Vision**:
- ✅ Image understanding
- ✅ Multimodal input (text + images)

**August 2024 Improvements**:
- ✅ 50% higher throughput
- ✅ 20-25% lower latencies
- ✅ Better tool use decision-making
- ✅ Improved instruction following
- ✅ Enhanced structured data analysis
- ✅ Robustness to prompt formatting

## Tokenization

### Tokenize Request

**Endpoint**: `POST /v2/tokenize`

```json
{
  "text": "Hello, how are you?",
  "model": "command-r-plus-08-2024"
}
```

### Tokenize Response

```json
{
  "tokens": [31587, 11, 1577, 525, 564, 30],
  "token_strings": ["Hello", ",", " how", " are", " you", "?"]
}
```

**Token Count**: `tokens.length` or `token_strings.length`

## RAG (Retrieval Augmented Generation)

### Document Structure

```json
{
  "documents": [
    {
      "id": "doc_0",
      "text": "Cohere was founded in 2019 by Aidan Gomez, Ivan Zhang, and Nick Frosst."
    },
    {
      "id": "doc_1",
      "text": "The company is headquartered in Toronto, Canada."
    }
  ]
}
```

### Citations in Response

```json
{
  "citations": [
    {
      "start": 0,
      "end": 50,
      "text": "Cohere was founded in 2019 by Aidan Gomez",
      "document_ids": ["doc_0"]
    }
  ]
}
```

## Tool Use (Function Calling)

### Tool Definition

```json
{
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "search_web",
        "description": "Search the web for information",
        "parameters": {
          "type": "object",
          "properties": {
            "query": {
              "type": "string",
              "description": "The search query"
            }
          },
          "required": ["query"]
        }
      }
    }
  ]
}
```

### Tool Call in Response

```json
{
  "message": {
    "tool_calls": [
      {
        "id": "call_abc123",
        "type": "function",
        "function": {
          "name": "search_web",
          "arguments": "{\"query\":\"Cohere AI company\"}"
        }
      }
    ]
  }
}
```

## Implementation Status

### ✅ Completed

- [x] Research API specifications
- [x] Document request/response formats
- [x] Document streaming event types
- [x] Document model specifications
- [x] Identify authentication requirements

### 🚧 In Progress

- [ ] Create `CohereModels.swift`
- [ ] Implement `CohereProvider.swift`
- [ ] Add Cohere models to `ModelProvider.swift`
- [ ] Create `MockCohereAPI.swift`
- [ ] Create `CohereProviderTests.swift`

### 📋 Pending

- [ ] Test with actual API calls
- [ ] Add usage examples to README
- [ ] Performance optimization
- [ ] Integration testing

## Implementation Notes

### Key Differences from Other Providers

1. **Streaming Events**: Cohere uses typed events (message-start, content-delta, message-end) vs. generic SSE chunks
2. **Message Content**: Content is an array of content blocks, not a simple string
3. **Token Usage**: Separate `billed_units` and `tokens` objects in usage
4. **RAG Integration**: Built-in `documents` parameter and `citations` in response
5. **Safety Modes**: Provider-specific safety filtering options
6. **Response Format**: Can force JSON with optional schema validation

### Mapping to AIRequest/AIResponse

**System Prompt**:
- In v2 API, use `{"role": "system", "content": "..."}` in messages array
- Cohere v2 uses `system` role directly (no separate preamble)

**Temperature/Top-P/Top-K**:
- Map directly to Cohere parameters
- Cohere supports all three sampling methods

**Max Tokens**:
- Map `AIRequest.maxTokens` to `max_tokens` parameter

**Stop Sequences**:
- Map to `stop_sequences` array

**Content Extraction**:
- Extract text from `message.content[0].text`
- Handle content blocks array (may have multiple blocks)

**Token Counting**:
- Use `usage.billed_units.input_tokens` and `usage.billed_units.output_tokens`
- These represent the tokens that will be billed

### Error Handling

- Parse `message` and `status_code` fields from error response
- Map 401/403 to `.invalidAPIKey`
- Map 429 to `.rateLimitExceeded`
- Map 400 to `.invalidRequest`
- Map 500+ to `.providerError`

### Streaming Accumulation

```swift
var accumulatedContent = ""

for event in stream {
    if event.type == "content-delta" {
        if let text = event.delta.message.content.text {
            accumulatedContent += text
            // Yield AIResponse with accumulated content
        }
    } else if event.type == "message-end" {
        // Extract finish_reason and usage
        // Yield final AIResponse
        break
    }
}
```

## Testing Checklist

- [ ] Test basic chat completion (non-streaming)
- [ ] Test streaming with SSE events
- [ ] Test token counting via tokenize endpoint
- [ ] Test RAG with documents and citations
- [ ] Test tool/function calling
- [ ] Test structured JSON output
- [ ] Test all error codes (401, 429, 400, 500)
- [ ] Test all supported models
- [ ] Test system prompt handling
- [ ] Test max_tokens enforcement
- [ ] Test stop sequences
- [ ] Test safety modes
- [ ] Test multimodal (vision) if command-a-vision available

## References

- **Chat API Documentation**: [https://docs.cohere.com/v2/reference/chat](https://docs.cohere.com/v2/reference/chat)
- **Streaming Guide**: [https://docs.cohere.com/v2/docs/streaming](https://docs.cohere.com/v2/docs/streaming)
- **Chat API Guide**: [https://docs.cohere.com/v2/docs/chat-api](https://docs.cohere.com/v2/docs/chat-api)
- **Models Overview**: [https://docs.cohere.com/v2/docs/models](https://docs.cohere.com/v2/docs/models)
- **Command R+**: [https://docs.cohere.com/v2/docs/command-r-plus](https://docs.cohere.com/v2/docs/command-r-plus)
- **Tokens and Tokenizers**: [https://docs.cohere.com/docs/tokens-and-tokenizers](https://docs.cohere.com/docs/tokens-and-tokenizers)
- **Tokenize API**: [https://docs.cohere.com/reference/tokenize](https://docs.cohere.com/reference/tokenize)
- **Tool Use**: [https://docs.cohere.com/docs/tool-use-quickstart](https://docs.cohere.com/docs/tool-use-quickstart)
- **Working with API**: [https://docs.cohere.com/reference/about](https://docs.cohere.com/reference/about)

## Version History

**v0.6.0** (Planned)
- Initial Cohere provider implementation
- Support for Command A and Command R families
- Chat completion and streaming
- Token counting
- RAG support
- Tool/function calling
- Structured JSON output
