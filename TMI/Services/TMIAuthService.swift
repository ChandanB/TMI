//
//  TMIAuthService.swift
//  TMI
//
//  Created by Chandan Brown on 8/7/25.
//

@preconcurrency import Firebase
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseAuth
import Observation
import Combine

/// Represents the different states of the app during startup and authentication flow
enum TMIAuthState: Equatable {
    /// App is initializing resources and dependencies
    case initializing
    
    /// User needs to authenticate
    case needsAuthentication
    
    /// User is authenticated but needs to create a profile
    case needsProfileSetup(User)
    
    /// User is authenticated with Firebase but TMIUser not yet loaded
    case authenticated(User)
    
    /// User is fully authenticated with TMIUser loaded
    case userReady(TMIUser)
    
    /// An error occurred during state transitions
    case error(IdentifiableError)
}

// MARK: - TMI Authentication Service Protocol
/// Protocol defining core authentication functionality for the TMI application.
protocol TMIAuthService {
    /// The current user's ID, if logged in
    var currentUserID: String? { get }
    
    /// The current Firebase User object, if logged in
    var currentUser: User? { get }

    /// The current TMIUser, if logged in
    var currentTMIUser: TMIUser? { get }
    
    /// The current authentication state
    var authState: TMIAuthState { get }
        
    /// Sets up a listener for authentication state changes
    /// - Parameter completion: Callback that receives the updated User object (or nil when signed out)
    /// - Returns: A handle that can be used to remove the listener
    func listenToAuthStateChanges(completion: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle
    
    /// Signs in with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: Firebase User object on success
    func signIn(withEmail email: String, password: String) async throws -> User
    
    /// Creates a new user account with email and password
    /// - Parameters:
    ///   - email: New user's email address
    ///   - password: New user's password
    /// - Returns: Firebase User object uid on success
    func signUp(email: String, password: String) async throws -> User
    
    /// Signs out the current user
    func signOut() throws
    
    /// Sends a password reset email
    /// - Parameter email: The email address to send reset instructions to
    func sendPasswordReset(email: String) async throws
    
    /// Re-authenticates the current user with credentials
    /// - Parameter credential: Authentication credentials (e.g., EmailAuthProvider)
    func reauthenticate(credential: AuthCredential) async throws
    
    /// Updates the user's email address
    /// - Parameter newEmail: The new email address
    func updateEmail(newEmail: String) async throws
    
    /// Updates the user's password
    /// - Parameter newPassword: The new password
    func updatePassword(newPassword: String) async throws
    
    /// Fetches the currently authenticated user
    /// - Returns: The current user's TMIUser
    /// - Throws: Authentication or fetch errors
    func fetchCurrentTMIUser() async throws -> TMIUser
    
    /// Sends an email verification to the current user
    func sendEmailVerification() async throws
    
    /// Checks if the provided email is available for registration
    /// - Parameter email: Email to check
    /// - Returns: Boolean indicating if email is available
    func isEmailAvailable(_ email: String) async throws -> Bool
    
    /// Sets up the auth state listener to track authentication changes
    func setupAuthStateListener()
    
    /// Removes the auth state listener
    func removeAuthStateListener()
    
    /// Updates the auth state directly
    /// - Parameter newState: The new auth state to set
    func updateAuthState(_ newState: TMIAuthState)
    
    /// Verifies if the current authentication token is valid
    /// - Returns: Boolean indicating if the token is valid
    func verifyAuthToken() async throws -> Bool
    
    /// Attempts to restore the authentication state from persistent storage
    /// - Returns: Boolean indicating if restoration was successful
    func restoreAuthenticationState() async throws -> Bool
}

// MARK: - Firebase TMI Auth Service Implementation
/// Implementation of TMIAuthService using Firebase Authentication
@Observable
@MainActor
class FirebaseTMIAuthService: TMIAuthService {
    private let auth = Auth.auth()
    private let firebaseManager: FirebaseManager
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    private var _isHandlingAuthChange = false
    
    private var isHandlingAuthChange: Bool {
        get { _isHandlingAuthChange }
        set { _isHandlingAuthChange = newValue }
    }
    
    private let userSubject = CurrentValueSubject<TMIUser?, Never>(nil)
    
