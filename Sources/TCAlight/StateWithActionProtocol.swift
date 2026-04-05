//
//  StateWithActionProtocol.swift
//  GamePoints
//
//  Created by Yann Bonafons on 11/02/2026.
//

import Foundation

/// A state type that is associated with exactly one action type.
public protocol StateWithActionProtocol<ActionType>: Equatable, Sendable where ActionType.StateType == Self {
    /// The action type that can mutate this state.
    associatedtype ActionType: ActionProtocol
}

/// A reducer protocol that mutates a state for a given action.
public protocol ActionProtocol<StateType> where StateType.ActionType == Self {
    /// The state type handled by this reducer.
    associatedtype StateType: StateWithActionProtocol
    
    /// Applies one action to the provided mutable state.
    /// - Parameters:
    ///   - state: The current state to mutate in place.
    ///   - action: The action to apply.
    static func reducer(state: inout StateType, with action: Self)
}
