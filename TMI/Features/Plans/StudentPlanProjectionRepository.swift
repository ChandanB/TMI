import Foundation

nonisolated enum StudentPlanProjectionRepositoryError: Error, Equatable, Sendable {
    case capabilityUnavailable
    case unavailable
}

/// Loads only the redacted value that Student Mode is allowed to render.
///
/// Raw plan records and child records stay inside the loader closure. This
/// repository does not expose an API that a Student Mode view can use to ask
/// for professional need, staff notes, approvals, revisions, or restricted
/// student records.
nonisolated struct StudentPlanProjectionRepository: Sendable {
    typealias Load = @MainActor @Sendable (StudentModeGrant) async throws
        -> [StudentPlanProjection]

    private let load: Load

    init(load: @escaping Load) {
        self.load = load
    }

    @MainActor
    func projections(grant: StudentModeGrant) async throws -> [StudentPlanProjection] {
        guard grant.scope.allowedOperations.contains(.readStudentVisiblePlan) else {
            throw StudentPlanProjectionRepositoryError.capabilityUnavailable
        }
        return try await load(grant)
    }
}

extension StudentPlanProjectionRepository {
    /// Bridges the canonical staff repositories while Student Mode is using
    /// the local supervised runtime. If a respondent identity is active, the
    /// Firestore rules deny the staff-only plan-root query and this loader
    /// fails closed. A respondent-safe backend projection is required before
    /// trusted-callable Student Mode can activate this route.
    @MainActor
    static func canonical(
        dependencies: AppDependencies,
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> StudentPlanProjectionRepository {
        StudentPlanProjectionRepository { grant in
            guard let plans = dependencies.planRepository,
                  let children = dependencies.planChildRepository else {
                throw StudentPlanProjectionRepositoryError.unavailable
            }
            let identity = grant.staffIdentity
            let claim = TrustedTenantClaim(
                userID: identity.userID,
                districtID: identity.districtID,
                accessClass: .staff,
                membershipVersion: identity.membershipVersion
            )
            let member: MembershipContext
            do {
                member = try await dependencies.membership.membership(for: claim)
            } catch {
                throw StudentPlanProjectionRepositoryError.unavailable
            }

            let records: [PlanRecord]
            do {
                records = try await plans.plans(member: member)
            } catch {
                throw StudentPlanProjectionRepositoryError.unavailable
            }

            var projections: [StudentPlanProjection] = []
            for plan in records where plan.districtID == grant.scope.districtID
                && plan.studentIDs.contains(grant.scope.studentID)
                && plan.status == .active
                && plan.approvalStatus == .approved {
                do {
                    let goals = try await children.goals(planID: plan.id, member: member)
                    let actions = try await children.actions(planID: plan.id, member: member)
                    let progress = try await children.progress(planID: plan.id, member: member)
                    if let projection = StudentPlanProjectionBuilder.projection(
                        plan: plan,
                        goals: goals,
                        actions: actions,
                        progress: progress,
                        now: now()
                    ) {
                        projections.append(projection)
                    }
                } catch {
                    // A partial plan can mislead a student. If any child
                    // record cannot be authorized and loaded, expose none.
                    throw StudentPlanProjectionRepositoryError.unavailable
                }
            }
            return projections.sorted { $0.planTitle < $1.planTitle }
        }
    }
}
