//
//  TMIError.swift
//  TMI
//
//  Created by Chandan Brown on 8/20/25.
//

import Foundation

// MARK: - Modern Error Types for iOS 26

/// Comprehensive error type for TMI application with iOS 26 best practices
struct TMIError: Error, LocalizedError, Sendable, Equatable {
    let code: ErrorCode
    let message: String
    let underlyingError: (any Error)?
    let context: [String: String]
    let timestamp: Date
    
    init(
        code: ErrorCode,
        message: String,
        underlyingError: (any Error)? = nil,
        context: [String: String] = [:]
    ) {
        self.code = code
        self.message = message
        self.underlyingError = underlyingError
        self.context = context
        self.timestamp = Date()
    }
    
    // MARK: - LocalizedError Conformance
    
    var errorDescription: String? {
        message
    }
    
    var recoverySuggestion: String? {
        code.recoverySuggestion
    }
    
    var failureReason: String? {
        code.failureReason
    }
    
    var helpAnchor: String? {
        code.helpAnchor
    }
    
    // MARK: - Equatable Conformance
    
    static func == (lhs: TMIError, rhs: TMIError) -> Bool {
        lhs.code == rhs.code && 
        lhs.message == rhs.message &&
        lhs.timestamp == rhs.timestamp
    }
}

// MARK: - Error Codes

extension TMIError {
    enum ErrorCode: String, CaseIterable, Sendable {
        // Authentication Errors
        case authenticationRequired = "auth_required"
        case authenticationFailed = "auth_failed"
        case invalidCredentials = "invalid_credentials"
        case sessionExpired = "session_expired"
        
        // Data Errors
        case dataNotFound = "data_not_found"
        case dataCorrupted = "data_corrupted"
        case invalidDataFormat = "invalid_data_format"
        case dataValidationFailed = "data_validation_failed"
        case dataStorageFailed = "data_storage_failed"
        case dataRetrievalFailed = "data_retrieval_failed"
        
        // Network Errors
        case networkUnavailable = "network_unavailable"
        case networkTimeout = "network_timeout"
        case serverError = "server_error"
        case rateLimitExceeded = "rate_limit_exceeded"
        
        // Firebase Errors
        case firebaseConfigurationError = "firebase_config_error"
        case firestoreError = "firestore_error"
        case storageError = "storage_error"
        case functionsError = "functions_error"
        
        // Student Management Errors
        case studentNotFound = "student_not_found"
        case studentCreationFailed = "student_creation_failed"
        case studentUpdateFailed = "student_update_failed"
        case studentDeleteFailed = "student_delete_failed"
        case duplicateStudent = "duplicate_student"
        
        // TMI Plan Errors
        case planNotFound = "plan_not_found"
        case planCreationFailed = "plan_creation_failed"
        case planUpdateFailed = "plan_update_failed"
        case planDeleteFailed = "plan_delete_failed"
        case invalidPlanConfiguration = "invalid_plan_config"
        
        // Permission Errors
        case insufficientPermissions = "insufficient_permissions"
        case accessDenied = "access_denied"
        case resourceUnavailable = "resource_unavailable"
        
        // System Errors
        case unknownError = "unknown_error"
        case internalError = "internal_error"
        case featureUnavailable = "feature_unavailable"
        case maintenanceMode = "maintenance_mode"
        case securityError = "security_error"
        
        var userFriendlyMessage: String {
            switch self {
            case .authenticationRequired:
                return "Please sign in to continue"
            case .authenticationFailed:
                return "Unable to sign in. Please check your credentials"
            case .invalidCredentials:
                return "Invalid email or password"
            case .sessionExpired:
                return "Your session has expired. Please sign in again"
                
            case .dataNotFound:
                return "The requested information could not be found"
            case .dataCorrupted:
                return "The data appears to be corrupted. Please try refreshing"
            case .invalidDataFormat:
                return "Invalid data format received"
            case .dataValidationFailed:
                return "Please check your input and try again"
                
            case .networkUnavailable:
                return "No internet connection available"
            case .networkTimeout:
                return "The request timed out. Please try again"
            case .serverError:
                return "Server error occurred. Please try again later"
            case .rateLimitExceeded:
                return "Too many requests. Please wait a moment"
                
            case .firebaseConfigurationError:
                return "Configuration error. Please contact support"
            case .firestoreError:
                return "Database error occurred. Please try again"
            case .storageError:
                return "File storage error. Please try again"
            case .functionsError:
                return "Service error. Please try again later"
                
            case .studentNotFound:
                return "Student not found"
            case .studentCreationFailed:
                return "Unable to create student. Please try again"
            case .studentUpdateFailed:
                return "Unable to update student information"
            case .studentDeleteFailed:
                return "Unable to delete student"
            case .duplicateStudent:
                return "A student with this information already exists"
                
            case .planNotFound:
                return "TMI plan not found"
            case .planCreationFailed:
                return "Unable to create TMI plan. Please try again"
            case .planUpdateFailed:
                return "Unable to update TMI plan"
            case .planDeleteFailed:
                return "Unable to delete TMI plan"
            case .invalidPlanConfiguration:
                return "Invalid plan configuration. Please review your selections"
                
            case .insufficientPermissions:
                return "You don't have permission to perform this action"
            case .accessDenied:
                return "Access denied"
            case .resourceUnavailable:
                return "Resource is currently unavailable"
                
            case .unknownError:
                return "An unexpected error occurred"
            case .internalError:
                return "Internal error. Please contact support if this persists"
            case .featureUnavailable:
                return "This feature is currently unavailable"
            case .maintenanceMode:
                return "The app is undergoing maintenance. Please try again later"
            case .securityError:
                return "A security error occurred. Please contact support."
            @unknown default:
                return "An unexpected error occurred"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .authenticationRequired, .sessionExpired:
                return "Tap 'Sign In' to authenticate"
            case .authenticationFailed, .invalidCredentials:
                return "Double-check your email and password, or reset your password"
            case .networkUnavailable:
                return "Check your internet connection and try again"
            case .networkTimeout, .serverError:
                return "Wait a moment and try again"
            case .dataNotFound:
                return "Refresh the page or try a different search"
            case .rateLimitExceeded:
                return "Wait a few minutes before trying again"
            case .insufficientPermissions:
                return "Contact your administrator for access"
            case .dataValidationFailed:
                return "Review the highlighted fields and correct any errors"
            case .duplicateStudent:
                return "Check if the student already exists or use different information"
            case .securityError:
                return "Try refreshing the app or contact support for further assistance."
            default:
                return "Try refreshing the app or contact support if the problem persists"
            }
        }
        
