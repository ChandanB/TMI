//
//  AuthenticationService.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation
import FirebaseAuth

class AuthenticationService {
    static let shared = AuthenticationService()
    private init() {}
    
    func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
//        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
//            if let user = authResult?.user {
//                completion(.success(user))
//            } else if let error = error {
//                completion(.failure(error))
//            }
//        }
    }
    
    func signUp(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
//        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
//            if let user = authResult?.user {
//                completion(.success(user))
//            } else if let error = error {
//                completion(.failure(error))
//            }
//        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
}

