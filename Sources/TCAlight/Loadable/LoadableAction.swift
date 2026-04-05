//
//  LoadableAction.swift
//  GamePoints
//
//  Created by Yann Bonafons on 11/02/2026.
//

import Foundation

/// Actions dedicated to `LoadableState` transitions.
public enum LoadableAction<Value: StateWithActionProtocol>: ActionProtocol {
    /// The state reduced by `LoadableAction`.
    public typealias StateType = LoadableState<Value>

    /// Starts a loading phase.
    case loadingAction
    /// Finishes a loading phase with either a value or a failure.
    case loadedAction(LoadedState<Value>)
    /// Applies an action on the wrapped loaded value.
    case otherAction(Value.ActionType)

    /// Reduces one `LoadableAction` into a `LoadableState`.
    /// - Parameters:
    ///   - state: The loadable state to mutate.
    ///   - action: The action to apply.
    public static func reducer(state: inout LoadableState<Value>, with action: Self) {
        switch action {
        case .loadingAction:
            state.toLoading()

        case .loadedAction(let loadedState):
            switch loadedState {
            case .failure:
                state.finishLoading()
            case .success(let value):
                state = .loaded(value)
            }

        case .otherAction(let innerAction):
            // Cancel loading before applying custom action
            if case .loading = state {
                state.finishLoading()
            }

            // Check if value is not nil before applying custom action
            guard var value = state.value else {
                return
            }
            
            // Apply custom action
            Value.ActionType.reducer(state: &value, with: innerAction)
            state = .loaded(value)
        }
    }
}

/// Represents the completion result of a loading operation.
public enum LoadedState<Value> {
    /// Loading succeeded with a value.
    case success(Value)
    /// Loading failed.
    case failure
}
