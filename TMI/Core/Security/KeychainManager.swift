import Foundation
import Security
import CryptoKit

// MARK: - Keychain Error
nonisolated enum KeychainError: Error, LocalizedError, Sendable {
    case storeFailed(status: OSStatus)
    case retrieveFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    case clearFailed(status: OSStatus)
    case keyStoreFailed(status: OSStatus)
    case keyRetrieveFailed(status: OSStatus)
    case bulkRetrieveFailed(status: OSStatus)
    case itemNotFound
    case keyNotFound
    case invalidData
    case invalidKeyData
    case accessControlCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .storeFailed(let status):
            return "Failed to store keychain item (status: \(status))"
        case .retrieveFailed(let status):
            return "Failed to retrieve keychain item (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete keychain item (status: \(status))"
        case .clearFailed(let status):
            return "Failed to clear keychain items (status: \(status))"
        case .keyStoreFailed(let status):
            return "Failed to store cryptographic key (status: \(status))"
        case .keyRetrieveFailed(let status):
            return "Failed to retrieve cryptographic key (status: \(status))"
        case .bulkRetrieveFailed(let status):
            return "Failed to retrieve all keychain items (status: \(status))"
        case .itemNotFound:
            return "Keychain item not found"
        case .keyNotFound:
            return "Cryptographic key not found"
        case .invalidData:
            return "Invalid keychain data"
        case .invalidKeyData:
            return "Invalid cryptographic key data"
        case .accessControlCreationFailed(let description):
            return "Failed to create access control: \(description)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .storeFailed, .retrieveFailed, .deleteFailed, .clearFailed,
             .keyStoreFailed, .keyRetrieveFailed, .bulkRetrieveFailed:
            return "Keychain operation failed with system error"
        case .itemNotFound, .keyNotFound:
            return "Requested item does not exist in keychain"
        case .invalidData, .invalidKeyData:
            return "Data format is not valid for this operation"
        case .accessControlCreationFailed:
            return "System security settings prevent access control creation"
        }
    }
    
    /// Convert to TMIError for broader error handling
    func toTMIError() -> TMIError {
        let errorCode: TMIError.ErrorCode
        let category: String
        
        switch self {
        case .storeFailed, .keyStoreFailed:
            errorCode = .dataStorageFailed
            category = "keychain_store"
        case .retrieveFailed, .keyRetrieveFailed, .bulkRetrieveFailed:
            errorCode = .dataRetrievalFailed
            category = "keychain_retrieve"
        case .deleteFailed, .clearFailed:
            errorCode = .dataStorageFailed
            category = "keychain_delete"
        case .itemNotFound, .keyNotFound:
            errorCode = .dataNotFound
            category = "keychain_missing"
        case .invalidData, .invalidKeyData:
            errorCode = .dataValidationFailed
            category = "keychain_validation"
        case .accessControlCreationFailed:
            errorCode = .securityError
            category = "keychain_access_control"
        }
        
        return TMIError(
            code: errorCode,
            message: errorDescription ?? "Unknown keychain error",
            underlyingError: self,
            context: [
                "category": category,
                "error_type": String(describing: self)
            ]
        )
    }
}

// MARK: - Keychain Statistics
nonisolated struct KeychainStatistics: Sendable {
    let totalItems: Int
    let accessibleItems: Int
    let totalSize: Int
    let service: String
    
    var averageItemSize: Int {
        accessibleItems > 0 ? totalSize / accessibleItems : 0
    }
    
    var description: String {
        """
        Keychain Statistics for \(service):
        - Total Items: \(totalItems)
        - Accessible Items: \(accessibleItems)
        - Total Size: \(totalSize) bytes
        - Average Item Size: \(averageItemSize) bytes
        """
    }
}

