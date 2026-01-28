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
            planId: planId,
            resourceTitle: resourceTitle,
            resourceCategory: resourceCategory,
            resourceURL: resourceURL,
            reason: nil,
            relatedCareer: nil,
            relatedInterest: nil,
            status: .assigned,
            viewedAt: nil,
            completedAt: nil,
            notes: nil,
            engagementMetrics: nil
        )
        
        let collection = db.collection("users").document(uid).collection("resourceAssignments")
        var data: [String: Any] = [
            "studentId": assignment.studentId,
            "resourceId": assignment.resourceId,
            "assignedBy": assignment.assignedBy,
            "assignedAt": Timestamp(date: assignment.assignedAt),
            "planId": assignment.planId as Any,
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
        if let metrics = assignment.engagementMetrics {
            data["engagementMetrics"] = encodeEngagementMetrics(metrics)
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
            "updatedAt": Date().timeIntervalSince1970,
            "engagementMetrics.completionPercentage": max(0, min(progress, 1.0))
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
            updates["engagementMetrics.completionPercentage"] = 1.0
        } else if status == .inProgress {
            updates["viewedAt"] = Timestamp(date: Date())
        }
        
        try await docRef.updateData(updates)
    }

    // MARK: - Engagement Tracking

    func trackResourceView(assignmentId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ResourceAssignmentError.userNotAuthenticated
        }

        let docRef = db.collection("users").document(uid).collection("resourceAssignments").document(assignmentId)

        let event = ResourceAssignment.EngagementMetrics.InteractionEvent(
            timestamp: Date(),
            eventType: .viewed,
            duration: nil
        )

        let updates: [String: Any] = [
            "engagementMetrics.viewCount": FieldValue.increment(Int64(1)),
            "engagementMetrics.lastViewedAt": Timestamp(date: Date()),
            "engagementMetrics.interactionEvents": FieldValue.arrayUnion([encodeInteractionEvent(event)]),
            "viewedAt": Timestamp(date: Date())
        ]

        try await docRef.updateData(updates)
    }

    func trackResourceProgress(assignmentId: String, percentage: Double, timeSpent: TimeInterval) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ResourceAssignmentError.userNotAuthenticated
        }

        let docRef = db.collection("users").document(uid).collection("resourceAssignments").document(assignmentId)
        let clamped = max(0, min(percentage, 1.0))

        let eventType: ResourceAssignment.EngagementMetrics.InteractionEvent.EventType =
            clamped >= 1.0 ? .completed : .started
        let event = ResourceAssignment.EngagementMetrics.InteractionEvent(
            timestamp: Date(),
            eventType: eventType,
            duration: timeSpent
        )

        var updates: [String: Any] = [
            "engagementMetrics.totalTimeSpent": FieldValue.increment(timeSpent),
            "engagementMetrics.completionPercentage": clamped,
            "engagementMetrics.interactionEvents": FieldValue.arrayUnion([encodeInteractionEvent(event)]),
            "updatedAt": Date().timeIntervalSince1970
        ]

        if clamped >= 1.0 {
            updates["status"] = ResourceAssignment.AssignmentStatus.completed.rawValue
            updates["completedAt"] = Timestamp(date: Date())
        } else if clamped > 0 {
            updates["status"] = ResourceAssignment.AssignmentStatus.inProgress.rawValue
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
        
        let engagementMetrics = parseEngagementMetrics(from: data["engagementMetrics"])

        return ResourceAssignment(
            id: document.documentID,
            studentId: studentId,
            resourceId: resourceId,
            assignedBy: assignedBy,
            assignedAt: assignedAt,
            planId: data["planId"] as? String,
            resourceTitle: resourceTitle,
            resourceCategory: resourceCategory,
            resourceURL: resourceURL,
            reason: data["reason"] as? String,
            relatedCareer: data["relatedCareer"] as? String,
            relatedInterest: data["relatedInterest"] as? String,
            status: status,
            viewedAt: viewedAt,
            completedAt: completedAt,
            notes: data["notes"] as? String,
            engagementMetrics: engagementMetrics
        )
    }

    private func encodeEngagementMetrics(_ metrics: ResourceAssignment.EngagementMetrics) -> [String: Any] {
        var data: [String: Any] = [
            "viewCount": metrics.viewCount,
            "totalTimeSpent": metrics.totalTimeSpent,
            "completionPercentage": metrics.completionPercentage,
            "interactionEvents": metrics.interactionEvents.map { encodeInteractionEvent($0) }
        ]

        if let lastViewedAt = metrics.lastViewedAt {
            data["lastViewedAt"] = Timestamp(date: lastViewedAt)
        }

        return data
    }

    private func encodeInteractionEvent(_ event: ResourceAssignment.EngagementMetrics.InteractionEvent) -> [String: Any] {
        var data: [String: Any] = [
            "timestamp": Timestamp(date: event.timestamp),
            "eventType": event.eventType.rawValue
        ]

        if let duration = event.duration {
            data["duration"] = duration
        }

        return data
    }

    private func parseEngagementMetrics(from raw: Any?) -> ResourceAssignment.EngagementMetrics? {
        guard let data = raw as? [String: Any] else { return nil }

        let viewCount = data["viewCount"] as? Int ?? 0
        let totalTimeSpent = data["totalTimeSpent"] as? TimeInterval ?? 0
        let completionPercentage = data["completionPercentage"] as? Double ?? 0

        let lastViewedAt: Date?
        if let timestamp = data["lastViewedAt"] as? Timestamp {
            lastViewedAt = timestamp.dateValue()
        } else if let seconds = data["lastViewedAt"] as? Double {
            lastViewedAt = Date(timeIntervalSince1970: seconds)
        } else {
            lastViewedAt = nil
        }

        let eventsRaw = data["interactionEvents"] as? [[String: Any]] ?? []
        let events: [ResourceAssignment.EngagementMetrics.InteractionEvent] = eventsRaw.compactMap { eventData in
            guard let typeRaw = eventData["eventType"] as? String,
                  let eventType = ResourceAssignment.EngagementMetrics.InteractionEvent.EventType(rawValue: typeRaw) else {
                return nil
            }

            let timestamp: Date
            if let ts = eventData["timestamp"] as? Timestamp {
                timestamp = ts.dateValue()
            } else if let seconds = eventData["timestamp"] as? Double {
                timestamp = Date(timeIntervalSince1970: seconds)
            } else {
                return nil
            }

            let duration = eventData["duration"] as? TimeInterval

            return ResourceAssignment.EngagementMetrics.InteractionEvent(
                timestamp: timestamp,
                eventType: eventType,
                duration: duration
            )
        }

        return ResourceAssignment.EngagementMetrics(
            viewCount: viewCount,
            totalTimeSpent: totalTimeSpent,
            lastViewedAt: lastViewedAt,
            completionPercentage: completionPercentage,
            interactionEvents: events
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
