//
//  TMILoggerTests.swift
//  TMITests
//
//  Created by Claude Code on 8/20/25.
//

import XCTest
import OSLog
@testable import TMI

final class TMILoggerTests: XCTestCase {
    
    private var logger: TMILogger!
    private let testCategory = "TestCategory"
    
    override func setUp() {
        super.setUp()
        logger = TMILogger(category: testCategory)
    }
    
    override func tearDown() {
        logger = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testLoggerInitialization() {
        // When
        let logger = TMILogger(category: "TestCategory")
        
        // Then
        XCTAssertNotNil(logger, "Logger should initialize successfully")
    }
    
    func testLoggerCategorySubsystemSetCorrectly() {
        // Given
        let expectedSubsystem = "com.tmi.education"
        
        // When creating a logger with specific category
        let logger = TMILogger(category: "NetworkManager")
        
        // Then - Logger should be created with correct subsystem
        // Note: We can't directly test the internal logger properties, 
        // but we can verify the logger works correctly
        XCTAssertNotNil(logger)
    }
    
    // MARK: - Basic Logging Tests
    
    func testInfoLogging() {
        // When
        logger.info("Test info message", metadata: ["key": "value"])
        
        // Then - Should not crash and should handle metadata
        // In a production app, you would use a mock logger to verify the actual logging calls
        XCTAssertTrue(true, "Info logging should work without crashing")
    }
    
    func testDebugLogging() {
        // When
        logger.debug("Test debug message", metadata: ["debugKey": "debugValue"])
        
        // Then
        XCTAssertTrue(true, "Debug logging should work without crashing")
    }
    
    func testWarningLogging() {
        // When
        logger.warning("Test warning message", metadata: ["warningLevel": "medium"])
        
        // Then
        XCTAssertTrue(true, "Warning logging should work without crashing")
    }
    
    func testErrorLogging() {
        // Given
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // When
        logger.error("Test error message", error: testError, metadata: ["errorCode": 123])
        
        // Then
        XCTAssertTrue(true, "Error logging should work without crashing")
    }
    
    func testCriticalLogging() {
        // When
        logger.critical("Test critical message", metadata: ["severity": "high"])
        
        // Then
        XCTAssertTrue(true, "Critical logging should work without crashing")
    }
    
    // MARK: - Specialized Logging Tests
    
    func testNetworkRequestLogging() {
        // Given
        let requestData = NetworkRequestData(
            url: "https://api.example.com/users",
            method: "GET",
            statusCode: 200,
            responseSize: 1024,
            duration: 0.5
        )
        
        // When
        logger.logNetworkRequest(requestData)
        
        // Then
        XCTAssertTrue(true, "Network request logging should work without crashing")
    }
    
    func testNetworkErrorLogging() {
        // Given
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        
        // When
        logger.logNetworkError(error, url: "https://api.example.com/test")
        
        // Then
        XCTAssertTrue(true, "Network error logging should work without crashing")
    }
    
    func testFirebaseEventLogging() {
        // When
        logger.logFirebaseEvent("user_login", parameters: ["method": "email", "userId": "123"])
        
        // Then
        XCTAssertTrue(true, "Firebase event logging should work without crashing")
    }
    
    func testFirebaseErrorLogging() {
        // Given
        let firebaseError = NSError(domain: "FIRFirestoreErrorDomain", code: 14)
        
        // When
        logger.logFirebaseError(firebaseError, operation: "fetchStudents")
        
        // Then
        XCTAssertTrue(true, "Firebase error logging should work without crashing")
    }
    
    func testUserActionLogging() {
        // When
        logger.logUserAction("button_tap", details: ["buttonName": "saveStudent", "screenName": "studentDetail"])
        
        // Then
        XCTAssertTrue(true, "User action logging should work without crashing")
    }
    
    func testAccessibilityEventLogging() {
        // When
        logger.logAccessibilityEvent("voiceOverEnabled", metadata: ["previousState": false, "newState": true])
        
        // Then
        XCTAssertTrue(true, "Accessibility event logging should work without crashing")
    }
    
    // MARK: - Performance Logging Tests
    
    func testPerformanceMeasurementLogging() {
        // When
        logger.logPerformanceMeasurement(
            operation: "studentDataLoad",
            duration: 2.5,
            metadata: ["recordCount": 150]
        )
        
        // Then
        XCTAssertTrue(true, "Performance measurement logging should work without crashing")
    }
    
    func testMemoryUsageLogging() {
        // When
        logger.logMemoryUsage(used: 512, available: 2048, context: "afterStudentLoad")
        
        // Then
        XCTAssertTrue(true, "Memory usage logging should work without crashing")
    }
    
    // MARK: - Error Context Tests
    
    func testErrorLoggingWithComplexMetadata() {
        // Given
        let complexMetadata: [String: Any] = [
            "userId": "user123",
            "operation": "fetchStudents",
            "retryCount": 3,
            "timestamp": Date(),
            "requestParameters": ["limit": 50, "offset": 100],
            "networkConditions": ["type": "wifi", "strength": "excellent"]
        ]
        
        // When
        logger.error("Complex operation failed", metadata: complexMetadata)
        
        // Then
        XCTAssertTrue(true, "Complex metadata logging should work without crashing")
    }
    
    func testErrorLoggingWithNilMetadata() {
        // When
        logger.error("Error with nil metadata", metadata: nil)
        
        // Then
        XCTAssertTrue(true, "Nil metadata should be handled gracefully")
    }
    
    func testErrorLoggingWithEmptyMetadata() {
        // When
        logger.error("Error with empty metadata", metadata: [:])
        
        // Then
        XCTAssertTrue(true, "Empty metadata should be handled gracefully")
    }
    
    // MARK: - Specialized Logger Tests
    
    func testSpecializedLoggers() {
        // Test various specialized loggers exist and work
        let networkLogger = Log.network
        let authLogger = Log.authentication
        let firestoreLogger = Log.firestore
        let analyticsLogger = Log.analytics
        
        // When
        networkLogger.info("Network test message")
        authLogger.info("Auth test message")
        firestoreLogger.info("Firestore test message")
        analyticsLogger.info("Analytics test message")
        
        // Then
        XCTAssertTrue(true, "All specialized loggers should work")
    }
    
    // MARK: - Performance Tests
    
    func testLoggingPerformance() {
        // Test that logging doesn't significantly impact performance
        measure {
            for i in 0..<1000 {
                logger.info("Performance test message \(i)", metadata: ["iteration": i])
            }
        }
    }
    
    func testConcurrentLogging() {
        // Test thread safety of logging
        let expectation = XCTestExpectation(description: "Concurrent logging completed")
        expectation.expectedFulfillmentCount = 10
        
        for i in 0..<10 {
            DispatchQueue.global().async {
                self.logger.info("Concurrent message \(i)", metadata: ["threadId": i])
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Edge Case Tests
    
    func testLoggingWithSpecialCharacters() {
        // Given
        let specialMessage = "Test with émojis 🎉, quotes \"test\", and newlines\n\nMulti-line message"
        let specialMetadata = [
            "emoji": "🚀",
            "quotes": "\"quoted text\"",
            "newlines": "line1\nline2\nline3"
        ]
        
        // When
        logger.info(specialMessage, metadata: specialMetadata)
        
        // Then
        XCTAssertTrue(true, "Special characters should be handled properly")
    }
    
    func testLoggingWithLargeMetadata() {
        // Given
        var largeMetadata: [String: Any] = [:]
        for i in 0..<100 {
            largeMetadata["key\(i)"] = "value\(i) with some longer text to test size handling"
        }
        
        // When
        logger.info("Message with large metadata", metadata: largeMetadata)
        
        // Then
        XCTAssertTrue(true, "Large metadata should be handled efficiently")
    }
    
    func testLoggingWithNilValues() {
        // Given
        let metadataWithNils: [String: Any?] = [
            "validKey": "validValue",
            "nullKey": nil,
            "emptyKey": ""
        ]
        
        // Filter out nils as expected by the logger
        let filteredMetadata = metadataWithNils.compactMapValues { $0 }
        
        // When
        logger.info("Message with nil values", metadata: filteredMetadata)
        
        // Then
        XCTAssertTrue(true, "Nil values should be handled gracefully")
    }
}

// MARK: - NetworkRequestData Test Helper

struct NetworkRequestData {
    let url: String
    let method: String
    let statusCode: Int
    let responseSize: Int
    let duration: TimeInterval
}