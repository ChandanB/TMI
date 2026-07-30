//
//  KeychainManagerTests.swift
//  TMITests
//
//  Created by Claude Code on 8/20/25.
//

import XCTest
import CryptoKit
import Security
@testable import TMI

final class KeychainManagerTests: XCTestCase {
    
    private var keychainManager: KeychainManager!
    private let testService = "com.tmi.test.keychain"
    private let testKey = "testKeychainKey"
    private let testData = "Test keychain data".data(using: .utf8)!
    
    override func setUp() async throws {
        try await super.setUp()
        keychainManager = KeychainManager(service: testService)
        
        // Clean up any existing test data
        try? await keychainManager.delete(for: testKey)
    }
    
    override func tearDown() async throws {
        // Clean up test data
        try? await keychainManager.clearAll()
        keychainManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Storage Tests
    
    func testStoreAndRetrieveData() async throws {
        // When
        try await keychainManager.store(testData, for: testKey)
        let retrievedData = try await keychainManager.retrieve(for: testKey)
        
        // Then
        XCTAssertEqual(testData, retrievedData, "Retrieved data should match stored data")
    }
    
    func testOverwriteExistingData() async throws {
        // Given
        let originalData = "Original data".data(using: .utf8)!
        let newData = "New data".data(using: .utf8)!
        
        // When
        try await keychainManager.store(originalData, for: testKey)
        try await keychainManager.store(newData, for: testKey) // Overwrite
        let retrievedData = try await keychainManager.retrieve(for: testKey)
        
        // Then
        XCTAssertEqual(newData, retrievedData, "Retrieved data should be the new data")
    }
    
    func testStoreWithAccessControl() async throws {
#if os(macOS)
        throw XCTSkip(
            "Passcode-protected retrieval requires an interactive Local Authentication prompt on macOS."
        )
#else
        // Given
        do {
            let accessControl = try keychainManager.createPasscodeAccessControl()
            
            // When
            try await keychainManager.store(testData, for: testKey, accessControl: accessControl)
            let retrievedData = try await keychainManager.retrieve(for: testKey)
            
            // Then
            XCTAssertEqual(testData, retrievedData, "Data with access control should be retrieved correctly")
        } catch KeychainError.accessControlCreationFailed {
            throw XCTSkip("Access control creation failed - may not be supported in test environment")
        }
#endif
    }
    
    func testStoreSynchronizableItemCanBeOverwrittenAndRetrieved() async throws {
        let replacementData = "Replacement synchronizable data".data(using: .utf8)!

        try await keychainManager.store(testData, for: testKey, synchronizable: true)
        try await keychainManager.store(replacementData, for: testKey, synchronizable: true)

        let retrievedData = try await keychainManager.retrieve(for: testKey)
        XCTAssertEqual(replacementData, retrievedData, "Synchronizable data should be overwritten without a duplicate-item error")
    }
    
    // MARK: - Error Handling Tests
    
    func testRetrieveNonExistentItem() async throws {
        // When/Then
        do {
            _ = try await keychainManager.retrieve(for: "nonExistentKey")
            XCTFail("Should have thrown an error for non-existent key")
        } catch KeychainError.itemNotFound {
            // Expected error
            XCTAssertTrue(true, "Should throw itemNotFound error")
        } catch {
            XCTFail("Should throw itemNotFound error, got \(error)")
        }
    }
    
    // MARK: - Key Existence Tests
    
    func testKeyExists() async throws {
        // Initially should not exist
        let existsInitially = await keychainManager.exists(for: testKey)
        XCTAssertFalse(existsInitially, "Key should not exist initially")
        
        // Store data
        try await keychainManager.store(testData, for: testKey)
        let existsAfterStore = await keychainManager.exists(for: testKey)
        XCTAssertTrue(existsAfterStore, "Key should exist after storing")
        
        // Delete data
        try await keychainManager.delete(for: testKey)
        let existsAfterDelete = await keychainManager.exists(for: testKey)
        XCTAssertFalse(existsAfterDelete, "Key should not exist after deletion")
    }
    
    // MARK: - Deletion Tests
    
    func testDeleteExistingItem() async throws {
        // Given
        try await keychainManager.store(testData, for: testKey)
        let existsBeforeDeletion = await keychainManager.exists(for: testKey)
        XCTAssertTrue(existsBeforeDeletion, "Key should exist before deletion")
        
        // When
        try await keychainManager.delete(for: testKey)
        
        // Then
        let existsAfterDeletion = await keychainManager.exists(for: testKey)
        XCTAssertFalse(existsAfterDeletion, "Key should not exist after deletion")
    }
    
    func testDeleteNonExistentItem() async throws {
        // When/Then - Should not throw an error
        try await keychainManager.delete(for: "nonExistentKey")
        // Test passes if no error is thrown
    }

    func testDeleteAllWithPrefixIsServiceScopedAndIdempotent() async throws {
        let prefix = "student-page-cache.v1.denied-authorities."
        let otherService = KeychainManager(
            service: "\(testService).other.\(UUID().uuidString)"
        )
        defer { try? otherService.deleteAll() }

        try await keychainManager.store(testData, for: "\(prefix)authority-a")
        try await keychainManager.store(testData, for: "\(prefix)authority-b")
        try await keychainManager.store(testData, for: "unrelated")
        try await otherService.store(testData, for: "\(prefix)authority-a")

        try await keychainManager.deleteAll(withPrefix: prefix)

        let firstMatchExists = await keychainManager.exists(
            for: "\(prefix)authority-a"
        )
        let secondMatchExists = await keychainManager.exists(
            for: "\(prefix)authority-b"
        )
        let unrelatedExists = await keychainManager.exists(for: "unrelated")
        let otherServiceMatchExists = await otherService.exists(
            for: "\(prefix)authority-a"
        )
        XCTAssertFalse(firstMatchExists)
        XCTAssertFalse(secondMatchExists)
        XCTAssertTrue(unrelatedExists)
        XCTAssertTrue(otherServiceMatchExists)

        try await keychainManager.deleteAll(withPrefix: prefix)
    }

    func testClearAll() async throws {
        // Given
        let keys = ["key1", "key2", "key3"]
        for key in keys {
            try await keychainManager.store("test data".data(using: .utf8)!, for: key)
        }
        
        // Verify all keys exist
        for key in keys {
            let exists = await keychainManager.exists(for: key)
            XCTAssertTrue(exists, "Key \(key) should exist")
        }
        
        // When
        try await keychainManager.clearAll()
        
        // Then
        for key in keys {
            let exists = await keychainManager.exists(for: key)
            XCTAssertFalse(exists, "Key \(key) should not exist after clearing")
        }
    }
    
    // MARK: - Cryptographic Key Tests
    
    func testStoreAndRetrieveSymmetricKey() async throws {
        // Given
        let originalKey = SymmetricKey(size: .bits256)
        let keyIdentifier = "testSymmetricKey"
        
        // When
        try await keychainManager.storeKey(originalKey, for: keyIdentifier)
        let retrievedKey = try await keychainManager.retrieveKey(for: keyIdentifier)
        
        // Then
        // Compare the raw key data since SymmetricKey doesn't conform to Equatable
        let originalKeyData = originalKey.withUnsafeBytes { Data($0) }
        let retrievedKeyData = retrievedKey.withUnsafeBytes { Data($0) }
        XCTAssertEqual(originalKeyData, retrievedKeyData, "Retrieved symmetric key should match original")
        
        // Clean up
        try await keychainManager.delete(for: keyIdentifier)
    }
    
    func testRetrieveNonExistentKey() async throws {
        // When/Then
        do {
            _ = try await keychainManager.retrieveKey(for: "nonExistentKey")
            XCTFail("Should have thrown an error for non-existent key")
        } catch KeychainError.keyNotFound {
            XCTAssertTrue(true, "Should throw keyNotFound error")
        } catch {
            XCTFail("Should throw keyNotFound error, got \(error)")
        }
    }

    func testSecureStorageRetrievalMigratesLegacyKeyClassWithoutChangingBytes() async throws {
        try await assertSecureStorageUpgrade(applicationTagUsesData: false)
        try await assertSecureStorageUpgrade(applicationTagUsesData: true)
    }

    private func assertSecureStorageUpgrade(applicationTagUsesData: Bool) async throws {
        let identifier = "legacy-symmetric-key-\(UUID().uuidString)"
        let payloadKey = "legacy-encrypted-payload"
        let keyData = Data((0..<32).map(UInt8.init))
        let applicationTag: Any = applicationTagUsesData ? Data(identifier.utf8) : identifier
        var legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTag,
        ]
        var legacyAddQuery = legacyQuery
        legacyAddQuery[kSecValueData as String] = keyData
        legacyAddQuery[kSecAttrKeySizeInBits as String] = keyData.count * 8
        legacyAddQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
#if os(macOS)
        legacyAddQuery[kSecUseDataProtectionKeychain as String] = true
        legacyAddQuery[kSecAttrKeyType as String] = kSecAttrKeyTypeAES
        legacyAddQuery[kSecAttrKeyClass as String] = kSecAttrKeyClassSymmetric
        legacyQuery[kSecUseDataProtectionKeychain as String] = true
        legacyQuery[kSecAttrKeyType as String] = kSecAttrKeyTypeAES
        legacyQuery[kSecAttrKeyClass as String] = kSecAttrKeyClassSymmetric
#endif

        SecItemDelete(legacyQuery as CFDictionary)
        defer { SecItemDelete(legacyQuery as CFDictionary) }
        XCTAssertEqual(SecItemAdd(legacyAddQuery as CFDictionary, nil), errSecSuccess)

        var seededRetrievalQuery = legacyQuery
        seededRetrievalQuery[kSecReturnData as String] = true
        seededRetrievalQuery[kSecMatchLimit as String] = kSecMatchLimitOne
        var seededResult: AnyObject?
        XCTAssertEqual(SecItemCopyMatching(seededRetrievalQuery as CFDictionary, &seededResult), errSecSuccess)
        let legacyStoredData = try XCTUnwrap(seededResult as? Data)
        let payload = Data("data encrypted before the key representation upgrade".utf8)
        let encodedPayload = try JSONEncoder().encode(payload)
        let sealedPayload = try AES.GCM.seal(
            encodedPayload,
            using: SymmetricKey(data: legacyStoredData)
        )
        let combinedPayload = try XCTUnwrap(sealedPayload.combined)
        try await keychainManager.store(combinedPayload, for: payloadKey)

        let storage = SecureStorage(keychain: keychainManager, encryptionKeyTag: identifier)
        let restoredPayload = try await storage.retrieve(Data.self, for: payloadKey)
        let retrievedData = try await keychainManager.retrieveKey(for: identifier)
        let migratedStoredData = try await keychainManager.retrieve(for: identifier)

        XCTAssertEqual(restoredPayload, payload)
        XCTAssertEqual(retrievedData.withUnsafeBytes { Data($0) }, legacyStoredData)
        XCTAssertEqual(SecItemCopyMatching(legacyQuery as CFDictionary, nil), errSecItemNotFound)
        XCTAssertEqual(migratedStoredData, legacyStoredData)
    }
    
