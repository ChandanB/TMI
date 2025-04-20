
//
//  ErrorHandlingHelper.swift
//  The Social Point
//
//  Created by Chandan Brown on 3/30/25.
//

import Firebase
import Foundation

// MARK: - Error Categories

/// Represents different categories of errors in the application
enum ErrorCategory: String, Equatable {
    case authentication
    case network
    case userProfile
    case dataFetch
    case validation
    case permission
    case unknown
    
    /// User-friendly display name for the error category
    var displayName: String {
        switch self {
        case .authentication: return "Authentication Error"
        case .network: return "Network Error"
        case .userProfile: return "Profile Error"
        case .dataFetch: return "Data Error"
        case .validation: return "Validation Error"
        case .permission: return "Permission Error"
        case .unknown: return "Error"
        }
    }
}

// MARK: - Identifiable Error

/// A standardized error type that can be uniquely identified and displayed to users
struct IdentifiableError: Identifiable, Equatable, Error {
    /// Unique identifier for the error
    let id: String
    
    /// The original error that occurred, if available
    let error: Error?
    
    /// Technical error message
    let message: String
    
    /// Category of the error
    let category: ErrorCategory
    
    /// User-friendly message that can be displayed in the UI
    let userFriendlyMessage: String?
    
    /// Options for recovering from the error
    let recoveryOptions: [String]?
    
    /// When the error occurred
    let timestamp: Date
    
    /// Initializes a new identifiable error
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID)
    ///   - error: The original error
    ///   - message: Technical error message
    ///   - category: Category of the error
    ///   - userFriendlyMessage: User-friendly message
    ///   - recoveryOptions: Options for recovering from the error
    ///   - timestamp: When the error occurred
    init(
        id: String = UUID().uuidString,
        error: Error? = nil,
        message: String,
        category: ErrorCategory = .unknown,
        userFriendlyMessage: String? = nil,
        recoveryOptions: [String]? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.error = error
        self.message = message
        self.category = category
        self.userFriendlyMessage = userFriendlyMessage
        self.recoveryOptions = recoveryOptions
        self.timestamp = timestamp
    }
    
    /// Display message prioritizes user-friendly message over technical message
    var displayMessage: String {
        return userFriendlyMessage ?? message
    }
    
    /// Description of the error
    var errorDescription: String {
        error?.localizedDescription ?? "Identifiable Error"
    }
    
    // MARK: - Equatable
    
    static func == (lhs: IdentifiableError, rhs: IdentifiableError) -> Bool {
        return lhs.id == rhs.id && lhs.message == rhs.message
    }
}

// MARK: - Firebase Error Types

/// Represents Firebase-specific errors
enum FirebaseError: Error {
    case validationFailed(field: String, reason: String)
    case signInFailed(String)
    case signUpFailed(String)
    case signOutFailed(String)
    case dataFetchFailed(String)
    case dataSaveFailed(String)
    case dataDeleteFailed(String)
    case userFetchFailed(String)
    case missingData(String)
    case insufficientPermission(String)
    case imageUploadFailed(String)
    case listenerError(String)
    case accountCreationFailed(String)
    case userProfileUpdateFailed(String)
    case authError(String)
    case invalidFilterValue(String)
    case invalidOperation(String)
    case errorDescription(String)
    case invalidDocumentID
    case userNotAuthenticated
    case documentNotFound
    case decodingError
    case encodingError
    case networkError
    case unknownError
    case userNotLoggedIn
    case documentDoesNotExist
    case documentDecodingFailed
    case invalidFormTemplate
    case unknownField
}

// MARK: - Registration Error Types

/// Error types that can occur during the user registration process
enum RegistrationError: Error, LocalizedError, Equatable {
    /// Username is already taken by another user
    case usernameAlreadyExists
    
    /// Email address is already associated with an account
    case emailAlreadyInUse
    
    /// The provided invite code is invalid or expired
    case invalidInviteCode
    
    /// Username format is invalid
    case invalidUsername
    
    /// Email format is invalid
    case invalidEmail
    
    /// Password doesn't meet strength requirements
    case weakPassword
    
    /// Required registration fields are missing
    case missingRequiredFields
    
    /// Authentication with Firebase failed
    case authFailed(NSError)
    
    /// Error occurred while saving data to the database
    case databaseError(NSError)
    
    /// Account creation failed due to system or validation issues
    case accountCreationFailed(NSError)
    
    /// A user-friendly error message describing the issue
    var errorMessage: String {
        return errorDescription ?? "An unknown error occurred during registration."
    }
    
    /// Localized description of the error (conforms to LocalizedError)
    var errorDescription: String? {
        switch self {
        case .emailAlreadyInUse:
            return "Email address is already in use. Please choose another."
            
        case .usernameAlreadyExists:
            return "Username already exists. Please choose another."
            
        case .invalidUsername:
            return "Username should only contain letters, numbers, and underscores."
            
        case .invalidEmail:
            return "Please enter a valid email address."
            
        case .invalidInviteCode:
            return "Invite code is invalid or expired."
            
        case .weakPassword:
            return "Password should be at least 8 characters with letters and numbers."
            
        case .missingRequiredFields:
            return "Please fill in all required fields."
            
        case .authFailed(let error):
            return "Authentication failed: \(error.localizedDescription)"
            
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
            
        case .accountCreationFailed(let error):
            return "Account creation failed: \(error.localizedDescription)"
        }
    }
    
