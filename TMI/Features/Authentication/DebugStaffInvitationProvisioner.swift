#if DEBUG
import Foundation

nonisolated enum DebugStaffInvitationError: Error, Equatable {
    case emailNotAllowed
}

@MainActor
final class DebugStaffInvitationProvisioner: StaffInvitationProvisioning {
    static let invitationAlias = "TMI-DEBUG-ACCESS-2026"
    static let allowedEmail = "tmi-debug@example.com"
    static let districtID = "district-debug"
    static let schoolID = "school-debug"

    private let delegate: any StaffInvitationProvisioning

    init(delegate: any StaffInvitationProvisioning) {
        self.delegate = delegate
    }

    func requiresTrustedClaimRefresh(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) -> Bool {
        !Self.isAllowed(request: request, identity: identity)
    }

    func provision(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) async throws -> MembershipContext {
        guard request.invitationCode == Self.invitationAlias else {
            return try await delegate.provision(request: request, identity: identity)
        }
        guard Self.isAllowed(identity: identity) else {
            throw DebugStaffInvitationError.emailNotAllowed
        }

        return Self.membership(for: identity)
    }

    static func isAllowed(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) -> Bool {
        request.invitationCode == invitationAlias && isAllowed(identity: identity)
    }

    static func isAllowed(identity: AuthIdentity) -> Bool {
        identity.email?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == allowedEmail
    }

    static func membership(for identity: AuthIdentity) -> MembershipContext {
        MembershipContext(
            userID: identity.userID,
            districtID: districtID,
            schoolIDs: [schoolID],
            role: .teacher,
            capabilities: [.studentReadDetail, .studentWriteDetail],
            assignedStudentIDs: [],
            isActive: true,
            version: 1
        )
    }

    static func session(for identity: AuthIdentity) -> AuthSession {
        AuthSession(
            identity: AuthIdentity(
                userID: identity.userID,
                email: identity.email,
                isEmailVerified: identity.isEmailVerified,
                districtID: districtID
            ),
            membership: membership(for: identity)
        )
    }
}

@MainActor
final class DebugAuthenticationSessionLoader: AuthenticationSessionLoading {
    private let delegate: any AuthenticationSessionLoading

    init(delegate: any AuthenticationSessionLoading) {
        self.delegate = delegate
    }

    func session(for identity: AuthIdentity) async throws -> AuthSession {
        guard DebugStaffInvitationProvisioner.isAllowed(identity: identity) else {
            return try await delegate.session(for: identity)
        }
        return DebugStaffInvitationProvisioner.session(for: identity)
    }
}
#endif
