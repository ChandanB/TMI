//
//  ViewState.swift
//  The Social Point
//
//  Created by Chandan Brown on 3/30/25.
//

import Foundation

/// Enum representing the different view states in a state-driven UI
enum ViewState<T, E: Error> {
    case idle
    case loading
    case loaded(T)
    case error(E)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var value: T? {
        if case .loaded(let value) = self {
            return value
        }
        return nil
    }
    
    var error: E? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }
    
    /// Maps the value of this ViewState to a new value using the provided transform function
    func map<U>(_ transform: (T) -> U) -> ViewState<U, E> {
        switch self {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .loaded(let value):
            return .loaded(transform(value))
        case .error(let error):
            return .error(error)
        }
    }
    
    /// Executes the provided closure if this ViewState is in the loaded state
    func ifLoaded(_ action: (T) -> Void) {
        if case .loaded(let value) = self {
            action(value)
        }
    }
    
    /// Executes the provided closure if this ViewState is in the error state
    func ifError(_ action: (E) -> Void) {
        if case .error(let error) = self {
            action(error)
        }
    }
}

/// Extension to make ViewState equatable when the content is equatable
extension ViewState: Equatable where T: Equatable, E: Equatable {
    static func == (lhs: ViewState<T, E>, rhs: ViewState<T, E>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case (.loaded(let lhsValue), .loaded(let rhsValue)):
            return lhsValue == rhsValue
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}
