# ``Configuration``

Framework configuration and API key management.

## Overview

The `Configuration` type defines how the `AIGateway` manages API keys and authenticates with AI providers. It supports multiple strategies for API key management.

**Key Strategies:**
- **Company Key**: Single API key for all requests (server-side)
- **Client Keys**: Per-request API keys from clients (client-side)
- **Hybrid**: Combination of company and client keys
- **Per-Provider**: Different API keys for different providers

## Topics

### Configuration Builders
- ``withCompanyKey(_:)``
- ``withClientKeys()``
- ``withHybridKeys(companyKey:)``
- ``withPerProviderKeys(_:)``

### API Key Strategy
- ``APIKeyStrategy``
- ``companyKey``
- ``clientKey``
- ``hybrid``
- ``perProvider``

### Provider Configuration
- ``ProviderConfiguration``
- ``defaultTimeout``
- ``maxRetries``
