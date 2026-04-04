//
//  BaseStateModel.swift
//  The Social Point
//
//  Created by Chandan Brown on 3/30/25.
//

import Firebase
import SwiftUI
import Foundation
import Observation
import Combine

/// A protocol that defines common functionality for state models
protocol StateModelProtocol {
    associatedtype ModelType
    associatedtype ErrorType: Error
    
    var state: ViewState<ModelType, ErrorType> { get }
    
    @MainActor
    func fetch() async
    
    @MainActor
    func refresh() async
    
    func resetState()
}

/// Base protocol for state model errors that can be identified
protocol IdentifiableStateModelError: Error, Identifiable {
    var id: String { get }
    var errorDescription: String { get }
}

/// Class to manage Firebase listeners with proper lifecycle handling
class ListenerManager {
    private var listeners: [String: ListenerRegistration] = [:]
    private var isPaused: Bool = false
    private var pauseTime: Date?
    private let maxPauseDuration: TimeInterval = 300 // 5 minutes
    
    /// Add a listener with a unique identifier
    func addListener(id: String, listener: ListenerRegistration) {
        removeListener(id: id)
        listeners[id] = listener
    }
    
    /// Remove a specific listener by ID
    func removeListener(id: String) {
        listeners[id]?.remove()
        listeners[id] = nil
    }
    
    /// Remove all listeners
    func removeAllListeners() {
        for (id, _) in listeners {
            removeListener(id: id)
        }
        listeners.removeAll()
    }
    
    /// Pause all listeners (e.g., when app goes to background)
    func pauseListeners() {
        isPaused = true
        pauseTime = Date()
    }
    
    /// Resume listeners if they haven't been paused for too long
    func resumeListeners() -> Bool {
        // If paused for too long, return false to indicate a refresh is needed
        if let pauseTime = pauseTime,
           Date().timeIntervalSince(pauseTime) > maxPauseDuration {
            return false
        }
        
        isPaused = false
        return true
    }
    
    /// Check if listeners are currently paused
    var isListeningPaused: Bool {
        return isPaused
    }
    
    deinit {
        removeAllListeners()
    }
}

/// A structure to group UI state properties
struct UIState {
    // Common UI state properties
    var isEditing: Bool = false
    var isShowingDetail: Bool = false
    var isShowingSheet: Bool = false
    var isShowingAlert: Bool = false
    var alertMessage: String = ""
    var selectedIndex: Int = 0
    
    // Custom properties dictionary for model-specific UI state
    private var properties: [String: Any] = [:]
    
    /// Set a custom UI state property
    mutating func set<T>(_ key: String, value: T) {
        properties[key] = value
    }
    
    /// Get a custom UI state property
    func get<T>(_ key: String) -> T? {
        return properties[key] as? T
    }
    
    /// Reset all UI state to default values
    mutating func reset() {
        isEditing = false
        isShowingDetail = false
        isShowingSheet = false
        isShowingAlert = false
        alertMessage = ""
        selectedIndex = 0
        properties.removeAll()
    }
}

/// A base class implementing common state model functionality
@Observable
class BaseStateModel<T, E: Error>: StateModelProtocol {
    typealias ModelType = T
    typealias ErrorType = E
    
    // MARK: - Properties
    
    /// The current state of the model
    private(set) var state: ViewState<T, E> = .idle
    
    /// UI state properties
    var ui = UIState()
    
    /// Task manager for handling async tasks
    private var tasks: [UUID: Task<Void, Never>] = [:]
    
    /// Listener manager for Firebase listeners
    let listenerManager = ListenerManager()
    
    // MARK: - Computed Properties
    
    /// Whether the model is currently loading
    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    /// Whether the model has an error
    var hasError: Bool {
        if case .error = state { return true }
        return false
    }

    /// The error message, if any
    var errorMessage: String? {
        if case .error(let error) = state {
            return (error as? IdentifiableError)?.errorDescription ?? error.localizedDescription
        }
        return nil
    }

    /// The current value, if loaded
    var value: T? {
        if case .loaded(let value) = state {
            return value
        }
        return nil
    }
    
    // MARK: - Lifecycle Methods
    
    deinit {
        cancelAllTasks()
        listenerManager.removeAllListeners()
    }
    
    // MARK: - Public Methods
    
    /// Fetches data for the model
    /// This is a base implementation that should be overridden by subclasses
    @MainActor
    func fetch() async {
        // Default implementation does nothing
        // Subclasses should override this method
    }
    
    /// Refreshes the model by resetting state and fetching again
    @MainActor
    func refresh() async {
        resetState()
        await fetch()
    }
    
    /// Resets the state to idle
    func resetState() {
        state = .idle
        ui.reset()
    }
    
    /// Updates the state of the model
    @MainActor
    func updateState(_ newState: ViewState<T, E>) {
        state = newState
    }
    
    /// Handle an error by converting it to the appropriate error type and updating state
    @MainActor
    func handleError(_ error: Error, userFriendlyMessage: String? = nil) {
        let handledError = ErrorHandlingHelper.handleRepositoryError(
            error,
            userFriendlyMessage: userFriendlyMessage
        )
        
        if let typedError = handledError as? E {
            updateState(.error(typedError))
        } else {
            // Create a generic error of type E if possible
            // This depends on your error type implementation
            print("Warning: Error type mismatch in handleError")
            // Fallback approach if you have a way to create a generic error
            // updateState(.error(E.genericError(message: handledError.localizedDescription)))
        }
    }
    
    // MARK: - Task Management Methods
    
