//
//  AuthenticationService.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation
import FirebaseAuth

extension FirebaseManager {
    // Note: Core authentication methods (signIn, signUp, signOut, resetPassword) 
    // are now implemented in the main FirebaseManager class with enhanced error handling
    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthenticationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user is currently signed in."])
        }
        
        // First delete user data from Firestore
        try await firestore.collection("users").document(user.uid).delete()
        
        // Then delete the auth account
        try await user.delete()
    }
    
    func getCurrentUser() -> User? {
        return Auth.auth().currentUser
    }
    
    func verifyEmail() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthenticationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user is currently signed in."])
        }
        try await user.sendEmailVerification()
    }
    
    func updateEmail(to newEmail: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthenticationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user is currently signed in."])
        }

        try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)

        // Update email in Firestore as well
        try await firestore.collection("users").document(user.uid).updateData([
            "email": newEmail
        ])
    }
    
    func reauthenticate(with password: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw NSError(domain: "AuthenticationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user email available."])
        }
        
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await user.reauthenticate(with: credential)
    }
}

