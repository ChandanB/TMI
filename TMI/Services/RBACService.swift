//
//  RBACService.swift
//  TMI
//
//  Role-Based Access Control service for permission validation
//

import Foundation

/// Service for checking role-based permissions throughout the app
final class RBACService {
    static let shared = RBACService()

    private init() {}

    // MARK: - Permission Definitions

    enum Permission {
        // Student Management
        case viewStudents
        case createStudent
        case editStudent
        case deleteStudent
        case viewStudentSensitiveData
        case assignStaffToStudent

        // TMI Plan Management
        case viewPlans
        case createPlan
        case editPlan
        case deletePlan
        case approvePlan
        case submitPlanForApproval

        // Resource Management
        case viewResources
        case createResource
        case editResource
        case deleteResource
        case assignResources

        // Survey & Forms
        case createSurvey
        case assignSurvey
        case viewSurveyResults
        case createFormTemplate
        case assignForm

        // District & Analytics
        case viewDistrict
        case manageDistrict
        case viewReports
        case viewAnalytics
        case exportData

        // Meeting Management
        case scheduleMeeting
        case viewMeetings
        case manageMeetings

        // Administrative
        case manageUsers
        case manageRoles
        case viewAuditLogs
        case manageCompliance
    }

    // MARK: - Permission Checking

    /// Check if a user has a specific permission
    func hasPermission(_ permission: Permission, user: TMIUser) -> Bool {
        return hasPermission(permission, role: user.role)
    }

    /// Check if a role has a specific permission
    func hasPermission(_ permission: Permission, role: UserRole) -> Bool {
        switch permission {
        // Student Management Permissions
        case .viewStudents:
            return role.canViewStudents
        case .createStudent:
            return role.canCreateStudents
        case .editStudent:
            return role.canEditStudents
        case .deleteStudent:
            return role.canDeleteStudents
        case .viewStudentSensitiveData:
            return role.canViewSensitiveData
        case .assignStaffToStudent:
            return role.canAssignStaff

        // Plan Management Permissions
        case .viewPlans:
            return role.canViewPlans
        case .createPlan:
            return role.canCreatePlans
        case .editPlan:
            return role.canEditPlans
        case .deletePlan:
            return role.canDeletePlans
        case .approvePlan:
            return role.canApprovePlans
        case .submitPlanForApproval:
            return role.canSubmitPlans

        // Resource Management
        case .viewResources:
            return true // All authenticated users can view resources
        case .createResource:
            return role.canCreateResources
        case .editResource:
            return role.canEditResources
        case .deleteResource:
            return role.canDeleteResources
        case .assignResources:
            return role.canAssignResources

        // Survey & Forms
        case .createSurvey:
            return role.canCreateSurveys
        case .assignSurvey:
            return role.canAssignSurveys
        case .viewSurveyResults:
            return role.canViewSurveyResults
        case .createFormTemplate:
            return role.canCreateForms
        case .assignForm:
            return role.canAssignForms

        // District & Analytics
        case .viewDistrict:
            return role.canViewDistrict
        case .manageDistrict:
            return role.canManageDistrict
        case .viewReports:
            return role.canViewReports
        case .viewAnalytics:
            return role.canViewAnalytics
        case .exportData:
            return role.canExportData

        // Meeting Management
        case .scheduleMeeting:
            return role.canScheduleMeetings
        case .viewMeetings:
            return role.canViewMeetings
        case .manageMeetings:
            return role.canManageMeetings

        // Administrative
        case .manageUsers:
            return role.canManageUsers
        case .manageRoles:
            return role.canManageRoles
        case .viewAuditLogs:
            return role.canViewAuditLogs
        case .manageCompliance:
            return role.canManageCompliance
        }
    }

    /// Require a permission - throws error if user doesn't have it
    func requirePermission(_ permission: Permission, user: TMIUser) throws {
        guard hasPermission(permission, user: user) else {
            throw RBACError.permissionDenied(permission)
        }
    }

    /// Check if user can access a specific student
    func canAccessStudent(_ studentId: String, user: TMIUser, student: Student) -> Bool {
        // Students can only access their own data
        if user.role == .student {
            return user.userID == studentId
        }

        // Parents/guardians can access their children
        if user.role == .parent || user.role == .legalGuardian {
            // TODO: Wire guardian relationships when student contact fields are added
            return false
        }

        // Staff assigned to student can access
        if student.assignedCounselorId == user.userID ||
           student.primaryTeacherId == user.userID ||
           student.createdBy == user.userID {
            return true
        }

        // District admins can access all students in their district
        if user.role.canManageDistrict {
            return user.districtId == student.districtId
        }

        // Staff in same district can view (but not necessarily edit)
        return user.districtId == student.districtId && hasPermission(.viewStudents, user: user)
    }

    /// Check if user can access a specific plan
    func canAccessPlan(_ plan: TMIPlan, user: TMIUser) -> Bool {
        // Plan creator can access
        if plan.createdBy == user.userID {
            return true
        }

        // Assigned counselor can access
        if plan.assignedCounselorId == user.userID {
            return true
        }

        // Approvers can access
        if let currentApprovers = plan.currentApprovers, currentApprovers.contains(user.userID) {
            return true
        }

        // District admins can access all plans in their district
        if user.role.canManageDistrict && user.districtId == plan.districtId {
            return true
        }

        return false
    }
}

