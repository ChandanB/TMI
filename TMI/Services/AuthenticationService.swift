//
//  AuthenticationService.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation
import FirebaseAuth

extension FirebaseManager {
    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }
    
    func signUp(email: String, password: String) async throws {
        try await Auth.auth().createUser(withEmail: email, password: password)
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthenticationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user is currently signed in."])
        }
        try await user.delete()
    }
    
    func getCurrentUser() -> User? {
        return Auth.auth().currentUser
    }
}

