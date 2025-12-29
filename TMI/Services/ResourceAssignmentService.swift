//
//  ResourceAssignmentService.swift
//  TMI
//
//  Service for assigning resources to students/plans.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Resource Assignment Service

final class ResourceAssignmentService {
    static let shared = ResourceAssignmentService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Assignment Operations
    
    /// Assign a resource to a student
    func assignResource(resourceId: String, studentId: String, planId: String?, resourceTitle: String, resourceCategory: String, resourceURL: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ResourceAssignmentError.userNotAuthenticated
        }
        
        let assignment = ResourceAssignment(
            id: nil,
            studentId: studentId,
            resourceId: resourceId,
            assignedBy: uid,
            assignedAt: Date(),
            resourceTitle: resourceTitle,
            resourceCategory: resourceCategory,
            resourceURL: resourceURL,
            reason: nil,
            relatedCareer: nil,
            relatedInterest: nil,
            status: .assigned,
            viewedAt: nil,
            completedAt: nil,
            notes: nil
        )
        
        let collection = db.collection("users").document(uid).collection("resourceAssignments")
        var data: [String: Any] = [
            "studentId": assignment.studentId,
            "resourceId": assignment.resourceId,
            "assignedBy": assignment.assignedBy,
            "assignedAt": Timestamp(date: assignment.assignedAt),
            "resourceTitle": assignment.resourceTitle,
            "resourceCategory": assignment.resourceCategory,
            "resourceURL": assignment.resourceURL,
            "status": assignment.status.rawValue
        ]
        
        if let reason = assignment.reason {
            data["reason"] = reason
        }
        if let relatedCareer = assignment.relatedCareer {
            data["relatedCareer"] = relatedCareer
        }
        if let relatedInterest = assignment.relatedInterest {
            data["relatedInterest"] = relatedInterest
        }
        if let viewedAt = assignment.viewedAt {
            data["viewedAt"] = Timestamp(date: viewedAt)
        }
        if let completedAt = assignment.completedAt {
            data["completedAt"] = Timestamp(date: completedAt)
        }
        if let notes = assignment.notes {
            data["notes"] = notes
        }
        
        try await collection.addDocument(data: data)
        
        print("[ResourceAssignmentService] Assigned resource \(resourceId) to student \(studentId)")
    }
    
    /// Get assignments for a student
    func getAssignments(forStudentId studentId: String) async throws -> [ResourceAssignment] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ResourceAssignmentError.userNotAuthenticated
        }
        
        let collection = db.collection("users").document(uid).collection("resourceAssignments")
        let query = collection.whereField("studentId", isEqualTo: studentId)
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { parseAssignment(from: $0) }
    }
    
    /// Get assignments for a plan
    func getAssignments(forPlanId planId: String) async throws -> [ResourceAssignment] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ResourceAssignmentError.userNotAuthenticated
        }
        
        let collection = db.collection("users").document(uid).collection("resourceAssignments")
        let query = collection.whereField("planId", isEqualTo: planId)
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { parseAssignment(from: $0) }
    }
    
    /// Update assignment progress
    func updateProgress(assignmentId: String, progress: Double) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ResourceAssignmentError.userNotAuthenticated
        }
        
        let docRef = db.collection("users").document(uid).collection("resourceAssignments").document(assignmentId)
        
        var updates: [String: Any] = [
            "updatedAt": Date().timeIntervalSince1970
        ]
        
        if progress >= 1.0 {
            updates["status"] = ResourceAssignment.AssignmentStatus.completed.rawValue
            updates["completedAt"] = Timestamp(date: Date())
        } else if progress > 0 {
            updates["status"] = ResourceAssignment.AssignmentStatus.inProgress.rawValue
        }
        
        try await docRef.updateData(updates)
    }
    
    /// Remove an assignment
    func removeAssignment(assignmentId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ResourceAssignmentError.userNotAuthenticated
        }
        
        try await db.collection("users").document(uid).collection("resourceAssignments").document(assignmentId).delete()
    }
    
    /// Update assignment status
    func updateAssignmentStatus(_ assignmentId: String, status: ResourceAssignment.AssignmentStatus, notes: String?) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ResourceAssignmentError.userNotAuthenticated
        }
        
        let docRef = db.collection("users").document(uid).collection("resourceAssignments").document(assignmentId)
        
        var updates: [String: Any] = [
            "status": status.rawValue,
            "updatedAt": Date().timeIntervalSince1970
        ]
        
        if let notes = notes {
            updates["notes"] = notes
        }
        
        if status == .completed {
            updates["completedAt"] = Timestamp(date: Date())
        } else if status == .inProgress {
            updates["viewedAt"] = Timestamp(date: Date())
        }
        
        try await docRef.updateData(updates)
    }
    
    // MARK: - Private Helpers
    
    private func parseAssignment(from document: DocumentSnapshot) -> ResourceAssignment? {
        guard let data = document.data() else { return nil }
        
        guard let resourceId = data["resourceId"] as? String,
              let studentId = data["studentId"] as? String,
              let assignedBy = data["assignedBy"] as? String,
              let resourceTitle = data["resourceTitle"] as? String,
              let resourceCategory = data["resourceCategory"] as? String,
              let resourceURL = data["resourceURL"] as? String,
              let statusRaw = data["status"] as? String,
              let status = ResourceAssignment.AssignmentStatus(rawValue: statusRaw) else {
            return nil
        }
        
        // Parse dates
        let assignedAt: Date
        if let assignedAtTimestamp = data["assignedAt"] as? Timestamp {
            assignedAt = assignedAtTimestamp.dateValue()
        } else if let assignedAtDouble = data["assignedAt"] as? Double {
            assignedAt = Date(timeIntervalSince1970: assignedAtDouble)
        } else {
            return nil
        }
        
        let completedAt: Date?
        if let completedAtTimestamp = data["completedAt"] as? Timestamp {
            completedAt = completedAtTimestamp.dateValue()
        } else if let completedAtDouble = data["completedAt"] as? Double {
            completedAt = Date(timeIntervalSince1970: completedAtDouble)
        } else {
            completedAt = nil
        }
        
        let viewedAt: Date?
        if let viewedAtTimestamp = data["viewedAt"] as? Timestamp {
            viewedAt = viewedAtTimestamp.dateValue()
        } else if let viewedAtDouble = data["viewedAt"] as? Double {
            viewedAt = Date(timeIntervalSince1970: viewedAtDouble)
        } else {
            viewedAt = nil
        }
        
        return ResourceAssignment(
            id: document.documentID,
            studentId: studentId,
            resourceId: resourceId,
            assignedBy: assignedBy,
            assignedAt: assignedAt,
            resourceTitle: resourceTitle,
            resourceCategory: resourceCategory,
            resourceURL: resourceURL,
            reason: data["reason"] as? String,
            relatedCareer: data["relatedCareer"] as? String,
            relatedInterest: data["relatedInterest"] as? String,
            status: status,
            viewedAt: viewedAt,
            completedAt: completedAt,
            notes: data["notes"] as? String
        )
    }
}


// MARK: - Errors

enum ResourceAssignmentError: LocalizedError {
    case userNotAuthenticated
    case assignmentNotFound
    case updateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .assignmentNotFound:
            return "Assignment not found"
        case .updateFailed(let message):
            return "Failed to update assignment: \(message)"
        }
    }
}
