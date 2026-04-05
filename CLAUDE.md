# TCAlight

Lightweight state container inspired by TCA:
- A `State` owns its associated `Action`
- Actions mutate state through a static `reducer`
- A `Store` serializes state updates on `MainActor`

## Project structure

```
Sources/TCAlight/              # Library source code
Tests/TCAlightTests/           # Unit tests
Example/TCAlightApp/           # Demo app (Xcode project via project.yml)
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

### Core protocols

- `StateWithActionProtocol`: strongly couples a state type to one action type
- `ActionProtocol`: defines the reducer entry point: `static func reducer(state: inout StateType, with action: Self)`
- Constraint symmetry (`ActionType.StateType == Self` and reverse) guarantees compile-time consistency between `State` and `Action`

### Store model

- `Store<State>` is a `@MainActor` class built on `CurrentValueSubject<State, Never>`
- Read current state through `state`
- Mutate state through `trigger(_ actions: State.ActionType...)`
- Observe updates with `observe(on:_:)`, with duplicate filtering (`removeDuplicates()`)
- `send(_:)` only emits when the new state differs from the current one

### Substore model

- `getSubStore(_:)` creates a two-way synchronized substore through a writable key path
- Parent -> child updates are mapped and deduplicated
- Child -> parent updates are merged back into root state
- Synchronization relies on `Equatable` to avoid unnecessary emissions

### Loadable feature

- `LoadableState<Value>` models async lifecycle: `idle`, `loading(last:)`, `loaded(_:)`
- `LoadableAction<Value>` provides: `loadingAction`, `loadedAction(success/failure)`, `otherAction(inner)`
- `otherAction` applies inner reducer only when a value exists
- Loading cancellation/fallback is handled in reducer transitions

### Current limitations

- No effect system yet (no async side-effect orchestration inside store)
- No scoped action routing from child to parent reducer (substore sync only)
- Test coverage is currently minimal (`Tests/TCAlightTests` scaffold only)

### Access Control Convention

- `public` only on types/members that the consumer module needs
- Default to `internal` for implementation details

## Code Style

- **4-space indentation**
- **PascalCase** for types, **camelCase** for properties/methods
- Prefer Swift Observation for app-layer UI state; use Combine in the package only when justified by API design
- **Swift concurrency** (async/await) over Combine
- **Swift Testing** for unit tests (not XCTest)
- No force unwrapping
- Prefer `let` over `var`
- `public` only where necessary for cross-module access
- ViewModifiers exposed via View extensions (ViewModifier is private)
- MARK: comments to organize file sections
- Doc comments (`///`) on public API

## Public API docs

- Every `public` symbol must include a concise `///` doc comment
- Public reducers and state transitions should document expected side effects (or lack thereof)

## Testing expectations

- Use `import Testing` and `@Test`
- Priority test areas:
  1. Reducer determinism and idempotence
  2. `Store.trigger` multi-action sequencing
  3. `getSubStore` two-way synchronization without feedback loops
  4. `LoadableState` transition matrix (`idle/loading/loaded`)