    /// Executes an asynchronous task and manages its lifecycle
    @discardableResult
    func startTask(_ operation: @escaping () async -> Void) -> UUID {
        let id = UUID()
        let task = Task {
            await operation()
            // Remove task reference when complete
            self.tasks[id] = nil
        }
        
        tasks[id] = task
        return id
    }
    
    /// Cancels a specific task by ID
    func cancelTask(id: UUID) {
        tasks[id]?.cancel()
        tasks[id] = nil
    }
    
    /// Cancels all running tasks
    func cancelAllTasks() {
        for (_, task) in tasks {
            task.cancel()
        }
        tasks.removeAll()
    }
    
    // MARK: - Task Execution Methods
    
    /// Executes an asynchronous task and transforms its result into a new state
    /// - Parameters:
    ///   - task: The asynchronous task to execute
    ///   - transform: A closure that transforms the current state and task result into a new state
    @MainActor
    func executeTask<R>(
        task: @escaping () async throws -> R,
        transform: @escaping (ViewState<T, E>, TaskResult<R>) -> ViewState<T, E>
    ) async {
        let handler = AsyncTaskHandler<ViewState<T, E>, R>()
        await handler.execute(
            initialState: state,
            stateBinding: Binding<ViewState<T, E>>(
                get: { self.state },
                set: { self.updateState($0) }
            ),
            task: task,
            transform: transform
        )
    }
    
    /// Executes a task with loading state and standard success/error handling
    /// - Parameters:
    ///   - task: The asynchronous task to execute
    ///   - success: A closure that transforms the successful result into the model type
    @MainActor
    func executeLoadingTask<R>(
        task: @escaping () async throws -> R,
        success: @escaping (R) -> T
    ) async {
        updateState(.loading)
        await executeTask(
            task: task,
            transform: { _, result in
                switch result {
                case .success(let value):
                    return .loaded(success(value))
                case .failure(let error):
                    return .error(ErrorHandlingHelper.handleRepositoryError(error) as! E)
                }
            }
        )
    }
    
    /// Performs an optimistic update on a collection
    /// - Parameters:
    ///   - item: The item to update
    ///   - updatedItem: The updated version of the item
    ///   - action: The action to perform, which returns a boolean indicating success
    @MainActor
    func performOptimisticUpdate<ItemType: Equatable>(
        item: ItemType,
        updatedItem: ItemType,
        action: @escaping () async throws -> Bool
    ) async where T == [ItemType] {
        guard case .loaded(var items) = state else { return }
        
        // Find and update the item in the collection
        if let index = items.firstIndex(where: { $0 == item }) {
            let originalItem = items[index]
            items[index] = updatedItem
            updateState(.loaded(items))
            
            do {
                let success = try await action()
                if !success {
                    // Revert on failure
                    revertOptimisticUpdate(originalItem: originalItem, updatedItem: updatedItem)
                }
            } catch {
                // Revert on error
                revertOptimisticUpdate(originalItem: originalItem, updatedItem: updatedItem)
            }
        }
    }
    
    // MARK: - Firebase Listener Methods
    
    /// Add a Firebase listener with a unique ID
    func addListener(id: String, listener: ListenerRegistration) {
        listenerManager.addListener(id: id, listener: listener)
    }
    
    /// Remove a specific Firebase listener
    func removeListener(id: String) {
        listenerManager.removeListener(id: id)
    }
    
    /// Remove all Firebase listeners
    func removeAllListeners() {
        listenerManager.removeAllListeners()
    }
    
    /// Pause listeners (e.g., when view disappears)
    func pauseListeners() {
        listenerManager.pauseListeners()
    }
    
    /// Resume listeners and return whether a refresh is needed
    func resumeListeners() -> Bool {
        return listenerManager.resumeListeners()
    }
    
    // MARK: - Private Helper Methods
    
    /// Reverts an optimistic update if it fails
    /// - Parameters:
    ///   - originalItem: The original item before the update
    ///   - updatedItem: The updated item that needs to be reverted
    @MainActor
    private func revertOptimisticUpdate<ItemType: Equatable>(
        originalItem: ItemType,
        updatedItem: ItemType
    ) where T == [ItemType] {
        if case .loaded(var currentItems) = state,
           let revertIndex = currentItems.firstIndex(where: { $0 == updatedItem }) {
            currentItems[revertIndex] = originalItem
            updateState(.loaded(currentItems))
        }
    }
}

// MARK: - Error Boundary Component

/// Error boundary to catch and handle errors gracefully
struct TMIErrorBoundary<Content: View>: View {
    let content: Content
    @State private var error: IdentifiableError?

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Group {
            if let error = error {
                TMICard(style: .default) {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)

                        Text("Something went wrong")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.tmiTextPrimary)

                        Text(error.message)
                            .font(.system(size: 14))
                            .foregroundColor(Color.tmiTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        TMIButton(
                            text: "Try Again",
                            style: .secondary,
                            action: {
                                withAnimation {
                                    self.error = nil
                                }
                            }
                        )
                        .padding(.top)
                    }
                    .padding()
                }
                .transition(.opacity.combined(with: .scale))
            } else {
                content
                    .onReceive(NotificationCenter.default.publisher(for: .TMIErrorOccurred)) { notification in
                        if let error = notification.object as? IdentifiableError {
                            withAnimation {
                                self.error = error
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Error Notification Extension

extension Notification.Name {
    static let TMIErrorOccurred = Notification.Name("TMIErrorOccurred")
}

// MARK: - Extensions for View Modifiers

extension View {
    /// Wrap view in error boundary
    func errorBoundary() -> some View {
        TMIErrorBoundary {
            self
        }
    }
}

