//
//  ErrorHandlerTests.swift
//  TMITests
//
//  Created by Claude Code on 8/20/25.
//

import XCTest
@testable import TMI

@MainActor
final class ErrorHandlerTests: XCTestCase {
    
    private var errorHandler: ErrorHandler!
    
    override func setUp() async throws {
        try await super.setUp()
        errorHandler = ErrorHandler.shared
        // Reset handler state between tests
        errorHandler.dismiss()
    }
    
    override func tearDown() async throws {
        errorHandler.dismiss()
        errorHandler = nil
        try await super.tearDown()
    }
    
    // MARK: - Error Handling Tests
    
    func testHandleBasicError() async throws {
        // Given
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error message"])
        let context = ErrorContext(operation: "testOperation", userId: "testUser", metadata: ["key": "value"])
        
        // When
        errorHandler.handle(testError, context: context)
        
        // Then
        XCTAssertNotNil(errorHandler.currentError, "Current error should be set")
        XCTAssertTrue(errorHandler.isShowingError, "Should be showing error")
        XCTAssertEqual(errorHandler.currentError?.message, "Test error message", "Error message should match")
    }
    
    func testHandleTMIError() async throws {
        // Given
        let tmiError = TMIError.network(.networkUnavailable, underlyingError: nil)
        
        // When
        errorHandler.handle(tmiError)
        
        // Then
        XCTAssertNotNil(errorHandler.currentError, "Current error should be set")
        XCTAssertTrue(errorHandler.isShowingError, "Should be showing error")
        XCTAssertEqual(errorHandler.currentError?.code, .networkUnavailable, "Error code should match")
    }
    
    func testHandleNetworkError() async throws {
        // Given
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        
        // When
        errorHandler.handle(networkError)
        
        // Then
        XCTAssertNotNil(errorHandler.currentError, "Current error should be set")
        XCTAssertEqual(errorHandler.currentError?.code, .networkUnavailable, "Should map to network unavailable")
    }
    
    func testHandleTimeoutError() async throws {
        // Given
        let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        
        // When
        errorHandler.handle(timeoutError)
        
        // Then
        XCTAssertNotNil(errorHandler.currentError, "Current error should be set")
        XCTAssertEqual(errorHandler.currentError?.code, .networkTimeout, "Should map to network timeout")
    }
    
    func testDismissError() async throws {
        // Given
        let testError = NSError(domain: "TestDomain", code: 123)
        errorHandler.handle(testError)
        
        // When
        errorHandler.dismiss()
        
        // Then
        XCTAssertNil(errorHandler.currentError, "Current error should be nil")
        XCTAssertFalse(errorHandler.isShowingError, "Should not be showing error")
        XCTAssertFalse(errorHandler.isRecovering, "Should not be recovering")
    }
    
    // MARK: - Recovery Tests
    
    func testRecoverableError() async throws {
        // Given
        let recoverableError = TMIError.network(.networkTimeout, underlyingError: nil)
        
        // When
        errorHandler.handle(recoverableError)
        
        // Then
        XCTAssertTrue(recoverableError.isRecoverable, "Network timeout should be recoverable")
    }
    
    func testNonRecoverableError() async throws {
        // Given
        let nonRecoverableError = TMIError.authentication(.invalidCredentials, underlyingError: nil)
        
        // When
        errorHandler.handle(nonRecoverableError)
        
        // Then
        XCTAssertFalse(nonRecoverableError.isRecoverable, "Invalid credentials should not be recoverable")
    }
    