    // MARK: - Bulk Operations Tests
    
    func testGetAllKeys() async throws {
        // Given
        let keys = ["bulk1", "bulk2", "bulk3"]
        for key in keys {
            try await keychainManager.store("data for \(key)".data(using: .utf8)!, for: key)
        }
        
        // When
        let retrievedKeys = try await keychainManager.getAllKeys()
        
        // Then
        for key in keys {
            XCTAssertTrue(retrievedKeys.contains(key), "Retrieved keys should contain \(key)")
        }
        
        // Clean up
        for key in keys {
            try await keychainManager.delete(for: key)
        }
    }
    
    func testGetAllKeysEmpty() async throws {
        // Ensure keychain is empty
        try await keychainManager.clearAll()
        
        // When
        let retrievedKeys = try await keychainManager.getAllKeys()
        
        // Then
        XCTAssertTrue(retrievedKeys.isEmpty, "Should return empty array for empty keychain")
    }
    
    func testExportAndImportAll() async throws {
        // Given
        let testData = [
            "export1": "Export test data 1".data(using: .utf8)!,
            "export2": "Export test data 2".data(using: .utf8)!,
            "export3": "Export test data 3".data(using: .utf8)!
        ]
        
        for (key, data) in testData {
            try await keychainManager.store(data, for: key)
        }
        
        // When - Export
        let exportedData = try await keychainManager.exportAll()
        XCTAssertFalse(exportedData.isEmpty, "Exported data should not be empty")
        
        // Clear keychain
        try await keychainManager.clearAll()
        
        // When - Import
        try await keychainManager.importAll(exportedData)
        
        // Then - Verify imported data
        for (key, originalData) in testData {
            let retrievedData = try await keychainManager.retrieve(for: key)
            XCTAssertEqual(originalData, retrievedData, "Imported data should match original for key \(key)")
        }
        
        // Clean up
        try await keychainManager.clearAll()
    }

