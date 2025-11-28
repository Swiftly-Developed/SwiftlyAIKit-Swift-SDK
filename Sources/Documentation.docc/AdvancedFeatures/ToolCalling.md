# Tool Calling (Function Calling)

Give AI models access to real-time data and custom functions.

## Overview

Tool calling (also called function calling) enables AI models to:
- **Access real-time data** (weather, stock prices, database queries)
- **Perform actions** (send emails, create records, make API calls)
- **Use your custom logic** when they need information

**Supported providers:**
- Anthropic Claude
- OpenAI GPT
- Google Gemini
- Mistral AI
- Cohere
- xAI Grok
- DeepSeek

## How It Works

1. You define available tools (functions)
2. AI decides whether to call a tool
3. You execute the tool and return results
4. AI uses results to formulate final response

## Complete Example

```swift
import SwiftlyAIKit

// 1. Define your tools
let tools = [
    AITool(
        name: "get_weather",
        description: "Get current weather for a location",
        parameters: AIToolParameters(
            type: "object",
            properties: [
                "location": AIToolProperty(
                    type: "string",
                    description: "City name"
                ),
                "unit": AIToolProperty(
                    type: "string",
                    description: "celsius or fahrenheit",
                    enumValues: ["celsius", "fahrenheit"]
                )
            ],
            required: ["location"]
        )
    )
]

// 2. Send request with tools
let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [.user("What's the weather in Tokyo?")],
    tools: tools
)

let response = try await gateway.sendMessage(request)

// 3. Check if AI wants to call tools
if let toolCalls = response.toolCalls {
    for toolCall in toolCalls {
        if toolCall.name == "get_weather" {
            let location = toolCall.arguments["location"] as? String ?? ""
            let unit = toolCall.arguments["unit"] as? String ?? "celsius"

            // 4. Execute your function
            let weather = await getWeather(location: location, unit: unit)

            // 5. Send result back to AI
            let followUp = AIRequest(
                model: .claude(.sonnet4_5),
                messages: request.messages + [
                    .assistant("", toolCalls: [toolCall]),
                    .tool(name: toolCall.name, content: weather)
                ]
            )

            let finalResponse = try await gateway.sendMessage(followUp)
            print(finalResponse.message.content)
            // "The current weather in Tokyo is 18°C with partly cloudy skies."
        }
    }
}

// Implement your function
func getWeather(location: String, unit: String) async -> String {
    // Call weather API
    return "{\"temperature\": 18, \"conditions\": \"partly cloudy\", \"unit\": \"celsius\"}"
}
```

## Tool Definition Best Practices

### Clear Descriptions

```swift
// ❌ Bad: Vague description
AITool(
    name: "search",
    description: "Search",
    parameters: ...
)

// ✅ Good: Clear, specific description
AITool(
    name: "search_knowledge_base",
    description: "Search the company knowledge base for relevant documents based on a query",
    parameters: ...
)
```

### Detailed Parameters

```swift
AIToolParameters(
    type: "object",
    properties: [
        "query": AIToolProperty(
            type: "string",
            description: "The search query. Be specific and include relevant keywords."
        ),
        "max_results": AIToolProperty(
            type: "integer",
            description: "Maximum number of results to return (1-50). Default is 10.",
            minimum: 1,
            maximum: 50
        ),
        "category": AIToolProperty(
            type: "string",
            description: "Optional category to filter results",
            enumValues: ["technical", "business", "legal", "hr"]
        )
    ],
    required: ["query"]
)
```

## Multi-Tool Pattern

```swift
let tools = [
    AITool(name: "get_weather", description: "Get weather", parameters: ...),
    AITool(name: "search_web", description: "Search web", parameters: ...),
    AITool(name: "get_stock_price", description: "Get stock price", parameters: ...),
    AITool(name: "send_email", description: "Send email", parameters: ...)
]

let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [.user("What's Apple's stock price and the weather in Cupertino?")],
    tools: tools
)

// AI may call multiple tools
let response = try await gateway.sendMessage(request)

if let toolCalls = response.toolCalls {
    var results: [String] = []

    for toolCall in toolCalls {
        let result = await executeToolCall(toolCall)
        results.append(result)
    }

    // Send all results back
    let followUp = AIRequest(
        model: .claude(.sonnet4_5),
        messages: request.messages + [
            .assistant("", toolCalls: toolCalls),
        ] + toolCalls.enumerated().map { index, call in
            .tool(name: call.name, content: results[index])
        }
    )

    let final = try await gateway.sendMessage(followUp)
}
```

## Tool Choice Control

```swift
// Let AI decide when to use tools
let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [.user("Question")],
    tools: tools,
    toolChoice: .auto // AI decides
)

// Force AI to use a specific tool
let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [.user("Get the weather")],
    tools: tools,
    toolChoice: .specific("get_weather")
)

// Disable tools for this request
let request = AIRequest(
    model: .claude(.sonnet4_5),
    messages: [.user("Just chat")],
    tools: tools,
    toolChoice: .none
)
```

## Common Use Cases

### Database Query Tool

```swift
let dbTool = AITool(
    name: "query_database",
    description: "Query the customer database",
    parameters: AIToolParameters(
        type: "object",
        properties: [
            "sql": AIToolProperty(
                type: "string",
                description: "SQL query to execute (SELECT only)"
            )
        ],
        required: ["sql"]
    )
)

func executeToolCall(_ call: AIToolCall) async -> String {
    if call.name == "query_database" {
        let sql = call.arguments["sql"] as? String ?? ""

        // Execute SQL safely
        let results = await database.execute(sql)
        return try! JSONEncoder().encode(results).string
    }

    return "{\"error\": \"Unknown tool\"}"
}
```

### API Call Tool

```swift
let apiTool = AITool(
    name: "call_api",
    description: "Make HTTP API calls",
    parameters: AIToolParameters(
        type: "object",
        properties: [
            "url": AIToolProperty(type: "string", description: "API endpoint"),
            "method": AIToolProperty(type: "string", description: "HTTP method", enumValues: ["GET", "POST"]),
            "body": AIToolProperty(type: "object", description: "Request body for POST")
        ],
        required: ["url", "method"]
    )
)
```

## Error Handling

```swift
do {
    let response = try await gateway.sendMessage(request)

    if let toolCalls = response.toolCalls {
        for toolCall in toolCalls {
            do {
                let result = try await executeToolCall(toolCall)
                // Send result back
            } catch {
                // Send error to AI
                let errorResult = "{\"error\": \"\(error.localizedDescription)\"}"
                // AI can handle the error in its response
            }
        }
    }
} catch AIError.unsupportedFeature(let feature, let provider) {
    print("\(provider) doesn't support \(feature)")
    // Fall back to provider that supports tools
}
```

## Best Practices

### ✅ Do

- Provide clear, detailed tool descriptions
- Validate tool call arguments before executing
- Return structured JSON results
- Handle errors gracefully
- Limit tool execution time (timeouts)
- Log tool usage for debugging

### ❌ Don't

- Give tools unrestricted access to systems
- Execute dangerous operations without confirmation
- Return huge data payloads (summarize instead)
- Forget to validate arguments
- Allow recursive tool calls (can loop)

## See Also

- ``AITool``
- ``AIToolChoice``
- ``AIToolCall``
- <doc:ToolCalling>
- <doc:AnthropicGuide>
- <doc:OpenAIGuide>
