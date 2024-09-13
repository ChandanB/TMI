// AuthViewModel.swift

import SwiftUI
import FirebaseAuth

@Observable
class AuthViewModel: ObservableObject {
    var isLoggedIn: Bool = false
    var user: User?

    init() {
        self.user = Auth.auth().currentUser
        self.isLoggedIn = self.user != nil
        
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isLoggedIn = user != nil
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            if let error = error {
                completion(error)
            } else {
                self?.isLoggedIn = true
                completion(nil)
            }
        }
    }
    
    func register(email: String, password: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] _, error in
            if let error = error {
                completion(error)
            } else {
                self?.isLoggedIn = true
                completion(nil)
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            isLoggedIn = false
            user = nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}
