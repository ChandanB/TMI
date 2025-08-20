//
//  CacheEntry.swift
//  TMI
//
//  Created by Chandan Brown on 8/20/25.
//

import Foundation

// MARK: - Cache Entry

private struct CacheEntry<T: Sendable>: Sendable {
    let value: T
    let timestamp: Date
    let accessCount: Int
    let lastAccessed: Date
    
    init(value: T) {
        self.value = value
        self.timestamp = Date()
        self.accessCount = 1
        self.lastAccessed = Date()
    }
    
    func accessed() -> CacheEntry<T> {
        CacheEntry(
            value: value
        )
    }
    
    var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }
    
    var timeSinceLastAccess: TimeInterval {
        Date().timeIntervalSince(lastAccessed)
    }
}

// MARK: - Cache Configuration

struct CacheConfiguration: Sendable {
    let maxMemorySize: Int // in MB
    let defaultExpiration: TimeInterval
    let cleanupInterval: TimeInterval
    let maxEntries: Int
    
    static let `default` = CacheConfiguration(
        maxMemorySize: 50, // 50MB
        defaultExpiration: 300, // 5 minutes
        cleanupInterval: 60, // 1 minute
        maxEntries: 1000
    )
    
    static let aggressive = CacheConfiguration(
        maxMemorySize: 100, // 100MB
        defaultExpiration: 600, // 10 minutes
        cleanupInterval: 120, // 2 minutes
        maxEntries: 2000
    )
    
    static let minimal = CacheConfiguration(
        maxMemorySize: 20, // 20MB
        defaultExpiration: 180, // 3 minutes
        cleanupInterval: 30, // 30 seconds
        maxEntries: 500
    )
}

// MARK: - Data Cache Actor

/// Thread-safe data cache using Actor pattern for iOS 26
actor DataCache: Sendable {
    
    // MARK: - Properties
    
    private var storage: [String: Any] = [:]
    private var metadata: [String: CacheMetadata] = [:]
    private let configuration: CacheConfiguration
    private var cleanupTask: Task<Void, Never>?
    
    private struct CacheMetadata: Sendable {
        let timestamp: Date
        let expiration: TimeInterval
        let accessCount: Int
        let lastAccessed: Date
        let estimatedSize: Int // in bytes
        
        init(expiration: TimeInterval, estimatedSize: Int = 0) {
            self.timestamp = Date()
            self.expiration = expiration
            self.accessCount = 1
            self.lastAccessed = Date()
            self.estimatedSize = estimatedSize
        }
        
        func accessed() -> CacheMetadata {
            CacheMetadata(
                timestamp: timestamp,
                expiration: expiration,
                accessCount: accessCount + 1,
                lastAccessed: Date(),
                estimatedSize: estimatedSize
            )
        }
        
        private init(
            timestamp: Date,
            expiration: TimeInterval,
            accessCount: Int,
            lastAccessed: Date,
            estimatedSize: Int
        ) {
            self.timestamp = timestamp
            self.expiration = expiration
            self.accessCount = accessCount
            self.lastAccessed = lastAccessed
            self.estimatedSize = estimatedSize
        }
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > expiration
        }
        
        var age: TimeInterval {
            Date().timeIntervalSince(timestamp)
        }
        
        var timeSinceLastAccess: TimeInterval {
            Date().timeIntervalSince(lastAccessed)
        }
    }
    
    // MARK: - Initialization
    
    init(configuration: CacheConfiguration = .default) {
        self.configuration = configuration
        startCleanupTask()
    }
    
    deinit {
        cleanupTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Get a value from the cache
    func get<T: Sendable>(key: String) -> T? {
        guard let entry = storage[key] as? T,
              let meta = metadata[key],
              !meta.isExpired else {
            // Remove expired entry
            storage.removeValue(forKey: key)
            metadata.removeValue(forKey: key)
            return nil
        }
        
        // Update access metadata
        metadata[key] = meta.accessed()
        return entry
    }
    
    /// Set a value in the cache
    func set<T: Sendable>(
        key: String,
        value: T,
        expiration: TimeInterval? = nil
    ) async {
        let expirationTime = expiration ?? configuration.defaultExpiration
        let estimatedSize = estimateSize(of: value)
        
        storage[key] = value
        metadata[key] = CacheMetadata(
            expiration: expirationTime,
            estimatedSize: estimatedSize
        )
        
        // Clean up if needed
        await cleanupIfNeeded()
    }
    
    /// Remove a specific key from the cache
    func remove(key: String) {
        storage.removeValue(forKey: key)
        metadata.removeValue(forKey: key)
    }
    
    /// Clear all cache entries
    func clear() {
        storage.removeAll()
        metadata.removeAll()
    }
    
    /// Get cache statistics
    func getStatistics() -> CacheStatistics {
        let totalSize = metadata.values.reduce(0) { $0 + $1.estimatedSize }
        let totalSizeMB = Double(totalSize) / (1024 * 1024)
        
        let expiredCount = metadata.values.filter { $0.isExpired }.count
        let totalAccesses = metadata.values.reduce(0) { $0 + $1.accessCount }
        
        return CacheStatistics(
            entryCount: storage.count,
            totalSizeMB: totalSizeMB,
            expiredEntries: expiredCount,
            totalAccesses: totalAccesses,
            averageAccessCount: storage.isEmpty ? 0 : Double(totalAccesses) / Double(storage.count),
            oldestEntryAge: metadata.values.map { $0.age }.max() ?? 0
        )
    }
    
    /// Check if cache contains a key
    func contains(key: String) -> Bool {
        guard let meta = metadata[key] else { return false }
        
        if meta.isExpired {
            storage.removeValue(forKey: key)
            metadata.removeValue(forKey: key)
            return false
        }
        
        return true
    }
    
    /// Get all keys in the cache
    func getAllKeys() -> Set<String> {
        // Clean expired entries first
        let expiredKeys = metadata.compactMap { key, meta in
            meta.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            storage.removeValue(forKey: key)
            metadata.removeValue(forKey: key)
        }
        
        return Set(storage.keys)
    }
    
    // MARK: - Private Methods
    
    private func cleanupIfNeeded() async {
        let stats = await getStatistics()
        
        // Check if cleanup is needed
        let needsCleanup = storage.count > configuration.maxEntries ||
                          stats.totalSizeMB > Double(configuration.maxMemorySize) ||
                          stats.expiredEntries > 0
        
        if needsCleanup {
            await performCleanup()
        }
    }
    
    private func performCleanup() {
        // Remove expired entries first
        let expiredKeys = metadata.compactMap { key, meta in
            meta.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            storage.removeValue(forKey: key)
            metadata.removeValue(forKey: key)
        }
        
        // If still over limits, use LRU eviction
        let currentSize = metadata.values.reduce(0) { $0 + $1.estimatedSize }
        let currentSizeMB = Double(currentSize) / (1024 * 1024)
        
        if storage.count > configuration.maxEntries || 
           currentSizeMB > Double(configuration.maxMemorySize) {
            performLRUEviction()
        }
    }
    
    private func performLRUEviction() {
        // Sort by last access time (least recently used first)
        let sortedKeys = metadata.sorted { first, second in
            first.value.timeSinceLastAccess > second.value.timeSinceLastAccess
        }
        
        let targetCount = Int(Double(configuration.maxEntries) * 0.8) // Remove 20% buffer
        let keysToRemove = sortedKeys.prefix(storage.count - targetCount)
        
        for (key, _) in keysToRemove {
            storage.removeValue(forKey: key)
            metadata.removeValue(forKey: key)
        }
    }
    
    private func estimateSize<T>(of value: T) -> Int {
        // Rough estimation - in a real implementation, you might want more accurate sizing
        if let data = value as? Data {
            return data.count
        } else if let string = value as? String {
            return string.utf8.count
        } else if let array = value as? [Any] {
            return array.count * 64 // Rough estimate
        } else {
            return 64 // Default estimate for objects
        }
    }
    
    private func startCleanupTask() {
        cleanupTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(configuration.cleanupInterval))
                
                if !Task.isCancelled {
                    await performCleanup()
                }
            }
        }
    }
}