    func testExportAndImportAllExcludeRawKeyMaterial() async throws {
        let excludedKey = "TMI_MASTER_KEY"
        let rawKeyMaterial = Data(repeating: 0xA5, count: 32)
        let payloadKey = "device-bound-payload"
        let payload = Data("encrypted payload".utf8)

        try keychainManager.storeKey(rawKeyMaterial, for: excludedKey)
        try await keychainManager.store(payload, for: payloadKey)

        let exportedData = try await keychainManager.exportAll(excluding: [excludedKey])
        let exportedItems = try JSONDecoder().decode([String: Data].self, from: exportedData)

        XCTAssertNil(exportedItems[excludedKey], "Raw key material must never be present in an exported archive")
        XCTAssertEqual(exportedItems[payloadKey], payload)

        try await keychainManager.clearAll()

        let archiveWithRawKeyMaterial = try JSONEncoder().encode([
            excludedKey: rawKeyMaterial,
            payloadKey: payload,
        ])
        try await keychainManager.importAll(archiveWithRawKeyMaterial, excluding: [excludedKey])

        let excludedKeyExists = await keychainManager.exists(for: excludedKey)
        let importedPayload = try await keychainManager.retrieve(for: payloadKey)
        XCTAssertFalse(excludedKeyExists, "Excluded raw key material must not be imported")
        XCTAssertEqual(importedPayload, payload)
    }
    
