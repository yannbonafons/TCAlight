//
//  LoadableState.swift
//  GamePoints
//
//  Created by Yann Bonafons on 11/02/2026.
//

import Foundation

/// Represents an asynchronous loading lifecycle for a state value.
public enum LoadableState<LoadableType: StateWithActionProtocol>: StateWithActionProtocol {
    /// The associated action type for `LoadableState`.
    public typealias ActionType = LoadableAction<LoadableType>

    /// No value has been requested yet.
    case idle
    /// A request is in-flight and may keep the last loaded value.
    case loading(last: LoadableType?)
    /// A value has been fully loaded.
    case loaded(LoadableType)

    /// The current value when available.
    public var value: LoadableType? {
        switch self {
        case let .loaded(value): return value
        case let .loading(last): return last
        default: return nil
        }
    }
    
    /// `true` when the state is currently `.loaded`.
    public var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }

    public static nonisolated func == (lhs: LoadableState<LoadableType>, rhs: LoadableState<LoadableType>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case let (.loading(lhs), .loading(rhs)):
            return lhs == rhs
        case let (.loaded(lhsV), .loaded(rhsV)):
            return lhsV == rhsV
        default: return false
        }
    }
    
    mutating func toLoading() {
        self = switch self {
        case .idle:
            .loading(last: nil)
        case .loading:
            self
        case let .loaded(value):
            .loading(last: value)
        }
    }
    
    mutating func finishLoading() {
        self = switch self {
        case .loading(let last):
            if let last {
                .loaded(last)
            } else {
                .idle
            }
        default:
            .idle
        }
    }
}
