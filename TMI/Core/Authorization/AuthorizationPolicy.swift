import Foundation

struct StudentAuthorizationScope: Codable, Sendable, Equatable {
    let studentID: String
    let districtID: String
    let schoolID: String
}

extension StudentAuthorizationScope {
    init?(student: Student) {
        guard let studentID = student.id,
              let districtID = student.districtId,
              let schoolID = student.schoolId else {
            return nil
        }

        self.init(
            studentID: studentID,
            districtID: districtID,
            schoolID: schoolID
        )
    }
}

struct SchoolAuthorizationScope: Codable, Sendable, Equatable {
    let districtID: String
    let schoolID: String
}

struct PlanAuthorizationScope: Codable, Sendable, Equatable {
    let planID: String
    let districtID: String
    let students: [StudentAuthorizationScope]
}

struct FormAssignmentAuthorizationScope: Codable, Sendable, Equatable {
    let districtID: String
    let schoolID: String?
    let students: [StudentAuthorizationScope]
}

struct TemplateAuthorizationScope: Codable, Sendable, Equatable {
    let districtID: String
    let schoolID: String?
}

enum AuthorizationPolicy {
    static func canCreateStudent(
        _ member: MembershipContext,
        school: SchoolAuthorizationScope
    ) -> Bool {
        guard isWellFormed(member),
              isWellFormedIdentifier(school.districtID),
              isWellFormedIdentifier(school.schoolID),
              member.districtID == school.districtID else {
            return false
        }

        switch member.role {
        case .teacher, .counselor:
            return member.schoolIDs.contains(school.schoolID)
        case .socialWorker:
            return false
        case .schoolAdministrator:
            return member.schoolIDs.contains(school.schoolID)
                && member.capabilities.contains(.studentWriteDetail)
        case .districtAdministrator:
            return member.capabilities.contains(.studentWriteDetail)
        }
    }

    static func canReadStudentDetail(
        _ member: MembershipContext,
        student: StudentAuthorizationScope
    ) -> Bool {
        guard hasValidStudentBoundary(member, student: student) else {
            return false
        }

        switch member.role {
        case .teacher, .counselor, .socialWorker:
            return isAssignedStudentInMemberSchool(member, student: student)
        case .schoolAdministrator:
            return member.schoolIDs.contains(student.schoolID)
                && member.capabilities.contains(.studentReadDetail)
        case .districtAdministrator:
            return member.capabilities.contains(.studentReadDetail)
        }
    }

    static func canWriteStudentDetail(
        _ member: MembershipContext,
        student: StudentAuthorizationScope
    ) -> Bool {
        guard hasValidStudentBoundary(member, student: student) else {
            return false
        }

        switch member.role {
        case .teacher, .counselor:
            return isAssignedStudentInMemberSchool(member, student: student)
        case .socialWorker:
            return false
        case .schoolAdministrator:
            return member.schoolIDs.contains(student.schoolID)
                && member.capabilities.contains(.studentWriteDetail)
        case .districtAdministrator:
            return member.capabilities.contains(.studentWriteDetail)
        }
    }

    static func canReadRestrictedRecord(
        _ member: MembershipContext,
        student: StudentAuthorizationScope
    ) -> Bool {
        guard hasValidStudentBoundary(member, student: student) else {
            return false
        }

        return canReadStudentDetail(member, student: student)
            && member.capabilities.contains(.studentRestrictedRead)
    }

    static func canWriteRestrictedRecord(
        _ member: MembershipContext,
        student: StudentAuthorizationScope
    ) -> Bool {
        guard hasValidStudentBoundary(member, student: student) else {
            return false
        }

        return canReadStudentDetail(member, student: student)
            && member.capabilities.contains(.studentRestrictedWrite)
    }

    static func canViewAggregate(
        _ member: MembershipContext,
        districtID: String,
        schoolID: String? = nil
    ) -> Bool {
        guard isWellFormed(member),
              isWellFormedIdentifier(districtID),
              member.districtID == districtID else {
            return false
        }

        guard let schoolID else {
            return member.role == .districtAdministrator
        }

        guard isWellFormedIdentifier(schoolID) else {
            return false
        }

        switch member.role {
        case .schoolAdministrator:
            return member.schoolIDs.contains(schoolID)
        case .districtAdministrator:
            return true
        case .teacher, .counselor, .socialWorker:
            return false
        }
    }

    static func canDeleteStudent(
        _ member: MembershipContext,
        student: StudentAuthorizationScope
    ) -> Bool {
        // Student records remain institution-owned until the retention-safe
        // archive/delete contract is implemented.
        false
    }

    static func canReadPlan(
        _ member: MembershipContext,
        plan: PlanAuthorizationScope
    ) -> Bool {
        guard hasValidPlanBoundary(member, plan: plan) else {
            return false
        }

        return plan.students.allSatisfy {
            canReadStudentDetail(member, student: $0)
        }
    }

    static func canWritePlan(
        _ member: MembershipContext,
        plan: PlanAuthorizationScope
    ) -> Bool {
        guard hasValidPlanBoundary(member, plan: plan) else {
            return false
        }

        switch member.role {
        case .teacher, .counselor:
            return plan.students.allSatisfy {
                isAssignedStudentInMemberSchool(member, student: $0)
            }
        case .socialWorker:
            return member.capabilities.contains(.studentWriteDetail)
                && plan.students.allSatisfy {
                    isAssignedStudentInMemberSchool(member, student: $0)
                }
        case .schoolAdministrator, .districtAdministrator:
            return plan.students.allSatisfy {
                canWriteStudentDetail(member, student: $0)
            }
        }
    }

