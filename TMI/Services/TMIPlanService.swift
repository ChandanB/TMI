//
//  TMIPlanService.swift
//  TMI
//
//  Created by Chandan Brown on 8/7/25.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation

/// Service for managing TMI Plan data operations with Firestore
@Observable
class TMIPlanService {
    private let db = Firestore.firestore()
    
    /// Get the user-scoped TMI plans collection
    private var userPlansCollection: CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[TMIPlanService] Error: User not logged in")
            return nil
        }
        return db.collection("users").document(uid).collection("tmiPlans")
    }
    
    /// Fetch all TMI plans for the current user
    func fetchPlans() async throws -> [TMIPlan] {
        guard let collection = userPlansCollection else {
            throw TMIPlanServiceError.userNotAuthenticated
        }
        
        do {
            print("[TMIPlanService] Fetching TMI plans...")
            let querySnapshot = try await collection.getDocuments()
            
            let plans = querySnapshot.documents.compactMap { document -> TMIPlan? in
                do {
                    var plan = try document.data(as: TMIPlan.self)
                    // Ensure the plan has the document ID set
                    if plan.id == nil {
                        plan.id = document.documentID
                    }
                    return plan
                } catch {
                    print("[TMIPlanService] Failed to decode TMI plan document \(document.documentID): \(error)")
                    return nil
                }
            }
            
            print("[TMIPlanService] Successfully fetched \(plans.count) TMI plans")
            return plans
        } catch {
            print("[TMIPlanService] Error fetching TMI plans: \(error)")
            throw TMIPlanServiceError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Add a new TMI plan to Firestore
    func addPlan(_ plan: TMIPlan) async throws -> TMIPlan {
        guard let collection = userPlansCollection else {
            throw TMIPlanServiceError.userNotAuthenticated
        }
        
        do {
            print("[TMIPlanService] Adding TMI plan: \(plan.model.rawValue)")
            
            // Convert plan to Firestore data (without ID)
            let data = plan.toFirestoreData()
            
            // Add the document and get the reference
            let documentRef = try await collection.addDocument(data: data)
            
            print("[TMIPlanService] TMI plan added with ID: \(documentRef.documentID)")
            
            // Return the plan with the generated ID
            var savedPlan = plan
            savedPlan.id = documentRef.documentID
            
            return savedPlan
        } catch {
            print("[TMIPlanService] Error adding TMI plan: \(error)")
            throw TMIPlanServiceError.saveFailed(error.localizedDescription)
        }
    }
    
    /// Update an existing TMI plan in Firestore
    func updatePlan(_ plan: TMIPlan) async throws -> TMIPlan {
        guard let planId = plan.id else {
            throw TMIPlanServiceError.invalidPlanId
        }
        
        guard let collection = userPlansCollection else {
            throw TMIPlanServiceError.userNotAuthenticated
        }
        
        do {
            print("[TMIPlanService] Updating TMI plan: \(plan.model.rawValue)")
            
            var updatedPlan = plan
            updatedPlan.lastUpdated = Date() // Update the lastUpdated timestamp
            
            let data = updatedPlan.toFirestoreData()
            try await collection.document(planId).updateData(data)
            
            print("[TMIPlanService] TMI plan updated successfully")
            return updatedPlan
        } catch {
            print("[TMIPlanService] Error updating TMI plan: \(error)")
            throw TMIPlanServiceError.updateFailed(error.localizedDescription)
        }
    }
    
    /// Delete a TMI plan from Firestore
    func deletePlan(_ plan: TMIPlan) async throws {
        guard let planId = plan.id else {
            throw TMIPlanServiceError.invalidPlanId
        }
        
        guard let collection = userPlansCollection else {
            throw TMIPlanServiceError.userNotAuthenticated
        }
        
        do {
            print("[TMIPlanService] Deleting TMI plan: \(plan.model.rawValue)")
            try await collection.document(planId).delete()
            print("[TMIPlanService] TMI plan deleted successfully")
        } catch {
            print("[TMIPlanService] Error deleting TMI plan: \(error)")
            throw TMIPlanServiceError.deleteFailed(error.localizedDescription)
        }
    }
    
    /// Get a specific TMI plan by ID
    func getPlan(by id: String) async throws -> TMIPlan? {
        guard let collection = userPlansCollection else {
            throw TMIPlanServiceError.userNotAuthenticated
        }
        
        do {
            print("[TMIPlanService] Fetching TMI plan with ID: \(id)")
            let document = try await collection.document(id).getDocument()
            
            if document.exists {
                var plan = try document.data(as: TMIPlan.self)
                plan.id = document.documentID
                return plan
            } else {
                return nil
            }
        } catch {
            print("[TMIPlanService] Error fetching TMI plan: \(error)")
            throw TMIPlanServiceError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Get plans for a specific student
    func getPlansForStudent(_ studentId: String) async throws -> [TMIPlan] {
        guard let collection = userPlansCollection else {
            throw TMIPlanServiceError.userNotAuthenticated
        }
        
        do {
            print("[TMIPlanService] Fetching TMI plans for student: \(studentId)")
            let querySnapshot = try await collection
                .whereField("student.id", isEqualTo: studentId)
                .getDocuments()
            
            let plans = querySnapshot.documents.compactMap { document -> TMIPlan? in
                do {
                    var plan = try document.data(as: TMIPlan.self)
                    plan.id = document.documentID
                    return plan
                } catch {
                    print("[TMIPlanService] Failed to decode TMI plan document \(document.documentID): \(error)")
                    return nil
                }
            }
            
            print("[TMIPlanService] Successfully fetched \(plans.count) TMI plans for student")
            return plans
        } catch {
            print("[TMIPlanService] Error fetching TMI plans for student: \(error)")
            throw TMIPlanServiceError.fetchFailed(error.localizedDescription)
        }
    }
}

// MARK: - Error Types

enum TMIPlanServiceError: Error, LocalizedError {
    case userNotAuthenticated
    case invalidPlanId
    case fetchFailed(String)
    case saveFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .invalidPlanId:
            return "TMI Plan ID is invalid or missing"
        case .fetchFailed(let message):
            return "Failed to fetch TMI plans: \(message)"
        case .saveFailed(let message):
            return "Failed to save TMI plan: \(message)"
        case .updateFailed(let message):
            return "Failed to update TMI plan: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete TMI plan: \(message)"
        }
    }
}