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
        "role": "student",  // Default role
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
  
  // MARK: - Educator Data Seeding
  /// Seeds sample students, interests, and hobbies for a newly authenticated educator if missing.
  func seedInitialEducatorDataIfNeeded() async throws {
    guard let userID = auth.currentUser?.uid else { return }
    let studentsCollection = firestore.collection("users").document(userID).collection("students")
    let studentSnapshot = try await studentsCollection.limit(to: 1).getDocuments()
    
    // Seed only if no students found
    if studentSnapshot.isEmpty {
      // Seed sample students
      let students = Student.sampleStudents
      for student in students {
        let studentID = student.id ?? UUID().uuidString
        var studentWithID = student
        studentWithID.id = studentID
        let doc = studentsCollection.document(studentID)
        try await doc.setData(studentWithID.toFirestoreData())
      }
      
      // Seed interests
      let interestsCollection = firestore.collection("users").document(userID).collection("interests")
      let interests = Interest.sampleInterests
      for interest in interests {
        let doc = interestsCollection.document(interest.id ?? UUID().uuidString)
        try await doc.setData(interest.toFirestoreData())
      }
      
      // Seed hobbies
      let hobbiesCollection = firestore.collection("users").document(userID).collection("hobbies")
      let hobbies = Hobby.sampleHobbies
      for hobby in hobbies {
        let doc = hobbiesCollection.document(hobby.id.uuidString)
        try await doc.setData(hobby.toFirestoreData())
      }
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

// MARK: - Firestore Encoding for Student
extension Student {
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id ?? UUID().uuidString,
            "name": name,
            "grade": grade,
            "dateOfBirth": dateOfBirth.timeIntervalSince1970,
        ]
        if let studentID = studentID { data["studentID"] = studentID }
        if let photoURL = photoURL { data["photoURL"] = photoURL.absoluteString }
        if let tmiPlans = tmiPlans { data["tmiPlans"] = tmiPlans.map { $0.id } }
        if !interests.isEmpty { data["interests"] = interests.map { $0.id ?? "" } }
        if !hobbies.isEmpty { data["hobbies"] = hobbies.map { $0.id.uuidString } }
        if let surveyResults = surveyResults { data["surveyResults"] = surveyResults.map { $0.id } }
        if let academicPerformance = academicPerformance {
            data["academicPerformance"] = [
                "gpa": academicPerformance.gpa as Any,
                "strengths": academicPerformance.strengths,
                "areasForImprovement": academicPerformance.areasForImprovement
            ]
        }
        if let engagementHistory = engagementHistory {
            data["engagementHistory"] = engagementHistory.map { [
                "date": $0.date.timeIntervalSince1970,
                "score": $0.score,
                "source": $0.source.rawValue,
                "notes": $0.notes ?? ""
            ] }
        }
        if let notes = notes {
            data["notes"] = notes.map { [
                "id": $0.id.uuidString,
                "date": $0.date.timeIntervalSince1970,
                "author": $0.author,
                "content": $0.content,
                "category": $0.category.rawValue
            ] }
        }
        if let lastInteractionDate = lastInteractionDate {
            data["lastInteractionDate"] = lastInteractionDate.timeIntervalSince1970
        }
        return data
    }
}