    func testRetryFunctionality() async throws {
        // Given
        let retryError = TMIError.network(.networkTimeout, underlyingError: nil)
        errorHandler.handle(retryError)
        
        let expectation = XCTestExpectation(description: "Retry notification should be posted")
        
        let observer = NotificationCenter.default.addObserver(
            forName: .errorRetryRequested,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertNotNil(notification.userInfo?["error"], "Error should be in notification")
            expectation.fulfill()
        }
        
        // When
        errorHandler.retry()
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - Error Context Tests
    
    func testErrorContextCreation() {
        // When
        let context = ErrorContext(
            operation: "testOp", 
            userId: "user123", 
            metadata: ["key": "value"]
        )
        
        // Then
        XCTAssertEqual(context.operation, "testOp")
        XCTAssertEqual(context.userId, "user123")
        XCTAssertEqual(context.metadata?["key"] as? String, "value")
    }
    
    func testErrorContextWithoutOptionalParams() {
        // When
        let context = ErrorContext(operation: "testOp")
        
        // Then
        XCTAssertEqual(context.operation, "testOp")
        XCTAssertNil(context.userId)
        XCTAssertNil(context.metadata)
    }
    
    // MARK: - Error Visibility Tests
    
    func testSilentErrorsNotShown() async throws {
        // Given
        let silentError = TMIError.data(.dataNotFound, underlyingError: nil)
        
        // When
        errorHandler.handle(silentError)
        
        // Then
        XCTAssertFalse(errorHandler.isShowingError, "Data not found errors should be handled silently")
    }
    
    func testUserVisibleErrorsShown() async throws {
        // Given
        let visibleError = TMIError.network(.networkUnavailable, underlyingError: nil)
        
        // When
        errorHandler.handle(visibleError)
        
        // Then
        XCTAssertTrue(errorHandler.isShowingError, "Network errors should be shown to user")
    }
    
    // MARK: - Firebase Error Mapping Tests
    
    func testFirebaseErrorMapping() async throws {
        // Given
        let firebaseError = NSError(
            domain: "FIRFirestoreErrorDomain", 
            code: 14, 
            userInfo: [NSLocalizedDescriptionKey: "Firebase Firestore error"]
        )
        
        // When
        errorHandler.handle(firebaseError)
        
        // Then
        XCTAssertNotNil(errorHandler.currentError)
        XCTAssertEqual(errorHandler.currentError?.code, .firestoreError, "Should map Firebase errors correctly")
    }
    
    // MARK: - Performance Tests
    
    func testErrorHandlingPerformance() async throws {
        measure {
            for _ in 0..<1000 {
                let error = NSError(domain: "TestDomain", code: Int.random(in: 0...999))
                errorHandler.handle(error)
                errorHandler.dismiss()
            }
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentErrorHandling() async throws {
        let expectation = XCTestExpectation(description: "All concurrent errors handled")
        expectation.expectedFulfillmentCount = 10
        
        // When - Handle multiple errors concurrently
        for i in 0..<10 {
            Task { @MainActor in
                let error = NSError(domain: "TestDomain", code: i)
                self.errorHandler.handle(error)
                expectation.fulfill()
            }
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
    }
}

// MARK: - TMIError Recovery Tests Extension

extension ErrorHandlerTests {
    
    func testNetworkErrorRecovery() {
        let networkErrors: [TMIErrorCode] = [.networkUnavailable, .networkTimeout, .serverError]
        
        for errorCode in networkErrors {
            let error = TMIError(code: errorCode, message: "Test error")
            XCTAssertTrue(error.isRecoverable, "\(errorCode) should be recoverable")
            XCTAssertTrue(error.shouldRetry, "\(errorCode) should be retryable")
        }
    }
    
    func testFirebaseErrorRecovery() {
        let firebaseErrors: [TMIErrorCode] = [.firestoreError, .storageError, .functionsError]
        
        for errorCode in firebaseErrors {
            let error = TMIError(code: errorCode, message: "Test error")
            XCTAssertTrue(error.isRecoverable, "\(errorCode) should be recoverable")
        }
    }
    
    func testAuthenticationErrorsNotRecoverable() {
        let authErrors: [TMIErrorCode] = [.authenticationRequired, .authenticationFailed, .invalidCredentials]
        
        for errorCode in authErrors {
            let error = TMIError(code: errorCode, message: "Test error")
            XCTAssertFalse(error.isRecoverable, "\(errorCode) should not be recoverable")
            XCTAssertFalse(error.shouldRetry, "\(errorCode) should not be retryable")
        }
    }
    
    func testPermissionErrorsNotRecoverable() {
        let permissionErrors: [TMIErrorCode] = [.insufficientPermissions, .accessDenied]
        
        for errorCode in permissionErrors {
            let error = TMIError(code: errorCode, message: "Test error")
            XCTAssertFalse(error.isRecoverable, "\(errorCode) should not be recoverable")
        }
    }
}