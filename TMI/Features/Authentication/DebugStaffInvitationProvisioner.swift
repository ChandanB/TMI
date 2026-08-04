#if DEBUG
import Foundation

nonisolated enum DebugStaffInvitationError: Error, Equatable {
    case emailNotAllowed
}

@MainActor
final class DebugStaffInvitationProvisioner: StaffInvitationProvisioning {
    static let invitationAlias = "TMI-DEBUG-ACCESS-2026"
    static let allowedEmail = "tmi-debug@example.com"
    static let opaqueInvitationCode = "VE1JLURlYnVnLUNhbm9uaWNhbC1JbnZpdGUtMjAyNiE"

    private let delegate: any StaffInvitationProvisioning

    init(delegate: any StaffInvitationProvisioning) {
        self.delegate = delegate
    }

    func provision(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) async throws -> MembershipContext {
        guard request.invitationCode == Self.invitationAlias else {
            return try await delegate.provision(request: request, identity: identity)
        }

        let normalizedEmail = identity.email?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard normalizedEmail == Self.allowedEmail else {
            throw DebugStaffInvitationError.emailNotAllowed
        }

        let translatedRequest = StaffInvitationAcceptanceRequest(
            displayName: request.displayName,
            invitationCode: Self.opaqueInvitationCode,
            privacyPolicyVersion: request.privacyPolicyVersion,
            acceptableUsePolicyVersion: request.acceptableUsePolicyVersion
        )
        return try await delegate.provision(
            request: translatedRequest,
            identity: identity
        )
    }
}
#endif
