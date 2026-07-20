import Testing
@testable import TMI

@Suite("Feature Flags")
struct FeatureFlagsTests {
    @Test("Production disables every optional capability")
    func productionDefaults() {
        let flags = FeatureFlags.production

        #expect(flags.independentStudentAccounts == false)
        #expect(flags.guardianAccounts == false)
        #expect(flags.aiSuggestions == false)
        #expect(flags.institutionalSSO == false)
    }

    @Test("Production denies unsupported and missing account roles")
    func productionDeniedAccountRoutes() {
        let flags = FeatureFlags.production

        #expect(flags.accountRoute(for: .student) == .unavailable)
        #expect(flags.accountRoute(for: .parent) == .unavailable)
        #expect(flags.accountRoute(for: .legalGuardian) == .unavailable)
        #expect(flags.accountRoute(for: nil) == .unavailable)
    }

    @Test("Production routes supported staff roles to the staff root")
    func productionStaffAccountRoutes() {
        let staffRoles: [UserRole] = [
            .teacher,
            .counselor,
            .administrator,
            .admin,
            .socialWorker,
            .superintendent,
            .districtAdmin,
        ]

        for role in staffRoles {
            #expect(FeatureFlags.production.accountRoute(for: role) == .staff)
        }
    }

    @Test("An enabled independent student account routes to the student root")
    func enabledStudentAccountRoute() {
        let flags = FeatureFlags(
            independentStudentAccounts: true,
            guardianAccounts: false,
            aiSuggestions: false,
            institutionalSSO: false
        )

        #expect(flags.accountRoute(for: .student) == .student)
    }

    @Test("Enabled guardian accounts route to the existing nonstudent root")
    func enabledGuardianAccountRoutes() {
        let flags = FeatureFlags(
            independentStudentAccounts: false,
            guardianAccounts: true,
            aiSuggestions: false,
            institutionalSSO: false
        )

        #expect(flags.accountRoute(for: .parent) == .staff)
        #expect(flags.accountRoute(for: .legalGuardian) == .staff)
    }

    @Test("Production exposes only the staff role category")
    func productionRoleCategories() {
        #expect(
            SimplifiedRoleCategory.availableCategories(for: .production) == [.staff]
        )
    }

    @Test("Student and guardian role categories are independently gated")
    func independentlyGatedRoleCategories() {
        let studentFlags = FeatureFlags(
            independentStudentAccounts: true,
            guardianAccounts: false,
            aiSuggestions: false,
            institutionalSSO: false
        )
        let guardianFlags = FeatureFlags(
            independentStudentAccounts: false,
            guardianAccounts: true,
            aiSuggestions: false,
            institutionalSSO: false
        )

        #expect(
            SimplifiedRoleCategory.availableCategories(for: studentFlags) == [.student, .staff]
        )
        #expect(
            SimplifiedRoleCategory.availableCategories(for: guardianFlags) == [.staff, .parentGuardian]
        )
    }

    @Test("Every simplified registration account type remains a staff account")
    func simplifiedRegistrationAccountRoutes() {
        for accountType in AccountType.allCases {
            #expect(
                FeatureFlags.production.accountRoute(for: accountType.userRole) == .staff
            )
        }
    }
}
