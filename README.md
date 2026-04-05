# TCAlight

Lightweight state container inspired by TCA.

## Requirements

- iOS 17+
- Swift 6.0
- Xcode 26+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/yannbonafons/TCAlight", from: "1.0.0")
]
```

## Quick Start

Define a state and its action reducer:

```swift
import TCAlight

struct CounterState: StateWithActionProtocol {
    typealias ActionType = CounterAction
    var count = 0
}

enum CounterAction: ActionProtocol {
    typealias StateType = CounterState

    case increment
    case decrement

    static func reducer(state: inout CounterState, with action: CounterAction) {
        switch action {
        case .increment:
            state.count += 1
        case .decrement:
            state.count -= 1
        }
    }
}
```

Create a store, observe changes, then trigger actions:

```swift
let store = Store(CounterState())

let cancellable = store.observe { state in
    print("count:", state.count)
}

store.trigger(.increment)
store.trigger(.increment, .decrement)
```

Use `LoadableState` for async lifecycle:

```swift
var loadable: LoadableState<CounterState> = .idle
LoadableAction<CounterState>.reducer(state: &loadable, with: .loadingAction)
LoadableAction<CounterState>.reducer(
    state: &loadable,
    with: .loadedAction(.success(.init(count: 42)))
)
```

## Example App: TCAlightApp

Launch the example app located in `Example/` for a complete integration sample.
