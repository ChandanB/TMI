//
//  OptimisticUpdateManager.swift
//  The Social Point
//
//  Created by Chandan Brown on 3/30/25.
//

import SwiftUI

/// Error types specific to optimistic updates
enum OptimisticUpdateError: Error {
    case alreadyProcessing
    case updateFailed(Error)
    case actionReturnedFalse
}

/// A manager for handling optimistic updates with automatic rollback
@Observable
final class OptimisticUpdateManager<T: Equatable> {
    // MARK: - Properties
    
    /// The original state before an optimistic update
    private var originalState: T?
    
    /// The current state of the managed value
    private(set) var currentState: T
    
    /// Indicates whether an update operation is in progress
    private(set) var isProcessing = false
    
    /// Tracks the last error that occurred during an update
    private(set) var lastError: OptimisticUpdateError?
    
    // MARK: - Initialization
    
    /// Creates a new optimistic update manager with the specified initial state
    /// - Parameter initialState: The initial state to manage
    init(initialState: T) {
        self.currentState = initialState
    }
    
    // MARK: - Public Methods
    
    /// Performs an optimistic update with automatic rollback on failure
    /// - Parameters:
    ///   - newState: The new state to optimistically apply
    ///   - action: The async action to perform that confirms the update
    /// - Returns: A boolean indicating whether the update was successful
    @MainActor
    func performOptimisticUpdate(
        newState: T,
        action: @escaping () async throws -> Bool
    ) async -> Bool {
        guard !isProcessing else {
            lastError = .alreadyProcessing
            return false
        }
        
        isProcessing = true
        originalState = currentState
        currentState = newState
        
        do {
            let success = try await action()
            if !success {
                // If the action returns false, revert to original state
                revertToOriginalState()
                lastError = .actionReturnedFalse
                isProcessing = false
                originalState = nil
                return false
            }
            
            // Clear any previous errors on success
            lastError = nil
            isProcessing = false
            originalState = nil
            return true
        } catch {
            // On error, revert to original state
            revertToOriginalState()
            lastError = .updateFailed(error)
            isProcessing = false
            originalState = nil
            return false
        }
    }
    
    /// Manually updates the current state without performing an action
    /// - Parameter newState: The new state to set
    @MainActor
    func updateState(_ newState: T) {
        guard !isProcessing else { return }
        currentState = newState
    }
    
    /// Resets the manager to a specific state, clearing any errors
    /// - Parameter state: The state to reset to
    @MainActor
    func reset(to state: T) {
        currentState = state
        originalState = nil
        isProcessing = false
        lastError = nil
    }
    
    // MARK: - Private Methods
    
    /// Reverts the current state to the original state if available
    private func revertToOriginalState() {
        if let originalState = originalState {
            currentState = originalState
        }
    }
}

// MARK: - Convenience Extensions

extension OptimisticUpdateManager {
    /// Creates a new manager with a value type and applies a transform function to it
    /// - Parameters:
    ///   - value: The initial value
    ///   - transform: A function that transforms the value to the managed state type
    /// - Returns: A configured OptimisticUpdateManager
    static func create<V>(with value: V, transform: (V) -> T) -> OptimisticUpdateManager<T> {
        OptimisticUpdateManager(initialState: transform(value))
    }
}
