# RAG Optimization

Build retrieval-augmented generation systems with SwiftlyAIKit.

## Overview

RAG (Retrieval-Augmented Generation) combines:
- **Your knowledge base** (documents, data)
- **AI reasoning** (understand and answer)

This creates AI systems that can answer questions using your proprietary data while providing citations.

**Best providers for RAG:**
1. **Cohere** - RAG-optimized with citations
2. **Google Gemini** - Massive 2M context
3. **Anthropic Claude** - Long context analysis
4. **Perplexity** - Web search RAG

## Basic RAG Pattern

### Simple Document RAG

```swift
import SwiftlyAIKit

// Your knowledge base
let documents = [
    Document(id: "1", content: "SwiftlyAIKit supports 9 AI providers"),
    Document(id: "2", content: "Configuration uses API key strategies"),
    Document(id: "3", content: "AIGateway is the main coordinator")
]

// User asks a question
let question = "How many providers does SwiftlyAIKit support?"

// Include documents in request
let request = AIRequest(
    model: .custom("command-a-plus"),
    messages: [.user(question)],
    documents: documents.map { ["id": $0.id, "text": $0.content] }
)

let response = try await gateway.sendMessage(request, to: .cohere)

print(response.message.content)
// "SwiftlyAIKit supports 9 AI providers."

if let citations = response.citations {
    print("Sources: \(citations.map { $0.documentId })")
    // ["1"]
}
```

## Cohere RAG (Recommended)

### Why Cohere for RAG?

- **Optimized retrieval** - Models trained specifically for RAG
- **Automatic citations** - Which documents were used
- **Token counting** - Estimate costs before processing
- **Safety modes** - Content filtering
- **Multi-lingual** - 100+ languages

### Advanced Cohere RAG

```swift
class CohereRAGService {
    let gateway: AIGateway
    let knowledgeBase: [KBDocument]

    struct KBDocument {
        let id: String
        let title: String
        let content: String
        let metadata: [String: String]
    }

    func ask(_ question: String) async throws -> AnswerWithCitations {
        // 1. Search knowledge base (semantic search)
        let relevantDocs = await searchKnowledgeBase(question)

        // 2. Format documents for Cohere
        let documents = relevantDocs.map { doc in
            [
                "id": doc.id,
                "text": doc.content,
                "title": doc.title
            ]
        }

        // 3. Create RAG request
        let request = AIRequest(
            model: .custom("command-a-plus"),
            messages: [.user(question)],
            documents: documents
        )

        // 4. Get response with citations
        let response = try await gateway.sendMessage(request, to: .cohere)

        // 5. Map citations to documents
        let sources = (response.citations ?? []).compactMap { citation in
            relevantDocs.first { $0.id == citation.documentId }
        }

        return AnswerWithCitations(
            answer: response.message.content,
            sources: sources
        )
    }

    private func searchKnowledgeBase(_ query: String) async -> [KBDocument] {
        // Implement semantic search
        // Return top-k most relevant documents
        return knowledgeBase.filter { doc in
            doc.content.localizedCaseInsensitiveContains(query)
        }.prefix(10).map { $0 }
    }
}

struct AnswerWithCitations {
    let answer: String
    let sources: [CohereRAGService.KBDocument]
}
```

## Gemini Long-Context RAG

### Use Massive Context

```swift
// Gemini can fit entire document sets in context
let allDocuments = loadEntireKnowledgeBase() // 500K tokens

let combined = allDocuments.map { doc in
    """
    [Document ID: \(doc.id)]
    [Title: \(doc.title)]
    \(doc.content)
    ---
    """
}.joined(separator: "\n\n")

let request = AIRequest(
    model: .gemini(.pro2_5),
    messages: [
        .user("""
        Here is our knowledge base:

        \(combined)

        Question: \(userQuestion)

        Answer the question using ONLY information from the knowledge base above.
        Cite document IDs in your response.
        """)
    ]
)

let response = try await gateway.sendMessage(request, to: .google)
```

**Advantages:**
- No need for semantic search (everything fits)
- AI sees all context
- Good for smaller knowledge bases (< 1.5M tokens)

**Disadvantages:**
- Expensive for large KBs
- May need token counting to avoid errors

## Vector Search Integration

### Semantic Search First

```swift
import VectorDB // Example

class VectorRAGService {
    let gateway: AIGateway
    let vectorDB: VectorDatabase

    func ask(_ question: String) async throws -> String {
        // 1. Embed the question
        let questionEmbedding = await vectorDB.embed(question)

        // 2. Search for similar documents
        let similarDocs = await vectorDB.search(
            embedding: questionEmbedding,
            topK: 10
        )

        // 3. Use AI to answer from retrieved docs
        let request = AIRequest(
            model: .custom("command-a-plus"),
            messages: [.user(question)],
            documents: similarDocs.map { ["id": $0.id, "text": $0.content] }
        )

        let response = try await gateway.sendMessage(request, to: .cohere)
        return response.message.content
    }
}
```