    /// Additional context about why the error occurred (conforms to LocalizedError)
    var failureReason: String? {
        switch self {
        case .emailAlreadyInUse:
            return "The email is already registered in our system."
            
        case .usernameAlreadyExists:
            return "The username is taken by another user."
            
        case .invalidUsername:
            return "Username validation failed - must be alphanumeric with underscores only."
            
        case .invalidEmail:
            return "Email address format validation failed."
            
        case .invalidInviteCode:
            return "The invite code couldn't be verified or has expired."
            
        case .weakPassword:
            return "The password doesn't meet the minimum security requirements."
            
        case .missingRequiredFields:
            return "One or more required fields were left empty or undefined."
            
        case .authFailed(let error):
            return "Firebase authentication service returned an error: \(error.domain) (\(error.code))"
            
        case .databaseError(let error):
            return "Firestore database operation failed: \(error.domain) (\(error.code))"
            
        case .accountCreationFailed(let error):
            return "Account creation process failed: \(error.domain) (\(error.code))"
        }
    }
    
    // MARK: - Equatable
    
    static func == (lhs: RegistrationError, rhs: RegistrationError) -> Bool {
        switch (lhs, rhs) {
        case (.usernameAlreadyExists, .usernameAlreadyExists),
             (.emailAlreadyInUse, .emailAlreadyInUse),
             (.invalidInviteCode, .invalidInviteCode),
             (.invalidUsername, .invalidUsername),
             (.invalidEmail, .invalidEmail),
             (.weakPassword, .weakPassword),
             (.missingRequiredFields, .missingRequiredFields):
            return true
            
        case (.authFailed(let lhsError), .authFailed(let rhsError)):
            return lhsError.code == rhsError.code && lhsError.domain == rhsError.domain
            
        case (.databaseError(let lhsError), .databaseError(let rhsError)):
            return lhsError.code == rhsError.code && lhsError.domain == rhsError.domain
            
        case (.accountCreationFailed(let lhsError), .accountCreationFailed(let rhsError)):
            return lhsError.code == rhsError.code && lhsError.domain == rhsError.domain
            
        default:
            return false
        }
    }
}

// MARK: - Transaction Error Types

/// Errors that can occur during transactions
public enum TransactionError: Error, LocalizedError {
    /// User doesn't have enough points for the transaction
    case insufficientFunds
    
    /// The transaction is invalid (e.g., negative amount)
    case invalidTransaction
    
    /// The transaction failed for a server reason
    case transactionFailed
    
    /// User is not authenticated
    case userNotAuthenticated
    
    /// The amount is invalid
    case invalidAmount(String)
    
    /// The user is not found
    case userNotFound(String)
    
    /// Localized error description
    public var errorDescription: String? {
        switch self {
        case .insufficientFunds:
            return "Insufficient social points for this transaction."
        case .invalidTransaction:
            return "The transaction is invalid."
        case .transactionFailed:
            return "Transaction failed to process."
        case .userNotAuthenticated:
            return "You must be signed in to make this transaction."
        case .invalidAmount(let message):
            return "Invalid amount: \(message)"
        case .userNotFound(let userID):
            return "User not found: \(userID)"
        }
    }
}

// MARK: - Post Error Types

/// Errors that can occur when working with posts
public enum PostError: Error {
    /// Throw when any attached media is missing media description (alt text)
    case missingAltText
}

extension PostError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .missingAltText:
            return NSLocalizedString("status.error.no-alt-text", comment: "media does not have media description")
        }
    }
}

// MARK: - Image Source Error Types

/// Errors that can occur when working with images
public enum ImageSourceError: Error {
    /// Failed to decode image data
    case decodingFailed
    
    /// Failed to encode image data
    case encodingFailed
    
    /// The URL is invalid
    case invalidURL
    
    /// Failed to convert data
    case dataConversionFailed
    
    /// Failed to compress image
    case compressionFailed
    
    /// Network error occurred
    case networkError(Error)
}

// MARK: - Server Error Types

/// Error returned from the server
public struct ServerError: Decodable, Error, Sendable {
    /// Error message from the server
    public let error: String?
    
    /// HTTP status code
    public var httpCode: Int?
}

// MARK: - Transfer Error Types

/// Errors that can occur during data transfer
enum TransferError: Error {
    /// Failed to import data
    case importFailed
}

// MARK: - Migration Error Types

/// Errors that can occur during data migration
enum MigrationError: Error {
    /// Failed to decode a document
    case decodingError(String)
    
    /// Document not found
    case documentNotFound(String)
    
    /// Required field is missing
    case fieldMissing(String)
    
    /// Batch commit failed
    case batchCommitFailed(Error)
    
    /// Unknown error
    case unknown(Error)
    
    /// Localized description of the error
    var localizedDescription: String {
        switch self {
        case .decodingError(let document):
            return "Failed to decode document: \(document)"
        case .documentNotFound(let id):
            return "Document not found: \(id)"
        case .fieldMissing(let field):
            return "Required field missing: \(field)"
        case .batchCommitFailed(let error):
            return "Batch commit failed: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
