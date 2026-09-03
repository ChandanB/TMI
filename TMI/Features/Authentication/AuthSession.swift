import Foundation

nonisolated enum AppAccessState: Sendable, Equatable {
    case signedOut
    case emailVerificationRequired
    case membershipRequired
    case membershipInactive
    case authorized
}

nonisolated struct AuthIdentity: Sendable, Equatable {
    let userID: String
    let email: String?
    let isEmailVerified: Bool
    let districtID: String?

    init(
        userID: String,
        email: String? = nil,
        isEmailVerified: Bool,
        districtID: String? = nil
    ) {
        self.userID = userID
        self.email = email
        self.isEmailVerified = isEmailVerified
        self.districtID = districtID
    }
}

nonisolated enum AuthMembershipState: Sendable, Equatable {
    case missing
    case inactive
    case active(MembershipContext)
}

nonisolated struct AuthSession: Sendable, Equatable {
    let identity: AuthIdentity?
    let membershipState: AuthMembershipState

    init(
        identity: AuthIdentity?,
        membership: MembershipContext?
    ) {
        self.identity = identity
        if let membership {
            membershipState = membership.isActive ? .active(membership) : .inactive
        } else {
            membershipState = .missing
        }
    }

    init(
        identity: AuthIdentity?,
        membershipState: AuthMembershipState
    ) {
        self.identity = identity
        self.membershipState = membershipState
    }

    static let signedOut = AuthSession(identity: nil, membership: nil)

    var membership: MembershipContext? {
        guard case .active(let membership) = membershipState else {
            return nil
        }
        return membership
    }

    var access: AppAccessState {
        access(requiringEmailVerification: true)
    }

    func access(requiringEmailVerification: Bool) -> AppAccessState {
        guard let identity else {
            return .signedOut
        }
        guard !requiringEmailVerification || identity.isEmailVerified else {
            return .emailVerificationRequired
        }

        switch membershipState {
        case .missing:
            return .membershipRequired
        case .inactive:
            return .membershipInactive
        case .active(let membership):
            guard membership.isActive,
                  membership.version > 0,
                  membership.userID == identity.userID,
                  identity.districtID.map({ $0 == membership.districtID }) ?? true else {
                return .membershipRequired
            }
            return .authorized
        }
    }
}

nonisolated enum StaffPolicyVersions {
    static let privacyPolicyVersion = "2026-07-20"
    static let acceptableUsePolicyVersion = "2026-07-20"
}

nonisolated enum AuthenticationPresentationPolicy {
    static let signInFailureMessage =
        "We couldn't sign you in. Check your credentials and try again."
    static let registrationFailureMessage =
        "We couldn't create the account. Check the invitation and entered information, then try again."
    static let registrationRecoveryMessage =
        "Your account was created, but organization access is still being prepared. Continue setup to retry securely."
    static let passwordResetConfirmation =
        "If an account matches that email, a password reset link will be sent."

    static let registrationProvisioningUnavailableMessage =
        "This build cannot create staff accounts on its own. Ask your "
            + "administrator to provision the account, then sign in."

    static func registrationMessage(for error: Error) -> String {
        guard let repositoryError = error as? AuthenticationRepositoryError else {
            return registrationFailureMessage
        }
        switch repositoryError {
        case .invitationRequired:
            return "Enter the staff invitation code provided by your institution."
        case .provisioningUnavailable:
            return registrationProvisioningUnavailableMessage
        case .registrationRollbackFailed:
            return registrationFailureMessage
        }
    }
}