// MARK: - Cache Statistics

struct CacheStatistics: Sendable {
    let entryCount: Int
    let totalSizeMB: Double
    let expiredEntries: Int
    let totalAccesses: Int
    let averageAccessCount: Double
    let oldestEntryAge: TimeInterval
    
    var hitRate: Double {
        // This would be calculated based on hit/miss tracking
        // For now, return a placeholder
        return 0.0
    }
    
    var description: String {
        """
        Cache Statistics:
        - Entries: \(entryCount)
        - Size: \(String(format: "%.2f", totalSizeMB)) MB
        - Expired: \(expiredEntries)
        - Total Accesses: \(totalAccesses)
        - Avg Access Count: \(String(format: "%.1f", averageAccessCount))
        - Oldest Entry: \(String(format: "%.1f", oldestEntryAge))s old
        """
    }
}

// MARK: - Convenience Extensions

extension DataCache {
    /// Convenience method for storing Codable objects
    func setCodable<T: Codable & Sendable>(
        key: String,
        value: T,
        expiration: TimeInterval? = nil
    ) async {
        await set(key: key, value: value, expiration: expiration)
    }
    
    /// Convenience method for retrieving Codable objects
    func getCodable<T: Codable & Sendable>(key: String, type: T.Type) -> T? {
        return get(key: key)
    }
    
    /// Store a collection of identifiable items
    func setCollection<T: Identifiable & Sendable>(
        key: String,
        items: [T],
        expiration: TimeInterval? = nil
    ) async {
        await set(key: key, value: items, expiration: expiration)
    }
    
    /// Get a collection of identifiable items
    func getCollection<T: Identifiable & Sendable>(
        key: String,
        type: T.Type
    ) -> [T]? {
        return get(key: key)
    }
    
    /// Update a single item in a cached collection
    func updateItemInCollection<T: Identifiable & Sendable & Equatable>(
        collectionKey: String,
        item: T,
        type: T.Type
    ) async {
        guard var collection: [T] = get(key: collectionKey) else { return }
        
        if let index = collection.firstIndex(where: { $0.id == item.id }) {
            collection[index] = item
            await set(key: collectionKey, value: collection)
        }
    }
    
    /// Remove an item from a cached collection
    func removeItemFromCollection<T: Identifiable & Sendable>(
        collectionKey: String,
        itemId: T.ID,
        type: T.Type
    ) async {
        guard var collection: [T] = get(key: collectionKey) else { return }
        
        collection.removeAll { $0.id == itemId }
        await set(key: collectionKey, value: collection)
    }
}

// MARK: - Global Cache Instance

/// Global cache instance for the TMI app
@globalActor
actor TMICache: GlobalActor {
    static let shared = DataCache(configuration: .default)
}
