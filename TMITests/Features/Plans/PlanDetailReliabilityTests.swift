import Foundation
import Testing
@testable import TMI

@Suite("Plan detail reliability")
@MainActor
struct PlanDetailReliabilityTests {
    private func member(active: Bool = true, district: String = "d1", version: Int = 1,
                        userID: String = "owner", approve: Bool = false) -> MembershipContext {
        MembershipContext(userID: userID, districtID: district, schoolIDs: ["s1"],
                          role: .teacher,
                          capabilities: approve ? [.studentReadDetail, .planApprove] : [.studentReadDetail, .studentWriteDetail, .reportExport],
                          assignedStudentIDs: [], isActive: active, version: version)
    }

    @Test func failedSnapshotIsNotPublishedAndRetryRecovers() async {
        let children = ReliabilityChildren()
        children.failure = .unavailable
        let state = CanonicalPlanDetailState(planID: "p1", repository: ReliabilityPlans(), children: children)
        await state.load(member: member())
        guard case .failed = state.childrenPhase else { Issue.record("Expected explicit child failure"); return }
        #expect(state.goals.isEmpty)
        #expect(!state.canExport(member()))
        children.failure = nil
        await state.reloadChildren(member: member())
        #expect(state.childrenPhase == .loaded)
        #expect(state.goals.count == 1)
        #expect(state.canExport(member()))
    }

    @Test func missingChildrenCannotExport() async {
        let state = CanonicalPlanDetailState(planID: "p1", repository: ReliabilityPlans())
        await state.load(member: member())
        await state.export(kind: .professionalPlan, member: member())
        #expect(!state.canExport(member()))
        #expect(state.exportedPDF == nil)
    }

    @Test func changedMembershipClearsPrivateState() async {
        let state = CanonicalPlanDetailState(planID: "p1", repository: ReliabilityPlans(), children: ReliabilityChildren())
        await state.load(member: member())
        state.studentDisplayName = "Private name"
        #expect(!state.canExport(member(active: false)))
        #expect(!state.canExport(member(district: "d2")))
        #expect(!state.canExport(member(version: 2)))
        state.updateMembership(member(version: 2))
        #expect(state.plan == nil)
        #expect(state.goals.isEmpty)
        #expect(state.studentDisplayName == nil)
        #expect(state.exportedPDF == nil)
    }

    @Test func permissionDeniedClearsLoadedSnapshot() async {
        let children = ReliabilityChildren()
        let state = CanonicalPlanDetailState(planID: "p1", repository: ReliabilityPlans(), children: children)
        await state.load(member: member())
        children.failure = .permissionDenied
        await state.reloadChildren(member: member())
        #expect(state.phase == .permissionDenied)
        #expect(state.goals.isEmpty)
        #expect(state.revisions.isEmpty)
        #expect(!state.canExport(member()))
    }

    @Test func approvalAndActivationHaveSeparateAuthority() async {
        let plans = ReliabilityPlans()
        let state = CanonicalPlanDetailState(planID: "p1", repository: plans)
        await state.load(member: member())
        #expect(!state.availableTransitions(for: member()).contains(.active))
        plans.stored.status = .pendingApproval
        await state.load(member: member(approve: true))
        #expect(state.availableTransitions(for: member(approve: true)).contains(.approved))
        #expect(state.availableTransitions(for: member(approve: true)).contains(.changesRequested))
        #expect(!state.availableTransitions(for: member(approve: true)).contains(.active))
        plans.stored.status = .approved
        await state.load(member: member())
        #expect(state.availableTransitions(for: member()).contains(.active))
        await state.load(member: member(userID: "other"))
        #expect(!state.availableTransitions(for: member(userID: "other")).contains(.active))
    }
}

@MainActor
private final class ReliabilityPlans: PlanRecordRepository {
    var stored = PlanRecord(id: "p1", districtID: "d1", studentIDs: ["child"], schoolIDs: ["s1"],
                            assignedMemberIDs: ["owner"], status: .draft, model: .chaseYourSpace,
                            title: "Plan", summary: nil, startDate: .now, targetDate: nil,
                            approvalStatus: .notRequested,
                            metadata: CanonicalRecordMetadata(schemaVersion: 1, recordVersion: 1,
                                                              createdAt: .now, createdBy: "owner", updatedAt: .now, updatedBy: "owner"))
    func plans(member: MembershipContext) async throws -> [PlanRecord] { [stored] }
    func plan(id: String, member: MembershipContext) async throws -> PlanRecord { stored }
    func create(_ draft: PlanDraft, operationID: UUID, member: MembershipContext) async throws -> PlanRecord { stored }
    func update(id: String, draft: PlanDraft, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord { stored }
    func transition(id: String, to status: PlanRecordStatus, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord {
        stored.status = status
        return stored
    }
}

@MainActor
private final class ReliabilityChildren: PlanChildRepositoryProtocol {
    var failure: PlanRecordRepositoryError?
    func goals(planID: String, member: MembershipContext) async throws -> [GoalRecord] {
        [GoalRecord(id: "g1", planID: planID, studentID: "child", title: "Goal", studentFacingTitle: nil,
                    measure: .count, baseline: "0", target: "1", dueDate: .now,
                    responsibleMemberID: "owner", status: .inProgress)]
    }
    func actions(planID: String, member: MembershipContext) async throws -> [ActionRecord] { [] }
    func progress(planID: String, member: MembershipContext) async throws -> [ProgressRecord] { [] }
    func revisions(planID: String, member: MembershipContext) async throws -> [PlanRevision] {
        if let failure { throw failure }
        return []
    }
    func save(goal: GoalRecord, member: MembershipContext) async throws {}
    func save(action: ActionRecord, member: MembershipContext) async throws {}
    func append(progress: ProgressRecord, member: MembershipContext) async throws {}
    func freeze(revision: PlanRevision, member: MembershipContext) async throws {}
}
