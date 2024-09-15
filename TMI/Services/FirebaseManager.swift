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
    
//    func signUp(withEmail email: String, password: String, name: String) async throws -> Student {
//        let authResult = try await auth.createUser(withEmail: email, password: password)
//        let student = Student(id: authResult.user.uid, name: name, email: email, grade: "", dateOfBirth: [], tmiPlans: [], studentID: [])
//        return student
//    }
    
    func signOut() async throws -> Bool {
        do {
            try auth.signOut()
            return true
        } catch {
            throw FirebaseManagerError.signOutFailed
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
    }
}
