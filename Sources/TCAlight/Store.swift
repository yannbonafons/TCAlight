//
//  Store.swift
//  GamePoints
//
//  Created by Yann Bonafons on 11/02/2026.
//

import Foundation
import Combine

/// Main state container that applies actions and publishes state updates.
@MainActor
public final class Store<State: StateWithActionProtocol> {
    // MARK: - Private Properties
    private let subject: CurrentValueSubject<State, Never>
    private var cancellables: Set<AnyCancellable> = []

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
    
    /// Subscribes to deduplicated state changes.
    /// - Parameters:
    ///   - scheduler: Optional scheduler used to receive updates. Defaults to immediate delivery on the current context.
    ///   - action: Callback invoked on each deduplicated state update.
    /// - Returns: A cancellable token. Keep a strong reference to continue receiving updates.
    public func observe(on scheduler: DispatchQueue? = nil,
                        _ action: @escaping (State) -> Void) -> AnyCancellable {
        if let scheduler {
            subject
                .removeDuplicates()
                .receive(on: scheduler)
                .sink(receiveValue: action)
        } else {
            subject
                .removeDuplicates()
                .sink(receiveValue: action)
        }
    }
    
    /// Applies one or more actions sequentially and publishes the final state if it changed.
    /// - Parameter actions: Actions to apply in order.
    public func trigger(_ actions: State.ActionType...) {
        var currentState = subject.value
        for action in actions {
            State.ActionType.reducer(state: &currentState, with: action)
        }
        send(currentState)
    }
    
    /// Creates a bidirectionally synchronized store scoped to a child state.
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
        subStore.subject
            .removeDuplicates()
            .sink { [weak self] newSub in
                guard let self else {
                    return
                }
                var current = subject.value
                current[keyPath: stateKeyPath] = newSub
                send(current)
            }
            .store(in: &cancellables)
        
        return subStore
    }

    // MARK: - Private functions
    /// Trigger an update only if `newValue` if differente from current `subject.value`
    private func send(_ newState: State) {
        guard subject.value != newState else {
            return
        }
        subject.send(newState)
    }
}