// MARK: - Advanced Keychain Manager
nonisolated final class KeychainManager: Sendable {
    private let service: String
    private let accessGroup: String?
    private let logger: TMILogger
    
    // MARK: - Initialization
    init(service: String = "com.tmi.education.secure", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
        self.logger = TMILogger(category: "Keychain")
    }
    
    // MARK: - Generic Data Storage
    
    /// Store data with advanced security options
    func store(
        _ data: Data,
        for key: String,
        accessControl: SecAccessControl? = nil,
        synchronizable: Bool = false,
        requiresBiometric: Bool = false
    ) async throws {
        try storeSynchronously(
            data,
            for: key,
            accessControl: accessControl,
            synchronizable: synchronizable,
            requiresBiometric: requiresBiometric
        )
    }
    
    /// Legacy store method for compatibility
    func store(_ data: Data, for key: String, requiresBiometric: Bool = false) throws {
        try storeSynchronously(
            data,
            for: key,
            accessControl: nil,
            synchronizable: false,
            requiresBiometric: requiresBiometric
        )
    }
    
    /// Retrieve data from keychain
    func retrieve(for key: String) async throws -> Data {
        try retrieveSynchronously(for: key)
    }
    
    /// Legacy retrieve method for compatibility
    func retrieve(for key: String) throws -> Data {
        try retrieveSynchronously(for: key)
    }
    
    /// Check if item exists
    func exists(for key: String) async -> Bool {
        let query = baseQuery(for: key)
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Legacy exists method for compatibility
    func exists(for key: String) -> Bool {
        let query = baseQuery(for: key)
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Delete item from keychain
    func delete(for key: String) async throws {
        try deleteSynchronously(for: key)
    }
    
    /// Legacy delete method for compatibility
    func delete(for key: String) throws {
        try deleteSynchronously(for: key)
    }
    
    /// Clear all items for this service
    func clearAll() async throws {
        try clearAllSynchronously()
    }
    
    /// Legacy deleteAll method for compatibility
    func deleteAll() throws {
        try clearAllSynchronously()
    }
    
    // MARK: - Cryptographic Key Storage
    
    /// Store a symmetric key
    func storeKey(_ key: SymmetricKey, for identifier: String) async throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        try storeKeyDataSynchronously(keyData, for: identifier)
    }
    
    /// Store raw key data
    func storeKey(_ keyData: Data, for tag: String) throws {
        try storeKeyDataSynchronously(keyData, for: tag)
    }
    
    /// Retrieve a symmetric key
    func retrieveKey(for identifier: String) async throws -> SymmetricKey {
        let keyData = try await retrieveKeyData(for: identifier)
        return SymmetricKey(data: keyData)
    }
    
    /// Retrieve raw key data
    func retrieveKey(for tag: String) throws -> Data {
        try retrieveKeyDataSynchronously(for: tag)
    }
    
    /// Store raw key data (private method for async version)
    private func storeKeyData(_ keyData: Data, for identifier: String) async throws {
        try storeKeyDataSynchronously(keyData, for: identifier)
    }
    
    /// Retrieve raw key data (private method for async version)
    private func retrieveKeyData(for identifier: String) async throws -> Data {
        try retrieveKeyDataSynchronously(for: identifier)
    }
    
    // MARK: - Bulk Operations
    
    /// Get all items for this service
    func getAllKeys() async throws -> [String] {
        logger.debug("Retrieving all keychain keys")
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return []
            }
            logger.error("Failed to retrieve all keys with status \(status): \(keychainErrorDescription(status))")
            throw KeychainError.bulkRetrieveFailed(status: status)
        }
        
        guard let items = result as? [[String: Any]] else {
            logger.error("Invalid bulk retrieve data format")
            throw KeychainError.invalidData
        }
        
        let keys = Array(Set(items.compactMap { $0[kSecAttrAccount as String] as? String }))
        logger.debug("Successfully retrieved all keys, count: \(keys.count)")
        return keys
    }
    
    /// Export all data (for backup purposes)
    func exportAll(excluding excludedKeys: Set<String> = []) async throws -> Data {
        logger.info("Exporting all keychain data")
        
        let keys = try await getAllKeys()
        var exportData: [String: Data] = [:]
        
        for key in keys where !excludedKeys.contains(key) {
            if let data = try? await retrieve(for: key) {
                exportData[key] = data
            }
        }
        
        let archiveData = try JSONEncoder().encode(exportData)
        logger.info("Successfully exported keychain data with item count: \(exportData.count)")
        return archiveData
    }
    
    /// Legacy exportAll method for compatibility
    func exportAll(excluding excludedKeys: Set<String> = []) throws -> Data {
        let keys = try getAllKeysSynchronously()
        var exportData: [String: Data] = [:]
        for key in keys where !excludedKeys.contains(key) {
            exportData[key] = try? retrieveSynchronously(for: key)
        }
        return try JSONEncoder().encode(exportData)
    }
    
    /// Import data from backup
    func importAll(_ data: Data, excluding excludedKeys: Set<String> = []) async throws {
        logger.info("Importing keychain data")
        
        let exportData = try JSONDecoder().decode([String: Data].self, from: data)
        
        for (key, itemData) in exportData where !excludedKeys.contains(key) {
            try await store(itemData, for: key)
        }
        
        logger.info("Successfully imported keychain data with item count: \(exportData.count)")
    }
    
    /// Legacy importAll method for compatibility
    func importAll(_ data: Data, excluding excludedKeys: Set<String> = []) throws {
        let exportData = try JSONDecoder().decode([String: Data].self, from: data)
        for (key, itemData) in exportData where !excludedKeys.contains(key) {
            try storeSynchronously(
                itemData,
                for: key,
                accessControl: nil,
                synchronizable: false,
                requiresBiometric: false
            )
        }
    }
    
    // MARK: - Access Control Creation
    
    /// Create access control for biometric protection
    func createBiometricAccessControl() throws -> SecAccessControl {
        return try createAccessControl(
            protection: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            flags: [.biometryCurrentSet, .or, .devicePasscode]
        )
    }
    
    /// Create access control for device passcode only
    func createPasscodeAccessControl() throws -> SecAccessControl {
        return try createAccessControl(
            protection: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            flags: [.devicePasscode]
        )
    }
    
    /// Create access control with custom settings
    func createAccessControl(
        protection: CFString,
        flags: SecAccessControlCreateFlags
    ) throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            protection,
            flags,
            &error
        ) else {
            var errorDescription = "Unknown error"
            if let cfError = error?.takeRetainedValue() {
                errorDescription = CFErrorCopyDescription(cfError) as String
            }
            logger.error("Failed to create access control: \(errorDescription)")
            throw KeychainError.accessControlCreationFailed(errorDescription)
        }
        
        return accessControl
    }
    
    // MARK: - Statistics
    
    /// Get keychain usage statistics
    func getStatistics() async -> KeychainStatistics {
        do {
            let allKeys = try await getAllKeys()
            var totalSize: Int = 0
            var accessibleCount: Int = 0
            
            for key in allKeys {
                if let data = try? await retrieve(for: key) {
                    totalSize += data.count
                    accessibleCount += 1
                }
            }
            
            return KeychainStatistics(
                totalItems: allKeys.count,
                accessibleItems: accessibleCount,
                totalSize: totalSize,
                service: service
            )
        } catch {
            logger.error("Failed to get keychain statistics: \(error)")
            return KeychainStatistics(
                totalItems: 0,
                accessibleItems: 0,
                totalSize: 0,
                service: service
            )
        }
    }
    
    // MARK: - Helper Methods

    /// CryptoKit symmetric keys are raw secret bytes rather than `SecKey` objects.
    /// Storing those bytes as a generic-password item is supported consistently by
    /// both the iOS data-protection keychain and the macOS keychain.
    private func storeKeyDataSynchronously(_ keyData: Data, for identifier: String) throws {
        logger.debug("Storing cryptographic key for identifier '\(identifier)'")

        var query = baseQuery(for: identifier)
        query[kSecValueData as String] = keyData
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        query[kSecAttrSynchronizable as String] = false

        SecItemDelete(baseQuery(for: identifier) as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            logger.error(
                "Failed to store cryptographic key for identifier '\(identifier)' with status \(status): \(keychainErrorDescription(status))"
            )
            throw KeychainError.keyStoreFailed(status: status)
        }

        logger.info("Successfully stored cryptographic key for identifier '\(identifier)'")
    }

    private func retrieveKeyDataSynchronously(for identifier: String) throws -> Data {
        logger.debug("Retrieving cryptographic key for identifier '\(identifier)'")

        var query = baseQuery(for: identifier)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound,
               let legacyKeyData = try migrateLegacyKeyDataIfNeeded(for: identifier) {
                return legacyKeyData
            }
            if status == errSecItemNotFound {
                logger.debug("Cryptographic key not found for identifier '\(identifier)'")
                throw KeychainError.keyNotFound
            }
            logger.error(
                "Failed to retrieve cryptographic key for identifier '\(identifier)' with status \(status): \(keychainErrorDescription(status))"
            )
            throw KeychainError.keyRetrieveFailed(status: status)
        }

        guard let keyData = result as? Data else {
            logger.error("Invalid key data format for identifier '\(identifier)'")
            throw KeychainError.invalidKeyData
        }

        logger.debug("Successfully retrieved cryptographic key for identifier '\(identifier)'")
        return keyData
    }

    /// Task 11 moved raw symmetric-key bytes from `kSecClassKey` to a generic-password
    /// record. Preserve existing encrypted data by moving legacy bytes before callers
    /// decide that no key exists and generate a replacement.
    private func migrateLegacyKeyDataIfNeeded(for identifier: String) throws -> Data? {
        for matchQuery in legacyKeyQueries(for: identifier) {
            var retrievalQuery = matchQuery
            retrievalQuery[kSecReturnData as String] = true
            retrievalQuery[kSecMatchLimit as String] = kSecMatchLimitOne

            var result: AnyObject?
            let status = SecItemCopyMatching(retrievalQuery as CFDictionary, &result)
            if status == errSecItemNotFound {
                continue
            }
            guard status == errSecSuccess else {
                throw KeychainError.keyRetrieveFailed(status: status)
            }
            guard let keyData = result as? Data else {
                throw KeychainError.invalidKeyData
            }

            try storeKeyDataSynchronously(keyData, for: identifier)

            let deleteStatus = SecItemDelete(matchQuery as CFDictionary)
            guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
                try? deleteSynchronously(for: identifier)
                throw KeychainError.keyStoreFailed(status: deleteStatus)
            }

            logger.info("Migrated legacy cryptographic key for identifier '\(identifier)'")
            return keyData
        }

        return nil
    }

    private func legacyKeyQueries(for identifier: String) -> [[String: Any]] {
        // The pre-upgrade writer supplied a String even though Security documents
        // application tags as Data. Query both forms because normalization differs
        // across Keychain implementations and OS versions.
        let applicationTags: [Any] = [identifier, Data(identifier.utf8)]
#if os(macOS)
        return applicationTags.flatMap { applicationTag in
            var dataProtectionQuery = legacyKeyQuery(applicationTag: applicationTag)
            dataProtectionQuery[kSecUseDataProtectionKeychain as String] = true
            return [dataProtectionQuery, legacyKeyQuery(applicationTag: applicationTag)]
        }
#else
        return applicationTags.map { legacyKeyQuery(applicationTag: $0) }
#endif
    }

    private func legacyKeyQuery(applicationTag: Any) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTag,
        ]
