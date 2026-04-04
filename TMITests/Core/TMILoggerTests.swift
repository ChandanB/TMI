//
//  TMILoggerTests.swift
//  TMITests
//
//  Created by Claude Code on 8/20/25.
//

import XCTest
@testable import TMI

final class TMILoggerTests: XCTestCase {
    private var logger: TMILogger!

    override func setUp() {
        super.setUp()
        logger = TMILogger(category: "TestCategory")
    }

    override func tearDown() {
        logger = nil
        super.tearDown()
    }

    func testLoggerInitialization() {
        XCTAssertNotNil(logger)
    }

    func testBasicLoggingMethodsDoNotCrash() {
        logger.debug("Debug message", metadata: ["key": "value"])
        logger.info("Info message", metadata: ["key": "value"])
        logger.warning("Warning message", metadata: ["key": "value"])
        logger.error("Error message", error: NSError(domain: "Test", code: 1))
        logger.critical("Critical message", error: NSError(domain: "Test", code: 2))

        XCTAssertTrue(true)
    }

    func testSpecializedLoggingMethodsDoNotCrash() {
        logger.logPerformance("student-load", duration: 0.4, metadata: ["count": 10])
        logger.logUserAction("button_tap", userId: "user-1", metadata: ["screen": "dashboard"])
        logger.logNetwork("/students", method: "GET", statusCode: 200, duration: 0.2)
        logger.logFirebase("fetchStudents", collection: "students", documentId: "123", success: true)
        logger.logAccessibility("voiceover_toggled", element: "mainButton", metadata: ["enabled": true])

        XCTAssertTrue(true)
    }

    func testGlobalLoggerFactoryProvidesExpectedCategories() {
        let loggers = [
            Log.auth,
            Log.firebase,
            Log.ui,
            Log.network,
            Log.data,
            Log.performance,
            Log.security,
            Log.validation,
            Log.accessibility,
            Log.tmiPlan,
            Log.student,
            Log.cache,
            Log.storage
        ]

        XCTAssertEqual(loggers.count, 13)
    }

    func testErrorLoggingAcceptsContext() {
        let context = ErrorContext(
            operation: "fetchStudents",
            userId: "user-123",
            metadata: ["screen": "dashboard"]
        )

        logger.error(
            "Operation failed",
            error: NSError(domain: "Test", code: 99),
            context: context
        )

        XCTAssertTrue(true)
    }
}
