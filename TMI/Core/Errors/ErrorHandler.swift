//
//  ErrorHandler.swift
//  TMI
//
//  Created by Claude Code on 8/20/25.
//

import SwiftUI
import Observation
import OSLog

@Observable
@MainActor
final class ErrorHandler {
    static let shared = ErrorHandler()
    
    // Published error state
    private(set) var currentError: TMIError?
    private(set) var isShowingError = false
    private(set) var isRecovering = false
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    
    // Logger for error tracking
    private let logger = Logger(subsystem: "com.tmi.education", category: "ErrorHandler")
    
    // Error context tracking
    private var errorContext: [String: Any] = [:]
    
    private init() {}
    
    // MARK: - Public Methods
    
    func handle(_ error: Error, context: ErrorContext? = nil) {
        let tmiError = mapToTMIError(error, context: context)
        
        // Log the error
        logger.error("Error handled: \(tmiError.code.rawValue) - \(tmiError.message)")
        
        // Store context for recovery
        if let context = context {
            errorContext["operation"] = context.operation
            errorContext["userId"] = context.userId ?? "anonymous"
            errorContext["metadata"] = context.metadata
        }
        
        // Show to user if needed
        if shouldShowToUser(tmiError) {
            currentError = tmiError
            isShowingError = true
        }
        
        // Attempt automatic recovery if possible
        if tmiError.isRecoverable {
            Task {
                await attemptRecovery(for: tmiError, context: context)
            }
        }
    }
    
    func dismiss() {
        currentError = nil
        isShowingError = false
        isRecovering = false
        errorContext.removeAll()
    }
    
    func retry() {
        guard let error = currentError else { return }
        
        Task {
            isRecovering = true
            defer { isRecovering = false }
            
            // Notify listeners to retry
            NotificationCenter.default.post(
                name: .errorRetryRequested,
                object: nil,
                userInfo: ["error": error, "context": errorContext]
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func shouldShowToUser(_ error: TMIError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkTimeout:
            return true
        case .authenticationRequired, .authenticationFailed, .sessionExpired:
            return true
        case .firestoreError, .storageError:
            return true
        case .studentNotFound, .dataNotFound:
            return false // Handle silently
        case .serverError, .internalError:
            return true
        default:
            return true
        }
    }
    
    private func mapToTMIError(_ error: Error, context: ErrorContext?) -> TMIError {
        // If already a TMIError, return as is
        if let tmiError = error as? TMIError {
            return tmiError
        }
        
        // Map common system errors
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSURLErrorDomain:
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet:
                    return TMIError.network(.networkUnavailable, underlyingError: error)
                case NSURLErrorTimedOut:
                    return TMIError.network(.networkTimeout, underlyingError: error)
                case NSURLErrorCannotConnectToHost:
                    return TMIError.network(.serverError, underlyingError: error)
                default:
                    return TMIError.network(.networkUnavailable, underlyingError: error)
                }
            default:
                break
            }
        }
        
        // Check if it's a Firebase error (would need Firebase import to be more specific)
        if error.localizedDescription.contains("Firebase") || 
           error.localizedDescription.contains("firestore") {
            return TMIError.firebase(.firestoreError, underlyingError: error)
        }
        
