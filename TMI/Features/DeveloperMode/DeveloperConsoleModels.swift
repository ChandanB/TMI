#if DEBUG
import Foundation

nonisolated struct DeveloperConsoleStatus: Codable, Sendable, Equatable {
    let isEnabled: Bool
    let isOperator: Bool
    let projectID: String
}

nonisolated struct DevSchool: Codable, Sendable, Equatable, Identifiable, Hashable {
    let schoolID: String
    let name: String
    let programType: ProgramType?

    var id: String { schoolID }
}

nonisolated struct DevTenant: Codable, Sendable, Equatable, Identifiable, Hashable {
    let districtID: String
    let name: String
    let organizationKind: OrganizationKind
    let programType: ProgramType
    let memberCount: Int
    let schools: [DevSchool]

    var id: String { districtID }

    func effectiveProgram(for school: DevSchool) -> ProgramType {
        ProgramType.resolve(site: school.programType, organization: programType)
    }
}

nonisolated enum DevInvitationStatus: String, Codable, Sendable, CaseIterable, Equatable {
    case active
    case consumed
    case expired
    case revoked

    var displayName: String { rawValue.capitalized }

    var canRevoke: Bool { self == .active || self == .expired }
    var canDelete: Bool { self == .revoked || self == .expired }
}

nonisolated struct DevInvitation: Codable, Sendable, Equatable, Identifiable, Hashable {
    let invitationID: String
    let districtID: String
    let role: StaffRole
    let schoolIDs: [String]
    let capabilities: [Capability]
    let label: String?
    let status: DevInvitationStatus
    let createdAt: String?
    let createdBy: String?
    let expiresAt: String?
    let consumedAt: String?
    let consumedByUserID: String?
    let revokedAt: String?

    var id: String { invitationID }
    var shortID: String { String(invitationID.prefix(8)) }
}

nonisolated struct DevMember: Codable, Sendable, Equatable, Identifiable, Hashable {
    let userID: String
    let email: String?
    let displayName: String?
    let role: StaffRole?
    let schoolIDs: [String]
    let capabilities: [Capability]
    let assignedStudentCount: Int
    let isActive: Bool
    let version: Int
    let claimDistrictID: String?

    var id: String { userID }
    var title: String { displayName ?? email ?? userID }
}

nonisolated struct DevCreatedInvitation: Codable, Sendable, Equatable {
    let invitationID: String
    let invitationCode: String
    let expiresAt: String
}

nonisolated struct DevInvitationDraft: Sendable, Equatable {
    var districtID: String
    var schoolIDs: [String]
    var role: StaffRole
    var capabilities: [Capability]
    var recipientEmail: String
    var expiresInDays: Int
    var label: String

    static func defaults(districtID: String, schoolIDs: [String]) -> DevInvitationDraft {
        DevInvitationDraft(
            districtID: districtID,
            schoolIDs: schoolIDs,
            role: .teacher,
            capabilities: DeveloperConsoleDefaults.capabilities(for: .teacher),
            recipientEmail: "",
            expiresInDays: 14,
            label: ""
        )
    }
}

nonisolated struct DevMembershipDraft: Sendable, Equatable {
    var districtID: String
    var userID: String?
    var email: String
    var role: StaffRole
    var schoolIDs: [String]
    var capabilities: [Capability]
    var isActive: Bool
}

/// Mirrors `defaultCapabilitiesByRole` in `functions/src/developerConsole.ts`.
nonisolated enum DeveloperConsoleDefaults {
    static func capabilities(for role: StaffRole) -> [Capability] {
        switch role {
        case .teacher, .counselor:
            [.studentReadDetail, .studentWriteDetail]
        case .socialWorker:
            [.studentReadDetail]
        case .schoolAdministrator:
            [.studentReadDetail, .studentWriteDetail, .staffManage, .reportExport]
        case .districtAdministrator:
            [
                .studentReadDetail, .studentWriteDetail, .studentRestrictedRead,
                .planApprove, .staffManage, .reportExport, .auditRead,
            ]
        }
    }
}

extension Capability {
    nonisolated var displayName: String {
        switch self {
        case .studentReadDetail: "Read student detail"
        case .studentWriteDetail: "Edit student detail"
        case .studentRestrictedRead: "Read restricted records"
        case .studentRestrictedWrite: "Write restricted records"
        case .planApprove: "Approve plans"
        case .staffManage: "Manage staff"
        case .reportExport: "Export reports"
        case .auditRead: "Read audit events"
        }
    }
}
#endif
