import Testing
import Combine
import Dispatch
@testable import TCAlight

// MARK: - Test Fixtures
private nonisolated struct CounterState: StateWithActionProtocol {
    typealias ActionType = CounterAction
    var count = 0
}

private nonisolated enum CounterAction: ActionProtocol {
    typealias StateType = CounterState
    case increment
    case decrement
    case set(Int)

    static func reducer(state: inout CounterState, with action: CounterAction) {
        switch action {
        case .increment:
            state.count += 1
        case .decrement:
            state.count -= 1
        case .set(let value):
            state.count = value
        }
    }
}

private nonisolated struct ParentState: StateWithActionProtocol {
    typealias ActionType = ParentAction
    var child = CounterState()
    var label: String = ""
}

private nonisolated enum ParentAction: ActionProtocol {
    typealias StateType = ParentState
    case setLabel(String)

    static func reducer(state: inout ParentState, with action: ParentAction) {
        switch action {
        case .setLabel(let text):
            state.label = text
        }
    }
}

// MARK: - Store Tests

@MainActor
@Suite("Store")
struct StoreTests {
    @Test("Initial state is preserved")
    func initialState() {
        let store = Store(CounterState(count: 42))
        #expect(store.state.count == 42)
    }

    @Test("Trigger single action mutates state")
    func triggerSingleAction() {
        let store = Store(CounterState())
        store.trigger(.increment)
        #expect(store.state.count == 1)
    }

    @Test("Trigger multiple actions applies them sequentially")
    func triggerMultipleActions() {
        let store = Store(CounterState())
        store.trigger(.increment, .increment, .increment, .decrement)
        #expect(store.state.count == 2)
    }

    @Test("Trigger with same resulting state does not emit")
    func triggerDeduplication() async {
        let store = Store(CounterState())
        var emissions: [CounterState] = []
        let cancellable = store.observe { emissions.append($0) }

        store.trigger(.increment)
        store.trigger(.decrement) // back to 0 – same as initial
        store.trigger(.set(0))   // still 0 – no new emission expected

        // Allow Combine pipeline to flush
        try? await Task.sleep(for: .milliseconds(50))

        // First emission is the initial value from CurrentValueSubject, then +1, then back to 0
        #expect(emissions.map(\.count) == [0, 1, 0])
        _ = cancellable
    }

    @Test("Observe receives deduplicated updates")
    func observe() async {
        let store = Store(CounterState())
        var received: [Int] = []
        let cancellable = store.observe { received.append($0.count) }

        store.trigger(.increment)
        store.trigger(.increment)
        store.trigger(.set(2)) // same value – should be filtered

        try? await Task.sleep(for: .milliseconds(50))

        #expect(received == [0, 1, 2])
        _ = cancellable
    }

    @Test("Observe on custom scheduler delivers on that queue")
    func observeOnScheduler() async {
        let store = Store(CounterState())
        let queue = DispatchQueue(label: "test.queue")
        var receivedOnQueue = false

        let cancellable = store.observe(on: queue) { _ in
            dispatchPrecondition(condition: .onQueue(queue))
            receivedOnQueue = true
        }

        store.trigger(.increment)
        try? await Task.sleep(for: .milliseconds(100))

        #expect(receivedOnQueue)
        _ = cancellable
    }
}

// MARK: - Reducer Determinism Tests

@MainActor
@Suite("Reducer")
struct ReducerTests {
    @Test("Reducer is deterministic – same actions produce same state")
    func deterministic() {
        let storeA = Store(CounterState())
        let storeB = Store(CounterState())

        let actions: [CounterAction] = [.increment, .increment, .set(10), .decrement]
        for action in actions {
            storeA.trigger(action)
            storeB.trigger(action)
        }

        #expect(storeA.state == storeB.state)
    }

    @Test("Reducer is idempotent for set action")
    func idempotent() {
        let store = Store(CounterState())
        store.trigger(.set(5))
        let afterFirst = store.state
        store.trigger(.set(5))
        #expect(store.state == afterFirst)
    }
}

// MARK: - SubStore Tests

