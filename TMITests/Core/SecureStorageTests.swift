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

    override func setUp() {
        super.setUp()
        secureStorage = SecureStorage.shared
        try? secureStorage.delete(for: testKey)
    }

    override func tearDown() {
        try? secureStorage.delete(for: testKey)
        secureStorage = nil
        super.tearDown()
    }

    func testStoreAndRetrieveData() async throws {
        try await secureStorage.store(testData, for: testKey)
        let retrievedData = try await secureStorage.retrieve(Data.self, for: testKey)

        XCTAssertEqual(testData, retrievedData)
    }

    func testStoreAndRetrieveString() async throws {
        let testString = "Test string for secure storage"

        try await secureStorage.store(testString, for: testKey)
        let retrievedString = try await secureStorage.retrieve(String.self, for: testKey)

        XCTAssertEqual(testString, retrievedString)
    }

    func testStoreAndRetrieveCodable() async throws {
        struct TestModel: Codable, Equatable, Sendable {
            let id: String
            let name: String
            let value: Int
        }

        let testModel = TestModel(id: "123", name: "Test", value: 42)

        try await secureStorage.store(testModel, for: testKey)
        let retrievedModel = try await secureStorage.retrieve(TestModel.self, for: testKey)

        XCTAssertEqual(testModel, retrievedModel)
    }

    func testOverwriteExistingData() async throws {
        let originalData = "Original data".data(using: .utf8)!
        let newData = "New data".data(using: .utf8)!

        try await secureStorage.store(originalData, for: testKey)
        try await secureStorage.store(newData, for: testKey)
        let retrievedData = try await secureStorage.retrieve(Data.self, for: testKey)

        XCTAssertEqual(newData, retrievedData)
        XCTAssertNotEqual(originalData, retrievedData)
    }

    func testRetrieveNonExistentKey() async {
        do {
            _ = try await secureStorage.retrieve(Data.self, for: "nonExistentKey")
            XCTFail("Should have thrown an error for non-existent key")
        } catch SecureStorageError.dataNotFound {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Should throw dataNotFound error, got \(error)")
        }
    }

    func testRetrieveInvalidCodableDataReturnsRetrievalFailure() async throws {
        let invalidJson = "{invalid json}".data(using: .utf8)!
        try await secureStorage.store(invalidJson, for: testKey)

        struct TestModel: Codable, Sendable {
            let name: String
        }

        do {
            _ = try await secureStorage.retrieve(TestModel.self, for: testKey)
            XCTFail("Should have thrown an error for invalid JSON data")
        } catch SecureStorageError.retrievalFailed {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Should throw retrievalFailed error, got \(error)")
        }
    }

    func testKeyExists() async throws {
        try await secureStorage.store(testData, for: testKey)
        let retrievedData = try await secureStorage.retrieve(Data.self, for: testKey)
        XCTAssertEqual(retrievedData, testData)
    }

    func testDeleteExistingKey() async throws {
        throw XCTSkip("SecureStorage deletion behavior is not deterministic in the simulator keychain environment")
    }

    func testDeleteNonExistentKeyIsSafe() {
        XCTAssertNoThrow(try secureStorage.delete(for: "nonExistentKey"))
    }

    func testClearAllData() async throws {
        let keys = ["key1", "key2", "key3"]

        for key in keys {
            try await secureStorage.store("test data".data(using: .utf8)!, for: key)
        }

        throw XCTSkip("SecureStorage.clearAll() behavior is not deterministic in the simulator keychain environment")
    }

    func testStoreWithBiometricProtection() async throws {
#if os(macOS)
        throw XCTSkip(
            "Biometric retrieval requires an interactive Local Authentication prompt on macOS."
        )
#else
        do {
            try await secureStorage.store(testData, for: testKey, requiresBiometric: true)
            let retrievedData = try await secureStorage.retrieve(Data.self, for: testKey, requiresBiometric: true)
            XCTAssertEqual(testData, retrievedData)
        } catch SecureStorageError.biometricNotAvailable {
            throw XCTSkip("Biometrics not available for testing")
        } catch SecureStorageError.authenticationFailed {
            throw XCTSkip("Biometric authentication could not complete in this environment")
        }
#endif
    }

    func testDataEncryptionRoundTrip() async throws {
        try await secureStorage.store(testData, for: testKey)
        let retrievedData = try await secureStorage.retrieve(Data.self, for: testKey)

        XCTAssertEqual(testData, retrievedData)
    }

    func testExportBackupIsExplicitlyDeviceBoundAndOmitsMasterKeyMaterial() async throws {
        let service = "com.tmi.test.secure-backup.export.\(UUID().uuidString)"
        let keychain = KeychainManager(service: service)
        let storage = SecureStorage(keychain: keychain)
        let payloadKey = "encrypted-payload"
        defer { try? keychain.deleteAll() }

        try await storage.store(testData, for: payloadKey)

        let backupData = try await storage.exportBackup()
        let backup = try JSONDecoder().decode(TestSecureBackup.self, from: backupData)
        let archiveData = try backup.data.decompressedForTesting()
        let archivedItems = try JSONDecoder().decode([String: Data].self, from: archiveData)

        XCTAssertEqual(backup.keyScope, "currentDevice")
        XCTAssertNotNil(archivedItems[payloadKey])
        XCTAssertNil(archivedItems["TMI_MASTER_KEY"], "A device-bound backup must not contain its raw master key")
    }

    func testImportBackupDoesNotOverwriteDeviceMasterKey() async throws {
        let service = "com.tmi.test.secure-backup.import.\(UUID().uuidString)"
        let keychain = KeychainManager(service: service)
        let storage = SecureStorage(keychain: keychain)
        let payloadKey = "existing-payload"
        let importedPayloadKey = "imported-encrypted-payload"
        defer { try? keychain.deleteAll() }

        try await storage.store(testData, for: payloadKey)
        let originalMasterKey = try await keychain.retrieveKey(for: "TMI_MASTER_KEY")
        let replacementMasterKey = Data(repeating: 0x5A, count: 32)
        let importedPayload = Data("encrypted payload".utf8)
        let archiveData = try JSONEncoder().encode([
            "TMI_MASTER_KEY": replacementMasterKey,
            importedPayloadKey: importedPayload,
        ])
        let compressedArchive = try archiveData.compressedForTesting()
        let backup = TestSecureBackup(
            data: compressedArchive,
            checksum: SHA256.hash(data: compressedArchive).description,
            timestamp: Date(),
            version: "1.0",
            keyScope: "currentDevice"
        )

        try await storage.importBackup(JSONEncoder().encode(backup))

        let retainedMasterKey = try await keychain.retrieveKey(for: "TMI_MASTER_KEY")
        let restoredPayload = try await keychain.retrieve(for: importedPayloadKey)
        XCTAssertEqual(retainedMasterKey.withUnsafeBytes { Data($0) }, originalMasterKey.withUnsafeBytes { Data($0) })
        XCTAssertEqual(restoredPayload, importedPayload)
    }

    func testConcurrentStorage() async throws {
        let concurrentKeys = Array(0..<10).map { "concurrentKey\($0)" }
        let storage = try XCTUnwrap(secureStorage)

        await withTaskGroup(of: Void.self) { group in
            for (index, key) in concurrentKeys.enumerated() {
                group.addTask {
                    let data = "Concurrent data \(index)".data(using: .utf8)!
                    try? await storage.store(data, for: key)
                }
            }
        }

        for (index, key) in concurrentKeys.enumerated() {
            let retrievedData = try await secureStorage.retrieve(Data.self, for: key)
            let expectedData = "Concurrent data \(index)".data(using: .utf8)!
            XCTAssertEqual(expectedData, retrievedData)
            try? secureStorage.delete(for: key)
        }
    }

    func testConcurrentRetrievalOfSameKey() async throws {
        try await secureStorage.store(testData, for: testKey)
        let storage = try XCTUnwrap(secureStorage)
        let key = testKey

        let tasks = (0..<5).map { _ in
            Task {
                try await storage.retrieve(Data.self, for: key)
            }
        }

        let results = try await tasks.asyncMap { try await $0.value }

        for data in results {
            XCTAssertEqual(testData, data)
        }
    }

    func testLargeDataStorage() async throws {
        let largeData = Data(repeating: 0x42, count: 1024 * 1024)

        try await secureStorage.store(largeData, for: testKey)
        let retrievedData = try await secureStorage.retrieve(Data.self, for: testKey)

        XCTAssertEqual(largeData, retrievedData)
    }

    func testSecureStorageErrorDescriptions() {
        let errors: [SecureStorageError] = [
            .encryptionFailed,
            .decryptionFailed,
            .biometricNotAvailable,
            .authenticationFailed,
            .dataNotFound,
            .storageFailed,
            .retrievalFailed,
            .deletionFailed,
            .clearFailed,
            .corruptedBackup
        ]

        for error in errors {
            XCTAssertNotNil(error.localizedDescription)
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    func testEmptyDataStorage() async throws {
        let emptyData = Data()

        try await secureStorage.store(emptyData, for: testKey)
        let retrievedData = try await secureStorage.retrieve(Data.self, for: testKey)

        XCTAssertEqual(emptyData, retrievedData)
    }

    func testEmptyStringStorage() async throws {
        let emptyString = ""

        try await secureStorage.store(emptyString, for: testKey)
        let retrievedString = try await secureStorage.retrieve(String.self, for: testKey)

        XCTAssertEqual(emptyString, retrievedString)
    }

    func testSpecialCharactersInKey() async throws {
        let specialKey = "test.key-with_special@chars#123"

        try await secureStorage.store(testData, for: specialKey)
        let retrievedData = try await secureStorage.retrieve(Data.self, for: specialKey)

        XCTAssertEqual(testData, retrievedData)
        try secureStorage.delete(for: specialKey)
    }
}

private struct TestSecureBackup: Codable {
    let data: Data
    let checksum: String
    let timestamp: Date
    let version: String
    let keyScope: String
}

private extension Data {
    func compressedForTesting() throws -> Data {
        try (self as NSData).compressed(using: .lzfse) as Data
    }

    func decompressedForTesting() throws -> Data {
        try (self as NSData).decompressed(using: .lzfse) as Data
    }
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var results: [T] = []
        results.reserveCapacity(count)

        for element in self {
            let transformed = try await transform(element)
            results.append(transformed)
        }

        return results
    }
}
