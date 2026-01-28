//
//  FirestorePaths.swift
//  TMI
//
//  Centralized Firestore path builder for district-scoped collections
//

import Foundation

/// Centralized path builder for consistent Firestore collection access
enum FirestorePaths {

    // MARK: - User-Scoped Paths (Legacy/Backward Compatibility)

    static func userStudents(userId: String) -> String {
        return "users/\(userId)/students"
    }

    static func userStudent(userId: String, studentId: String) -> String {
        return "users/\(userId)/students/\(studentId)"
    }

    static func userPlans(userId: String) -> String {
        return "users/\(userId)/tmiPlans"
    }

    static func userPlan(userId: String, planId: String) -> String {
        return "users/\(userId)/tmiPlans/\(planId)"
    }

    static func userResources(userId: String) -> String {
        return "users/\(userId)/resources"
    }

    static func userResource(userId: String, resourceId: String) -> String {
        return "users/\(userId)/resources/\(resourceId)"
    }

    static func userMeetings(userId: String) -> String {
        return "users/\(userId)/meetings"
    }

    static func userMeeting(userId: String, meetingId: String) -> String {
        return "users/\(userId)/meetings/\(meetingId)"
    }

    // MARK: - District-Scoped Paths (Primary)

    static func districtStudents(districtId: String) -> String {
        return "districts/\(districtId)/students"
    }

    static func districtStudent(districtId: String, studentId: String) -> String {
        return "districts/\(districtId)/students/\(studentId)"
    }

    static func districtPlans(districtId: String) -> String {
        return "districts/\(districtId)/plans"
    }

    static func districtPlan(districtId: String, planId: String) -> String {
        return "districts/\(districtId)/plans/\(planId)"
    }

    static func districtStaff(districtId: String) -> String {
        return "districts/\(districtId)/staff"
    }

    static func districtStaffMember(districtId: String, staffId: String) -> String {
        return "districts/\(districtId)/staff/\(staffId)"
    }

    static func districtAnalytics(districtId: String) -> String {
        return "districts/\(districtId)/analytics"
    }

    static func districtAnalyticsForDate(districtId: String, date: String) -> String {
        return "districts/\(districtId)/analytics/\(date)"
    }

    static func districtSchools(districtId: String) -> String {
        return "districts/\(districtId)/schools"
    }

    static func districtSchool(districtId: String, schoolId: String) -> String {
        return "districts/\(districtId)/schools/\(schoolId)"
    }

    static func districtAuditLogs(districtId: String) -> String {
        return "districts/\(districtId)/auditLogs"
    }

    // MARK: - Top-Level Student Edge Collections

    static func studentInterests(studentId: String) -> String {
        return "students/\(studentId)/studentInterests"
    }

    static func studentInterest(studentId: String, interestId: String) -> String {
        return "students/\(studentId)/studentInterests/\(interestId)"
    }

    static func studentCareerState(studentId: String) -> String {
        return "students/\(studentId)/careerState"
    }

    static func studentCareer(studentId: String, careerId: String) -> String {
        return "students/\(studentId)/careerState/\(careerId)"
    }

    static func studentSurveys(studentId: String) -> String {
        return "students/\(studentId)/surveys"
    }

    static func studentSurvey(studentId: String, surveyId: String) -> String {
        return "students/\(studentId)/surveys/\(surveyId)"
    }

    // MARK: - Top-Level Plan Sub-Collections

    static func planResources(planId: String) -> String {
        return "plans/\(planId)/planResources"
    }

    static func planResource(planId: String, resourceId: String) -> String {
        return "plans/\(planId)/planResources/\(resourceId)"
    }

    static func planActivities(planId: String) -> String {
        return "plans/\(planId)/activities"
    }

    static func planActivity(planId: String, activityId: String) -> String {
        return "plans/\(planId)/activities/\(activityId)"
    }

    static func planApprovals(planId: String) -> String {
        return "plans/\(planId)/approvals"
    }

    static func planApproval(planId: String, approvalId: String) -> String {
        return "plans/\(planId)/approvals/\(approvalId)"
    }

    // MARK: - Global Collections

    static let interests = "interests"

    static func interest(interestId: String) -> String {
        return "interests/\(interestId)"
    }

    static let careers = "careers"

    static func career(careerId: String) -> String {
        return "careers/\(careerId)"
    }

    static let resources = "resources"

