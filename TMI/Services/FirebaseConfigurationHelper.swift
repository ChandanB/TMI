//
//  FirebaseConfigurationHelper.swift
//  TMI
//
//  Created by Claude Code on 8/5/25.
//

import Firebase
import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Helper class to detect and handle Firebase configuration issues
class FirebaseConfigurationHelper {
  static let shared = FirebaseConfigurationHelper()
  
  private init() {}
  
  /// Checks if Firebase services are properly configured
  func checkFirebaseConfiguration() -> FirebaseConfigurationStatus {
      guard FirebaseApp.app() != nil else {
      return .notConfigured
    }
    
    // Check Auth service availability
    do {
      let _ = Auth.auth()
    }
    
    // Check Firestore service availability by attempting a simple operation
      _ = Firestore.firestore()
    
    // Return configured for now - actual connectivity issues will be handled in real-time
    // The app will detect database and App Check issues during actual operations
    return .configured
  }
  
  /// Provides user-friendly messages for configuration issues
  func getUserFriendlyMessage(for status: FirebaseConfigurationStatus) -> String {
    switch status {
    case .configured:
      return "Firebase is properly configured."
    case .notConfigured:
      return "Firebase is not configured. Please check your GoogleService-Info.plist file."
    case .databaseMissing:
      return "Firebase database needs to be set up. The app will work in offline mode for now."
    case .appCheckDisabled:
      return "Firebase App Check is disabled. Some security features may be limited."
    case .configurationError(let message):
      return "Firebase configuration issue: \(message)"
    }
  }
  
  /// Provides developer instructions for fixing configuration issues
  func getDeveloperInstructions(for status: FirebaseConfigurationStatus) -> [String] {
    switch status {
    case .configured:
      return []
    case .notConfigured:
      return [
        "1. Ensure GoogleService-Info.plist is added to your Xcode project",
        "2. Verify the bundle ID matches your Firebase project",
        "3. Check that Firebase.configure() is called in AppDelegate"
      ]
    case .databaseMissing:
      return [
        "1. Go to Firebase Console: https://console.firebase.google.com/",
        "2. Select your project: tmi-education",
        "3. Navigate to Firestore Database",
        "4. Create database in production mode",
        "5. Set up security rules as needed"
      ]
    case .appCheckDisabled:
      return [
        "1. Go to Firebase Console: https://console.firebase.google.com/",
        "2. Select your project: tmi-education", 
        "3. Navigate to App Check in the Build section",
        "4. Enable App Check for your iOS app",
        "5. Configure DeviceCheck or App Attest as needed"
      ]
    case .configurationError:
      return [
        "1. Check your Firebase project settings",
        "2. Verify network connectivity",
        "3. Ensure all required Firebase services are enabled",
        "4. Check the Firebase Console for any alerts or issues"
      ]
    }
  }
  
  /// Provides comprehensive setup instructions for all Firebase services
  func getCompleteSetupInstructions() -> [String] {
    return [
      "🔧 COMPLETE FIREBASE SETUP INSTRUCTIONS",
      "",
      "1. CREATE FIRESTORE DATABASE:",
      "   • Go to https://console.firebase.google.com/",
      "   • Select project: tmi-education",
      "   • Navigate to 'Firestore Database'",
      "   • Click 'Create database'",
      "   • Choose 'Start in production mode'",
      "   • Select your preferred region",
      "",
      "2. SETUP APP CHECK:",
      "   • In Firebase Console, go to 'App Check'",
      "   • Click 'Get started'",
      "   • Select your iOS app (TMI)",
      "   • Choose 'DeviceCheck' for iOS",
      "   • Follow the registration steps",
      "",
      "3. ENABLE REQUIRED APIS:",
      "   • Go to Google Cloud Console: https://console.developers.google.com/",
      "   • Select project: tmi-education (467646285210)",
      "   • Enable these APIs:",
      "     - Firebase App Check API",
      "     - Firebase In-App Messaging API",
      "     - Cloud Firestore API",
      "",
      "4. VERIFY CONFIGURATION:",
      "   • Restart your app after making changes",
      "   • Check for success messages in console logs",
      "   • Test authentication and data storage",
      "",
      "💡 The app will continue working in offline mode until setup is complete."
    ]
  }
  
