//
//  FirebaseManager.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import Firebase
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

let FIREBASE_MANAGER = FirebaseManager.shared
let FIRESTORE_DATABASE = FIREBASE_MANAGER.firestore

struct FirebaseManager {
    let auth: Auth
    let storage: Storage
    let firestore: Firestore
    static let shared = FirebaseManager()
    var firestoreListener: ListenerRegistration?
    
    private init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        auth = Auth.auth()
        storage = Storage.storage()
        firestore = Firestore.firestore()
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        Firestore.firestore().settings = settings
    }
}

// MARK: - User Session Service
extension FirebaseManager {
    func signIn(withEmail email: String, password: String) async throws {
        do {
            try await auth.signIn(withEmail: email, password: password)
        } catch {
            throw FirebaseManagerError.signInFailed(error.localizedDescription)
        }
    }
    
    func signUp(withEmail email: String, password: String) async throws -> String {
        do {
            let authResult = try await auth.createUser(withEmail: email, password: password)
            let uid = authResult.user.uid
            
            // Create a user profile document in Firestore
            let userData: [String: Any] = [
                "uid": uid,
                "email": email,
                "createdAt": FieldValue.serverTimestamp(),
                "role": "student" // Default role
            ]
            
            try await firestore.collection("users").document(uid).setData(userData)
            return uid
        } catch {
            throw FirebaseManagerError.accountCreationFailed(error.localizedDescription)
        }
    }
    
    func signOut() async throws -> Bool {
        do {
            try auth.signOut()
            return true
        } catch {
            throw FirebaseManagerError.signOutFailed
        }
    }
    
    func getCurrentUserProfile() async throws -> [String: Any]? {
        guard let currentUser = auth.currentUser else {
            throw FirebaseManagerError.userNotLoggedIn
        }
        
        let documentSnapshot = try await firestore.collection("users").document(currentUser.uid).getDocument()
        
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
    }
}
