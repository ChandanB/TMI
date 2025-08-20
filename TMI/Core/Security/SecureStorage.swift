//
//  SecureStorage.swift
//  TMI
//
//  Created by Claude Code on 8/20/25.
//

import Foundation
import CryptoKit
import LocalAuthentication
import Security

final class SecureStorage: Sendable {
    static let shared = SecureStorage()
    
    private let keychain = KeychainManager()
    private let logger = TMILogger(category: "SecureStorage")
    
    // Encryption key management
    private let encryptionKeyTag = "TMI_MASTER_KEY"
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Store sensitive data securely
    func store<T: Codable & Sendable>(
        _ object: T,
        for key: String,
        requiresBiometric: Bool = false
    ) async throws {
        logger.debug("Storing secure data", metadata: ["key": key, "biometric": requiresBiometric])
        
        if requiresBiometric {
            try await authenticateBiometric()
        }
        
        do {
            let data = try JSONEncoder().encode(object)
            let encryptedData = try await encrypt(data)
            
            try await keychain.store(encryptedData, for: key, requiresBiometric: requiresBiometric)
            logger.info("Successfully stored secure data", metadata: ["key": key])
        } catch {
            logger.error("Failed to store secure data", error: error)
            throw SecureStorageError.storageFailed
        }
    }
    
    /// Retrieve sensitive data securely
    func retrieve<T: Codable & Sendable>(
        _ type: T.Type,
        for key: String,
        requiresBiometric: Bool = false
    ) async throws -> T {
        logger.debug("Retrieving secure data", metadata: ["key": key, "type": String(describing: type)])
        
        if requiresBiometric {
            try await authenticateBiometric()
        }
        
        do {
            let encryptedData = try await keychain.retrieve(for: key)
            let decryptedData = try await decrypt(encryptedData)
            let object = try JSONDecoder().decode(type, from: decryptedData)
            
            logger.debug("Successfully retrieved secure data", metadata: ["key": key])
            return object
        } catch KeychainError.itemNotFound {
            throw SecureStorageError.dataNotFound
        } catch {
            logger.error("Failed to retrieve secure data", error: error)
            throw SecureStorageError.retrievalFailed
        }
    }
    
    /// Check if secure data exists for key
    func exists(for key: String) -> Bool {
        return keychain.exists(for: key)
    }
    
    /// Delete secure data
    func delete(for key: String) throws {
        logger.debug("Deleting secure data", metadata: ["key": key])
        
        do {
            try keychain.delete(for: key)
            logger.info("Successfully deleted secure data", metadata: ["key": key])
        } catch {
            logger.error("Failed to delete secure data", error: error)
            throw SecureStorageError.deletionFailed
        }
    }
    
    /// Clear all secure data (use with caution)
    func clearAll() throws {
        logger.warning("Clearing all secure data")
        
        do {
            try keychain.deleteAll()
            logger.info("Successfully cleared all secure data")
        } catch {
            logger.error("Failed to clear all secure data", error: error)
            throw SecureStorageError.clearFailed
        }
    }
    
    // MARK: - Encryption Methods
    
    private func encrypt(_ data: Data) async throws -> Data {
        do {
            let key = try await getOrCreateEncryptionKey()
            let sealedBox = try AES.GCM.seal(data, using: key)
            
            guard let combined = sealedBox.combined else {
                throw SecureStorageError.encryptionFailed
            }
            
            return combined
        } catch {
            logger.error("Encryption failed", error: error)
            throw SecureStorageError.encryptionFailed
        }
    }
    
    private func decrypt(_ data: Data) async throws -> Data {
        do {
            let key = try await getOrCreateEncryptionKey()
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            
            return decryptedData
        } catch {
            logger.error("Decryption failed", error: error)
            throw SecureStorageError.decryptionFailed
        }
    }
    
    private func getOrCreateEncryptionKey() async throws -> SymmetricKey {
        // Try to retrieve existing key
        if let existingKeyData = try? await keychain.retrieveKey(for: encryptionKeyTag) {
            return SymmetricKey(data: existingKeyData)
        }
        
        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        
        try keychain.storeKey(keyData, for: encryptionKeyTag)
        logger.info("Created new encryption key")
        
        return newKey
    }
    
    // MARK: - Biometric Authentication
    
    private func authenticateBiometric() async throws {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            logger.warning("Biometric authentication not available", metadata: ["error": error?.localizedDescription ?? "unknown"])
            throw SecureStorageError.biometricNotAvailable
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to access secure TMI data"
            )
            
            if !success {
                throw SecureStorageError.authenticationFailed
            }
            
            logger.debug("Biometric authentication successful")
        } catch {
            logger.error("Biometric authentication failed", error: error)
            throw SecureStorageError.authenticationFailed
        }
    }
    
    // MARK: - Keychain Backup
    
    /// Export encrypted backup of all secure data
    func exportBackup() async throws -> Data {
        logger.info("Creating secure backup")
        
        let backupData = try await keychain.exportAll()
        let compressedData = try backupData.compressed()
        
        // Add integrity check
        let backup = SecureBackup(
            data: compressedData,
            checksum: SHA256.hash(data: compressedData).description,
            timestamp: Date(),
            version: "1.0"
        )
        
        return try JSONEncoder().encode(backup)
    }
    
    /// Import encrypted backup
    func importBackup(_ backupData: Data) async throws {
        logger.info("Importing secure backup")
        
        let backup = try JSONDecoder().decode(SecureBackup.self, from: backupData)
        
        // Verify integrity
        let computedChecksum = SHA256.hash(data: backup.data).description
        guard computedChecksum == backup.checksum else {
            throw SecureStorageError.corruptedBackup
        }
        
        let decompressedData = try backup.data.decompressed()
        try await keychain.importAll(decompressedData)
        
        logger.info("Successfully imported secure backup")
    }
}

// MARK: - Supporting Types
enum SecureStorageError: LocalizedError, Sendable {
    case encryptionFailed
    case decryptionFailed
    case biometricNotAvailable
    case authenticationFailed
    case dataNotFound
    case storageFailed
    case retrievalFailed
    case deletionFailed
    case clearFailed
    case corruptedBackup
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .biometricNotAvailable:
            return "Biometric authentication is not available"
        case .authenticationFailed:
            return "Authentication failed"
        case .dataNotFound:
            return "Secure data not found"
        case .storageFailed:
            return "Failed to store data"
        case .retrievalFailed:
            return "Failed to retrieve data"
        case .deletionFailed:
            return "Failed to delete data"
        case .clearFailed:
            return "Failed to clear all data"
        case .corruptedBackup:
            return "Backup data is corrupted"
        }
    }
}

private struct SecureBackup: Codable, Sendable {
    let data: Data
    let checksum: String
    let timestamp: Date
    let version: String
}

// MARK: - Data Compression Extension
private extension Data {
    func compressed() throws -> Data {
        return try (self as NSData).compressed(using: .lzfse) as Data
    }
    
    func decompressed() throws -> Data {
        return try (self as NSData).decompressed(using: .lzfse) as Data
    }
}