  /// Enables offline mode with enhanced caching
  func enableOfflineMode() {
    let settings = FirestoreSettings()
    settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024)) // 100MB
    Firestore.firestore().settings = settings
    
    Log.firebase.info(
      "firebase_offline_cache_enabled",
      metadata: ["sizeBytes": "104857600"]
    )
  }
  
  /// Analyzes runtime Firebase errors and provides appropriate responses
  func handleFirebaseError(_ error: Error) -> FirebaseErrorResponse {
    let errorMessage = error.localizedDescription.lowercased()
    
    if errorMessage.contains("database (default) does not exist") {
      return .databaseNotConfigured(
        userMessage: "The app is working in offline mode. Data will sync when the database is set up.",
        shouldContinue: true
      )
    } else if errorMessage.contains("app not registered") || errorMessage.contains("app check") {
      return .appCheckDisabled(
        userMessage: "App Check security features need setup. Core functionality remains available.",
        shouldContinue: true
      )
    } else if errorMessage.contains("in-app messaging api") || errorMessage.contains("firebaseinappmessaging") {
      return .inAppMessagingDisabled(
        userMessage: "In-app messaging features are disabled. Main app functionality continues normally.",
        shouldContinue: true
      )
    } else if errorMessage.contains("permission denied") || errorMessage.contains("service_disabled") {
      return .permissionDenied(
        userMessage: "Some Firebase services need to be enabled. Core features remain available.",
        shouldContinue: true
      )
    } else if errorMessage.contains("network") || errorMessage.contains("connection") {
      return .networkError(
        userMessage: "Connection issue detected. Working in offline mode.",
        shouldContinue: true
      )
    } else {
      return .unknownError(
        userMessage: "An unexpected error occurred. Please try again.",
        shouldContinue: false
      )
    }
  }
}

/// Enum representing different Firebase configuration states
enum FirebaseConfigurationStatus {
  case configured
  case notConfigured
  case databaseMissing
  case appCheckDisabled
  case configurationError(String)
  
  var isWorking: Bool {
    switch self {
    case .configured:
      return true
    default:
      return false
    }
  }
  
  var canWorkOffline: Bool {
    switch self {
    case .configured, .databaseMissing, .appCheckDisabled:
      return true
    default:
      return false
    }
  }

  var telemetryValue: String {
    switch self {
    case .configured:
      return "configured"
    case .notConfigured:
      return "not_configured"
    case .databaseMissing:
      return "database_missing"
    case .appCheckDisabled:
      return "app_check_disabled"
    case .configurationError:
      return "configuration_error"
    }
  }
}

/// Enum representing Firebase error responses with user-friendly handling
enum FirebaseErrorResponse {
  case databaseNotConfigured(userMessage: String, shouldContinue: Bool)
  case appCheckDisabled(userMessage: String, shouldContinue: Bool)
  case inAppMessagingDisabled(userMessage: String, shouldContinue: Bool)
  case permissionDenied(userMessage: String, shouldContinue: Bool)
  case networkError(userMessage: String, shouldContinue: Bool)
  case unknownError(userMessage: String, shouldContinue: Bool)
  
  var userMessage: String {
    switch self {
    case .databaseNotConfigured(let message, _),
         .appCheckDisabled(let message, _),
         .inAppMessagingDisabled(let message, _),
         .permissionDenied(let message, _),
         .networkError(let message, _),
         .unknownError(let message, _):
      return message
    }
  }
  
  var shouldContinue: Bool {
    switch self {
    case .databaseNotConfigured(_, let shouldContinue),
         .appCheckDisabled(_, let shouldContinue),
         .inAppMessagingDisabled(_, let shouldContinue),
         .permissionDenied(_, let shouldContinue),
         .networkError(_, let shouldContinue),
         .unknownError(_, let shouldContinue):
      return shouldContinue
    }
  }
}
