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

    @Test("Production denies a missing trusted membership without bootstrap access")
    func productionDeniedAccountAccess() {
        let flags = FeatureFlags.production

        let decision = flags.authenticatedAccountAccess(for: nil)

        #expect(decision.destination == .unavailable)
        #expect(decision.canBootstrap == false)
    }

    @Test("Production routes every trusted staff membership to the staff root")
    func productionStaffAccountAccess() {
        for role in StaffRole.allCases {
            let decision = FeatureFlags.production.authenticatedAccountAccess(
                for: membership(role: role)
            )

            #expect(decision.destination == .staff)
            #expect(decision.canBootstrap)
        }
    }

    @Test("An enabled independent student account routes to the student root with bootstrap access")
    func enabledStudentAccountAccess() {
        let flags = FeatureFlags(
            independentStudentAccounts: true,
            guardianAccounts: false,
            aiSuggestions: false,
            institutionalSSO: false
        )

        let decision = flags.registrationAccountAccess(for: .student)

        #expect(decision.destination == .student)
        #expect(decision.canBootstrap)
    }

    @Test("Enabled guardian accounts use a restricted guardian root without bootstrap access")
    func enabledGuardianAccountAccess() {
        let flags = FeatureFlags(
            independentStudentAccounts: false,
            guardianAccounts: true,
            aiSuggestions: false,
            institutionalSSO: false
        )

        let decisions = [
            flags.registrationAccountAccess(for: .parent),
            flags.registrationAccountAccess(for: .legalGuardian),
        ]

        for decision in decisions {
            #expect(decision.destination == .guardian)
            #expect(decision.destination != .staff)
            #expect(decision.destination != .student)
            #expect(decision.canBootstrap == false)
        }
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
    func simplifiedRegistrationAccountAccess() {
        for accountType in AccountType.allCases {
            let decision = FeatureFlags.production.registrationAccountAccess(for: accountType.userRole)

            #expect(decision.destination == .staff)
            #expect(decision.canBootstrap)
        }
    }

    private func membership(role: StaffRole) -> MembershipContext {
        MembershipContext(
            userID: "staff-1",
            districtID: "district-a",
            schoolIDs: ["school-a"],
            role: role,
            capabilities: [],
            assignedStudentIDs: [],
            isActive: true,
            version: 1
        )
    }
}