    static func resource(resourceId: String) -> String {
        return "resources/\(resourceId)"
    }

    static let formTemplates = "formTemplates"

    static func formTemplate(templateId: String) -> String {
        return "formTemplates/\(templateId)"
    }

    static let formAssignments = "formAssignments"

    static func formAssignment(assignmentId: String) -> String {
        return "formAssignments/\(assignmentId)"
    }

    static let formSubmissions = "formSubmissions"

    static func formSubmission(submissionId: String) -> String {
        return "formSubmissions/\(submissionId)"
    }

    static let resourceAssignments = "resourceAssignments"

    static func resourceAssignment(assignmentId: String) -> String {
        return "resourceAssignments/\(assignmentId)"
    }

    static let districts = "districts"

    static func district(districtId: String) -> String {
        return "districts/\(districtId)"
    }

    static let users = "users"

    static func user(userId: String) -> String {
        return "users/\(userId)"
    }

    static let notifications = "notifications"

    static func notification(notificationId: String) -> String {
        return "notifications/\(notificationId)"
    }

    // MARK: - Generated Resources (AI-Generated Content)

    static let generatedResources = "generatedResources"

    static func generatedResourcesForInterest(interestId: String) -> String {
        return "generatedResources/\(interestId)/resources"
    }

    static func generatedResource(interestId: String, resourceId: String) -> String {
        return "generatedResources/\(interestId)/resources/\(resourceId)"
    }

    // MARK: - Helper Methods

    /// Get the appropriate student collection path based on migration strategy
    /// - Parameters:
    ///   - districtId: Optional district ID for district-scoped access
    ///   - userId: Optional user ID for user-scoped fallback
    /// - Returns: The collection path to use
    static func students(districtId: String?, userId: String?) -> String {
        if let districtId = districtId {
            return districtStudents(districtId: districtId)
        } else if let userId = userId {
            return userStudents(userId: userId)
        } else {
            fatalError("Either districtId or userId must be provided")
        }
    }

    /// Get the appropriate plan collection path based on migration strategy
    /// - Parameters:
    ///   - districtId: Optional district ID for district-scoped access
    ///   - userId: Optional user ID for user-scoped fallback
    /// - Returns: The collection path to use
    static func plans(districtId: String?, userId: String?) -> String {
        if let districtId = districtId {
            return districtPlans(districtId: districtId)
        } else if let userId = userId {
            return userPlans(userId: userId)
        } else {
            fatalError("Either districtId or userId must be provided")
        }
    }
}

// MARK: - Migration Helpers

extension FirestorePaths {
    /// Strategy for reading data during migration
    enum ReadStrategy {
        case districtOnly       // Read only from district-scoped collections
        case userOnly           // Read only from user-scoped collections (legacy)
        case districtWithFallback // Try district first, fall back to user-scoped
    }

    /// Strategy for writing data during migration
    enum WriteStrategy {
        case districtOnly    // Write only to district-scoped collections
        case userOnly        // Write only to user-scoped collections (legacy)
        case dualWrite       // Write to both locations (migration phase)
    }

    /// Get collection paths for students based on read strategy
    static func studentCollections(
        strategy: ReadStrategy,
        districtId: String?,
        userId: String?
    ) -> [String] {
        switch strategy {
        case .districtOnly:
            guard let districtId = districtId else { return [] }
            return [districtStudents(districtId: districtId)]

        case .userOnly:
            guard let userId = userId else { return [] }
            return [userStudents(userId: userId)]

        case .districtWithFallback:
            var paths: [String] = []
            if let districtId = districtId {
                paths.append(districtStudents(districtId: districtId))
            }
            if let userId = userId {
                paths.append(userStudents(userId: userId))
            }
            return paths
        }
    }

    /// Get collection paths for plans based on read strategy
    static func planCollections(
        strategy: ReadStrategy,
        districtId: String?,
        userId: String?
    ) -> [String] {
        switch strategy {
        case .districtOnly:
            guard let districtId = districtId else { return [] }
            return [districtPlans(districtId: districtId)]

        case .userOnly:
            guard let userId = userId else { return [] }
            return [userPlans(userId: userId)]

        case .districtWithFallback:
            var paths: [String] = []
            if let districtId = districtId {
                paths.append(districtPlans(districtId: districtId))
            }
            if let userId = userId {
                paths.append(userPlans(userId: userId))
            }
            return paths
        }
    }
}
