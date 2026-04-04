//
//  CoreTestSuite.swift
//  TMITests
//
//  Created by Claude Code on 8/20/25.
//

import XCTest
@testable import TMI

final class CoreTestSuite: XCTestCase {

    func testCoreModulesInstantiate() async throws {
        let logger = TMILogger(category: "CoreTestSuite")
        let secureStorage = SecureStorage.shared
        let keychainManager = KeychainManager()
        let minFontSize = WCAGCompliance.minimumAccessibleFontSize()

        XCTAssertNotNil(logger)
        XCTAssertNotNil(secureStorage)
        XCTAssertNotNil(keychainManager)
        XCTAssertGreaterThan(minFontSize, 0)

        await MainActor.run {
            XCTAssertNotNil(AccessibilityManager.shared)
        }
    }

    func testSecureStorageAndKeychainRoundTrip() async throws {
        let secureKey = "core-suite-secure-key"
        let keychainKey = "core-suite-keychain-key"
        let payload = Data("Core suite payload".utf8)

        try? SecureStorage.shared.delete(for: secureKey)
        try? await KeychainManager().delete(for: keychainKey)

        try await SecureStorage.shared.store(payload, for: secureKey)
        let secureResult = try await SecureStorage.shared.retrieve(Data.self, for: secureKey)
        XCTAssertEqual(secureResult, payload)

        let keychainManager = KeychainManager()
        try await keychainManager.store(payload, for: keychainKey)
        let keychainResult = try await keychainManager.retrieve(for: keychainKey)
        XCTAssertEqual(keychainResult, payload)

        try? SecureStorage.shared.delete(for: secureKey)
        try? await keychainManager.delete(for: keychainKey)
    }

    func testValidationAndLoggingSmokeCoverage() {
        let logger = TMILogger(category: "CoreSmoke")
        logger.info("Validation smoke test", metadata: ["suite": "core"])

        XCTAssertTrue(ValidationRules.email("teacher@example.com").isValid)
        XCTAssertFalse(ValidationRules.email("bad-email").isValid)
        XCTAssertTrue(ValidationRules.studentAge(12).isValid)
        XCTAssertFalse(ValidationRules.studentAge(30).isValid)
    }

    @MainActor
    func testAccessibilityAndWCAGUtilities() {
        let animation = WCAGCompliance.accessibleAnimation(duration: 0.2, curve: .easeInOut, respectsReduceMotion: false)
        let isAccessible = WCAGCompliance.isAnimationAccessible(duration: 0.1, hasReduceMotion: true)

        XCTAssertNotNil(animation)
        XCTAssertTrue(isAccessible)
    }
}