    static func canApprovePlan(
        _ member: MembershipContext,
        plan: PlanAuthorizationScope
    ) -> Bool {
        member.capabilities.contains(.planApprove)
            && canReadPlan(member, plan: plan)
    }

    static func canDeletePlan(
        _ member: MembershipContext,
        plan: PlanAuthorizationScope
    ) -> Bool {
        false
    }

    static func canAssignForm(
        _ member: MembershipContext,
        assignment: FormAssignmentAuthorizationScope
    ) -> Bool {
        guard isWellFormed(member),
              isWellFormedIdentifier(assignment.districtID),
              member.districtID == assignment.districtID,
              assignment.students.allSatisfy({
                  $0.districtID == assignment.districtID && isWellFormed($0)
              }) else {
            return false
        }

        if let schoolID = assignment.schoolID {
            guard isWellFormedIdentifier(schoolID),
                  assignment.students.allSatisfy({ $0.schoolID == schoolID }) else {
                return false
            }
        }

        switch member.role {
        case .teacher, .counselor, .socialWorker:
            guard let schoolID = assignment.schoolID,
                  member.schoolIDs.contains(schoolID) else {
                return false
            }
            return assignment.students.allSatisfy {
                isAssignedStudentInMemberSchool(member, student: $0)
            }
        case .schoolAdministrator:
            guard let schoolID = assignment.schoolID,
                  member.schoolIDs.contains(schoolID) else {
                return false
            }
            return assignment.students.allSatisfy {
                member.schoolIDs.contains($0.schoolID)
            }
        case .districtAdministrator:
            return true
        }
    }

    static func canDeleteAssignment(
        _ member: MembershipContext,
        assignment: FormAssignmentAuthorizationScope
    ) -> Bool {
        false
    }

    static func canReadTemplate(
        _ member: MembershipContext,
        template: TemplateAuthorizationScope
    ) -> Bool {
        hasValidTemplateBoundary(member, template: template)
    }

    static func canWriteTemplate(
        _ member: MembershipContext,
        template: TemplateAuthorizationScope
    ) -> Bool {
        guard hasValidTemplateBoundary(member, template: template) else {
            return false
        }

        switch member.role {
        case .teacher, .counselor, .socialWorker, .schoolAdministrator:
            guard let schoolID = template.schoolID else {
                return false
            }
            return member.schoolIDs.contains(schoolID)
        case .districtAdministrator:
            return true
        }
    }

    static func canManageStaff(_ member: MembershipContext) -> Bool {
        isWellFormed(member) && member.capabilities.contains(.staffManage)
    }

    static func canExportReports(_ member: MembershipContext) -> Bool {
        isWellFormed(member) && member.capabilities.contains(.reportExport)
    }

    static func canReadAudit(_ member: MembershipContext) -> Bool {
        isWellFormed(member) && member.capabilities.contains(.auditRead)
    }

    private static func hasValidStudentBoundary(
        _ member: MembershipContext,
        student: StudentAuthorizationScope
    ) -> Bool {
        isWellFormed(member)
            && isWellFormed(student)
            && member.districtID == student.districtID
    }

    private static func hasValidPlanBoundary(
        _ member: MembershipContext,
        plan: PlanAuthorizationScope
    ) -> Bool {
        isWellFormed(member)
            && isWellFormedIdentifier(plan.planID)
            && isWellFormedIdentifier(plan.districtID)
            && member.districtID == plan.districtID
            && !plan.students.isEmpty
            && plan.students.allSatisfy {
                isWellFormed($0) && $0.districtID == plan.districtID
            }
    }

    private static func hasValidTemplateBoundary(
        _ member: MembershipContext,
        template: TemplateAuthorizationScope
    ) -> Bool {
        guard isWellFormed(member),
              isWellFormedIdentifier(template.districtID),
              member.districtID == template.districtID else {
            return false
        }

        guard let schoolID = template.schoolID else {
            return true
        }

        guard isWellFormedIdentifier(schoolID) else {
            return false
        }

        return member.role == .districtAdministrator
            || member.schoolIDs.contains(schoolID)
    }

    private static func isAssignedStudentInMemberSchool(
        _ member: MembershipContext,
        student: StudentAuthorizationScope
    ) -> Bool {
        member.assignedStudentIDs.contains(student.studentID)
            && member.schoolIDs.contains(student.schoolID)
    }

    private static func isWellFormed(_ member: MembershipContext) -> Bool {
        member.isActive
            && member.version > 0
            && isWellFormedIdentifier(member.userID)
            && isWellFormedIdentifier(member.districtID)
            && member.schoolIDs.allSatisfy(isWellFormedIdentifier)
            && member.assignedStudentIDs.allSatisfy(isWellFormedIdentifier)
    }

    private static func isWellFormed(_ student: StudentAuthorizationScope) -> Bool {
        isWellFormedIdentifier(student.studentID)
            && isWellFormedIdentifier(student.districtID)
            && isWellFormedIdentifier(student.schoolID)
    }

    private static func isWellFormedIdentifier(_ value: String) -> Bool {
        !value.isEmpty
            && value == value.trimmingCharacters(in: .whitespacesAndNewlines)
            && value.utf8.count <= 1_500
            && !value.contains("/")
            && value != "."
            && value != ".."
            && value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
    }
}
