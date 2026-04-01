# TCAlight

Intro

## Project structure

```
Sources/TCAlight/              # Library source code
Tests/TCAlightTests/         # Unit tests
Example/TCAlightApp/         # Demo app (Xcode project via project.yml)
```

## Stack

- Swift 6, strict concurrency (`actor`, `Sendable`)
- SPM (swift-tools-version: 6.2)
- Minimum deployment: iOS 17
- Testing framework: Swift Testing (`import Testing`)
- Approachable concurrency: YES
- Default actor isolation: MainActor
- Strict concurrency checking: Complete
- SwiftLint via SPM build tool plugin

## Architecture

TBD

### Access Control Convention

- `public` only on types/members that the consumer module needs

## Code Style

- **4-space indentation**
- **PascalCase** for types, **camelCase** for properties/methods
- **@Observable** classes (only use Combine when @Observable is not enough)
- **Swift concurrency** (async/await) over Combine
- **Swift Testing** for unit tests (not XCTest)
- No force unwrapping
- Prefer `let` over `var`
- `public` only where necessary for cross-module access
- ViewModifiers exposed via View extensions (ViewModifier is private)
- MARK: comments to organize file sections
- Doc comments (`///`) on public API
