//
//  TMIPlanService.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class TMIPlanService {
  static let shared = TMIPlanService()
  private let firestore = FIRESTORE_DATABASE
  
  private init() {}
  
  // MARK: - Create TMI Plan
  func createTMIPlan(_ plan: TMIPlan) async throws -> String {
    guard let currentUser = Auth.auth().currentUser else {
      throw TMIPlanServiceError.userNotAuthenticated
    }
    
    let planID = plan.id ?? UUID().uuidString
    var planToSave = plan
    planToSave.id = planID
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.tmiPlans.rawValue)
    
    try await collection.document(planID).setData(from: planToSave)
    return planID
  }
  
  // MARK: - Fetch TMI Plan
  func fetchTMIPlan(id: String) async throws -> TMIPlan {
    guard let currentUser = Auth.auth().currentUser else {
      throw TMIPlanServiceError.userNotAuthenticated
    }
    
    let document = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.tmiPlans.rawValue)
      .document(id)
    
    let snapshot = try await document.getDocument()
    
    guard snapshot.exists else {
      throw TMIPlanServiceError.planNotFound
    }
    
    return try snapshot.data(as: TMIPlan.self)
  }
  
  // MARK: - Fetch All TMI Plans
  func fetchAllTMIPlans() async throws -> [TMIPlan] {
    guard let currentUser = Auth.auth().currentUser else {
      throw TMIPlanServiceError.userNotAuthenticated
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.tmiPlans.rawValue)
    
    let snapshot = try await collection
      .order(by: "lastUpdated", descending: true)
      .getDocuments()
    
    return try snapshot.documents.compactMap { document in
      try document.data(as: TMIPlan.self)
    }
  }
  
  // MARK: - Fetch TMI Plans for Student
  func fetchTMIPlans(for studentID: String) async throws -> [TMIPlan] {
    guard let currentUser = Auth.auth().currentUser else {
      throw TMIPlanServiceError.userNotAuthenticated
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.tmiPlans.rawValue)
    
    let snapshot = try await collection
      .whereField("student.id", isEqualTo: studentID)
      .order(by: "lastUpdated", descending: true)
      .getDocuments()
    
    return try snapshot.documents.compactMap { document in
      try document.data(as: TMIPlan.self)
    }
  }
  
  // MARK: - Update TMI Plan
  func updateTMIPlan(_ plan: TMIPlan) async throws {
    guard let currentUser = Auth.auth().currentUser else {
      throw TMIPlanServiceError.userNotAuthenticated
    }
    
    guard let planID = plan.id else {
      throw TMIPlanServiceError.invalidPlanID
    }
    
    var updatedPlan = plan
    updatedPlan.lastUpdated = Date()
    
    let document = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.tmiPlans.rawValue)
      .document(planID)
    
    try await document.setData(from: updatedPlan, merge: true)
  }
  
  // MARK: - Update TMI Plan Progress
  func updateTMIPlanProgress(planID: String, progress: Double, notes: String? = nil) async throws {
    guard let currentUser = Auth.auth().currentUser else {
      throw TMIPlanServiceError.userNotAuthenticated
    }
    
    let document = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.tmiPlans.rawValue)
      .document(planID)
    
    var updateData: [String: Any] = [
      "progress": progress,
      "lastUpdated": FieldValue.serverTimestamp()
    ]
    
    if let notes = notes {
      updateData["notes"] = notes
    }
    
    try await document.updateData(updateData)
  }
  
  // MARK: - Delete TMI Plan
  func deleteTMIPlan(id: String) async throws {
    guard let currentUser = Auth.auth().currentUser else {
      throw TMIPlanServiceError.userNotAuthenticated
    }
    
    let document = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.tmiPlans.rawValue)
      .document(id)
    
    try await document.delete()
  }
  
  // MARK: - Listen to TMI Plans Changes
  func listenToTMIPlans(completion: @escaping (Result<[TMIPlan], Error>) -> Void) -> ListenerRegistration? {
    guard let currentUser = Auth.auth().currentUser else {
      completion(.failure(TMIPlanServiceError.userNotAuthenticated))
      return nil
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.tmiPlans.rawValue)
    
    return collection
      .order(by: "lastUpdated", descending: true)
      .addSnapshotListener { snapshot, error in
        if let error = error {
          completion(.failure(error))
          return
        }
        
        guard let documents = snapshot?.documents else {
          completion(.success([]))
          return
        }
        
        do {
          let plans = try documents.compactMap { document in
            try document.data(as: TMIPlan.self)
          }
          completion(.success(plans))
        } catch {
          completion(.failure(error))
        }
      }
  }
  
  // MARK: - Completion-based methods for backward compatibility
  func createTMIPlan(_ plan: TMIPlan, completion: @escaping (Result<Void, Error>) -> Void) {
    Task {
      do {
        _ = try await createTMIPlan(plan)
        completion(.success(()))
      } catch {
        completion(.failure(error))
      }
    }
  }
  
  func fetchTMIPlan(id: String, completion: @escaping (Result<TMIPlan, Error>) -> Void) {
    Task {
      do {
        let plan = try await fetchTMIPlan(id: id)
        completion(.success(plan))
      } catch {
        completion(.failure(error))
      }
    }
  }
}

// MARK: - Error Handling
extension TMIPlanService {
  enum TMIPlanServiceError: Error, LocalizedError {
    case userNotAuthenticated
    case planNotFound
    case invalidPlanID
    case saveFailed(String)
    case fetchFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    
    var errorDescription: String? {
      switch self {
      case .userNotAuthenticated:
        return "User must be authenticated to access TMI plans"
      case .planNotFound:
        return "TMI plan not found"
      case .invalidPlanID:
        return "Invalid TMI plan ID provided"
      case .saveFailed(let message):
        return "Failed to save TMI plan: \(message)"
      case .fetchFailed(let message):
        return "Failed to fetch TMI plan: \(message)"
      case .updateFailed(let message):
        return "Failed to update TMI plan: \(message)"
      case .deleteFailed(let message):
        return "Failed to delete TMI plan: \(message)"
      }
    }
  }
}
