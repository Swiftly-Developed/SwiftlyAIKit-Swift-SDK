# Contributing to SwiftlyAIKit

Thank you for your interest in contributing to SwiftlyAIKit! This document provides guidelines and information for contributors.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## How to Contribute

### Reporting Bugs

Before submitting a bug report:
1. Check the [existing issues](https://github.com/Swiftly-Developed/SwiftlyAIKit/issues) to avoid duplicates
2. Use the bug report template when creating a new issue
3. Include as much detail as possible:
   - Swift version
   - Platform (iOS, macOS, Linux, etc.)
   - Steps to reproduce
   - Expected vs actual behavior
   - Relevant logs or error messages

### Suggesting Features

We welcome feature suggestions! Please:
1. Check existing issues and discussions first
2. Use the feature request template
3. Clearly describe the use case and benefits
4. Consider if it fits the project's scope

### Pull Requests

1. **Fork the repository** and create your branch from `dev`
2. **Follow the coding style** of the project
3. **Write tests** for new functionality
4. **Update documentation** as needed
5. **Ensure all tests pass** (`swift test`)
6. **Submit a pull request** to the `dev` branch

#### Branch Naming

- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring

#### Commit Messages

Follow conventional commit format:
```
type(scope): description

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Example:
```
feat(providers): add xAI Grok provider support

- Implement GrokProvider with full API coverage
- Add streaming support
- Add vision and tool calling capabilities
```

## Development Setup

### Prerequisites

- Swift 6.2+
- Xcode 16.0+ (for iOS/macOS development)
- macOS 13.0+

### Building

```bash
git clone https://github.com/Swiftly-Developed/SwiftlyAIKit.git
cd SwiftlyAIKit
swift build
```

### Running Tests

```bash
swift test
```

### Running Specific Tests

```bash
swift test --filter SwiftlyAIKitTests.AIGatewayTests
```

## Project Structure

```
Sources/SwiftlyAIKit/
├── Core/           # AIGateway, Configuration, ProviderProtocol
├── Models/         # AIRequest, AIResponse, AIMessage, AIError
├── Providers/      # Provider implementations (8 providers)
└── Utilities/      # HTTPClientManager, helpers
```

## Adding a New Provider

1. Create a new directory under `Sources/SwiftlyAIKit/Providers/`
2. Implement `ProviderProtocol`
3. Add provider-specific models
4. Add tests under `Tests/SwiftlyAIKitTests/ProviderTests/`
5. Update `ProviderType` enum
6. Update documentation

## Testing Guidelines

- Use Swift Testing framework (`@Test`, `#expect`)
- Aim for high test coverage on new code
- Include both unit tests and integration tests
- Mock external dependencies

## Documentation

- Use DocC-style comments for public APIs
- Update README.md for user-facing changes
- Update CHANGELOG.md following [Keep a Changelog](https://keepachangelog.com/)

## Questions?

- Open a [Discussion](https://github.com/Swiftly-Developed/SwiftlyAIKit/discussions)
- Check existing documentation

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
