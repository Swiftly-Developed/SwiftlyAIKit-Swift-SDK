# ``PerplexityProvider``

Complete API reference for Perplexity AI integration.

## Overview

The `PerplexityProvider` gives you access to Sonar, Sonar Pro, and Sonar Reasoning models with real-time web search capabilities and citation support.

**Key Features:**
- ✅ Chat Completions with web search
- ✅ Citation support for sources
- ✅ Domain filtering (search_domain_filter)
- ✅ Recency filtering (day, week, month, year)
- ✅ JSON Schema structured outputs
- ✅ SSE streaming support

**Context Window**: 127K tokens | **Models**: 3+ variants | **Web Search**: ✓

## Topics

### Provider Implementation
- ``PerplexityProvider``

### Request Types
- ``PerplexityRequest``
- ``PerplexityMessage``
- ``PerplexityMessageRole``

### Response Types
- ``PerplexityResponse``
- ``PerplexityChoice``
- ``PerplexityUsage``
- ``PerplexityCitation``

### Options Helper
- ``PerplexityOptions``

### Models & Configuration
- <doc:PerplexityGuide>
