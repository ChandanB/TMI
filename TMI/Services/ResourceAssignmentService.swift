//
//  ResourceAssignmentService.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #5
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Service for managing resource assignments to students
@Observable
class ResourceAssignmentService {
    private let db = Firestore.firestore()

    // MARK: - Assignment Operations

    /// Assign a resource to a student
    func assignResource(
        to studentId: String,
        resource: Resource,
        reason: String? = nil,
        relatedCareer: String? = nil,
        relatedInterest: String? = nil
    ) async throws -> ResourceAssignment {
        guard let currentUser = Auth.auth().currentUser else {
            throw ResourceAssignmentError.userNotAuthenticated
        }

        guard let resourceId = resource.id else {
            throw ResourceAssignmentError.invalidResource
        }

        let assignment = ResourceAssignment(
            studentId: studentId,
            resourceId: resourceId,
            assignedBy: currentUser.uid,
            resourceTitle: resource.title,
            resourceCategory: resource.category.rawValue,
            resourceURL: resource.url,
            reason: reason,
            relatedCareer: relatedCareer,
            relatedInterest: relatedInterest
        )

        let data = try Firestore.Encoder().encode(assignment)
        let docRef = try await db.collection("resourceAssignments").addDocument(data: data)

        var savedAssignment = assignment
        savedAssignment.id = docRef.documentID

        print("[ResourceAssignmentService] Assigned resource '\(resource.title)' to student \(studentId)")
        return savedAssignment
    }

    /// Bulk assign a resource to multiple students
    func assignResourceToMultipleStudents(
        studentIds: [String],
        resource: Resource,
        reason: String? = nil
    ) async throws -> [ResourceAssignment] {
        var assignments: [ResourceAssignment] = []

        for studentId in studentIds {
            do {
                let assignment = try await assignResource(
                    to: studentId,
                    resource: resource,
                    reason: reason
                )
                assignments.append(assignment)
            } catch {
                print("[ResourceAssignmentService] Failed to assign resource to student \(studentId): \(error)")
            }
        }

        return assignments
    }

    /// Fetch all resource assignments for a student
    func fetchAssignments(for studentId: String) async throws -> [ResourceAssignment] {
        let querySnapshot = try await db.collection("resourceAssignments")
            .whereField("studentId", isEqualTo: studentId)
            .order(by: "assignedAt", descending: true)
            .getDocuments()

        return querySnapshot.documents.compactMap { try? $0.data(as: ResourceAssignment.self) }
    }

    /// Fetch assignments by status
    func fetchAssignments(
        for studentId: String,
        status: ResourceAssignment.AssignmentStatus
    ) async throws -> [ResourceAssignment] {
        let querySnapshot = try await db.collection("resourceAssignments")
            .whereField("studentId", isEqualTo: studentId)
            .whereField("status", isEqualTo: status.rawValue)
            .order(by: "assignedAt", descending: true)
            .getDocuments()

        return querySnapshot.documents.compactMap { try? $0.data(as: ResourceAssignment.self) }
    }

    /// Fetch assignments related to a specific career
    func fetchCareerRelatedAssignments(
        for studentId: String,
        career: String
    ) async throws -> [ResourceAssignment] {
        let querySnapshot = try await db.collection("resourceAssignments")
            .whereField("studentId", isEqualTo: studentId)
            .whereField("relatedCareer", isEqualTo: career)
            .order(by: "assignedAt", descending: true)
            .getDocuments()

        return querySnapshot.documents.compactMap { try? $0.data(as: ResourceAssignment.self) }
    }

    /// Fetch assignments related to a specific interest
    func fetchInterestRelatedAssignments(
        for studentId: String,
        interest: String
    ) async throws -> [ResourceAssignment] {
        let querySnapshot = try await db.collection("resourceAssignments")
            .whereField("studentId", isEqualTo: studentId)
            .whereField("relatedInterest", isEqualTo: interest)
            .order(by: "assignedAt", descending: true)
            .getDocuments()

        return querySnapshot.documents.compactMap { try? $0.data(as: ResourceAssignment.self) }
    }

    /// Update assignment status
    func updateAssignmentStatus(
        _ assignmentId: String,
        status: ResourceAssignment.AssignmentStatus,
        notes: String? = nil
    ) async throws {
        var updateData: [String: Any] = ["status": status.rawValue]

        // Update timestamps based on status
        switch status {
        case .viewed:
            updateData["viewedAt"] = Timestamp(date: Date())
        case .completed:
            updateData["completedAt"] = Timestamp(date: Date())
        default:
            break
        }

        if let notes = notes {
            updateData["notes"] = notes
        }

        try await db.collection("resourceAssignments")
            .document(assignmentId)
            .updateData(updateData)

        print("[ResourceAssignmentService] Updated assignment \(assignmentId) status to \(status.displayName)")
    }

    /// Delete an assignment
    func deleteAssignment(_ assignmentId: String) async throws {
        try await db.collection("resourceAssignments")
            .document(assignmentId)
            .delete()

        print("[ResourceAssignmentService] Deleted assignment: \(assignmentId)")
    }

    // MARK: - Analytics

    /// Get assignment analytics for a student
    func getAssignmentAnalytics(for studentId: String) async throws -> ResourceAssignmentAnalytics {
        let assignments = try await fetchAssignments(for: studentId)
        return ResourceAssignmentAnalytics(assignments: assignments)
    }

    /// Get district-wide assignment analytics
    func getDistrictAssignmentAnalytics(districtId: String) async throws -> ResourceAssignmentAnalytics {
        // First get all students in district
        let studentsSnapshot = try await db.collection("users")
            .whereField("districtId", isEqualTo: districtId)
            .whereField("role", isEqualTo: "student")
            .getDocuments()

        let studentIds = studentsSnapshot.documents.compactMap { $0.documentID }

        // Fetch assignments for all students in district
        var allAssignments: [ResourceAssignment] = []
        for studentId in studentIds {
            let assignments = try await fetchAssignments(for: studentId)
            allAssignments.append(contentsOf: assignments)
        }

        return ResourceAssignmentAnalytics(assignments: allAssignments)
    }

    // MARK: - Recommendations

    /// Get recommended resource assignments for a student based on their interests and career goals
    func getRecommendedAssignments(for student: Student) async -> [Resource] {
        let careerService = CareerService.shared

        // Get personalized resource recommendations based on student's career interests
        let recommendedResources = await careerService.getRecommendedResources(for: student)

        // Filter out resources already assigned to this student
        guard let studentId = student.id else { return recommendedResources }

        do {
            let existingAssignments = try await fetchAssignments(for: studentId)
            let assignedResourceIds = Set(existingAssignments.map { $0.resourceId })

            return recommendedResources.filter { resource in
                guard let resourceId = resource.id else { return true }
                return !assignedResourceIds.contains(resourceId)
            }
        } catch {
            print("[ResourceAssignmentService] Failed to filter existing assignments: \(error)")
            return recommendedResources
        }
    }
}

// MARK: - Error Handling

enum ResourceAssignmentError: Error, LocalizedError {
    case userNotAuthenticated
    case invalidResource
    case assignmentNotFound
    case fetchFailed(String)
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .invalidResource:
            return "Invalid resource provided"
        case .assignmentNotFound:
            return "Assignment not found"
        case .fetchFailed(let message):
            return "Failed to fetch assignments: \(message)"
        case .saveFailed(let message):
            return "Failed to save assignment: \(message)"
        }
    }
}