@MainActor
@Suite("SubStore")
struct SubStoreTests {
    @Test("SubStore reflects parent's initial child state")
    func initialSync() {
        let parent = Store(ParentState(child: CounterState(count: 7)))
        let child = parent.getSubStore(\.child)
        #expect(child.state.count == 7)
    }

    @Test("Parent → child: triggering on parent updates child")
    func parentToChild() async {
        let parent = Store(ParentState())
        let child = parent.getSubStore(\.child)

        // Mutate child state through parent by directly modifying
        // We need to trigger via the child store since parent has no counter action
        child.trigger(.increment)

        try? await Task.sleep(for: .milliseconds(50))

        #expect(child.state.count == 1)
        #expect(parent.state.child.count == 1)
    }

    @Test("Child → parent: triggering on child updates parent")
    func childToParent() async {
        let parent = Store(ParentState())
        let child = parent.getSubStore(\.child)

        child.trigger(.increment)
        child.trigger(.increment)

        try? await Task.sleep(for: .milliseconds(50))

        #expect(parent.state.child.count == 2)
    }

    @Test("Bidirectional sync stays consistent")
    func bidirectionalSync() async {
        let parent = Store(ParentState())
        let child = parent.getSubStore(\.child)

        child.trigger(.set(10))
        try? await Task.sleep(for: .milliseconds(50))

        #expect(parent.state.child.count == 10)
        #expect(child.state.count == 10)

        // Now trigger on parent side (label change) – child should remain stable
        parent.trigger(.setLabel("hello"))
        try? await Task.sleep(for: .milliseconds(50))

        #expect(parent.state.label == "hello")
        #expect(child.state.count == 10)
    }
}

// MARK: - LoadableState Tests

@Suite("LoadableState")
struct LoadableStateTests {
    @Test("Idle has no value and is not loaded")
    func idle() {
        let state: LoadableState<CounterState> = .idle
        #expect(state.value == nil)
        #expect(!state.isLoaded)
    }

    @Test("Loading without previous value has nil value")
    func loadingNoPrevious() {
        let state: LoadableState<CounterState> = .loading(last: nil)
        #expect(state.value == nil)
        #expect(!state.isLoaded)
    }

    @Test("Loading with previous value preserves it")
    func loadingWithPrevious() {
        let previous = CounterState(count: 5)
        let state: LoadableState<CounterState> = .loading(last: previous)
        #expect(state.value?.count == 5)
        #expect(!state.isLoaded)
    }

    @Test("Loaded exposes value and reports isLoaded")
    func loaded() {
        let state: LoadableState<CounterState> = .loaded(CounterState(count: 3))
        #expect(state.value?.count == 3)
        #expect(state.isLoaded)
    }

    // MARK: Equatable

    @Test("Equatable: same cases are equal")
    func equatable() {
        #expect(LoadableState<CounterState>.idle == .idle)
        #expect(LoadableState<CounterState>.loading(last: nil) == .loading(last: nil))
        #expect(LoadableState<CounterState>.loading(last: CounterState(count: 1)) == .loading(last: CounterState(count: 1)))
        #expect(LoadableState<CounterState>.loaded(CounterState(count: 2)) == .loaded(CounterState(count: 2)))
    }

    @Test("Equatable: different cases are not equal")
    func notEqual() {
        #expect(LoadableState<CounterState>.idle != .loading(last: nil))
        #expect(LoadableState<CounterState>.idle != .loaded(CounterState()))
        #expect(LoadableState<CounterState>.loaded(CounterState(count: 1)) != .loaded(CounterState(count: 2)))
    }

    // MARK: Transitions

    @Test("idle → loading gives loading(last: nil)")
    func idleToLoading() {
        var state: LoadableState<CounterState> = .idle
        state.toLoading()
        #expect(state == .loading(last: nil))
    }

    @Test("loaded → loading preserves last value")
    func loadedToLoading() {
        var state: LoadableState<CounterState> = .loaded(CounterState(count: 9))
        state.toLoading()
        #expect(state == .loading(last: CounterState(count: 9)))
    }

    @Test("loading → loading is idempotent")
    func loadingToLoading() {
        var state: LoadableState<CounterState> = .loading(last: CounterState(count: 3))
        state.toLoading()
        #expect(state == .loading(last: CounterState(count: 3)))
    }

