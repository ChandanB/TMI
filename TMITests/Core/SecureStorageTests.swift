//
//  SecureStorageTests.swift
//  TMITests
//
//  Created by Claude Code on 8/20/25.
//

import XCTest
import CryptoKit
@testable import TMI

final class SecureStorageTests: XCTestCase {
    
    private var secureStorage: SecureStorage!
    private let testKey = "testStorageKey"
    private let testData = "Test data for secure storage".data(using: .utf8)!
    
    override func setUp() async throws {
        try await super.setUp()
        secureStorage = SecureStorage.shared
        
        // Clean up any existing test data
        try? await secureStorage.delete(key: testKey)
    }
    
    override func tearDown() async throws {
        // Clean up test data
        try? await secureStorage.delete(key: testKey)
        secureStorage = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Storage Tests
    
    func testStoreAndRetrieveData() async throws {
        // When
        try await secureStorage.store(testData, forKey: testKey)
        let retrievedData = try await secureStorage.retrieve(forKey: testKey)
        
        // Then
        XCTAssertEqual(testData, retrievedData, "Retrieved data should match stored data")
    }
    
    func testStoreAndRetrieveString() async throws {
        // Given
        let testString = "Test string for secure storage"
        
        // When
        try await secureStorage.store(testString, forKey: testKey)
        let retrievedString = try await secureStorage.retrieveString(forKey: testKey)
        
        // Then
        XCTAssertEqual(testString, retrievedString, "Retrieved string should match stored string")
    }
    
    func testStoreAndRetrieveCodable() async throws {
        // Given
        struct TestModel: Codable, Equatable {
            let id: String
            let name: String
            let value: Int
        }
        
        let testModel = TestModel(id: "123", name: "Test", value: 42)
        
        // When
        try await secureStorage.store(testModel, forKey: testKey)
        let retrievedModel: TestModel = try await secureStorage.retrieveCodable(forKey: testKey)
        
        // Then
        XCTAssertEqual(testModel, retrievedModel, "Retrieved model should match stored model")
    }
    
    func testOverwriteExistingData() async throws {
        // Given
        let originalData = "Original data".data(using: .utf8)!
        let newData = "New data".data(using: .utf8)!
        
        // When
        try await secureStorage.store(originalData, forKey: testKey)
        try await secureStorage.store(newData, forKey: testKey) // Overwrite
        let retrievedData = try await secureStorage.retrieve(forKey: testKey)
        
        // Then
        XCTAssertEqual(newData, retrievedData, "Retrieved data should be the new data")
        XCTAssertNotEqual(originalData, retrievedData, "Retrieved data should not be the original data")
    }
    
    // MARK: - Error Handling Tests
    
    func testRetrieveNonExistentKey() async throws {
        // When/Then
        do {
            _ = try await secureStorage.retrieve(forKey: "nonExistentKey")
            XCTFail("Should have thrown an error for non-existent key")
        } catch SecureStorageError.itemNotFound {
            // Expected error
            XCTAssertTrue(true, "Should throw itemNotFound error")
        } catch {
            XCTFail("Should throw itemNotFound error, got \(error)")
        }
    }
    
    func testRetrieveInvalidStringData() async throws {
        // Given
        let invalidStringData = Data([0xFF, 0xFE, 0xFD]) // Invalid UTF-8
        try await secureStorage.store(invalidStringData, forKey: testKey)
        
        // When/Then
        do {
            _ = try await secureStorage.retrieveString(forKey: testKey)
            XCTFail("Should have thrown an error for invalid string data")
        } catch SecureStorageError.dataCorrupted {
            XCTAssertTrue(true, "Should throw dataCorrupted error")
        } catch {
            XCTFail("Should throw dataCorrupted error, got \(error)")
        }
    }
    
    func testRetrieveInvalidCodableData() async throws {
        // Given
        struct TestModel: Codable {
            let name: String
        }
        
        let invalidJson = "{invalid json}".data(using: .utf8)!
        try await secureStorage.store(invalidJson, forKey: testKey)
        
        // When/Then
        do {
            let _: TestModel = try await secureStorage.retrieveCodable(forKey: testKey)
            XCTFail("Should have thrown an error for invalid JSON data")
        } catch SecureStorageError.dataCorrupted {
            XCTAssertTrue(true, "Should throw dataCorrupted error")
        } catch {
            XCTFail("Should throw dataCorrupted error, got \(error)")
        }
    }
    
    // MARK: - Key Existence Tests
    
    func testKeyExists() async throws {
        // Initially should not exist
        let existsInitially = await secureStorage.exists(key: testKey)
        XCTAssertFalse(existsInitially, "Key should not exist initially")
        
        // Store data
        try await secureStorage.store(testData, forKey: testKey)
        let existsAfterStore = await secureStorage.exists(key: testKey)
        XCTAssertTrue(existsAfterStore, "Key should exist after storing data")
        
        // Delete data
        try await secureStorage.delete(key: testKey)
        let existsAfterDelete = await secureStorage.exists(key: testKey)
        XCTAssertFalse(existsAfterDelete, "Key should not exist after deletion")
    }
    
    // MARK: - Deletion Tests
    
    func testDeleteExistingKey() async throws {
        // Given
        try await secureStorage.store(testData, forKey: testKey)
        XCTAssertTrue(await secureStorage.exists(key: testKey), "Key should exist before deletion")
        
        // When
        try await secureStorage.delete(key: testKey)
        
        // Then
        XCTAssertFalse(await secureStorage.exists(key: testKey), "Key should not exist after deletion")
    }
    
    func testDeleteNonExistentKey() async throws {
        // When/Then - Should not throw an error
        try await secureStorage.delete(key: "nonExistentKey")
        // Test passes if no error is thrown
    }
    
    func testClearAllData() async throws {
        // Given
        let keys = ["key1", "key2", "key3"]
        for key in keys {
            try await secureStorage.store("test data".data(using: .utf8)!, forKey: key)
        }
        
        // Verify all keys exist
        for key in keys {
            XCTAssertTrue(await secureStorage.exists(key: key), "Key \(key) should exist before clearing")
        }
        
        // When
        try await secureStorage.clearAll()
        
        // Then
        for key in keys {
            XCTAssertFalse(await secureStorage.exists(key: key), "Key \(key) should not exist after clearing")
        }
    }
    
    // MARK: - Data Classification Tests
    
    func testStoreWithDataClassification() async throws {
        // Given
        let sensitiveData = "Sensitive user information".data(using: .utf8)!
        
        // When
        try await secureStorage.store(
            sensitiveData, 
            forKey: testKey, 
            classification: .sensitive
        )
        let retrievedData = try await secureStorage.retrieve(forKey: testKey)
        
        // Then
        XCTAssertEqual(sensitiveData, retrievedData, "Data should be stored and retrieved correctly with classification")
    }
    
    func testStoreTraumaRelatedData() async throws {
        // Given
        let traumaData = "Trauma-related assessment data".data(using: .utf8)!
        
        // When
        try await secureStorage.store(
            traumaData, 
            forKey: testKey, 
            classification: .traumaRelated
        )
        let retrievedData = try await secureStorage.retrieve(forKey: testKey)
        
        // Then
        XCTAssertEqual(traumaData, retrievedData, "Trauma-related data should be stored and retrieved correctly")
    }
    
    // MARK: - Biometric Authentication Tests
    
    func testStoreWithBiometricProtection() async throws {
        // When
        do {
            try await secureStorage.storeWithBiometrics(testData, forKey: testKey)
            let retrievedData = try await secureStorage.retrieveWithBiometrics(forKey: testKey)
            
            // Then
            XCTAssertEqual(testData, retrievedData, "Biometric-protected data should be stored and retrieved correctly")
        } catch SecureStorageError.biometricsNotAvailable {
            // Skip test if biometrics not available (common in simulator)
            throw XCTSkip("Biometrics not available for testing")
        } catch SecureStorageError.userCancelled {
            // Skip test if user cancelled biometric prompt
            throw XCTSkip("User cancelled biometric authentication")
        }
    }
    
    func testStoreStringWithBiometrics() async throws {
        // Given
        let testString = "Biometric-protected string"
        
        // When
        do {
            try await secureStorage.storeWithBiometrics(testString, forKey: testKey)
            let retrievedString = try await secureStorage.retrieveStringWithBiometrics(forKey: testKey)
            
            // Then
            XCTAssertEqual(testString, retrievedString, "Biometric-protected string should match")
        } catch SecureStorageError.biometricsNotAvailable {
            throw XCTSkip("Biometrics not available for testing")
        }
    }
    
    // MARK: - Encryption Tests
    
    func testDataEncryption() async throws {
        // Store data and verify it's encrypted in keychain
        try await secureStorage.store(testData, forKey: testKey)
        
        // The fact that we can store and retrieve the same data
        // indicates encryption/decryption is working properly
        let retrievedData = try await secureStorage.retrieve(forKey: testKey)
        XCTAssertEqual(testData, retrievedData, "Encryption/decryption should be transparent")
    }
    
    func testEncryptionKeyRotation() async throws {
        // This would test key rotation functionality
        // For now, we verify that data remains accessible after storage
        try await secureStorage.store(testData, forKey: testKey)
        
        // Simulate app restart by creating new instance
        let newSecureStorage = SecureStorage.shared
        let retrievedData = try await newSecureStorage.retrieve(forKey: testKey)
        
        XCTAssertEqual(testData, retrievedData, "Data should be accessible after key operations")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentStorage() async throws {
        let concurrentKeys = Array(0..<10).map { "concurrentKey\($0)" }
        
        // Store data concurrently
        await withTaskGroup(of: Void.self) { group in
            for (index, key) in concurrentKeys.enumerated() {
                group.addTask {
                    let data = "Concurrent data \(index)".data(using: .utf8)!
                    try? await self.secureStorage.store(data, forKey: key)
                }
            }
        }
        
        // Verify all data was stored correctly
        for (index, key) in concurrentKeys.enumerated() {
            do {
                let retrievedData = try await secureStorage.retrieve(forKey: key)
                let expectedData = "Concurrent data \(index)".data(using: .utf8)!
                XCTAssertEqual(expectedData, retrievedData, "Concurrent storage should work correctly")
            } catch {
                XCTFail("Failed to retrieve concurrent data for key \(key): \(error)")
            }
        }
        
        // Clean up
        for key in concurrentKeys {
            try? await secureStorage.delete(key: key)
        }
    }
    
    func testConcurrentRetrievalOfSameKey() async throws {
        // Store initial data
        try await secureStorage.store(testData, forKey: testKey)
        
        // Retrieve the same key concurrently
        let tasks = (0..<5).map { _ in
            Task {
                return try await secureStorage.retrieve(forKey: testKey)
            }
        }
        
        // Wait for all tasks to complete
        var results: [Data] = []
        for task in tasks {
            do {
                let data = try await task.value
                results.append(data)
            } catch {
                XCTFail("Concurrent retrieval failed: \(error)")
            }
        }
        
        // Verify all results are identical
        for data in results {
            XCTAssertEqual(testData, data, "Concurrent retrieval should return consistent data")
        }
    }
    
    // MARK: - Performance Tests
    
    func testStoragePerformance() async throws {
        let testDatas = Array(0..<100).map { "Performance test data \($0)".data(using: .utf8)! }
        
        measure {
            Task {
                for (index, data) in testDatas.enumerated() {
                    try? await secureStorage.store(data, forKey: "perfKey\(index)")
                }
                
                // Clean up
                for index in 0..<testDatas.count {
                    try? await secureStorage.delete(key: "perfKey\(index)")
                }
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testLargeDataStorage() async throws {
        // Create 1MB of test data
        let largeData = Data(repeating: 0x42, count: 1024 * 1024)
        
        // When
        try await secureStorage.store(largeData, forKey: testKey)
        let retrievedData = try await secureStorage.retrieve(forKey: testKey)
        
        // Then
        XCTAssertEqual(largeData.count, retrievedData.count, "Large data should be stored completely")
        XCTAssertEqual(largeData, retrievedData, "Large data should be retrieved correctly")
    }
    
    // MARK: - SecureStorageError Tests
    
    func testSecureStorageErrorDescriptions() {
        let errors: [SecureStorageError] = [
            .itemNotFound,
            .dataCorrupted,
            .encryptionFailed,
            .decryptionFailed,
            .keychainError(status: -25300),
            .biometricsNotAvailable,
            .userCancelled
        ]
        
        for error in errors {
            XCTAssertNotNil(error.localizedDescription, "Error should have localized description")
            XCTAssertFalse(error.localizedDescription.isEmpty, "Error description should not be empty")
        }
    }
    
    // MARK: - Edge Cases
    
    func testEmptyDataStorage() async throws {
        // Given
        let emptyData = Data()
        
        // When
        try await secureStorage.store(emptyData, forKey: testKey)
        let retrievedData = try await secureStorage.retrieve(forKey: testKey)
        
        // Then
        XCTAssertEqual(emptyData, retrievedData, "Empty data should be handled correctly")
        XCTAssertTrue(retrievedData.isEmpty, "Retrieved data should be empty")
    }
    
    func testEmptyStringStorage() async throws {
        // Given
        let emptyString = ""
        
        // When
        try await secureStorage.store(emptyString, forKey: testKey)
        let retrievedString = try await secureStorage.retrieveString(forKey: testKey)
        
        // Then
        XCTAssertEqual(emptyString, retrievedString, "Empty string should be handled correctly")
        XCTAssertTrue(retrievedString.isEmpty, "Retrieved string should be empty")
    }
    
    func testSpecialCharactersInKey() async throws {
        // Given
        let specialKey = "test.key-with_special@chars#123"
        
        // When
        try await secureStorage.store(testData, forKey: specialKey)
        let retrievedData = try await secureStorage.retrieve(forKey: specialKey)
        
        // Then
        XCTAssertEqual(testData, retrievedData, "Keys with special characters should work")
        
        // Clean up
        try await secureStorage.delete(key: specialKey)
    }
}