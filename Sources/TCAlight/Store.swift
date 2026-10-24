//
//  Store.swift
//  GamePoints
//
//  Created by Yann Bonafons on 11/02/2026.
//

import Foundation
import Combine

/// Main state container that applies actions and publishes state updates.
public final class Store<State: StateWithActionProtocol> {
    // MARK: - Private Properties
    private let subject: CurrentValueSubject<State, Never>
    private var cancellables: Set<AnyCancellable> = []
    private let identifier = UUID()

    // MARK: - Public Properties
    /// The current state snapshot.
    public var state: State {
        subject.value
    }

    // MARK: - Public functions
    /// Creates a store with an initial state.
    /// - Parameter initialValue: The initial state value.
    public init(_ initialValue: State) {
        self.subject = .init(initialValue)
    }
    
    /// Subscribes to deduplicated changes of a part of the state.
    /// - Parameters:
    ///   - keyPath: Which subpart of the State is observed
    ///   - scheduler: Optional scheduler used to receive updates. Defaults to immediate delivery on the current context.
    ///   - action: Callback invoked on each deduplicated state update.
    /// - Returns: A cancellable token. Keep a strong reference to continue receiving updates.
    public func observe<Value: Equatable>(_ keyPath: KeyPath<State, Value>,
                                          on scheduler: DispatchQueue? = nil,
                                          _ action: @escaping (Value) -> Void) -> AnyCancellable {
        let publisher = subject
            .map(keyPath)
            .removeDuplicates()

        if let scheduler {
            return publisher
                .receive(on: scheduler)
                .sink(receiveValue: action)
        } else {
            return publisher
                .sink(receiveValue: action)
        }
    }
    
    /// Subscribes to deduplicated state changes.
    /// - Parameters:
    ///   - scheduler: Optional scheduler used to receive updates. Defaults to immediate delivery on the current context.
    ///   - action: Callback invoked on each deduplicated state update.
    /// - Returns: A cancellable token. Keep a strong reference to continue receiving updates.
    public func observe(on scheduler: DispatchQueue? = nil,
                        _ action: @escaping (State) -> Void) -> AnyCancellable {
        observe(\.self, on: scheduler, action)
    }
    
    /// Applies one or more actions sequentially and publishes the final state if it changed.
    /// - Parameter actions: Actions to apply in order.
    public func trigger(_ actions: State.ActionType...) {
        var currentState = state
        for action in actions {
            State.ActionType.reducer(state: &currentState, with: action)
        }
        send(currentState)
    }
    
    /// Creates a bidirectionally synchronized store scoped to a child state.
    ///
    /// Synchronization subscriptions are owned by the returned substore and released with it.
    /// The substore keeps its parent alive for as long as it exists.
    /// - Parameter stateKeyPath: Writable key path to the child state.
    /// - Returns: A store focused on the selected child state.
    public func getSubStore<SubState: StateWithActionProtocol>(_ stateKeyPath: WritableKeyPath<State, SubState>) -> Store<SubState> {
        let subStore = Store<SubState>(self.state[keyPath: stateKeyPath])

        // Parent -> Child
        subject
            .map {
                $0[keyPath: stateKeyPath]
            }
            .removeDuplicates()
            .sink { [weak subStore] newSubState in
                subStore?.send(newSubState)
            }
            .store(in: &subStore.cancellables)
        
        // Child -> Parent
        // Both subscriptions are owned by the substore so they are released with it.
        // The parent is captured strongly: a substore keeps its parent alive (no retain cycle,
        // since the parent never references the substore), preventing silent desynchronization.
        subStore.subject
            .removeDuplicates()
            .sink { newSub in
                var current = self.state
                current[keyPath: stateKeyPath] = newSub
                self.send(current)
            }
            .store(in: &subStore.cancellables)
        
        return subStore
    }

    // MARK: - Private functions
    /// Trigger an update only if `newValue` if differente from current `subject.value`
    private func send(_ newState: State) {
        guard state != newState else {
            return
        }
        subject.send(newState)
    }
}

extension Store: Hashable {
    public static func == (lhs: Store<State>, rhs: Store<State>) -> Bool {
        lhs.identifier == rhs.identifier
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}

extension Store where State: PersistableState {
    /// Use this function to load a saved data into your State. Will trigger the observation. Nothing will happen if no data has been saved
    public func loadState() async {
        guard let savedDataModel = try? await state.getSavedData() else {
            return
        }
        var currentState = state
        currentState.dataModel = savedDataModel
        send(currentState)
    }
}
