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

    func accountAccess(for role: UserRole?) -> AccountAccess {
        guard let role else {
            return AccountAccess(destination: .unavailable, canBootstrap: false)
        }

        switch role {
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
