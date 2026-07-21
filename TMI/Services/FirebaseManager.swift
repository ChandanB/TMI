//
//  FirebaseManager.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@MainActor
struct FirebaseManager {
  let auth: Auth
  let storage: Storage
  let firestore: Firestore
  static let shared = FirebaseManager()

  private init() {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    auth = Auth.auth()
    storage = Storage.storage()
    firestore = Firestore.firestore()
    
    // Check Firebase configuration status
    let configStatus = FirebaseConfigurationHelper.shared.checkFirebaseConfiguration()
    Log.firebase.info(
      "firebase_configuration_checked",
      metadata: ["status": configStatus.telemetryValue]
    )
    
    // Enable offline mode if needed
    if configStatus.canWorkOffline {
      FirebaseConfigurationHelper.shared.enableOfflineMode()
    }
    
    if !configStatus.isWorking {
      Log.firebase.warning(
        "firebase_configuration_incomplete",
        metadata: ["status": configStatus.telemetryValue]
      )
    }
  }
}

extension FirebaseManager {
  /// Performs Firebase configuration checks and configures offline support.
  /// Call this from your app's startup (e.g., AppDelegate, SceneDelegate, or main SwiftUI entry point) after FirebaseManager has been initialized.
  @MainActor
  static func configureIfNeeded() async {
    let configStatus = FirebaseConfigurationHelper.shared.checkFirebaseConfiguration()
    Log.firebase.info(
      "firebase_configuration_checked",
      metadata: ["status": configStatus.telemetryValue]
    )
    
    if configStatus.canWorkOffline {
      FirebaseConfigurationHelper.shared.enableOfflineMode()
    }
    
    if !configStatus.isWorking {
      Log.firebase.warning(
        "firebase_configuration_incomplete",
        metadata: ["status": configStatus.telemetryValue]
      )
    }
  }
}

// MARK: - User Session Service
extension FirebaseManager {
  func signIn(withEmail email: String, password: String) async throws {
    let configStatus = FirebaseConfigurationHelper.shared.checkFirebaseConfiguration()
    
    guard configStatus.isWorking else {
      throw FirebaseManagerError.databaseNotConfigured
    }
    
    do {
      try await auth.signIn(withEmail: email, password: password)
    } catch {
      // Use FirebaseConfigurationHelper to handle errors gracefully
      let errorResponse = FirebaseConfigurationHelper.shared.handleFirebaseError(error)
      
      switch errorResponse {
      case .databaseNotConfigured:
        throw FirebaseManagerError.databaseNotConfigured
      case .appCheckDisabled:
        throw FirebaseManagerError.appCheckNotEnabled
      case .inAppMessagingDisabled:
        // Log but don't throw - in-app messaging is not critical for authentication
        Log.firebase.warning(
          "firebase_in_app_messaging_unavailable",
          metadata: ["operation": "sign_in"]
        )
        throw FirebaseManagerError.signInFailed("Authentication completed with limited messaging features.")
      case .networkError:
        throw FirebaseManagerError.signInFailed("Network connection issue. Please check your internet connection.")
      case .permissionDenied:
        throw FirebaseManagerError.signInFailed("Permission denied. Please check your credentials.")
      case .unknownError:
        throw FirebaseManagerError.signInFailed(error.localizedDescription)
      }
    }
  }
  
  func signUp(
    withEmail email: String,
    password: String,
    requestedRole: String? = nil
  ) async throws -> String {
    do {
      let authResult = try await auth.createUser(withEmail: email, password: password)
      let uid = authResult.user.uid

      // Create a user profile document in Firestore
      var userData: [String: Any] = [
        "uid": uid,
        "email": email,
        "createdAt": FieldValue.serverTimestamp()
      ]
      if let requestedRole {
        userData["requestedRole"] = requestedRole
      }

      try await firestore.collection("users").document(uid).setData(userData)
      return uid
    } catch {
      throw FirebaseManagerError.accountCreationFailed(error.localizedDescription)
    }
  }

  func signOut() throws {
    do {
      try auth.signOut()
    } catch {
      throw FirebaseManagerError.signOutFailed
    }
  }
  
