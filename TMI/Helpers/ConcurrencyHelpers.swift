//
//  ConcurrencyHelpers.swift
//  TMI
//
//  Created by TMI AI Assistant on 11/20/25.
//

import Foundation

/// Errors that can occur during concurrent operations
enum ConcurrencyError: LocalizedError {
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "The operation timed out."
        }
    }
}

/// Executes an asynchronous operation with a timeout.
/// - Parameters:
///   - seconds: The timeout duration in seconds.
///   - operation: The asynchronous operation to execute.
/// - Returns: The result of the operation.
/// - Throws: `ConcurrencyError.timeout` if the operation exceeds the specified duration, or any error thrown by the operation.
func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @MainActor @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            return try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw ConcurrencyError.timeout
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
