import Foundation
import Testing
@testable import TMI

@Suite("App Router")
@MainActor
struct AppRouterTests {
    @Test("District navigation is available only to district administrators")
    func districtTabRequiresDistrictRole() {
        let teacher = AppRouter(policy: policy(role: .teacher))
        let districtAdministrator = AppRouter(
            policy: policy(role: .districtAdministrator)
        )

        #expect(teacher.availableTabs == [.dashboard, .students, .plans])
        #expect(
            districtAdministrator.availableTabs
                == [.dashboard, .students, .plans, .district]
        )
    }

    @Test("A role change leaves an unavailable district tab")
    func policyRefreshSelectsAnAvailableTab() throws {
        let router = AppRouter(
            policy: policy(
                role: .districtAdministrator,
                studentIDs: ["student-a"]
            )
        )
        try router.select(.district)
        router.setActiveStudent(id: "student-a", displayName: "Ava Stone")
        try router.present(.workspace)

        router.updatePolicy(policy(role: .teacher))

        #expect(router.selectedTab == .dashboard)
        #expect(router.path.isEmpty)
        #expect(router.presentedSheet == nil)
    }

    @Test("A trusted tenant or membership-version change clears sensitive state")
    func trustedBoundaryRefreshClearsSensitiveState() throws {
        let router = AppRouter(
            policy: AppNavigationPolicy(
                role: .teacher,
                districtID: "district-a",
                membershipVersion: 1,
                authorizedStudentIDs: ["student-a"]
            )
        )
        router.setActiveStudent(id: "student-a", displayName: "Ava Stone")
        try router.open(.student("student-a"))

        router.updatePolicy(
            AppNavigationPolicy(
                role: .teacher,
                districtID: "district-b",
                membershipVersion: 2,
                authorizedStudentIDs: ["student-a"]
            )
        )

        #expect(router.path.isEmpty)
        #expect(router.activeStudentID == nil)
        #expect(router.activeStudentName == nil)
    }

    @Test("A mutation cannot target a stale student context")
    func staleStudentContextBlocksMutationRoute() throws {
        let router = AppRouter(
            policy: policy(role: .teacher, studentIDs: ["student-a", "student-b"])
        )
        router.setActiveStudent(id: "student-a", displayName: "Ava Stone")

        #expect(throws: NavigationError.staleStudentContext) {
            try router.open(.editStudent("student-b"))
        }
        #expect(router.path.isEmpty)
        #expect(router.activeStudentName == "Ava Stone")
    }

    @Test("The active student's name remains visible on a valid mutation route")
    func activeStudentMutationOpens() throws {
        let router = AppRouter(
            policy: policy(role: .teacher, studentIDs: ["student-a"])
        )
        router.setActiveStudent(id: "student-a", displayName: "Ava Stone")

        try router.open(.editStudent("student-a"))

        #expect(router.selectedTab == .students)
        #expect(router.path == [.editStudent("student-a")])
        #expect(router.activeStudentName == "Ava Stone")
    }

    @Test("Student deep links are denied outside assigned scope")
    func deepLinkRequiresAuthorizedStudent() throws {
        let router = AppRouter(
            policy: policy(role: .teacher, studentIDs: ["student-a"])
        )

        #expect(throws: NavigationError.unauthorizedRoute) {
            try router.openDeepLink(
                URL(string: "tmi://student/student-b")!
            )
        }
        #expect(router.path.isEmpty)

        try router.openDeepLink(URL(string: "tmi://student/student-a")!)
        #expect(router.selectedTab == .students)
        #expect(router.path == [.student("student-a")])
        #expect(router.activeStudentID == "student-a")
    }

    @Test("Unsupported deep links fail closed")
    func unsupportedDeepLinkFailsClosed() {
        let router = AppRouter(policy: policy(role: .teacher))

        #expect(throws: NavigationError.unsupportedDeepLink) {
            try router.openDeepLink(URL(string: "https://example.com/student-a")!)
        }
        #expect(router.path.isEmpty)
    }

    @Test("A cold-launch deep link waits for a verified navigation policy")
    func coldLaunchDeepLinkResumesAfterPolicyLoad() throws {
        let router = AppRouter()
        try router.enqueueDeepLink(URL(string: "tmi://student/student-a")!)

        #expect(router.pendingDeepLink == .student("student-a"))
        #expect(router.path.isEmpty)

        router.updatePolicy(
            policy(role: .teacher, studentIDs: ["student-a"])
        )
        try router.resumePendingDeepLink()

        #expect(router.pendingDeepLink == nil)
        #expect(router.path == [.student("student-a")])
    }

    @Test("Malformed trusted identifiers never become authorized routes")
    func malformedIdentifiersFailClosed() {
        let router = AppRouter(
            policy: policy(
                role: .teacher,
                studentIDs: [" student-a ", "student/a"]
            )
        )

        #expect(throws: NavigationError.unauthorizedRoute) {
            try router.open(.student("student-a"))
        }
        #expect(throws: NavigationError.invalidIdentifier) {
            try router.open(.student("student/a"))
        }
        #expect(router.path.isEmpty)
    }

    @Test("Deep links do not repair malformed path identifiers")
    func malformedDeepLinkIdentifierFailsClosed() {
        let url = URL(string: "tmi://student/%20student-a%20")!

        #expect(DeepLinkRouter.route(for: url) == nil)
    }

    @Test("Plan deep links stay disabled until trusted plan scope is available")
    func planDeepLinkIsNotAdvertisedWithoutTrustedScope() {
        let url = URL(string: "tmi://plan/plan-a")!

        #expect(DeepLinkRouter.route(for: url) == nil)
    }

    @Test("A visible plan opens only after canonical scope authorization")
    func visiblePlanUsesTrustedScope() throws {
        let member = MembershipContext(
            userID: "teacher-a",
            districtID: "district-a",
            schoolIDs: ["school-a"],
            role: .teacher,
            capabilities: [],
            assignedStudentIDs: ["student-a"],
            isActive: true,
            version: 1
        )
        let router = AppRouter(policy: AppNavigationPolicy(membership: member))
        let authorizedPlan = plan(districtID: "district-a")

        try router.open(authorizedPlan)

        #expect(router.selectedTab == .plans)
        #expect(router.path == [.plan("plan-a")])
        #expect(router.activePlanID == "plan-a")
        #expect(router.activePlan?.id == "plan-a")

        let otherDistrictPlan = plan(districtID: "district-b")
        #expect(throws: NavigationError.unauthorizedRoute) {
            try router.open(otherDistrictPlan)
        }
    }

    @Test("A visible student uses canonical administrator scope")
    func visibleStudentUsesTrustedAdministratorScope() throws {
        let member = MembershipContext(
            userID: "administrator-a",
            districtID: "district-a",
            schoolIDs: ["school-a"],
            role: .schoolAdministrator,
            capabilities: [.studentReadDetail, .studentWriteDetail],
            assignedStudentIDs: [],
            isActive: true,
            version: 1
        )
        let router = AppRouter(policy: AppNavigationPolicy(membership: member))
        let authorizedStudent = student(
            id: "student-a",
            districtID: "district-a",
            schoolID: "school-a"
        )

        try router.open(authorizedStudent)

        #expect(router.selectedTab == .students)
        #expect(router.path == [.student("student-a")])
        #expect(router.activeStudent == authorizedStudent)

        let otherSchoolStudent = student(
            id: "student-b",
            districtID: "district-a",
            schoolID: "school-b"
        )
        #expect(throws: NavigationError.unauthorizedRoute) {
            try router.open(otherSchoolStudent)
        }
    }

    @Test("A canonical roster record uses trusted administrator scope")
    func canonicalRecordUsesTrustedAdministratorScope() throws {
        let member = MembershipContext(
            userID: "administrator-a",
            districtID: "district-a",
            schoolIDs: ["school-a"],
            role: .schoolAdministrator,
            capabilities: [.studentReadDetail, .studentWriteDetail],
            assignedStudentIDs: [],
            isActive: true,
            version: 1
        )
        let router = AppRouter(policy: AppNavigationPolicy(membership: member))
        let authorized = studentRecord(
            id: "student-a",
            districtID: "district-a",
            schoolID: "school-a"
        )

        try router.open(authorized)

        #expect(router.path == [.student("student-a")])
        #expect(router.activeStudentRecord == authorized)
        #expect(router.activeStudent == nil)

        let otherSchool = studentRecord(
            id: "student-b",
            districtID: "district-a",
            schoolID: "school-b"
        )
        #expect(throws: NavigationError.unauthorizedRoute) {
            try router.open(otherSchool)
        }
    }

    @Test("Signing out clears route and student context")
    func resetClearsSensitiveNavigationState() throws {
        let router = AppRouter(
            policy: policy(role: .teacher, studentIDs: ["student-a"])
        )
        router.setActiveStudent(id: "student-a", displayName: "Ava Stone")
        try router.open(.student("student-a"))

        router.reset()

        #expect(router.selectedTab == .dashboard)
        #expect(router.path.isEmpty)
        #expect(router.activeStudentID == nil)
        #expect(router.activeStudentName == nil)
    }

    @Test("Router-owned sheets clear with sensitive navigation state")
    func resetClearsPresentedSheet() throws {
        let router = AppRouter(
            policy: policy(role: .teacher, studentIDs: ["student-a"])
        )
        router.setActiveStudent(id: "student-a", displayName: "Ava Stone")
        try router.present(.workspace)

        #expect(router.presentedSheet == .workspace)

        router.reset()

        #expect(router.presentedSheet == nil)
    }

    @Test("The adaptive shell has one navigation owner on every platform")
    func adaptiveShellSourceContract() throws {
        let mainTabSource = try sourceFile(at: "TMI/Views/MainTabView.swift")
        let appSource = try sourceFile(at: "TMI/App/TMIApp.swift")
        let contextSource = try sourceFile(
            at: "TMI/StateModels/StudentContextStateModel.swift"
        )

        #expect(mainTabSource.contains("@Environment(AppRouter.self)"))
        #expect(mainTabSource.contains(".tabViewStyle(.sidebarAdaptable)"))
        #expect(mainTabSource.contains("NavigationSplitView"))
        #expect(mainTabSource.contains("router.open(.profile)"))
        #expect(mainTabSource.contains("router.open(.settings)"))
        #expect(!mainTabSource.contains("NavigationLink(destination: StudentDetailView"))
        #expect(!mainTabSource.contains("@State private var dashboardPath"))
        #expect(!mainTabSource.contains("@State private var studentsPath"))
        #expect(!mainTabSource.contains("@State private var plansPath"))

        #expect(appSource.contains("@State private var appRouter: AppRouter"))
        #expect(appSource.contains(".environment(appRouter)"))
        #expect(appSource.contains("try appRouter.enqueueDeepLink(url)"))
        #expect(!appSource.contains("@State private var deepLinkRouter"))

        #expect(!contextSource.contains("pendingDeepLink"))
        #expect(!contextSource.contains("DeepLinkDestination"))

        let studentListSource = try sourceFile(
            at: "TMI/Views/Students/StudentListView.swift"
        )
        let studentDetailSource = try sourceFile(
            at: "TMI/Views/Students/StudentDetailView.swift"
        )
        let quickActionsSource = try sourceFile(
            at: "TMI/Views/Dashboard/Components/QuickActionCards.swift"
        )
        let planApprovalSource = try sourceFile(
            at: "TMI/Services/PlanApprovalService.swift"
        )
        let notificationSource = try sourceFile(
            at: "TMI/Services/NotificationService.swift"
        )
        let interestDetailSource = try sourceFile(
            at: "TMI/Views/InterestsAndHobbies/InterestDetailView.swift"
        )
        #expect(studentListSource.contains("router.open(record)"))
        #expect(!studentListSource.contains("NavigationLink(destination: StudentDetailView"))
        #expect(!studentListSource.contains("label: {\n                        studentRow(student)"))
        #expect(studentDetailSource.contains("StudentDetailState("))
        #expect(studentDetailSource.contains("StudentEditorView("))
        #expect(!studentDetailSource.contains("StudentDetailStateModel"))
        #expect(mainTabSource.contains("StudentDetailView(studentID: studentID)"))
        #expect(mainTabSource.contains("CanonicalStudentEditRoute(record: record)"))
        #expect(quickActionsSource.contains("router.select(.students)"))
        #expect(quickActionsSource.contains("router.select(.plans)"))
        #expect(!quickActionsSource.contains(".navigationDestination("))
        #expect(!quickActionsSource.contains("NavigationLink(destination: StudentDetailView"))
        #expect(mainTabSource.contains("@SceneStorage(\"tmi.staff.selectedTab\")"))
        #expect(mainTabSource.contains("if contextMatchesRouter {\n                    HStack(spacing:"))
        #expect(!planApprovalSource.contains("tmi://plans/"))
        #expect(!notificationSource.contains("tmi://plans/"))
        // The legacy plan detail view that this guarded is retired.
        #expect(!interestDetailSource.contains("StudentDetailView(studentId:"))
    }

    private func policy(
        role: StaffRole,
        studentIDs: Set<String> = []
    ) -> AppNavigationPolicy {
        AppNavigationPolicy(
            role: role,
            authorizedStudentIDs: studentIDs,
            authorizedPlanIDs: []
        )
    }

    private func sourceFile(at relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryRoot.appending(path: relativePath),
            encoding: .utf8
        )
    }

    private func plan(districtID: String) -> TMIPlan {
        let student = student(
            id: "student-a",
            districtID: districtID,
            schoolID: "school-a"
        )

        var plan = TMIPlan.samplePlan
        plan.id = "plan-a"
        plan.districtId = districtID
        plan.students = [student]
        return plan
    }

    private func student(
        id: String,
        districtID: String,
        schoolID: String
    ) -> Student {
        var student = Student.sampleStudent
        student.id = id
        student.districtId = districtID
        student.schoolId = schoolID
        return student
    }

    private func studentRecord(
        id: String,
        districtID: String,
        schoolID: String
    ) -> StudentRecord {
        StudentRecord(
            id: id,
            districtID: districtID,
            schoolID: schoolID,
            displayName: "Ava Stone",
            grade: "7",
            studentIdentifier: "S-001",
            dateOfBirth: nil,
            pronouns: nil,
            assignedMemberIDs: [],
            isArchived: false,
            metadata: CanonicalRecordMetadata(
                schemaVersion: 1,
                recordVersion: 1,
                createdAt: Date(timeIntervalSince1970: 1),
                createdBy: "administrator-a",
                updatedAt: Date(timeIntervalSince1970: 1),
                updatedBy: "administrator-a"
            )
        )
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
