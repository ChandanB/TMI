struct FeatureFlags: Sendable, Equatable {
    let independentStudentAccounts: Bool
    let guardianAccounts: Bool
    let aiSuggestions: Bool
    let institutionalSSO: Bool

    static let production = FeatureFlags(
        independentStudentAccounts: false,
        guardianAccounts: false,
        aiSuggestions: false,
        institutionalSSO: false
    )
}

extension FeatureFlags {
    struct AccountAccess: Sendable, Equatable {
        enum Destination: Sendable, Equatable {
            case student
            case staff
            case guardian
            case unavailable
        }

        let destination: Destination
        let canBootstrap: Bool
    }

    func authenticatedAccountAccess(
        for membership: MembershipContext?
    ) -> AccountAccess {
        guard let membership,
              membership.isActive,
              membership.version > 0,
              TrustedIdentifier.isValid(membership.userID),
              TrustedIdentifier.isValid(membership.districtID) else {
            return AccountAccess(destination: .unavailable, canBootstrap: false)
        }

        return AccountAccess(destination: .staff, canBootstrap: true)
    }

    /// Registration availability only. `UserRole` is an untrusted account-type
    /// request and must never drive authenticated routing or data access.
    func registrationAccountAccess(for requestedRole: UserRole?) -> AccountAccess {
        guard let requestedRole else {
            return AccountAccess(destination: .unavailable, canBootstrap: false)
        }

        switch requestedRole {
        case .student:
            if independentStudentAccounts {
                return AccountAccess(destination: .student, canBootstrap: true)
            }
            return AccountAccess(destination: .unavailable, canBootstrap: false)
        case .parent, .legalGuardian:
            if guardianAccounts {
                return AccountAccess(destination: .guardian, canBootstrap: false)
            }
            return AccountAccess(destination: .unavailable, canBootstrap: false)
        case .teacher, .counselor, .administrator, .admin, .socialWorker,
                .superintendent, .districtAdmin:
            return AccountAccess(destination: .staff, canBootstrap: true)
        }
    }
}
