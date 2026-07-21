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
        guard let identity else {
            return .signedOut
        }
        guard identity.isEmailVerified else {
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
