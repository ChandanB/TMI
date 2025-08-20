//
//  AsyncTaskHandler.swift
//  The Social Point
//
//  Created by Chandan Brown on 3/30/25.
//

import SwiftUI
import Firebase

/// Represents the result of an asynchronous task
enum TaskResult<T> {
    case success(T)
    case failure(Error)
    
    /// Maps the success value to a new value using the provided transform function
    func map<U>(_ transform: (T) -> U) -> TaskResult<U> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Extracts the success value or throws the error
    func get() throws -> T {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
    
    /// Returns the success value or a default value if there was an error
    func getOrDefault(_ defaultValue: T) -> T {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return defaultValue
        }
    }
}

/// A class to manage async task execution with state transitions
@Observable
final class AsyncTaskHandler<State, Result> {
    typealias TaskFunction = () async throws -> Result
    typealias StateTransformer = (State, TaskResult<Result>) -> State
    
    /// Whether a task is currently running
    private(set) var isRunning = false
    
    /// The last error that occurred, if any
    private(set) var lastError: Error?
    
    /// The current task, if any
    private var currentTask: Task<Void, Never>?
    
    /// Executes an asynchronous task and updates state based on the result
    /// - Parameters:
    ///   - initialState: The initial state to transform
    ///   - stateBinding: A binding to the state to update
    ///   - task: The asynchronous task to execute
    ///   - transform: A closure that transforms the state based on the task result
    @MainActor
    func execute(
        initialState: State,
        stateBinding: Binding<State>,
        task: @escaping TaskFunction,
        transform: @escaping StateTransformer
    ) async {
        guard !isRunning else { return }
        
        // Cancel any existing task
        currentTask?.cancel()
        
        isRunning = true
        lastError = nil
        
        // Create a new task
        currentTask = Task {
            do {
                let result = try await task()
                
                // Only update state if the task wasn't cancelled
                if !Task.isCancelled {
                    await MainActor.run {
                        stateBinding.wrappedValue = transform(initialState, .success(result))
                        isRunning = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        lastError = error
                        stateBinding.wrappedValue = transform(initialState, .failure(error))
                        isRunning = false
                    }
                }
            }
        }
    }
    
    /// Executes an asynchronous task with a simpler interface
    /// - Parameters:
    ///   - stateBinding: A binding to the state to update
    ///   - task: The asynchronous task to execute
    ///   - onSuccess: A closure to call when the task succeeds
    ///   - onFailure: A closure to call when the task fails
    @MainActor
    func executeSimple(
        stateBinding: Binding<State>,
        task: @escaping TaskFunction,
        onSuccess: @escaping (Result) -> State,
        onFailure: @escaping (Error) -> State
    ) async {
        let initialState = stateBinding.wrappedValue
        
        await execute(
            initialState: initialState,
            stateBinding: stateBinding,
            task: task,
            transform: { _, result in
                switch result {
                case .success(let value):
                    return onSuccess(value)
                case .failure(let error):
                    return onFailure(error)
                }
            }
        )
    }
    
    /// Cancels the current task if one is running
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        
        // Reset running state directly since we're already on MainActor
        isRunning = false
    }
    
    deinit {
        cancel()
    }
}