    var userPublisher: AnyPublisher<TMIUser?, Never> {
        userSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Properties
    
    var currentUserID: String? { auth.currentUser?.uid }
    var currentUser: User? { auth.currentUser }
    var currentTMIUser: TMIUser? {
        get { _currentTMIUser }
        set {
            _currentTMIUser = newValue
            userSubject.send(newValue)
        }
    }
    private var _currentTMIUser: TMIUser?
    
    // Auth state property
    private var _authState: TMIAuthState = .initializing
    
    var authState: TMIAuthState {
        get { _authState }
        set { _authState = newValue }
    }
    
    // Statistics for debugging (thread-safe)
    private var _authStateChanges = 0
    private var _lastAuthChange: Date?
    
    private var authStateChanges: Int {
        get { _authStateChanges }
        set { _authStateChanges = newValue }
    }
    
    private var lastAuthChange: Date? {
        get { _lastAuthChange }
        set { _lastAuthChange = newValue }
    }
    
    // MARK: - Initialization
    
    init(firebaseManager: FirebaseManager = FirebaseManager.shared) {
        self.firebaseManager = firebaseManager
        setupAuthStateListener()
    }
    
    isolated deinit {
        removeAuthStateListener()
    }
    
    // MARK: - Auth State Management
    
    func setupAuthStateListener() {
        // Prevent duplicate listeners
        removeAuthStateListener()
        
        Log.auth.debug("auth_listener_setup")
        authStateHandler = auth.addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }

            // Track statistics
            self.authStateChanges += 1
            self.lastAuthChange = Date()
            
            // Prevent concurrent auth state handling
            guard !self.isHandlingAuthChange else { return }
            self.isHandlingAuthChange = true
            
            if let user = user {
                Log.auth.info(
                    "auth_state_signed_in",
                    metadata: ["userID": user.uid]
                )
                self.updateAuthState(.authenticated(user))
                
                let userID = user.uid
                Log.auth.debug(
                    "profile_load_started",
                    metadata: ["userID": userID]
                )
                
                // Check if we already have a TMI user
                if let tmiUser = self.currentTMIUser {
                    self.currentTMIUser = tmiUser
                    self.updateAuthState(.userReady(tmiUser))
                    self.isHandlingAuthChange = false
                } else {
                    // Load TMI user asynchronously
                    Task { @MainActor [weak self, user] in
                        guard let self = self else { return }
                        
                        do {
                            let tmiUser = try await self.fetchCurrentTMIUser()
                            self.currentTMIUser = tmiUser
                            self.updateAuthState(.userReady(tmiUser))
                        } catch {
                            Log.auth.warning("profile_load_failed")
                            // User authenticated but profile load failed - they can still use basic features
                            self.updateAuthState(.needsProfileSetup(user))
                        }
                        
                        self.isHandlingAuthChange = false
                    }
                }

            } else {
                Log.auth.info("auth_state_signed_out")
                self.currentTMIUser = nil
                self.updateAuthState(.needsAuthentication)
                self.isHandlingAuthChange = false
            }
        }
    }
    
    func removeAuthStateListener() {
        if let authStateHandler = authStateHandler {
            Log.auth.debug("auth_listener_removed")
            auth.removeStateDidChangeListener(authStateHandler)
            self.authStateHandler = nil
        }
    }
    
    func updateAuthState(_ newState: TMIAuthState) {
        // Use the thread-safe property accessor
        self.authState = newState
        
        if case .userReady(let tmiUser) = newState {
            self.currentTMIUser = tmiUser
        } else if case .needsAuthentication = newState {
            self.currentTMIUser = nil
        }
        
        // Log state changes for debugging
        let stateDescription: String
        switch newState {
        case .initializing:
            stateDescription = "Initializing"
        case .needsAuthentication:
            stateDescription = "Needs Authentication"
        case .authenticated:
            stateDescription = "authenticated"
        case .needsProfileSetup:
            stateDescription = "needs_profile_setup"
        case .userReady:
            stateDescription = "user_ready"
        case .error:
            stateDescription = "error"
        }

        Log.auth.debug(
            "auth_state_updated",
            metadata: ["state": stateDescription]
        )
    }
    
