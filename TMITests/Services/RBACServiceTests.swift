import Foundation
import Testing
@testable import TMI

@Suite("Trusted authorization adapter")
struct RBACServiceTests {
    private let service = RBACService()

    @Test("Editable administrator request never expands a teacher membership")
    func editableProfileCannotEscalateTeacher() {
        let profile = TMIUser(
            userID: "teacher-1",
            displayName: "Taylor Teacher",
            email: "teacher@example.org",
            requestedRole: .administrator
        )
        let member = membership(role: .teacher, assignedStudentIDs: ["student-1"])
        let student = studentScope()

        #expect(profile.requestedRole == .administrator)
        #expect(FeatureFlags.production.authenticatedAccountAccess(for: member).destination == .staff)
        #expect(AppNavigationPolicy(membership: member).availableTabs == [.dashboard, .students, .plans])
        #expect(service.canReadStudent(member: member, student: student))
        #expect(!service.canViewDistrict(member: member))
    }

    @Test("Student deletion remains denied for every trusted staff role")
    func studentDeletionFailsClosed() {
        for role in StaffRole.allCases {
            let member = membership(
                role: role,
                capabilities: Set(Capability.allCases),
                assignedStudentIDs: ["student-1"]
            )

            #expect(!service.canDeleteStudent(member: member, student: studentScope()))
        }
    }

    @Test("Student creation is tenant and school scoped")
    func studentCreationUsesTrustedScope() {
        let teacher = membership(role: .teacher)
        let districtAdministrator = membership(
            role: .districtAdministrator,
            capabilities: [.studentWriteDetail]
        )

        #expect(service.canCreateStudent(member: teacher, school: schoolScope()))
        #expect(!service.canCreateStudent(member: teacher, school: schoolScope(districtID: "district-b")))
        #expect(!service.canCreateStudent(member: teacher, school: schoolScope(schoolID: "school-b")))
        #expect(service.canCreateStudent(member: districtAdministrator, school: schoolScope(schoolID: "school-b")))
    }

    @Test("Plan approval requires trusted capability and canonical student scope")
    func planApprovalUsesTrustedCapabilityAndTarget() {
        let plan = PlanAuthorizationScope(
            planID: "plan-1",
            districtID: "district-a",
            students: [studentScope()]
        )
        let teacher = membership(role: .teacher, assignedStudentIDs: ["student-1"])
        let counselor = membership(
            role: .counselor,
            capabilities: [.planApprove],
            assignedStudentIDs: ["student-1"]
        )

        #expect(!service.canApprovePlan(member: teacher, plan: plan))
        #expect(service.canApprovePlan(member: counselor, plan: plan))
        #expect(!service.canApprovePlan(
            member: counselor,
            plan: PlanAuthorizationScope(
                planID: "plan-1",
                districtID: "district-b",
                students: [studentScope(districtID: "district-b")]
            )
        ))
    }

    @Test("Form assignments and template writes stay inside trusted tenant scope")
    func formsAndTemplatesUseTypedScope() {
        let teacher = membership(role: .teacher, assignedStudentIDs: ["student-1"])
        let assignment = FormAssignmentAuthorizationScope(
            districtID: "district-a",
            schoolID: "school-a",
            students: [studentScope()]
        )

        #expect(service.canAssignForm(member: teacher, assignment: assignment))
        #expect(!service.canAssignForm(
            member: teacher,
            assignment: FormAssignmentAuthorizationScope(
                districtID: "district-b",
                schoolID: "school-a",
                students: [studentScope(districtID: "district-b")]
            )
        ))
        #expect(service.canWriteTemplate(member: teacher, template: templateScope()))
        #expect(!service.canWriteTemplate(
            member: teacher,
            template: templateScope(schoolID: "school-b")
        ))
    }

    @Test("Unsupported destructive legacy operations deny")
    func unsupportedOperationsDeny() {
        let administrator = membership(
            role: .districtAdministrator,
            capabilities: Set(Capability.allCases)
        )
        let plan = PlanAuthorizationScope(
            planID: "plan-1",
            districtID: "district-a",
            students: [studentScope()]
        )

        #expect(!service.canDeletePlan(member: administrator, plan: plan))
        #expect(!service.canDeleteAssignment(
            member: administrator,
            assignment: FormAssignmentAuthorizationScope(
                districtID: "district-a",
                schoolID: nil,
                students: []
            )
        ))
    }

    private func membership(
        role: StaffRole,
        capabilities: Set<Capability> = [],
        assignedStudentIDs: Set<String> = []
    ) -> MembershipContext {
        MembershipContext(
            userID: "staff-1",
            districtID: "district-a",
            schoolIDs: ["school-a"],
            role: role,
            capabilities: capabilities,
            assignedStudentIDs: assignedStudentIDs,
            isActive: true,
            version: 1
        )
    }

    private func studentScope(
        districtID: String = "district-a",
        schoolID: String = "school-a"
    ) -> StudentAuthorizationScope {
        StudentAuthorizationScope(
            studentID: "student-1",
            districtID: districtID,
            schoolID: schoolID
        )
    }

    private func schoolScope(
        districtID: String = "district-a",
        schoolID: String = "school-a"
    ) -> SchoolAuthorizationScope {
        SchoolAuthorizationScope(districtID: districtID, schoolID: schoolID)
    }

    private func templateScope(
        districtID: String = "district-a",
        schoolID: String? = "school-a"
    ) -> TemplateAuthorizationScope {
        TemplateAuthorizationScope(districtID: districtID, schoolID: schoolID)
    }
}
