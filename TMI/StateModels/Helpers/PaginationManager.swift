//
//  PaginationManager.swift
//  The Social Point
//
//  Created by Chandan Brown on 3/30/25.
//

import Firebase
import Foundation
import Observation

/// A class to manage pagination state across different state models
@Observable
final class PaginationManager<T> {
    // MARK: - Properties
    
    /// The collection of items loaded so far
    private(set) var items: [T] = []
    
    /// Whether a pagination request is currently in progress
    private(set) var isLoading = false
    
    /// Whether there are more items to load
    private(set) var hasMoreItems = true
    
    /// The last document retrieved, used for Firebase pagination
    private var lastDocument: DocumentSnapshot?
    
    /// The number of items to load per page
    private let pageSize: Int
    
    /// The total number of items loaded so far
    var count: Int {
        return items.count
    }
    
    /// Whether more items can be loaded
    var canLoadMore: Bool {
        return hasMoreItems && !isLoading
    }
    
    /// The last document retrieved, used for Firebase pagination
    var currentLastDocument: DocumentSnapshot? {
        return lastDocument
    }
    
    /// The configured page size
    var currentPageSize: Int {
        return pageSize
    }
    
    // MARK: - Initialization
    
    /// Initialize a new pagination manager
    /// - Parameter pageSize: The number of items to load per page
    init(pageSize: Int = 10) {
        self.pageSize = pageSize
    }
    
    // MARK: - Public Methods
    
    /// Reset the pagination state
    func reset() {
        items = []
        lastDocument = nil
        hasMoreItems = true
        isLoading = false
    }
    
    /// Update the pagination state with new items
    /// - Parameters:
    ///   - newItems: The new items to add or replace existing items
    ///   - lastDoc: The last document retrieved, used for Firebase pagination
    ///   - append: Whether to append the new items or replace existing items
    func update(newItems: [T], lastDoc: DocumentSnapshot?, append: Bool = false) {
        if append && !items.isEmpty {
            items.append(contentsOf: newItems)
        } else {
            items = newItems
        }
        
        lastDocument = lastDoc
        hasMoreItems = lastDoc != nil && newItems.count >= pageSize
    }
    
    /// Set the loading state
    /// - Parameter loading: Whether a pagination request is in progress
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    /// Get an item at a specific index
    /// - Parameter index: The index of the item to retrieve
    /// - Returns: The item at the specified index, or nil if the index is out of bounds
    func item(at index: Int) -> T? {
        guard index >= 0, index < items.count else { return nil }
        return items[index]
    }
    
    /// Update a specific item in the collection
    /// - Parameters:
    ///   - index: The index of the item to update
    ///   - item: The new item value
    func updateItem(at index: Int, with item: T) {
        guard index >= 0, index < items.count else { return }
        items[index] = item
    }
    
    /// Remove an item at a specific index
    /// - Parameter index: The index of the item to remove
    func removeItem(at index: Int) {
        guard index >= 0, index < items.count else { return }
        items.remove(at: index)
    }
    
    /// Insert an item at a specific index
    /// - Parameters:
    ///   - item: The item to insert
    ///   - index: The index at which to insert the item
    func insertItem(_ item: T, at index: Int) {
        guard index >= 0, index <= items.count else { return }
        items.insert(item, at: index)
    }
    
    /// Add an item to the beginning of the collection
    /// - Parameter item: The item to add
    func prependItem(_ item: T) {
        items.insert(item, at: 0)
    }
    
    /// Add an item to the end of the collection
    /// - Parameter item: The item to add
    func appendItem(_ item: T) {
        items.append(item)
    }
}


/// A specialized state model for paginated data
@Observable
class PaginatedStateModel<T, E: Error>: BaseStateModel<[T], E> {
    // MARK: - Properties
    
    /// Manager for handling pagination
    private(set) var paginationManager: PaginationManager<T>
    
    /// The number of items to load per page
    private let pageSize: Int
    
    // MARK: - Initialization
    
    /// Initializes a new paginated state model
    /// - Parameter pageSize: The number of items to load per page
    init(pageSize: Int = 10) {
        self.pageSize = pageSize
        self.paginationManager = PaginationManager<T>(pageSize: pageSize)
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Loads the next page of data
    /// - Parameter loadFunction: A function that loads a page of data given the last document
    @MainActor
    func loadNextPage(
        loadFunction: @escaping (DocumentSnapshot?) async throws -> (items: [T], lastDoc: DocumentSnapshot?)
    ) async {
        guard paginationManager.canLoadMore else { return }
        
        paginationManager.setLoading(true)
        
        do {
            let (items, lastDoc) = try await loadFunction(paginationManager.currentLastDocument)
            paginationManager.update(newItems: items, lastDoc: lastDoc)
            
            if case .loaded = state {
                updateState(.loaded(paginationManager.items))
            }
        } catch {
            // Don't update state to error if we already have data
            if state.value == nil {
                handleError(error)
            }
        }
        
        paginationManager.setLoading(false)
    }
    
    /// Resets the pagination state and fetches the first page
    @MainActor
    override func refresh() async {
        guard !paginationManager.isLoading else { return }
        
        resetState()
        await fetch()
    }
    
    /// Resets the state and pagination manager
    override func resetState() {
        super.resetState()
        paginationManager.reset()
    }
    
    /// Checks if more items can be loaded
    var canLoadMore: Bool {
        return paginationManager.canLoadMore && !paginationManager.isLoading
    }
    
    /// Whether pagination is currently loading more items
    var isLoadingMore: Bool {
        return paginationManager.isLoading
    }
    
    /// The total number of items loaded so far
    var itemCount: Int {
        return paginationManager.items.count
    }
    
    /// Adds new items to the existing collection
    @MainActor
    func appendItems(_ newItems: [T], lastDoc: DocumentSnapshot? = nil) {
        paginationManager.update(newItems: paginationManager.items + newItems, lastDoc: lastDoc)
        
        if case .loaded = state {
            updateState(.loaded(paginationManager.items))
        } else {
            updateState(.loaded(paginationManager.items))
        }
    }
    
    /// Updates a specific item in the collection
    @MainActor
    func updateItem(at index: Int, with item: T) where T: Equatable {
        guard index >= 0, index < paginationManager.items.count else { return }
        
        var updatedItems = paginationManager.items
        updatedItems[index] = item
        
        paginationManager.update(newItems: updatedItems, lastDoc: paginationManager.currentLastDocument)
        
        if case .loaded = state {
            updateState(.loaded(updatedItems))
        }
    }
    
    /// Updates an item that matches the given predicate
    @MainActor
    func updateItem(where predicate: (T) -> Bool, with item: T) where T: Equatable {
        guard let index = paginationManager.items.firstIndex(where: predicate) else { return }
        updateItem(at: index, with: item)
    }
    
    /// Removes an item at the specified index
    @MainActor
    func removeItem(at index: Int) {
        guard index >= 0, index < paginationManager.items.count else { return }
        
        var updatedItems = paginationManager.items
        updatedItems.remove(at: index)
        
        paginationManager.update(newItems: updatedItems, lastDoc: paginationManager.currentLastDocument)
        
        if case .loaded = state {
            updateState(.loaded(updatedItems))
        }
    }
    
    /// Removes an item that matches the given predicate
    @MainActor
    func removeItem(where predicate: (T) -> Bool) {
        guard let index = paginationManager.items.firstIndex(where: predicate) else { return }
        removeItem(at: index)
    }
}
