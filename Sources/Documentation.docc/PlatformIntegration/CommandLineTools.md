# Command-Line Tools

Build AI-powered command-line tools with SwiftlyAIKit.

## Overview

SwiftlyAIKit works great for CLI tools:
- Cross-platform (macOS, Linux)
- Simple integration
- Perfect for automation
- Easy deployment

## Quick Start

### Create a CLI Project

```bash
mkdir AITool
cd AITool
swift package init --type executable
```

### Add SwiftlyAIKit

```swift
// Package.swift
let package = Package(
    name: "AITool",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/Swiftly-Developed/SwiftlyAIKit.git", from: "0.10.0")
    ],
    targets: [
        .executableTarget(
            name: "AITool",
            dependencies: [
                .product(name: "SwiftlyAIKit", package: "SwiftlyAIKit")
            ]
        )
    ]
)
```

### Simple CLI Tool

```swift
// Sources/AITool/main.swift
import Foundation
import SwiftlyAIKit

@main
struct AITool {
    static func main() async throws {
        // Get API key from environment
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
            print("Error: ANTHROPIC_API_KEY not set")
            exit(1)
        }

        // Configure gateway
        let config = Configuration.withCompanyKey(apiKey)
        let gateway = AIGateway(configuration: config)

        // Get prompt from command line
        let args = CommandLine.arguments
        guard args.count > 1 else {
            print("Usage: aitool <prompt>")
            exit(1)
        }

        let prompt = args[1...].joined(separator: " ")

        // Send request
        let request = AIRequest(model: .claude(.sonnet4_5), prompt: prompt)
        let response = try await gateway.sendMessage(request)

        // Print response
        print(response.message.content)
    }
}
```

### Run It

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
swift run AITool "Explain quantum computing"
```

## Interactive CLI

### REPL-Style Interface

```swift
import Foundation
import SwiftlyAIKit

@main
struct InteractiveCLI {
    static func main() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
            print("Error: ANTHROPIC_API_KEY not set")
            exit(1)
        }

        let config = Configuration.withCompanyKey(apiKey)
        let gateway = AIGateway(configuration: config)

        var conversationHistory: [AIMessage] = []

        print("AI Chat (type 'exit' to quit)")
        print("================================\n")

        while true {
            print("You: ", terminator: "")
            guard let input = readLine(), !input.isEmpty else { continue }

            if input.lowercased() == "exit" {
                print("Goodbye!")
                break
            }

            conversationHistory.append(.user(input))

            let request = AIRequest(
                model: .claude(.sonnet4_5),
                messages: conversationHistory
            )

            print("AI: ", terminator: "")

            do {
                let stream = try await gateway.streamMessage(request)

                var fullResponse = ""
                for try await chunk in stream {
                    print(chunk.message.content, terminator: "")
                    fullResponse += chunk.message.content
                }
                print("\n")

                conversationHistory.append(.assistant(fullResponse))

            } catch {
                print("Error: \(error.localizedDescription)\n")
            }
        }
    }
}
```

## File Processing Tool

### Process Multiple Files

```swift
import Foundation
import SwiftlyAIKit

@main
struct FileSummarizer {
    static func main() async throws {
        let files = CommandLine.arguments.dropFirst()

        guard !files.isEmpty else {
            print("Usage: summarizer <file1> <file2> ...")
            exit(1)
        }

        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
            print("Error: ANTHROPIC_API_KEY not set")
            exit(1)
        }

        let config = Configuration.withCompanyKey(apiKey)
        let gateway = AIGateway(configuration: config)

        for file in files {
            await summarizeFile(file, gateway: gateway)
        }
    }

    static func summarizeFile(_ path: String, gateway: AIGateway) async {
        do {
            let content = try String(contentsOfFile: path)

            print("Summarizing: \(path)")

            let request = AIRequest(
                model: .claude(.sonnet4_5),
                prompt: "Summarize this in 2-3 sentences:\n\n\(content)",
                maxTokens: 150
            )

            let response = try await gateway.sendMessage(request)

            print("Summary: \(response.message.content)")
            print("Tokens: \(response.usage?.totalTokens ?? 0)")
            print("---\n")

        } catch {
            print("Error processing \(path): \(error)\n")
        }
    }
}
```

### Run It

```bash
swift run summarizer document1.txt document2.txt document3.txt
```

## Argument Parsing

### Using ArgumentParser

```swift
// Package.swift - add dependency
.package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0")

// main.swift
import ArgumentParser
import SwiftlyAIKit

@main
struct AITool: AsyncParsableCommand {
    @Option(name: .long, help: "AI provider to use")
    var provider: String = "anthropic"

    @Option(name: .long, help: "Model to use")
    var model: String = "claude-3-5-sonnet-20241022"

    @Option(name: .long, help: "Temperature (0-1)")
    var temperature: Double = 0.7

    @Argument(help: "Your prompt")
    var prompt: String

    mutating func run() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
            print("Error: ANTHROPIC_API_KEY not set")
            throw ExitCode.failure
        }

        let config = Configuration.withCompanyKey(apiKey)
        let gateway = AIGateway(configuration: config)

        let providerType = ProviderType(rawValue: provider) ?? .anthropic

        let request = AIRequest(
            model: .custom(model),
            prompt: prompt,
            temperature: temperature
        )

        let response = try await gateway.sendMessage(request, to: providerType)

        print(response.message.content)
    }
}
```

### Usage

```bash
swift run AITool --provider anthropic --model claude-3-5-sonnet --temperature 0.9 "Write a poem"
```

## Automation Scripts

### Batch File Processor

```swift
#!/usr/bin/env swift

import Foundation
import SwiftlyAIKit

guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
    print("Error: Set ANTHROPIC_API_KEY")
    exit(1)
}

let config = Configuration.withCompanyKey(apiKey)
let gateway = AIGateway(configuration: config)

let inputDir = "input/"
let outputDir = "output/"

let files = try FileManager.default.contentsOfDirectory(atPath: inputDir)

for file in files where file.hasSuffix(".txt") {
    let content = try String(contentsOfFile: inputDir + file)

    let request = AIRequest(
        model: .claude(.sonnet4_5),
        prompt: "Summarize:\n\n\(content)"
    )

    let response = try await gateway.sendMessage(request)

    let outputFile = outputDir + file.replacingOccurrences(of: ".txt", with: "-summary.txt")
    try response.message.content.write(toFile: outputFile, atomically: true, encoding: .utf8)

    print("✓ Processed: \(file)")
}

print("Done! Processed \(files.count) files")
```

## See Also

- <doc:SwiftUIIntegration>
- <doc:UIKitIntegration>
- <doc:VaporIntegration>
- ``AIGateway``
- ``Configuration``
