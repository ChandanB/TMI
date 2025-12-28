//
//  ResourceAssignment.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #5
//

import Foundation
import FirebaseFirestore

/// Represents a resource assignment to a student
struct ResourceAssignment: Codable, Identifiable, Sendable {
    @DocumentID var id: String?

    // Assignment metadata
    let studentId: String
    let resourceId: String
    let assignedBy: String // User ID of counselor/teacher who assigned it
    let assignedAt: Date

    // Resource details (denormalized for quick access)
    let resourceTitle: String
    let resourceCategory: String
    let resourceURL: String

    // Assignment context
    let reason: String? // Why this resource was assigned
    let relatedCareer: String? // Career title if assigned from career exploration
    let relatedInterest: String? // Interest name if assigned from interest profile

    // Completion tracking
    var status: AssignmentStatus
    var viewedAt: Date?
    var completedAt: Date?
    var notes: String?

    enum AssignmentStatus: String, Codable, CaseIterable, Sendable {
        case assigned = "assigned"
        case viewed = "viewed"
        case inProgress = "in_progress"
        case completed = "completed"

        var displayName: String {
            switch self {
            case .assigned: return "Assigned"
            case .viewed: return "Viewed"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            }
        }

        var icon: String {
            switch self {
            case .assigned: return "envelope.fill"
            case .viewed: return "eye.fill"
            case .inProgress: return "clock.fill"
            case .completed: return "checkmark.circle.fill"
            }
        }
    }

    init(
        id: String? = nil,
        studentId: String,
        resourceId: String,
        assignedBy: String,
        assignedAt: Date = Date(),
        resourceTitle: String,
        resourceCategory: String,
        resourceURL: String,
        reason: String? = nil,
        relatedCareer: String? = nil,
        relatedInterest: String? = nil,
        status: AssignmentStatus = .assigned,
        viewedAt: Date? = nil,
        completedAt: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.studentId = studentId
        self.resourceId = resourceId
        self.assignedBy = assignedBy
        self.assignedAt = assignedAt
        self.resourceTitle = resourceTitle
        self.resourceCategory = resourceCategory
        self.resourceURL = resourceURL
        self.reason = reason
        self.relatedCareer = relatedCareer
        self.relatedInterest = relatedInterest
        self.status = status
        self.viewedAt = viewedAt
        self.completedAt = completedAt
        self.notes = notes
    }
}

/// Analytics for resource assignments
struct ResourceAssignmentAnalytics: Codable, Sendable {
    let totalAssignments: Int
    let completedAssignments: Int
    let inProgressAssignments: Int
    let viewedAssignments: Int
    let newAssignments: Int
    let completionRate: Double
    let averageTimeToComplete: TimeInterval? // In seconds
    let assignmentsByCategory: [String: Int]

    init(assignments: [ResourceAssignment]) {
        self.totalAssignments = assignments.count
        self.completedAssignments = assignments.filter { $0.status == .completed }.count
        self.inProgressAssignments = assignments.filter { $0.status == .inProgress }.count
        self.viewedAssignments = assignments.filter { $0.status == .viewed }.count
        self.newAssignments = assignments.filter { $0.status == .assigned }.count

        self.completionRate = totalAssignments > 0
            ? Double(completedAssignments) / Double(totalAssignments)
            : 0.0

        // Calculate average time to complete
        let completedWithTimes = assignments.compactMap { assignment -> TimeInterval? in
            guard assignment.status == .completed,
                  let completedAt = assignment.completedAt else { return nil }
            return completedAt.timeIntervalSince(assignment.assignedAt)
        }

        self.averageTimeToComplete = completedWithTimes.isEmpty
            ? nil
            : completedWithTimes.reduce(0, +) / Double(completedWithTimes.count)

        // Group by category
        var categoryCount: [String: Int] = [:]
        for assignment in assignments {
            categoryCount[assignment.resourceCategory, default: 0] += 1
        }
        self.assignmentsByCategory = categoryCount
    }
}