    func restoreAuthenticationState() async throws -> Bool {
        Log.auth.debug("auth_restore_started")
        
        // First check if we already have a valid user
        if let currentUser = auth.currentUser {
            do {
                // Force token refresh to verify it's still valid with Firebase
                let _ = try await currentUser.getIDTokenResult(forcingRefresh: true)
                
                // If token refresh succeeded, try to fetch the TMI user
                if let _ = currentTMIUser {
                    Log.auth.info("auth_restore_existing_session_succeeded")
                    return true
                } else {
                    do {
                        let tmiUser = try await fetchCurrentTMIUser()
                        self.currentTMIUser = tmiUser
                        updateAuthState(.userReady(tmiUser))
                        Log.auth.info("auth_restore_profile_succeeded")
                        return true
                    } catch {
                        Log.auth.warning("auth_restore_profile_failed")
                        updateAuthState(.authenticated(currentUser))
                        return true
                    }
                }
            } catch {
                Log.auth.warning("auth_restore_token_refresh_failed")
                // Sign out the user since their token is invalid
                try? auth.signOut()
                updateAuthState(.needsAuthentication)
                return false
            }
        }
        
        // Try to restore from persistent storage if available
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        if let restoredUser = auth.currentUser {
            Log.auth.info("auth_restore_persistent_session_succeeded")
            updateAuthState(.authenticated(restoredUser))
            
            // Try to fetch the TMI user
            do {
                let tmiUser = try await fetchCurrentTMIUser()
                self.currentTMIUser = tmiUser
                updateAuthState(.userReady(tmiUser))
                return true
            } catch {
                Log.auth.warning("auth_restore_persistent_profile_failed")
                return true
            }
        }
        
        Log.auth.info("auth_restore_no_session")
        updateAuthState(.needsAuthentication)
        return false
    }

    // MARK: - Core Authentication Methods

