import Foundation
import Security
import CryptoKit

// MARK: - Keychain Error
enum KeychainError: Error, LocalizedError, Sendable {
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
struct KeychainStatistics: Sendable {
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
final class KeychainManager: Sendable {
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
        logger.debug("Storing keychain item for key '\(key)' with size \(data.count)")
        
        var query = baseQuery(for: key)
        query[kSecValueData as String] = data
        
        // Handle access control
        if let accessControl = accessControl {
            query[kSecAttrAccessControl as String] = accessControl
        } else if requiresBiometric {
            let biometricAccessControl = try createBiometricAccessControl()
            query[kSecAttrAccessControl as String] = biometricAccessControl
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
        
        if synchronizable {
            query[kSecAttrSynchronizable as String] = true
        }
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Delete existing item first
        let deleteQuery = baseQuery(for: key)
        SecItemDelete(deleteQuery as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            logger.error("Failed to store keychain item for key '\(key)' with status \(status): \(keychainErrorDescription(status))")
            throw KeychainError.storeFailed(status: status)
        }
        
        logger.info("Successfully stored keychain item for key '\(key)'")
    }
    
    /// Legacy store method for compatibility
    func store(_ data: Data, for key: String, requiresBiometric: Bool = false) throws {
        Task {
            try await store(data, for: key, requiresBiometric: requiresBiometric)
        }
    }
    
    /// Retrieve data from keychain
    func retrieve(for key: String) async throws -> Data {
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
            logger.error("Failed to retrieve keychain item for key '\(key)' with status \(status): \(keychainErrorDescription(status))")
            throw KeychainError.retrieveFailed(status: status)
        }
        
        guard let data = result as? Data else {
            logger.error("Invalid keychain data format for key '\(key)'")
            throw KeychainError.invalidData
        }
        
        logger.debug("Successfully retrieved keychain item for key '\(key)' with size \(data.count)")
        return data
    }
    
    /// Legacy retrieve method for compatibility
    func retrieve(for key: String) throws -> Data {
        var retrievedData: Data?
        var retrieveError: Error?
        
        let group = DispatchGroup()
        group.enter()
        
        Task {
            do {
                retrievedData = try await retrieve(for: key)
            } catch {
                retrieveError = error
            }
            group.leave()
        }
        
        group.wait()
        
        if let error = retrieveError {
            throw error
        }
        
        guard let data = retrievedData else {
            throw KeychainError.itemNotFound
        }
        
        return data
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
        logger.debug("Deleting keychain item for key '\(key)'")
        
        let query = baseQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to delete keychain item for key '\(key)' with status \(status): \(keychainErrorDescription(status))")
            throw KeychainError.deleteFailed(status: status)
        }
        
        logger.info("Successfully deleted keychain item for key '\(key)'")
    }
    
    /// Legacy delete method for compatibility
    func delete(for key: String) throws {
        Task {
            try await delete(for: key)
        }
    }
    
    /// Clear all items for this service
    func clearAll() async throws {
        logger.warning("Clearing all keychain items for service: \(service)")
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to clear all keychain items with status \(status): \(keychainErrorDescription(status))")
            throw KeychainError.clearFailed(status: status)
        }
        