        // Default to unknown error
        return TMIError(
            code: .unknownError,
            message: error.localizedDescription,
            underlyingError: error,
            context: context?.metadata?.reduce(into: [String: String]()) { result, pair in
                result[pair.key] = String(describing: pair.value)
            } ?? [:]
        )
    }
    
    private func attemptRecovery(for error: TMIError, context: ErrorContext?) async {
        isRecovering = true
        defer { isRecovering = false }
        
        logger.info("Attempting recovery for error: \(error.code.rawValue)")
        
        switch error.code {
        case .networkUnavailable, .networkTimeout:
            await handleNetworkRecovery()
        case .firestoreError, .storageError, .serverError:
            await retryOperation(context: context)
        case .sessionExpired:
            await handleSessionRecovery()
        default:
            logger.debug("No automatic recovery available for error: \(error.code.rawValue)")
        }
    }
    
    private func handleNetworkRecovery() async {
        // Wait for network connection
        for attempt in 1...5 {
            try? await Task.sleep(for: .seconds(Double(attempt)))
            
            // Check if network is back
            var request = URLRequest(url: URL(string: "https://www.google.com")!)
            request.timeoutInterval = 5.0
            
            do {
                _ = try await URLSession.shared.data(for: request)
                
                // Network recovered - notify listeners
                await MainActor.run {
                    NotificationCenter.default.post(name: .networkRecovered, object: nil)
                }
                break
            } catch {
                continue
            }
        }
    }
    
    private func retryOperation(context: ErrorContext?) async {
        guard let context = context else { return }
        
        logger.info("Retrying operation: \(context.operation)")
        
        for attempt in 1...maxRetries {
            try? await Task.sleep(for: .seconds(retryDelay * Double(attempt)))
            
            // Post retry notification with exponential backoff
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .operationRetryRequested,
                    object: nil,
                    userInfo: [
                        "operation": context.operation,
                        "attempt": attempt,
                        "maxRetries": maxRetries,
                        "userId": context.userId ?? "anonymous"
                    ]
                )
            }
        }
    }
    
    private func handleSessionRecovery() async {
        logger.info("Attempting session recovery")
        
        // Notify that session needs to be refreshed
        await MainActor.run {
            NotificationCenter.default.post(
                name: .sessionRecoveryRequested,
                object: nil
            )
        }
    }
}

// MARK: - Error Context
struct ErrorContext: @unchecked Sendable {
    let operation: String
    let userId: String?
    let metadata: [String: Any]?
    
    init(operation: String, userId: String? = nil, metadata: [String: Any]? = nil) {
        self.operation = operation
        self.userId = userId
        self.metadata = metadata
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let errorRetryRequested = Notification.Name("TMIErrorRetryRequested")
    static let networkRecovered = Notification.Name("TMINetworkRecovered")
    static let operationRetryRequested = Notification.Name("TMIOperationRetryRequested")
    static let sessionRecoveryRequested = Notification.Name("TMISessionRecoveryRequested")
}

// MARK: - View Modifier for Error Handling
struct ErrorHandlerModifier: ViewModifier {
    @State private var errorHandler = ErrorHandler.shared
    
    func body(content: Content) -> some View {
        content
            .alert(
                "Error",
                isPresented: .constant(errorHandler.isShowingError),
                presenting: errorHandler.currentError
            ) { error in
                if error.isRecoverable {
                    Button("Retry") {
                        errorHandler.retry()
                    }
                    Button("Cancel", role: .cancel) {
                        errorHandler.dismiss()
                    }
                } else {
                    Button("OK") {
                        errorHandler.dismiss()
                    }
                }
            } message: { error in
                Text(error.message)
            }
            .overlay(alignment: .top) {
                if errorHandler.isRecovering {
                    RecoveryOverlay()
                }
            }
    }
}

struct RecoveryOverlay: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("Attempting to recover...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.tmiSurface, in: Capsule())
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

extension View {
    func withErrorHandling() -> some View {
        modifier(ErrorHandlerModifier())
    }
}

// MARK: - Extension for TMIError Recovery
extension TMIError {
    var isRecoverable: Bool {
        switch code {
        case .networkUnavailable, .networkTimeout, .serverError:
            return true
        case .firestoreError, .storageError, .functionsError:
            return true
        case .dataNotFound, .dataCorrupted:
            return true
        case .sessionExpired:
            return true
        case .rateLimitExceeded:
            return true
        case .authenticationRequired, .authenticationFailed, .invalidCredentials:
            return false
        case .insufficientPermissions, .accessDenied:
            return false
        case .duplicateStudent:
            return false
        case .firebaseConfigurationError, .internalError:
            return false
        default:
            return false
        }
    }
    
    var shouldRetry: Bool {
        switch code {
        case .networkTimeout, .serverError, .rateLimitExceeded:
            return true
        case .firestoreError, .storageError:
            return true
        default:
            return false
        }
    }
}