  func resetPassword(email: String) async throws {
    do {
      try await auth.sendPasswordReset(withEmail: email)
    } catch {
      // Use FirebaseConfigurationHelper to handle errors gracefully
      let errorResponse = FirebaseConfigurationHelper.shared.handleFirebaseError(error)
      
      switch errorResponse {
      case .databaseNotConfigured:
        throw FirebaseManagerError.databaseNotConfigured
      case .appCheckDisabled:
        throw FirebaseManagerError.appCheckNotEnabled
      case .inAppMessagingDisabled:
        // Log but continue - in-app messaging is not critical for password reset
        Log.firebase.warning(
          "firebase_in_app_messaging_unavailable",
          metadata: ["operation": "password_reset"]
        )
        return // Password reset succeeded despite messaging limitation
      case .networkError:
        throw FirebaseManagerError.signInFailed("Network connection issue. Please check your internet connection.")
      case .permissionDenied:
        throw FirebaseManagerError.signInFailed("Permission denied. Please verify the email address.")
      case .unknownError:
        throw FirebaseManagerError.signInFailed(error.localizedDescription)
      }
    }
  }

  func getCurrentUserProfile() async throws -> [String: Any]? {
    guard let currentUser = auth.currentUser else {
      throw FirebaseManagerError.userNotLoggedIn
    }

    let documentSnapshot = try await firestore.collection("users").document(currentUser.uid)
      .getDocument()

    if documentSnapshot.exists {
      return documentSnapshot.data()
    } else {
      return nil
    }
  }

  func updateUserProfile(data: [String: Any]) async throws {
    guard let currentUser = auth.currentUser else {
      throw FirebaseManagerError.userNotLoggedIn
    }

    try await firestore.collection("users").document(currentUser.uid).updateData(data)
  }
  
  // MARK: - User Account Management

  /// Reauthenticate user with current password
  func reauthenticate(with password: String) async throws {
    guard let user = auth.currentUser, let email = user.email else {
      throw FirebaseManagerError.userNotLoggedIn
    }

    let credential = EmailAuthProvider.credential(withEmail: email, password: password)
    try await user.reauthenticate(with: credential)
  }

  /// Send email verification to current user
  func verifyEmail() async throws {
    guard let user = auth.currentUser else {
      throw FirebaseManagerError.userNotLoggedIn
    }

    try await user.sendEmailVerification()
  }

  /// Update user's email address
  func updateEmail(to newEmail: String) async throws {
    guard let user = auth.currentUser else {
      throw FirebaseManagerError.userNotLoggedIn
    }

    do {
      // Send verification email before updating
      try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)

      // Update email in Firestore user profile
      if let uid = auth.currentUser?.uid {
        try await firestore.collection("users").document(uid).updateData([
          "email": newEmail,
          "updatedAt": FieldValue.serverTimestamp()
        ])
      }
    } catch {
      throw FirebaseManagerError.userProfileUpdateFailed("Failed to update email: \(error.localizedDescription)")
    }
  }
}

// MARK: - Error Handling
extension FirebaseManager {
  enum FirebaseManagerError: Error {
    case signInFailed(String)
    case signOutFailed
    case accountCreationFailed(String)
    case userProfileUpdateFailed(String)
    case imageUploadFailed(String)
    case dataFetchFailed(String)
    case listenerError(String)
    case userNotLoggedIn
    case documentDoesNotExist
    case unknownError
    case databaseNotConfigured
    case appCheckNotEnabled
    
    var localizedDescription: String {
      switch self {
      case .signInFailed(let message):
        return "Sign in failed: \(message)"
      case .signOutFailed:
        return "Sign out failed"
      case .accountCreationFailed(let message):
        return "Account creation failed: \(message)"
      case .userProfileUpdateFailed(let message):
        return "Profile update failed: \(message)"
      case .imageUploadFailed(let message):
        return "Image upload failed: \(message)"
      case .dataFetchFailed(let message):
        return "Data fetch failed: \(message)"
      case .listenerError(let message):
        return "Listener error: \(message)"
      case .userNotLoggedIn:
        return "User not logged in"
      case .documentDoesNotExist:
        return "Document does not exist"
      case .unknownError:
        return "Unknown error occurred"
      case .databaseNotConfigured:
        return "Firebase database needs to be configured. The app will work in offline mode until the database is set up."
      case .appCheckNotEnabled:
        return "Firebase App Check needs to be enabled. The app will continue with reduced functionality."
      }
    }
  }
}