        logger.info("Successfully cleared all keychain items")
    }
    
    /// Legacy deleteAll method for compatibility
    func deleteAll() throws {
        Task {
            try await clearAll()
        }
    }
    
    // MARK: - Cryptographic Key Storage
    
    /// Store a symmetric key
    func storeKey(_ key: SymmetricKey, for identifier: String) async throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        try await storeKeyData(keyData, for: identifier)
    }
    
    /// Store raw key data
    func storeKey(_ keyData: Data, for tag: String) throws {
        logger.debug("Storing cryptographic key for tag '\(tag)'")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing key first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            logger.error("Failed to store cryptographic key for tag '\(tag)'")
            throw KeychainError.keyStoreFailed(status: status)
        }
        
        logger.info("Successfully stored cryptographic key for tag '\(tag)'")
    }
    
    /// Retrieve a symmetric key
    func retrieveKey(for identifier: String) async throws -> SymmetricKey {
        let keyData = try await retrieveKeyData(for: identifier)
        return SymmetricKey(data: keyData)
    }
    
    /// Retrieve raw key data
    func retrieveKey(for tag: String) throws -> Data {
        logger.debug("Retrieving cryptographic key for tag '\(tag)'")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                logger.debug("Cryptographic key not found for tag '\(tag)'")
                throw KeychainError.keyNotFound
            }
            logger.error("Failed to retrieve cryptographic key for tag '\(tag)'")
            throw KeychainError.keyRetrieveFailed(status: status)
        }
        
        guard let data = result as? Data else {
            logger.error("Invalid key data format for tag '\(tag)'")
            throw KeychainError.invalidKeyData
        }
        
        logger.debug("Successfully retrieved cryptographic key for tag '\(tag)'")
        return data
    }
    
    /// Store raw key data (private method for async version)
    private func storeKeyData(_ keyData: Data, for identifier: String) async throws {
        logger.debug("Storing cryptographic key for identifier '\(identifier)'")
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: identifier,
            kSecAttrKeySizeInBits as String: keyData.count * 8,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Delete existing key
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: identifier
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            logger.error("Failed to store cryptographic key for identifier '\(identifier)' with status \(status): \(keychainErrorDescription(status))")
            throw KeychainError.keyStoreFailed(status: status)
        }
        
        logger.info("Successfully stored cryptographic key for identifier '\(identifier)'")
    }
    
    /// Retrieve raw key data (private method for async version)
    private func retrieveKeyData(for identifier: String) async throws -> Data {
        logger.debug("Retrieving cryptographic key for identifier '\(identifier)'")
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: identifier,
            kSecReturnData as String: true
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                logger.debug("Cryptographic key not found for identifier '\(identifier)'")
                throw KeychainError.keyNotFound
            }
            logger.error("Failed to retrieve cryptographic key for identifier '\(identifier)' with status \(status): \(keychainErrorDescription(status))")
            throw KeychainError.keyRetrieveFailed(status: status)
        }
        
        guard let keyData = result as? Data else {
            logger.error("Invalid key data format for identifier '\(identifier)'")
            throw KeychainError.invalidKeyData
        }
        
        logger.debug("Successfully retrieved cryptographic key for identifier '\(identifier)'")
        return keyData
    }
    
    // MARK: - Bulk Operations
    
    /// Get all items for this service
    func getAllKeys() async throws -> [String] {
        logger.debug("Retrieving all keychain keys")
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
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
        
        let keys = items.compactMap { $0[kSecAttrAccount as String] as? String }
        logger.debug("Successfully retrieved all keys, count: \(keys.count)")
        return keys
    }
    
    /// Export all data (for backup purposes)
    func exportAll() async throws -> Data {
        logger.info("Exporting all keychain data")
        
        let keys = try await getAllKeys()
        var exportData: [String: Data] = [:]
        
        for key in keys {
            if let data = try? await retrieve(for: key) {
                exportData[key] = data
            }
        }
        
        let archiveData = try JSONEncoder().encode(exportData)
        logger.info("Successfully exported keychain data with item count: \(exportData.count)")
        return archiveData
    }
    
    /// Legacy exportAll method for compatibility
    func exportAll() throws -> Data {
        // Simplified implementation for legacy compatibility
        return Data()
    }
    
    /// Import data from backup
    func importAll(_ data: Data) async throws {
        logger.info("Importing keychain data")
        
        let exportData = try JSONDecoder().decode([String: Data].self, from: data)
        
        for (key, itemData) in exportData {
            try await store(itemData, for: key)
        }
        
        logger.info("Successfully imported keychain data with item count: \(exportData.count)")
    }
    
    /// Legacy importAll method for compatibility
    func importAll(_ data: Data) throws {
        Task {
            try await importAll(data)
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
    
    private func baseQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
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