#if os(macOS)
        query[kSecAttrKeyType as String] = kSecAttrKeyTypeAES
        query[kSecAttrKeyClass as String] = kSecAttrKeyClassSymmetric
#endif
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    private func storeSynchronously(
        _ data: Data,
        for key: String,
        accessControl: SecAccessControl?,
        synchronizable: Bool,
        requiresBiometric: Bool
    ) throws {
        logger.debug("Storing keychain item for key '\(key)' with size \(data.count)")

        var query = baseQuery(for: key)
        query[kSecValueData as String] = data

        if let accessControl {
            query[kSecAttrAccessControl as String] = accessControl
        } else if requiresBiometric {
            query[kSecAttrAccessControl as String] = try createBiometricAccessControl()
        } else {
            query[kSecAttrAccessible as String] = synchronizable
                ? kSecAttrAccessibleWhenUnlocked
                : kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        query[kSecAttrSynchronizable as String] = synchronizable
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        SecItemDelete(baseQuery(for: key) as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            logger.error(
                "Failed to store keychain item for key '\(key)' with status \(status): \(keychainErrorDescription(status))"
            )
            throw KeychainError.storeFailed(status: status)
        }

        logger.info("Successfully stored keychain item for key '\(key)'")
    }

    private func retrieveSynchronously(for key: String) throws -> Data {
        logger.debug("Retrieving keychain item for key '\(key)'")

        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                logger.debug("Keychain item not found for key '\(key)'")
                throw KeychainError.itemNotFound
            }
            logger.error(
                "Failed to retrieve keychain item for key '\(key)' with status \(status): \(keychainErrorDescription(status))"
            )
            throw KeychainError.retrieveFailed(status: status)
        }

        guard let data = result as? Data else {
            logger.error("Invalid keychain data format for key '\(key)'")
            throw KeychainError.invalidData
        }

        logger.debug("Successfully retrieved keychain item for key '\(key)' with size \(data.count)")
        return data
    }

    private func deleteSynchronously(for key: String) throws {
        logger.debug("Deleting keychain item for key '\(key)'")

        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error(
                "Failed to delete keychain item for key '\(key)' with status \(status): \(keychainErrorDescription(status))"
            )
            throw KeychainError.deleteFailed(status: status)
        }

        logger.info("Successfully deleted keychain item for key '\(key)'")
    }

    private func clearAllSynchronously() throws {
        logger.warning("Clearing all keychain items for service: \(service)")

        // Exact-account deletion avoids a macOS Keychain behavior where a broad
        // service query can report success after deleting only its first match.
        for key in try getAllKeysSynchronously() {
            let itemStatus = SecItemDelete(baseQuery(for: key) as CFDictionary)
            guard itemStatus == errSecSuccess || itemStatus == errSecItemNotFound else {
                logger.error(
                    "Failed to clear keychain item '\(key)' with status \(itemStatus): \(keychainErrorDescription(itemStatus))"
                )
                throw KeychainError.clearFailed(status: itemStatus)
            }
        }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error(
                "Failed to clear all keychain items with status \(status): \(keychainErrorDescription(status))"
            )
            throw KeychainError.clearFailed(status: status)
        }

        logger.info("Successfully cleared all keychain items")
    }

    private func getAllKeysSynchronously() throws -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess else {
            throw KeychainError.bulkRetrieveFailed(status: status)
        }
        guard let items = result as? [[String: Any]] else {
            throw KeychainError.invalidData
        }
        return Array(Set(items.compactMap { $0[kSecAttrAccount as String] as? String }))
    }
    
    private func baseQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
    
    private func keychainErrorDescription(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess: return "Success"
        case errSecItemNotFound: return "Item not found"
        case errSecDuplicateItem: return "Duplicate item"
        case errSecParam: return "Invalid parameter"
        case errSecAllocate: return "Allocation failure"
        case errSecNotAvailable: return "Service not available"
        case errSecAuthFailed: return "Authentication failed"
        case errSecInteractionNotAllowed: return "Interaction not allowed"
        case errSecDecode: return "Decode error"
        default: return "Unknown error (\(status))"
        }
    }
}
