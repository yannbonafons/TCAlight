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

## DataModel / DTO

`DataModel` and `DTO` decouple the data your app manipulates from the shape used by the API or
storage layer. A `DataModel` is initialized from its `DTO`, and vice versa; each side exposes a
computed property to convert to the other:

```swift
struct UserDTO: DTO {
    typealias DataModelType = User
    var name: String
    var age: Int

    init(dataModel: User) {
        name = dataModel.name
        age = dataModel.age
    }
}

struct User: DataModel {
    typealias DTOType = UserDTO
    var name: String
    var age: Int

    init(dto: UserDTO) {
        name = dto.name
        age = dto.age
    }
}

let user = User(name: "Ada", age: 30)
let dto = user.dto           // UserDTO
let restored = dto.dataModel // User
```

`Array` and `Optional` conditionally conform to `DataModel`/`DTO` when their `Element`/`Wrapped`
does, so `[User].dto`, `[UserDTO].dataModel`, `User?.dto`, and `UserDTO?.dataModel` all work out
of the box.

## PersistableState

Conform a `State` to `PersistableState` to make it persistable. Provide a `storageKey`, and
implement the save/load/delete functions using whatever storage mechanism you choose (e.g.
`UserDefaults`, `FileManager`), encoding the `persistedDTO` for storage:

```swift
struct AppState: StateWithActionProtocol, PersistableState {
    typealias DataModelType = User
    var dataModel: User = .init(name: "", age: 0)
    let storageKey = "app.user"

    func persistData() async throws {
        let data = try JSONEncoder().encode(persistedDTO)
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func getSavedData() async throws -> User? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try JSONDecoder().decode(UserDTO.self, from: data).dataModel
    }

    func deleteSavedData() async {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
```

Then load the saved value into the store, which publishes the update like any other state change:

```swift
let store = Store(AppState())
await store.loadState()
```

## Example App: TCAlightApp

Launch the example app located in `Example/` for a complete integration sample.