// MARK: - RBAC Errors

enum RBACError: LocalizedError {
    case permissionDenied(RBACService.Permission)
    case unauthorized
    case insufficientRole

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        case .unauthorized:
            return "Unauthorized access"
        case .insufficientRole:
            return "Your role does not have sufficient permissions for this action"
        }
    }
}

// MARK: - UserRole Permission Extensions

extension UserRole {
    // Student Management
    var canViewStudents: Bool {
        switch self {
        case .student, .parent, .legalGuardian:
            return false
        default:
            return true
        }
    }

    var canCreateStudents: Bool {
        return [.teacher, .counselor, .administrator, .admin, .socialWorker, .superintendent, .districtAdmin].contains(self)
    }

    var canEditStudents: Bool {
        return [.teacher, .counselor, .administrator, .admin, .socialWorker, .superintendent, .districtAdmin].contains(self)
    }

    var canDeleteStudents: Bool {
        return [.administrator, .admin, .superintendent, .districtAdmin].contains(self)
    }

    var canViewSensitiveData: Bool {
        return [.counselor, .administrator, .admin, .socialWorker, .superintendent, .districtAdmin].contains(self)
    }

    var canAssignStaff: Bool {
        return [.administrator, .admin, .counselor, .superintendent, .districtAdmin].contains(self)
    }

    // Plan Management
    var canViewPlans: Bool {
        return self != .parent && self != .legalGuardian
    }

    var canCreatePlans: Bool {
        return [.teacher, .counselor, .administrator, .admin, .socialWorker, .superintendent, .districtAdmin].contains(self)
    }

    var canEditPlans: Bool {
        return [.teacher, .counselor, .administrator, .admin, .socialWorker, .superintendent, .districtAdmin].contains(self)
    }

    var canDeletePlans: Bool {
        return [.administrator, .admin, .counselor, .superintendent, .districtAdmin].contains(self)
    }

    var canApprovePlans: Bool {
        return [.counselor, .administrator, .admin, .superintendent, .districtAdmin].contains(self)
    }

    var canSubmitPlans: Bool {
        return [.teacher, .counselor, .socialWorker].contains(self)
    }

    // Resource Management
    var canCreateResources: Bool {
        return self != .student && self != .parent && self != .legalGuardian
    }

    var canEditResources: Bool {
        return self != .student && self != .parent && self != .legalGuardian
    }

    var canDeleteResources: Bool {
        return [.administrator, .admin, .counselor, .superintendent, .districtAdmin].contains(self)
    }

    var canAssignResources: Bool {
        return [.teacher, .counselor, .administrator, .admin, .socialWorker, .superintendent, .districtAdmin].contains(self)
    }

    // Survey & Forms
    var canCreateSurveys: Bool {
        return [.teacher, .counselor, .administrator, .admin, .socialWorker, .superintendent, .districtAdmin].contains(self)
    }

    var canAssignSurveys: Bool {
        return [.teacher, .counselor, .administrator, .admin, .socialWorker, .superintendent, .districtAdmin].contains(self)
    }

    var canViewSurveyResults: Bool {
        return [.teacher, .counselor, .administrator, .admin, .socialWorker, .superintendent, .districtAdmin].contains(self)
    }

    var canCreateForms: Bool {
        return [.teacher, .counselor, .administrator, .admin, .socialWorker, .superintendent, .districtAdmin].contains(self)
    }

    var canAssignForms: Bool {
        return [.teacher, .counselor, .administrator, .admin, .socialWorker, .superintendent, .districtAdmin].contains(self)
    }

    // District & Analytics
    var canViewDistrict: Bool {
        return [.administrator, .admin, .counselor, .superintendent, .districtAdmin].contains(self)
    }

    var canManageDistrict: Bool {
        return [.administrator, .admin, .superintendent, .districtAdmin].contains(self)
    }

    var canViewReports: Bool {
        return self != .student && self != .parent && self != .legalGuardian
    }

    var canViewAnalytics: Bool {
        return [.administrator, .admin, .counselor, .superintendent, .districtAdmin].contains(self)
    }

    var canExportData: Bool {
        return [.administrator, .admin, .counselor, .superintendent, .districtAdmin].contains(self)
    }

    // Meeting Management
    var canScheduleMeetings: Bool {
        return [.teacher, .counselor, .administrator, .admin, .socialWorker, .superintendent, .districtAdmin].contains(self)
    }

    var canViewMeetings: Bool {
        return self != .parent && self != .legalGuardian
    }

    var canManageMeetings: Bool {
        return [.counselor, .administrator, .admin, .superintendent, .districtAdmin].contains(self)
    }

    // Administrative
    var canManageUsers: Bool {
        return [.administrator, .admin, .superintendent, .districtAdmin].contains(self)
    }

    var canManageRoles: Bool {
        return [.administrator, .admin, .superintendent, .districtAdmin].contains(self)
    }

    var canViewAuditLogs: Bool {
        return [.administrator, .admin, .superintendent, .districtAdmin].contains(self)
    }

    var canManageCompliance: Bool {
        return [.administrator, .admin, .superintendent, .districtAdmin].contains(self)
    }
}
