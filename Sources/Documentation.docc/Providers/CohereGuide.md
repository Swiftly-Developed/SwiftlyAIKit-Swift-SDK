# Cohere Guide

Complete guide to using Cohere models with SwiftlyAIKit.

## Overview

Cohere is the RAG optimization specialist:
- **RAG-optimized** - Built for retrieval-augmented generation
- **Citations included** - Automatic source attribution
- **Token counting** - Precise billing estimation
- **Enterprise features** - Safety modes, multi-tenancy
- **Large context** - 256K token window (Command R+)

Perfect for: Document Q&A, enterprise search, knowledge bases, customer support

## Getting Started

### Get an API Key

1. Visit [dashboard.cohere.com](https://dashboard.cohere.com)
2. Create an account
3. Navigate to **API Keys**
4. Create a new key
5. Copy your key (40+ characters)

### Basic Usage

```swift
import SwiftlyAIKit

let config = Configuration.withCompanyKey("your-cohere-key")
let gateway = AIGateway(configuration: config)

let request = AIRequest(
    model: .custom("command-a-plus"),
    prompt: "What is machine learning?"
)

let response = try await gateway.sendMessage(request, to: .cohere)
print(response.message.content)
```

## Available Models

| Model | Context | Quality | Pricing | Best For |
|-------|---------|---------|---------|----------|
| **Command A+** | 256K | Best | $3/$15 per M | Production RAG |
| **Command R+** | 256K | High | $3/$15 per M | Multilingual RAG |
| **Command A** | 256K | Good | $0.50/$1.50 per M | Cost-effective |
| **Command R** | 256K | Good | $0.15/$0.60 per M | High-volume |

## RAG (Retrieval-Augmented Generation)

The killer feature - provide documents and get cited answers:

### Basic RAG

```swift
// Your knowledge base documents
let documents = [
    Document(id: "1", text: "Paris is the capital of France. Population: 2.1M"),
    Document(id: "2", text: "London is the capital of UK. Population: 9M"),
    Document(id: "3", text: "Berlin is the capital of Germany. Population: 3.7M")
]

let request = AIRequest(
    model: .custom("command-a-plus"),
    messages: [.user("What's the capital of France?")],
    documents: documents.map { ["id": $0.id, "text": $0.text] }
)

let response = try await gateway.sendMessage(request, to: .cohere)

print(response.message.content)
// "Paris is the capital of France."

if let citations = response.citations {
    for citation in citations {
        print("Source: Document \(citation.documentId)")
    }
}
```

### Advanced RAG with Metadata

```swift
struct KnowledgeDocument {
    let id: String
    let title: String
    let content: String
    let author: String
    let date: String
}

func askWithRAG(_ question: String, documents: [KnowledgeDocument]) async throws -> AnswerWithCitations {
    let cohereDocuments = documents.map { doc in
        [
            "id": doc.id,
            "text": doc.content,
            "title": doc.title,
            "author": doc.author,
            "date": doc.date
        ]
    }

    let request = AIRequest(
        model: .custom("command-a-plus"),
        messages: [.user(question)],
        documents: cohereDocuments
    )

    let response = try await gateway.sendMessage(request, to: .cohere)

    return AnswerWithCitations(
        answer: response.message.content,
        citations: response.citations ?? []
    )
}
```

## Token Counting

Estimate costs before making requests:

```swift
let documents = loadLargeDocumentSet() // 100K tokens

let request = AIRequest(
    model: .custom("command-a-plus"),
    messages: [.user("Analyze these documents")],
    documents: documents
)

// Count tokens before sending
if let count = try await gateway.countTokens(request, for: .cohere) {
    let inputCost = Double(count) * 0.000003
    print("This request will cost: $\(String(format: "%.4f", inputCost))")

    if inputCost > 1.0 {
        print("Warning: Expensive request! Consider summarizing documents first.")
    }
}

let response = try await gateway.sendMessage(request, to: .cohere)
```

## Tool Calling

```swift
let tools = [
    AITool(
        name: "search_knowledge_base",
        description: "Search company knowledge base",
        parameters: [
            "query": .string(description: "Search query", required: true),
            "max_results": .integer(description: "Max results to return", required: false)
        ]
    )
]

let request = AIRequest(
    model: .custom("command-a-plus"),
    messages: [.user("Find our return policy")],
    tools: tools
)

let response = try await gateway.sendMessage(request, to: .cohere)

if let toolCalls = response.toolCalls {
    for toolCall in toolCalls {
        if toolCall.name == "search_knowledge_base" {
            let query = toolCall.arguments["query"] as? String
            let results = await searchKB(query: query ?? "")
            // Return results to Cohere
        }
    }
}
```

## Safety Modes

Control content filtering:

```swift
let request = AIRequest(
    model: .custom("command-a-plus"),
    messages: [.user("Your prompt")],
    safetyMode: .strict // .none, .contextual, .strict
)
```

**Safety levels:**
- `.none` - No filtering
- `.contextual` - Context-aware filtering
- `.strict` - Aggressive filtering

## JSON Mode with Schema

Get structured outputs with validation:

```swift
let schema = """
{
    "type": "object",
    "properties": {
        "summary": {"type": "string"},
        "key_points": {
            "type": "array",
            "items": {"type": "string"}
        },
        "confidence": {"type": "number"}
    },
    "required": ["summary", "key_points"]
}
"""

let request = AIRequest(
    model: .custom("command-a-plus"),
    messages: [.user("Summarize this article")],
    responseFormat: .json,
    responseSchema: schema
)

let response = try await gateway.sendMessage(request, to: .cohere)
// Guaranteed to match schema
```

## Use Cases

### Customer Support with RAG

```swift
class CustomerSupportBot {
    let gateway: AIGateway
    let knowledgeBase: [Document]

    func answer(_ question: String) async throws -> String {
        // Search knowledge base
        let relevantDocs = searchDocuments(question, in: knowledgeBase)

        let request = AIRequest(
            model: .custom("command-a-plus"),
            messages: [.user(question)],
            documents: relevantDocs.map { ["id": $0.id, "text": $0.content] }
        )

        let response = try await gateway.sendMessage(request, to: .cohere)

        // Response includes citations to knowledge base
        return response.message.content
    }
}
```

### Multi-Lingual RAG

Command R+ excels at multilingual tasks:

```swift
let documents = [
    ["id": "1", "text": "Paris est la capitale de la France"],
    ["id": "2", "text": "Londres es la capital del Reino Unido"],
    ["id": "3", "text": "Berlin ist die Hauptstadt von Deutschland"]
]

let request = AIRequest(
    model: .custom("command-r-plus"),
    messages: [.user("What's the capital of France?")],
    documents: documents
)

let response = try await gateway.sendMessage(request, to: .cohere)
// Handles multiple languages seamlessly
```

## Pricing Details

| Model | Input ($/M) | Output ($/M) | Total (50/50) |
|-------|-------------|--------------|---------------|
| Command A+ | $3.00 | $15.00 | $9.00 |
| Command R+ | $3.00 | $15.00 | $9.00 |
| Command A | $0.50 | $1.50 | $1.00 |
| Command R | $0.15 | $0.60 | $0.38 |

## Best Practices

### Optimize Document Chunking

```swift
func chunkDocuments(_ docs: [Document], maxChunkSize: Int = 500) -> [Document] {
    var chunks: [Document] = []

    for doc in docs {
        let words = doc.content.split(separator: " ")

        for i in stride(from: 0, to: words.count, by: maxChunkSize) {
            let chunk = words[i..<min(i + maxChunkSize, words.count)].joined(separator: " ")
            chunks.append(Document(
                id: "\(doc.id)-\(i/maxChunkSize)",
                content: chunk
            ))
        }
    }

    return chunks
}
```

### Citation Tracking

```swift
func answerWithSources(_ question: String) async throws -> AnswerWithSources {
    let request = AIRequest(
        model: .custom("command-a-plus"),
        messages: [.user(question)],
        documents: knowledgeBase
    )

    let response = try await gateway.sendMessage(request, to: .cohere)

    return AnswerWithSources(
        answer: response.message.content,
        sources: response.citations?.map { citation in
            let docId = citation.documentId
            return knowledgeBase.first { $0.id == docId }
        }.compactMap { $0 } ?? []
    )
}
```

## See Also

- ``CohereProvider``
- <doc:ProvidersOverview>
- <doc:RAGOptimization>
- <doc:ToolCalling>
- [Cohere Documentation](https://docs.cohere.com)
