//
//  AuditLog.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #8
//  Model for audit logging of sensitive operations
//

import Foundation
import FirebaseFirestore

/// Audit log entry for tracking sensitive operations
struct AuditLog: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let action: AuditAction
    let entityType: EntityType
    let entityId: String
    let userId: String
    let userName: String?
    let userRole: String?
    let districtId: String?
    let timestamp: Date
    let ipAddress: String?
    let metadata: [String: String]?

    enum AuditAction: String, Codable, CaseIterable {
        // Student operations
        case studentCreated = "student_created"
        case studentUpdated = "student_updated"
        case studentDeleted = "student_deleted"
        case studentViewed = "student_viewed"
        case studentDataExported = "student_data_exported"

        // TMI Plan operations
        case planCreated = "plan_created"
        case planUpdated = "plan_updated"
        case planDeleted = "plan_deleted"
        case planSubmitted = "plan_submitted"
        case planApproved = "plan_approved"
        case planRejected = "plan_rejected"
        case planExported = "plan_exported"

        // Form operations
        case formCreated = "form_created"
        case formAssigned = "form_assigned"
        case formSubmitted = "form_submitted"
        case formViewed = "form_viewed"

        // Meeting operations
        case meetingCreated = "meeting_created"
        case meetingUpdated = "meeting_updated"
        case meetingCompleted = "meeting_completed"
        case meetingDeleted = "meeting_deleted"

        // User & Access operations
        case userLogin = "user_login"
        case userLogout = "user_logout"
        case roleChanged = "role_changed"
        case permissionGranted = "permission_granted"
        case permissionRevoked = "permission_revoked"

        // Data export operations
        case reportGenerated = "report_generated"
        case bulkExport = "bulk_export"
        case analyticsExported = "analytics_exported"

        // Compliance operations
        case consentGranted = "consent_granted"
        case consentRevoked = "consent_revoked"
        case dataRetentionPolicyApplied = "data_retention_policy_applied"
        case dataDeleted = "data_deleted"

        var displayName: String {
            switch self {
            case .studentCreated: return "Student Created"
            case .studentUpdated: return "Student Updated"
            case .studentDeleted: return "Student Deleted"
            case .studentViewed: return "Student Viewed"
            case .studentDataExported: return "Student Data Exported"
            case .planCreated: return "Plan Created"
            case .planUpdated: return "Plan Updated"
            case .planDeleted: return "Plan Deleted"
            case .planSubmitted: return "Plan Submitted"
            case .planApproved: return "Plan Approved"
            case .planRejected: return "Plan Rejected"
            case .planExported: return "Plan Exported"
            case .formCreated: return "Form Created"
            case .formAssigned: return "Form Assigned"
            case .formSubmitted: return "Form Submitted"
            case .formViewed: return "Form Viewed"
            case .meetingCreated: return "Meeting Created"
            case .meetingUpdated: return "Meeting Updated"
            case .meetingCompleted: return "Meeting Completed"
            case .meetingDeleted: return "Meeting Deleted"
            case .userLogin: return "User Login"
            case .userLogout: return "User Logout"
            case .roleChanged: return "Role Changed"
            case .permissionGranted: return "Permission Granted"
            case .permissionRevoked: return "Permission Revoked"
            case .reportGenerated: return "Report Generated"
            case .bulkExport: return "Bulk Export"
            case .analyticsExported: return "Analytics Exported"
            case .consentGranted: return "Consent Granted"
            case .consentRevoked: return "Consent Revoked"
            case .dataRetentionPolicyApplied: return "Data Retention Policy Applied"
            case .dataDeleted: return "Data Deleted"
            }
        }

        var icon: String {
            switch self {
            case .studentCreated, .planCreated, .formCreated, .meetingCreated:
                return "plus.circle.fill"
            case .studentUpdated, .planUpdated, .meetingUpdated:
                return "pencil.circle.fill"
            case .studentDeleted, .planDeleted, .meetingDeleted, .dataDeleted:
                return "trash.circle.fill"
            case .studentViewed, .formViewed:
                return "eye.fill"
            case .studentDataExported, .planExported, .bulkExport, .analyticsExported:
                return "square.and.arrow.up.fill"
            case .planSubmitted, .formSubmitted:
                return "paperplane.fill"
            case .planApproved:
                return "checkmark.circle.fill"
            case .planRejected:
                return "xmark.circle.fill"
            case .formAssigned:
                return "doc.badge.arrow.up.fill"
            case .meetingCompleted:
                return "checkmark.seal.fill"
            case .userLogin:
                return "person.badge.key.fill"
            case .userLogout:
                return "rectangle.portrait.and.arrow.right.fill"
            case .roleChanged, .permissionGranted, .permissionRevoked:
                return "person.badge.shield.checkmark.fill"
            case .reportGenerated:
                return "chart.bar.doc.horizontal.fill"
            case .consentGranted:
                return "hand.thumbsup.fill"
            case .consentRevoked:
                return "hand.thumbsdown.fill"
            case .dataRetentionPolicyApplied:
                return "clock.badge.checkmark.fill"
            }
        }

        var severity: AuditSeverity {
            switch self {
            case .studentDeleted, .planDeleted, .meetingDeleted, .dataDeleted,
                 .consentRevoked, .permissionRevoked:
                return .high
            case .studentDataExported, .bulkExport, .roleChanged,
                 .permissionGranted, .dataRetentionPolicyApplied:
                return .medium
            default:
                return .low
            }
        }
    }

    enum EntityType: String, Codable, CaseIterable {
        case student = "student"
        case tmiPlan = "tmi_plan"
        case form = "form"
        case meeting = "meeting"
        case user = "user"
        case district = "district"
        case school = "school"
        case resource = "resource"
        case report = "report"

        var displayName: String {
            switch self {
            case .student: return "Student"
            case .tmiPlan: return "TMI Plan"
            case .form: return "Form"
            case .meeting: return "Meeting"
            case .user: return "User"
            case .district: return "District"
            case .school: return "School"
            case .resource: return "Resource"
            case .report: return "Report"
            }
        }
    }

    enum AuditSeverity: String, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"

        var color: String {
            switch self {
            case .low: return "#3498DB"
            case .medium: return "#F39C12"
            case .high: return "#E74C3C"
            }
        }
    }

    init(
        id: String? = nil,
        action: AuditAction,
        entityType: EntityType,
        entityId: String,
        userId: String,
        userName: String? = nil,
        userRole: String? = nil,
        districtId: String? = nil,
        timestamp: Date = Date(),
        ipAddress: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.action = action
        self.entityType = entityType
        self.entityId = entityId
        self.userId = userId
        self.userName = userName
        self.userRole = userRole
        self.districtId = districtId
        self.timestamp = timestamp
        self.ipAddress = ipAddress
        self.metadata = metadata
    }

    // MARK: - Firestore Conversion

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "action": action.rawValue,
            "entityType": entityType.rawValue,
            "entityId": entityId,
            "userId": userId,
            "timestamp": Timestamp(date: timestamp)
        ]

        if let userName = userName {
            data["userName"] = userName
        }

        if let userRole = userRole {
            data["userRole"] = userRole
        }

        if let districtId = districtId {
            data["districtId"] = districtId
        }

        if let ipAddress = ipAddress {
            data["ipAddress"] = ipAddress
        }

        if let metadata = metadata {
            data["metadata"] = metadata
        }

        return data
    }
}

// MARK: - Sample Data

extension AuditLog {
    static var sampleLog: AuditLog {
        AuditLog(
            action: .studentViewed,
            entityType: .student,
            entityId: "student-123",
            userId: "user-456",
            userName: "Ms. Johnson",
            userRole: "counselor",
            districtId: "district-789",
            timestamp: Date(),
            ipAddress: "192.168.1.1",
            metadata: [
                "studentName": "John Doe",
                "grade": "10"
            ]
        )
    }
}