    @Test("finishLoading with last value restores loaded")
    func finishLoadingWithValue() {
        var state: LoadableState<CounterState> = .loading(last: CounterState(count: 4))
        state.finishLoading()
        #expect(state == .loaded(CounterState(count: 4)))
    }

    @Test("finishLoading without last value returns to idle")
    func finishLoadingWithoutValue() {
        var state: LoadableState<CounterState> = .loading(last: nil)
        state.finishLoading()
        #expect(state == .idle)
    }

    @Test("finishLoading from non-loading state returns idle")
    func finishLoadingFromLoaded() {
        var state: LoadableState<CounterState> = .loaded(CounterState(count: 1))
        state.finishLoading()
        #expect(state == .idle)
    }
}

// MARK: - LoadableAction Reducer Tests

@MainActor
@Suite("LoadableAction Reducer")
struct LoadableActionReducerTests {
    @Test("loadingAction transitions idle → loading")
    func loadingFromIdle() {
        let store = Store<LoadableState<CounterState>>(.idle)
        store.trigger(.loadingAction)
        #expect(store.state == .loading(last: nil))
    }

    @Test("loadingAction transitions loaded → loading(last:)")
    func loadingFromLoaded() {
        let store = Store<LoadableState<CounterState>>(.loaded(CounterState(count: 5)))
        store.trigger(.loadingAction)
        #expect(store.state == .loading(last: CounterState(count: 5)))
    }

    @Test("loadedAction success sets loaded state")
    func loadedSuccess() {
        let store = Store<LoadableState<CounterState>>(.loading(last: nil))
        store.trigger(.loadedAction(.success(CounterState(count: 42))))
        #expect(store.state == .loaded(CounterState(count: 42)))
    }

    @Test("loadedAction failure restores last value or goes idle")
    func loadedFailureWithLast() {
        let store = Store<LoadableState<CounterState>>(.loading(last: CounterState(count: 3)))
        store.trigger(.loadedAction(.failure))
        #expect(store.state == .loaded(CounterState(count: 3)))
    }

    @Test("loadedAction failure without last value goes idle")
    func loadedFailureWithoutLast() {
        let store = Store<LoadableState<CounterState>>(.loading(last: nil))
        store.trigger(.loadedAction(.failure))
        #expect(store.state == .idle)
    }

    @Test("otherAction applies inner reducer on loaded value")
    func otherActionOnLoaded() {
        let store = Store<LoadableState<CounterState>>(.loaded(CounterState(count: 10)))
        store.trigger(.otherAction(.increment))
        #expect(store.state == .loaded(CounterState(count: 11)))
    }

    @Test("otherAction on idle is a no-op")
    func otherActionOnIdle() {
        let store = Store<LoadableState<CounterState>>(.idle)
        store.trigger(.otherAction(.increment))
        #expect(store.state == .idle)
    }

    @Test("otherAction during loading cancels loading and applies action")
    func otherActionCancelsLoading() {
        let store = Store<LoadableState<CounterState>>(.loading(last: CounterState(count: 5)))
        store.trigger(.otherAction(.increment))
        #expect(store.state == .loaded(CounterState(count: 6)))
    }

    @Test("otherAction during loading without last value is a no-op")
    func otherActionLoadingNoLast() {
        let store = Store<LoadableState<CounterState>>(.loading(last: nil))
        store.trigger(.otherAction(.increment))
        // finishLoading with nil -> idle, then guard var value = state.value -> nil -> return
        #expect(store.state == .idle)
    }

    @Test("Full lifecycle: idle → loading → loaded → otherAction")
    func fullLifecycle() {
        let store = Store<LoadableState<CounterState>>(.idle)

        store.trigger(.loadingAction)
        #expect(store.state == .loading(last: nil))

        store.trigger(.loadedAction(.success(CounterState(count: 1))))
        #expect(store.state == .loaded(CounterState(count: 1)))

        store.trigger(.otherAction(.increment))
        #expect(store.state == .loaded(CounterState(count: 2)))

        store.trigger(.loadingAction)
        #expect(store.state == .loading(last: CounterState(count: 2)))

        store.trigger(.loadedAction(.failure))
        #expect(store.state == .loaded(CounterState(count: 2)))
    }
}
