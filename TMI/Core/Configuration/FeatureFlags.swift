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
    enum AccountRoute: Sendable, Equatable {
        case student
        case staff
        case unavailable
    }

    func accountRoute(for role: UserRole?) -> AccountRoute {
        guard let role else {
            return .unavailable
        }

        switch role {
        case .student:
            return independentStudentAccounts ? .student : .unavailable
        case .parent, .legalGuardian:
            return guardianAccounts ? .staff : .unavailable
        case .teacher, .counselor, .administrator, .admin, .socialWorker,
                .superintendent, .districtAdmin:
            return .staff
        }
    }
}
