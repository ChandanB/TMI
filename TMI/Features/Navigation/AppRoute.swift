import Foundation

nonisolated enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case dashboard
    case students
    case plans
    case district

    var id: Self { self }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .students: "Students"
        case .plans: "TMI Plans"
        case .district: "District"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "chart.bar.fill"
        case .students: "person.3.fill"
        case .plans: "doc.text.fill"
        case .district: "building.2.fill"
        }
    }
}

nonisolated enum AppRoute: Hashable, Sendable {
    case student(String)
    case editStudent(String)
    case plan(String)
    case profile
    case settings

    var tab: AppTab? {
        switch self {
        case .student, .editStudent: .students
        case .plan: .plans
        case .profile, .settings: nil
        }
    }
}

nonisolated enum AppSheet: String, Identifiable, Sendable {
    case workspace

    var id: Self { self }
}

nonisolated enum NavigationError: Error, Equatable, Sendable {
    case unavailableTab
    case invalidIdentifier
    case missingStudentContext
    case staleStudentContext
    case unauthorizedRoute
    case unsupportedDeepLink
}

nonisolated struct AppNavigationPolicy: Equatable, Sendable {
    let role: StaffRole?
    let districtID: String?
    let membershipVersion: Int?
    let capabilities: Set<Capability>
    let authorizedStudentIDs: Set<String>
    let authorizedPlanIDs: Set<String>
    let trustedMembership: MembershipContext?

    init(
        role: StaffRole?,
        districtID: String? = nil,
        membershipVersion: Int? = nil,
        capabilities: Set<Capability> = [],
        authorizedStudentIDs: Set<String> = [],
        authorizedPlanIDs: Set<String> = []
    ) {
        self.init(
            role: role,
            districtID: districtID,
            membershipVersion: membershipVersion,
            capabilities: capabilities,
            authorizedStudentIDs: authorizedStudentIDs,
            authorizedPlanIDs: authorizedPlanIDs,
            trustedMembership: nil
        )
    }

    private init(
        role: StaffRole?,
        districtID: String?,
        membershipVersion: Int?,
        capabilities: Set<Capability>,
        authorizedStudentIDs: Set<String>,
        authorizedPlanIDs: Set<String>,
        trustedMembership: MembershipContext?
    ) {
        self.role = role
        self.districtID = districtID
        self.membershipVersion = membershipVersion
        self.capabilities = capabilities
        self.authorizedStudentIDs = Self.normalized(authorizedStudentIDs)
        self.authorizedPlanIDs = Self.normalized(authorizedPlanIDs)
        self.trustedMembership = trustedMembership
    }

    init(membership: MembershipContext?) {
        guard let membership,
              membership.isActive,
              membership.version > 0,
              TrustedIdentifier.isValid(membership.userID),
              TrustedIdentifier.isValid(membership.districtID),
              membership.schoolIDs.allSatisfy(TrustedIdentifier.isValid),
              membership.assignedStudentIDs.allSatisfy(TrustedIdentifier.isValid) else {
            self.init(role: nil)
            return
        }

        self.init(
            role: membership.role,
            districtID: membership.districtID,
            membershipVersion: membership.version,
            capabilities: membership.capabilities,
            authorizedStudentIDs: membership.assignedStudentIDs,
            authorizedPlanIDs: [],
            trustedMembership: membership
        )
    }

    var availableTabs: [AppTab] {
        switch role {
        case .districtAdministrator:
            [.dashboard, .students, .plans, .district]
        case .teacher, .counselor, .socialWorker, .schoolAdministrator:
            [.dashboard, .students, .plans]
        case nil:
            [.dashboard]
        }
    }

    func canReadStudent(_ studentID: String) -> Bool {
        authorizedStudentIDs.contains(studentID)
    }

    func canReadStudent(_ student: Student) -> Bool {
        guard let trustedMembership,
              let scope = StudentAuthorizationScope(student: student) else {
            return false
        }
        return AuthorizationPolicy.canReadStudentDetail(
            trustedMembership,
            student: scope
        )
    }

    func canReadStudent(_ record: StudentRecord) -> Bool {
        guard let trustedMembership,
              let scope = StudentAuthorizationScope(record: record) else {
            return false
        }
        return AuthorizationPolicy.canReadStudentDetail(
            trustedMembership,
            student: scope
        )
    }

    func canEditStudent(_ studentID: String) -> Bool {
        guard canReadStudent(studentID) else { return false }

        return switch role {
        case .teacher, .counselor:
            true
        case .schoolAdministrator, .districtAdministrator:
            capabilities.contains(.studentWriteDetail)
        case .socialWorker, nil:
            false
        }
    }

    func canEditStudent(_ student: Student) -> Bool {
        guard let trustedMembership,
              let scope = StudentAuthorizationScope(student: student) else {
            return false
        }
        return AuthorizationPolicy.canWriteStudentDetail(
            trustedMembership,
            student: scope
        )
    }

    func canEditStudent(_ record: StudentRecord) -> Bool {
        guard let trustedMembership,
              let scope = StudentAuthorizationScope(record: record) else {
            return false
        }
        return AuthorizationPolicy.canWriteStudentDetail(
            trustedMembership,
            student: scope
        )
    }

    func canReadPlan(_ planID: String) -> Bool {
        authorizedPlanIDs.contains(planID)
    }

    func canReadPlan(_ plan: TMIPlan) -> Bool {
        guard let trustedMembership,
              let scope = PlanAuthorizationScope(plan: plan) else {
            return false
        }
        return AuthorizationPolicy.canReadPlan(trustedMembership, plan: scope)
    }

    private static func normalized(_ identifiers: Set<String>) -> Set<String> {
        Set(identifiers.filter(TrustedIdentifier.isValid))
    }
}