    // MARK: - Access Control Tests
    
    func testCreateBiometricAccessControl() throws {
        // When
        do {
            let accessControl = try keychainManager.createBiometricAccessControl()
            XCTAssertNotNil(accessControl, "Biometric access control should be created")
        } catch KeychainError.accessControlCreationFailed {
            throw XCTSkip("Biometric access control creation failed - may not be supported")
        }
    }
    
    func testCreatePasscodeAccessControl() throws {
        // When
        do {
            let accessControl = try keychainManager.createPasscodeAccessControl()
            XCTAssertNotNil(accessControl, "Passcode access control should be created")
        } catch KeychainError.accessControlCreationFailed {
            throw XCTSkip("Passcode access control creation failed - may not be supported")
        }
    }
    
    func testCreateCustomAccessControl() throws {
        // When
        do {
            let accessControl = try keychainManager.createAccessControl(
                protection: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                flags: []
            )
            XCTAssertNotNil(accessControl, "Custom access control should be created")
        } catch KeychainError.accessControlCreationFailed {
            throw XCTSkip("Custom access control creation failed - may not be supported")
        }
    }
    
    // MARK: - Statistics Tests
    
    func testGetStatistics() async throws {
        // Given
        let testItems = [
            "stats1": "Statistics test data 1".data(using: .utf8)!,
            "stats2": "Statistics test data 2".data(using: .utf8)!
        ]
        
        for (key, data) in testItems {
            try await keychainManager.store(data, for: key)
        }
        
        // When
        let statistics = await keychainManager.getStatistics()
        
        // Then
        XCTAssertGreaterThanOrEqual(statistics.totalItems, testItems.count, "Should have at least test items")
        XCTAssertGreaterThanOrEqual(statistics.accessibleItems, testItems.count, "Should have accessible test items")
        XCTAssertGreaterThan(statistics.totalSize, 0, "Should have non-zero total size")
        XCTAssertEqual(statistics.service, testService, "Statistics should show correct service")
        
        // Test description
        let description = statistics.description
        XCTAssertFalse(description.isEmpty, "Statistics description should not be empty")
        XCTAssertTrue(description.contains(testService), "Description should contain service name")
        
        // Clean up
        for key in testItems.keys {
            try await keychainManager.delete(for: key)
        }
    }
    
