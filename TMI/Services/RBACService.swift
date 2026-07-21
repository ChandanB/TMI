import Foundation

/// Temporary compatibility adapter over the canonical, pure authorization policy.
///
/// This type deliberately has no singleton and accepts only trusted membership
/// plus typed target scopes. Callers cannot authorize with an editable profile.
nonisolated struct RBACService: Sendable {
    func canCreateStudent(
        member: MembershipContext,
        school: SchoolAuthorizationScope
    ) -> Bool {
        AuthorizationPolicy.canCreateStudent(member, school: school)
    }

    func canReadStudent(
        member: MembershipContext,
        student: StudentAuthorizationScope
    ) -> Bool {
        AuthorizationPolicy.canReadStudentDetail(member, student: student)
    }

    func canWriteStudent(
        member: MembershipContext,
        student: StudentAuthorizationScope
    ) -> Bool {
        AuthorizationPolicy.canWriteStudentDetail(member, student: student)
    }

    func canDeleteStudent(
        member: MembershipContext,
        student: StudentAuthorizationScope
    ) -> Bool {
        AuthorizationPolicy.canDeleteStudent(member, student: student)
    }

    func canReadPlan(
        member: MembershipContext,
        plan: PlanAuthorizationScope
    ) -> Bool {
        AuthorizationPolicy.canReadPlan(member, plan: plan)
    }

    func canWritePlan(
        member: MembershipContext,
        plan: PlanAuthorizationScope
    ) -> Bool {
        AuthorizationPolicy.canWritePlan(member, plan: plan)
    }

    func canApprovePlan(
        member: MembershipContext,
        plan: PlanAuthorizationScope
    ) -> Bool {
        AuthorizationPolicy.canApprovePlan(member, plan: plan)
    }

    func canDeletePlan(
        member: MembershipContext,
        plan: PlanAuthorizationScope
    ) -> Bool {
        AuthorizationPolicy.canDeletePlan(member, plan: plan)
    }

    func canAssignForm(
        member: MembershipContext,
        assignment: FormAssignmentAuthorizationScope
    ) -> Bool {
        AuthorizationPolicy.canAssignForm(member, assignment: assignment)
    }

    func canDeleteAssignment(
        member: MembershipContext,
        assignment: FormAssignmentAuthorizationScope
    ) -> Bool {
        AuthorizationPolicy.canDeleteAssignment(member, assignment: assignment)
    }

    func canReadTemplate(
        member: MembershipContext,
        template: TemplateAuthorizationScope
    ) -> Bool {
        AuthorizationPolicy.canReadTemplate(member, template: template)
    }

    func canWriteTemplate(
        member: MembershipContext,
        template: TemplateAuthorizationScope
    ) -> Bool {
        AuthorizationPolicy.canWriteTemplate(member, template: template)
    }

    func canViewDistrict(member: MembershipContext) -> Bool {
        AuthorizationPolicy.canViewAggregate(member, districtID: member.districtID)
    }

    func require(_ isAllowed: @autoclosure () -> Bool) throws {
        guard isAllowed() else {
            throw RBACError.unauthorized
        }
    }
}

nonisolated enum RBACError: LocalizedError, Equatable {
    case unauthorized

    var errorDescription: String? {
        "You don’t have access to this record."
    }
}
