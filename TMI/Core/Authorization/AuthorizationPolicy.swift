import Foundation

struct StudentAuthorizationScope: Codable, Sendable, Equatable {
    let studentID: String
    let districtID: String
    let schoolID: String
}

enum AuthorizationPolicy {
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

    private static func hasValidStudentBoundary(
        _ member: MembershipContext,
        student: StudentAuthorizationScope
    ) -> Bool {
        isWellFormed(member)
            && isWellFormed(student)
            && member.districtID == student.districtID
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
    }
}