        var failureReason: String? {
            switch self {
            case .authenticationRequired:
                return "User session is not active"
            case .networkUnavailable:
                return "Device is not connected to the internet"
            case .dataCorrupted:
                return "Data integrity check failed"
            case .serverError:
                return "Remote server returned an error response"
            case .firebaseConfigurationError:
                return "Firebase SDK configuration is invalid"
            case .insufficientPermissions:
                return "User role does not have required permissions"
            case .securityError:
                return "A security-related failure occurred."
            default:
                return nil
            }
        }
        
        var helpAnchor: String? {
            switch self {
            case .authenticationRequired, .authenticationFailed, .invalidCredentials, .sessionExpired:
                return "authentication-help"
            case .networkUnavailable, .networkTimeout:
                return "network-troubleshooting"
            case .insufficientPermissions, .accessDenied:
                return "permissions-help"
            case .studentCreationFailed, .studentUpdateFailed, .studentDeleteFailed:
                return "student-management-help"
            case .planCreationFailed, .planUpdateFailed, .planDeleteFailed:
                return "tmi-plan-help"
            case .securityError:
                return "security-help"
            default:
                return "general-help"
            }
        }
    }
}

// MARK: - Convenience Initializers

extension TMIError {
    static func authentication(
        _ code: ErrorCode,
        message: String? = nil,
        underlyingError: (any Error)? = nil
    ) -> TMIError {
        TMIError(
            code: code,
            message: message ?? code.userFriendlyMessage,
            underlyingError: underlyingError,
            context: ["category": "authentication"]
        )
    }
    
    static func network(
        _ code: ErrorCode,
        message: String? = nil,
        underlyingError: (any Error)? = nil
    ) -> TMIError {
        TMIError(
            code: code,
            message: message ?? code.userFriendlyMessage,
            underlyingError: underlyingError,
            context: ["category": "network"]
        )
    }
    
    static func data(
        _ code: ErrorCode,
        message: String? = nil,
        underlyingError: (any Error)? = nil,
        context: [String: String] = [:]
    ) -> TMIError {
        var errorContext = context
        errorContext["category"] = "data"
        return TMIError(
            code: code,
            message: message ?? code.userFriendlyMessage,
            underlyingError: underlyingError,
            context: errorContext
        )
    }
    
    static func firebase(
        _ code: ErrorCode,
        message: String? = nil,
        underlyingError: (any Error)? = nil
    ) -> TMIError {
        TMIError(
            code: code,
            message: message ?? code.userFriendlyMessage,
            underlyingError: underlyingError,
            context: ["category": "firebase"]
        )
    }
    
    static func student(
        _ code: ErrorCode,
        studentId: String? = nil,
        message: String? = nil,
        underlyingError: (any Error)? = nil
    ) -> TMIError {
        var context = ["category": "student"]
        if let studentId {
            context["studentId"] = studentId
        }
        return TMIError(
            code: code,
            message: message ?? code.userFriendlyMessage,
            underlyingError: underlyingError,
            context: context
        )
    }
    
    static func plan(
        _ code: ErrorCode,
        planId: String? = nil,
        message: String? = nil,
        underlyingError: (any Error)? = nil
    ) -> TMIError {
        var context = ["category": "plan"]
        if let planId {
            context["planId"] = planId
        }
        return TMIError(
            code: code,
            message: message ?? code.userFriendlyMessage,
            underlyingError: underlyingError,
            context: context
        )
    }
}

// MARK: - Error Extensions for Firebase Integration

extension TMIError {
    /// Convert Firebase errors to TMIError
    static func from(firebaseError: Error) -> TMIError {
        // This would be implemented based on specific Firebase error codes
        // For now, we'll create a generic Firebase error
        return TMIError.firebase(
            .firestoreError,
            message: "Firebase operation failed: \(firebaseError.localizedDescription)",
            underlyingError: firebaseError
        )
    }
}