## RAG Patterns

### Pattern 1: Retrieve Then Generate

```swift
// 1. Retrieve relevant documents
let docs = searchKnowledgeBase(query)

// 2. Generate answer from documents
let request = AIRequest(
    model: .custom("command-a-plus"),
    messages: [.user(query)],
    documents: docs
)
```

### Pattern 2: Generate Then Verify

```swift
// 1. Generate answer
let answer = try await gateway.sendMessage(initialRequest, to: .anthropic)

// 2. Verify against knowledge base
let verificationRequest = AIRequest(
    model: .custom("command-a-plus"),
    messages: [.user("Verify this answer is correct: \(answer.message.content)")],
    documents: knowledgeBase
)

let verification = try await gateway.sendMessage(verificationRequest, to: .cohere)
```

### Pattern 3: Multi-Stage RAG

```swift
// 1. Broad retrieval
let broadDocs = await searchKB(query, topK: 50)

// 2. AI filters to most relevant
let filterRequest = AIRequest(
    model: .claude(.haiku3_5), // Cheap model for filtering
    messages: [.user("Rank these documents by relevance to: \(query)")],
    documents: broadDocs
)
let filtering = try await gateway.sendMessage(filterRequest, to: .anthropic)

// 3. Deep analysis with filtered docs
let topDocs = parseTopDocuments(filtering.message.content)
let finalRequest = AIRequest(
    model: .claude(.sonnet4_5), // Smart model for final answer
    messages: [.user(query)],
    documents: topDocs
)
```

## Citation Handling

### Parse Citations

```swift
func extractSources(_ response: AIResponse, from documents: [Document]) -> [Document] {
    guard let citations = response.citations else {
        return []
    }

    return citations.compactMap { citation in
        documents.first { $0.id == citation.documentId }
    }
}

// Usage
let sources = extractSources(response, from: knowledgeBase)
for source in sources {
    print("Source: \(source.title)")
}
```

### Display Citations to Users

```swift
struct RAGAnswerView: View {
    let answer: String
    let sources: [Document]

    var body: some View {
        VStack(alignment: .leading) {
            Text(answer)
                .padding()

            if !sources.isEmpty {
                Divider()

                Text("Sources:")
                    .font(.headline)
                    .padding(.top)

                ForEach(sources, id: \.id) { source in
                    VStack(alignment: .leading) {
                        Text(source.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(source.content.prefix(100) + "...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
```

## Performance Optimization

### Document Chunking

```swift
func chunkDocument(_ document: String, maxChunkSize: Int = 500) -> [String] {
    let words = document.split(separator: " ")
    var chunks: [String] = []

    for i in stride(from: 0, to: words.count, by: maxChunkSize) {
        let end = min(i + maxChunkSize, words.count)
        let chunk = words[i..<end].joined(separator: " ")
        chunks.append(chunk)
    }

    return chunks
}

// Use chunks instead of full documents
let chunked = chunkDocument(largeDocument)
let docs = chunked.enumerated().map { index, chunk in
    ["id": "chunk-\(index)", "text": chunk]
}
```

### Limit Document Count

```swift
// Cohere recommends max 10-15 documents for best quality
let topDocuments = searchResults.prefix(10)
```

## Best Practices

### ✅ Do

- Retrieve only relevant documents (top-k search)
- Chunk large documents into smaller pieces
- Include document metadata (title, date, author)
- Request citations for verifiability
- Monitor token usage
- Cache document embeddings

### ❌ Don't

- Send entire knowledge base (too expensive)
- Forget to cite sources
- Use outdated/irrelevant documents
- Ignore document freshness
- Skip semantic search (poor retrieval)

## Testing RAG Systems

```swift
@Test("RAG returns cited answer")
func testRAG() async throws {
    let docs = [
        ["id": "1", "text": "The sky is blue"],
        ["id": "2", "text": "Grass is green"]
    ]

    let request = AIRequest(
        model: .custom("command-a-plus"),
        messages: [.user("What color is the sky?")],
        documents: docs
    )

    let response = try await gateway.sendMessage(request, to: .cohere)

    #expect(response.message.content.contains("blue"))
    #expect(response.citations?.contains { $0.documentId == "1" } == true)
}
```

## See Also

- <doc:CohereGuide>
- <doc:GeminiGuide>
- <doc:AnthropicGuide>
- ``AIRequest``
- ``AIResponse``
