//
//  SimpleAuthStateModel.swift
//  TMI
//
//  Created by Chandan Brown on 8/7/25.
//

import SwiftUI
import Firebase
import Observation

// MARK: - Environment Key
struct SimpleAuthStateModelKey: EnvironmentKey {
    static let defaultValue: SimpleAuthStateModel = SimpleAuthStateModel()
}

extension EnvironmentValues {
    var simpleAuthStateModel: SimpleAuthStateModel {
        get { self[SimpleAuthStateModelKey.self] }
        set { self[SimpleAuthStateModelKey.self] = newValue }
    }
}

@Observable
final class SimpleAuthStateModel: BaseStateModel<TMIAuthState, IdentifiableError> {
    
    // Form inputs and UI state
    var email = ""
    var password = ""
    var confirmPassword = ""
    
    var onAuthStateChanged: (() async -> Void)?
    
    // Dependencies
    private let authService: TMIAuthService
    
    init(authService: TMIAuthService = FirebaseTMIAuthService()) {
        self.authService = authService
        super.init()
        
        setupAuthStateListener()
    }
    
    // MARK: - Auth State Management
    
    private func setupAuthStateListener() {
        // Listen to changes from the auth service
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every second
                let currentAuthState = authService.authState
                
                await MainActor.run {
                    // Only update if the state has actually changed
                    if case .loaded(let currentState) = state, currentState != currentAuthState {
                        updateState(.loaded(currentAuthState))
                    } else if case .idle = state {
                        updateState(.loaded(currentAuthState))
                    }
                }
            }
        }
    }
    
    @MainActor
    override func fetch() async {
        do {
            let restored = try await authService.restoreAuthenticationState()
            if restored {
                updateState(.loaded(authService.authState))
            } else {
                updateState(.loaded(.needsAuthentication))
            }
        } catch {
            updateState(.error(ErrorHandlingHelper.handleAuthError(error)))
        }
        
        await onAuthStateChanged?()
    }
    
    @MainActor
    func handleLogin() async {
        guard !email.isEmpty, !password.isEmpty else {
            updateState(.error(IdentifiableError(message: "Email and password cannot be empty")))
            return
        }
        
        updateState(.loading)
        
        do {
            let _ = try await authService.signIn(withEmail: email, password: password)
            
            // Wait for auth state to be updated by the service
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            updateState(.loaded(authService.authState))
            
            // Clear form
            email = ""
            password = ""
            
            await onAuthStateChanged?()
        } catch {
            updateState(.error(ErrorHandlingHelper.handleAuthError(error)))
        }
    }
    
    @MainActor
    func handleSignUp() async {
        guard !email.isEmpty, !password.isEmpty else {
            updateState(.error(IdentifiableError(message: "Please fill in all required fields")))
            return
        }
        
        guard password == confirmPassword else {
            updateState(.error(IdentifiableError(message: "Passwords do not match")))
            return
        }
        
        // Start loading state
        updateState(.loading)
        
        do {
            let firebaseUser = try await authService.signUp(email: email, password: password)
            
            // Create a basic TMI user profile
            let tmiUser = TMIUser(
                id: firebaseUser.uid,
                email: email,
                displayName: firebaseUser.displayName ?? "User",
                role: .teacher, // Default role for MVP
                profileCreatedDate: Date(),
                lastLoginDate: Date()
            )
            
            // Save to Firestore
            try await saveUserProfile(tmiUser)
            
            // Update auth service
            authService.updateAuthState(.userReady(tmiUser))
            updateState(.loaded(.userReady(tmiUser)))
            
            // Clear form
            email = ""
            password = ""
            confirmPassword = ""
            
            await onAuthStateChanged?()
        } catch {
            // Transform and handle specific errors
            let identifiableError = ErrorHandlingHelper.handleAuthError(error)
            updateState(.error(identifiableError))
        }
    }
    
    @MainActor
    func handleLogout() async {
        do {
            try authService.signOut()
            updateState(.loaded(.needsAuthentication))
            await onAuthStateChanged?()
        } catch {
            updateState(.error(ErrorHandlingHelper.handleRepositoryError(error, userFriendlyMessage: "Failed to sign out")))
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveUserProfile(_ user: TMIUser) async throws {
        let userData: [String: Any] = [
            "id": user.id,
            "email": user.email,
            "displayName": user.displayName ?? "",
            "role": user.role.rawValue,
            "profileCreatedDate": user.profileCreatedDate,
            "lastLoginDate": user.lastLoginDate as Any
        ]
        
        try await FIREBASE_MANAGER.firestore
            .collection("users")
            .document(user.id!)
            .setData(userData)
    }
    
    // MARK: - Computed Properties
    
    var isAuthenticated: Bool {
        if case .loaded(let authState) = state {
            switch authState {
            case .authenticated, .userReady:
                return true
            default:
                return false
            }
        }
        return false
    }
    
    var currentUser: TMIUser? {
        if case .loaded(.userReady(let user)) = state {
            return user
        }
        return authService.currentTMIUser
    }
    
    var needsProfileSetup: Bool {
        if case .loaded(.needsProfileSetup) = state {
            return true
        }
        return false
    }
}