    func testGetStatisticsEmpty() async throws {
        // Ensure keychain is empty
        try await keychainManager.clearAll()
        
        // When
        let statistics = await keychainManager.getStatistics()
        
        // Then
        XCTAssertEqual(statistics.totalItems, 0, "Empty keychain should have 0 items")
        XCTAssertEqual(statistics.accessibleItems, 0, "Empty keychain should have 0 accessible items")
        XCTAssertEqual(statistics.totalSize, 0, "Empty keychain should have 0 size")
        XCTAssertEqual(statistics.averageItemSize, 0, "Empty keychain should have 0 average size")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentStorage() async throws {
        let concurrentKeys = Array(0..<10).map { "concurrent\($0)" }
        let manager = try XCTUnwrap(keychainManager)
        
        // Store data concurrently
        await withTaskGroup(of: Void.self) { group in
            for (index, key) in concurrentKeys.enumerated() {
                group.addTask {
                    let data = "Concurrent data \(index)".data(using: .utf8)!
                    try? await manager.store(data, for: key)
                }
            }
        }
        
        // Verify all data was stored correctly
        for (index, key) in concurrentKeys.enumerated() {
            do {
                let retrievedData = try await keychainManager.retrieve(for: key)
                let expectedData = "Concurrent data \(index)".data(using: .utf8)!
                XCTAssertEqual(expectedData, retrievedData, "Concurrent storage should work for key \(key)")
            } catch {
                XCTFail("Failed to retrieve concurrent data for key \(key): \(error)")
            }
        }
        
        // Clean up
        for key in concurrentKeys {
            try? await keychainManager.delete(for: key)
        }
    }
    
    // MARK: - Performance Tests
    
    func testStoragePerformance() async throws {
        let testData = Array(0..<100).map { "Performance test data \($0)".data(using: .utf8)! }
        let manager = keychainManager!
        
        measure {
            let expectation = XCTestExpectation(description: "Keychain performance task completed")

            Task {
                for (index, data) in testData.enumerated() {
                    try? await manager.store(data, for: "perf\(index)")
                }
                
                // Clean up
                for index in 0..<testData.count {
                    try? await manager.delete(for: "perf\(index)")
                }

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testKeychainErrorDescriptions() {
        let errors: [KeychainError] = [
            .storeFailed(status: -25299),
            .retrieveFailed(status: -25300),
            .deleteFailed(status: -25301),
            .clearFailed(status: -25302),
            .keyStoreFailed(status: -25303),
            .keyRetrieveFailed(status: -25304),
            .bulkRetrieveFailed(status: -25305),
            .itemNotFound,
            .keyNotFound,
            .invalidData,
            .invalidKeyData,
            .accessControlCreationFailed("Test error")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.localizedDescription, "Error should have localized description")
            XCTAssertFalse(error.localizedDescription.isEmpty, "Error description should not be empty")
            XCTAssertNotNil(error.failureReason, "Error should have failure reason")
        }
    }
    
    // MARK: - Edge Cases
    
    func testEmptyDataStorage() async throws {
        // Given
        let emptyData = Data()
        
        // When
        try await keychainManager.store(emptyData, for: testKey)
        let retrievedData = try await keychainManager.retrieve(for: testKey)
        
        // Then
        XCTAssertEqual(emptyData, retrievedData, "Empty data should be handled correctly")
        XCTAssertTrue(retrievedData.isEmpty, "Retrieved data should be empty")
    }
    
    func testLargeDataStorage() async throws {
        // Given - 100KB of data
        let largeData = Data(repeating: 0x42, count: 100 * 1024)
        
        // When
        try await keychainManager.store(largeData, for: testKey)
        let retrievedData = try await keychainManager.retrieve(for: testKey)
        
        // Then
        XCTAssertEqual(largeData.count, retrievedData.count, "Large data should be stored completely")
        XCTAssertEqual(largeData, retrievedData, "Large data should be retrieved correctly")
    }
    
    func testSpecialCharactersInKey() async throws {
        // Given
        let specialKey = "test.key-with_special@chars#123!$%"
        
        // When
        try await keychainManager.store(testData, for: specialKey)
        let retrievedData = try await keychainManager.retrieve(for: specialKey)
        
        // Then
        XCTAssertEqual(testData, retrievedData, "Keys with special characters should work")
        
        // Clean up
        try await keychainManager.delete(for: specialKey)
    }
    
    func testAccessGroupInitialization() {
        // Given
        let accessGroup = "group.com.tmi.test"
        
        // When
        let keychainWithGroup = KeychainManager(service: testService, accessGroup: accessGroup)
        
        // Then
        XCTAssertNotNil(keychainWithGroup, "Keychain manager with access group should initialize")
    }
}