    func listenToAuthStateChanges(completion: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle {
        return auth.addStateDidChangeListener { _, user in
            completion(user)
        }
    }

    func signIn(withEmail email: String, password: String) async throws -> User {
        do {
            try await firebaseManager.signIn(withEmail: email, password: password)
            guard let user = auth.currentUser else {
                throw FirebaseError.signInFailed("Failed to get authenticated user")
            }
            Log.auth.info(
                "sign_in_succeeded",
                metadata: ["userID": user.uid]
            )
            updateAuthState(.authenticated(user))
            return user
        } catch {
            Log.auth.warning("sign_in_failed")
            throw error
        }
    }

    func signUp(email: String, password: String) async throws -> User {
        guard !email.isEmpty, !password.isEmpty else {
            throw RegistrationError.missingRequiredFields
        }
        
        do {
            _ = try await firebaseManager.signUp(withEmail: email, password: password)
            guard let user = auth.currentUser else {
                throw FirebaseError.signUpFailed("Failed to get authenticated user after registration")
            }
            Log.auth.info(
                "sign_up_succeeded",
                metadata: ["userID": user.uid]
            )
            
            // Make email verification optional to avoid failing the whole registration
            do {
                try await user.sendEmailVerification()
                Log.auth.info("verification_email_sent")
            } catch {
                Log.auth.warning("verification_email_failed")
            }
            
            updateAuthState(.authenticated(user))
            return user
        } catch {
            throw error
        }
    }
    
    func signOut() throws {
        do {
            try firebaseManager.signOut()
            updateAuthState(.needsAuthentication)
        } catch {
            throw FirebaseError.signOutFailed(error.localizedDescription)
        }
    }
    
    func sendPasswordReset(email: String) async throws {
        do {
            try await firebaseManager.resetPassword(email: email)
            Log.auth.info("password_reset_requested")
        } catch {
            throw error
        }
    }
    
    func reauthenticate(credential: AuthCredential) async throws {
        guard let user = currentUser else {
            throw FirebaseError.userNotAuthenticated
        }
        
        do {
            try await user.reauthenticate(with: credential)
            Log.auth.info(
                "reauthentication_succeeded",
                metadata: ["userID": user.uid]
            )
        } catch {
            throw FirebaseError.authError("Failed to reauthenticate: \(error.localizedDescription)")
        }
    }
    
    func updateEmail(newEmail: String) async throws {
        guard let user = currentUser else {
            throw FirebaseError.userNotAuthenticated
        }
        
        do {
            try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
            Log.auth.info("email_update_verification_sent")
        } catch {
            throw FirebaseError.userProfileUpdateFailed("Failed to update email: \(error.localizedDescription)")
        }
    }
    
    func updatePassword(newPassword: String) async throws {
        guard let user = currentUser else {
            throw FirebaseError.userNotAuthenticated
        }
        
        do {
            try await user.updatePassword(to: newPassword)
            Log.auth.info(
                "password_update_succeeded",
                metadata: ["userID": user.uid]
            )
        } catch {
            throw FirebaseError.userProfileUpdateFailed("Failed to update password: \(error.localizedDescription)")
        }
    }
    
    func sendEmailVerification() async throws {
        guard let user = currentUser else {
            throw FirebaseError.userNotAuthenticated
        }
        
        do {
            try await user.sendEmailVerification()
            Log.auth.info(
                "verification_email_sent",
                metadata: ["userID": user.uid]
            )
        } catch {
            throw FirebaseError.authError("Failed to send verification email: \(error.localizedDescription)")
        }
    }
    
    func isEmailAvailable(_ email: String) async throws -> Bool {
        do {
            let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
            guard emailPred.evaluate(with: email) else {
                throw FirebaseError.validationFailed(field: "email", reason: "Invalid email format")
            }
            
            // Return true by default, and handle the collision during account creation
            return true
        } catch {
            throw FirebaseError.authError("Failed to check email availability: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get diagnostic information about the auth state
    var diagnosticInfo: String {
        return """
        Auth changes: \(authStateChanges)
        Last auth change: \(lastAuthChange?.formatted() ?? "none")
        Current user ID: \(currentUserID ?? "none")
        Current state: \(authStateDescription)
        """
    }
    
    /// Get a description of the current auth state
    var authStateDescription: String {
        switch authState {
        case .initializing:
            return "Initializing"
        case .needsAuthentication:
            return "Needs Authentication"
        case .authenticated(let user):
            return "Authenticated (\(user.uid))"
        case .needsProfileSetup(let user):
            return "Needs Profile Setup (\(user.uid))"
        case .userReady(let tmiUser):
            return "User Ready (\(tmiUser.email))"
        case .error(let error):
            return "Error: \(error.message)"
        }
    }
    
    // MARK: - Core User Operations
    
    /// Fetches the currently authenticated user
    /// - Returns: The current user's TMIUser
    /// - Throws: Authentication or fetch errors
    func fetchCurrentTMIUser() async throws -> TMIUser {
        guard let userID = currentUser?.uid else { throw FirebaseError.userNotAuthenticated }
        
        do {
            if let tmiUser = self.currentTMIUser {
                return tmiUser
            } else {
                let tmiUser = try await withTimeout(seconds: 10) { @MainActor @Sendable in
                    let userDoc = try await self.firebaseManager.firestore
                        .collection("users")
                        .document(userID)
                        .getDocument()

                    guard let userData = userDoc.data() else {
                        throw FirebaseError.documentNotFound
                    }

                    var tmiUser = try Firestore.Decoder().decode(TMIUser.self, from: userData)
                    tmiUser.id = userDoc.documentID
                    return tmiUser
                }
                self.currentTMIUser = tmiUser
                
                return tmiUser
            }
        } catch {
            throw FirebaseError.userFetchFailed("Failed to fetch current TMI user: \(error.localizedDescription)")
        }
    }
    
    func verifyAuthToken() async throws -> Bool {
        guard let currentUser = auth.currentUser else {
            return false
        }
        
        do {
            // Force token refresh to verify it's still valid with Firebase
            let _ = try await currentUser.getIDTokenResult(forcingRefresh: true)
            
            // If we successfully got a token, the auth is valid
            Log.auth.debug(
                "auth_token_verified",
                metadata: ["userID": currentUser.uid]
            )
            return true
        } catch let error as NSError {
            // Check for specific Firebase auth errors that indicate invalid token
            switch error.code {
            case AuthErrorCode.userTokenExpired.rawValue,
                 AuthErrorCode.invalidUserToken.rawValue,
                 AuthErrorCode.userDisabled.rawValue,
                 AuthErrorCode.userNotFound.rawValue:
                Log.auth.warning("auth_token_invalid")
                return false
            default:
                // For network errors or other temporary issues, we'll throw to let caller decide
                if error.domain == NSURLErrorDomain {
                    Log.auth.warning("auth_token_verification_network_unavailable")
                    // Return true for network errors to avoid unnecessary logouts
                    return true
                }
                
                // For other unknown errors, throw to let caller handle
                throw FirebaseError.authError("Failed to verify auth token: \(error.localizedDescription)")
            }
        }
    }
}
