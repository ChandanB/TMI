import Foundation
import Testing
@testable import TMI

@Suite("Canonical plan list")
@MainActor
struct CanonicalPlanListStateTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    @Test("List metadata comes from canonical students and actions")
    func canonicalMetadata() async {
        let owned = plan(
            id: "owned",
            status: .active,
            model: .chaseYourSpace,
            ownerID: member.userID,
            targetDate: now.addingTimeInterval(-86_400)
        )
        let state = CanonicalPlanListState(
            repository: PlanListPlanRepository(plans: [owned]),
            studentRepository: PlanListStudentRepository(records: ["student-1": student()]),
            children: PlanListChildRepository(actionsByPlan: [
                "owned": [
                    action(id: "done", status: .done, dueDate: now.addingTimeInterval(-172_800)),
                    action(id: "open", status: .open, dueDate: now.addingTimeInterval(-86_400)),
                ]
            ]),
            now: { now }
        )

        await state.load(member: member)

        let item = try? #require(state.visibleItems.first)
        #expect(item?.studentDisplayNames == ["Avery Rivera"])
        #expect(item?.progress == .percentage(50))
        #expect(item?.relationships == [.owned])
        #expect(item?.attentionReasons.contains(.overdueAction) == true)
        #expect(item?.attentionReasons.contains(.pastTargetDate) == true)
        #expect(item?.nextReviewDate == nil)
    }

    @Test("Missing child evidence never becomes a fabricated completion number")
    func missingProgressEvidence() async {
        let state = CanonicalPlanListState(
            repository: PlanListPlanRepository(plans: [plan(id: "plan")]),
            studentRepository: PlanListStudentRepository(records: ["student-1": student()]),
            children: nil,
            now: { now }
        )

        await state.load(member: member)

        #expect(state.visibleItems.first?.progress == .unavailable)
        #expect(state.visibleItems.first?.nextReviewDate == nil)
    }

    @Test("Search and canonical filters compose")
    func filtersCompose() async {
        let owned = plan(id: "owned", status: .active, model: .chaseYourSpace, ownerID: member.userID)
        let approval = plan(
            id: "approval",
            status: .pendingApproval,
            model: .alignYourMind,
            ownerID: "other-owner",
            assignedMemberIDs: ["other-owner"],
            approverMemberIDs: [member.userID]
        )
        let state = CanonicalPlanListState(
            repository: PlanListPlanRepository(plans: [owned, approval]),
            studentRepository: PlanListStudentRepository(records: ["student-1": student()]),
            children: PlanListChildRepository(actionsByPlan: [:]),
            now: { now }
        )
        await state.load(member: member)
        state.showOpenOnly = false

        state.searchText = "avery"
        #expect(Set(state.visibleItems.map(\.id)) == ["owned", "approval"])

        state.statusFilter = .pendingApproval
        #expect(state.visibleItems.map(\.id) == ["approval"])

        state.modelFilter = .alignYourMind
        state.studentFilter = "student-1"
        state.ownerFilter = "other-owner"
        state.schoolFilter = "school-1"
        state.relationshipFilter = .approvalAssigned
        state.attentionFilter = .needsApproval
        #expect(state.visibleItems.map(\.id) == ["approval"])

        state.searchText = "needs approval"
        #expect(state.visibleItems.map(\.id) == ["approval"])

        state.schoolFilter = "school-2"
        #expect(state.visibleItems.isEmpty)
    }

    @Test("Approval relationship requires authoritative assignment")
    func approvalRelationship() async {
        let approval = plan(
            id: "approval",
            status: .pendingApproval,
            ownerID: "other-owner",
            assignedMemberIDs: ["other-owner"],
            approverMemberIDs: [member.userID]
        )
        let unrelated = plan(
            id: "unrelated",
            status: .pendingApproval,
            ownerID: "other-owner",
            assignedMemberIDs: ["other-owner"],
            approverMemberIDs: ["different-approver"]
        )
        let state = CanonicalPlanListState(
            repository: PlanListPlanRepository(plans: [approval, unrelated]),
            children: PlanListChildRepository(actionsByPlan: [:]),
            now: { now }
        )

        await state.load(member: member)

        let item = state.visibleItems.first
        #expect(item?.relationships.contains(.approvalAssigned) == true)
        #expect(item?.relationships.contains(.owned) == false)
        #expect(item?.attentionReasons.contains(.needsApproval) == true)
        #expect(state.visibleItems.map(\.id) == ["approval"])
    }

    @Test("Creator provenance does not make a member the plan owner")
    func creatorIsNotOwner() async {
        let record = plan(
            id: "collaboration",
            ownerID: "other-owner",
            assignedMemberIDs: [member.userID, "other-owner"],
            createdBy: member.userID
        )
        let state = CanonicalPlanListState(
            repository: PlanListPlanRepository(plans: [record]),
            children: PlanListChildRepository(actionsByPlan: [:]),
            now: { now }
        )

        await state.load(member: member)

        let item = state.visibleItems.first
        #expect(item?.ownerMemberID == "other-owner")
        #expect(item?.relationships == [.collaborative])
    }

    private var member: MembershipContext {
        MembershipContext(
            userID: "member-1",
            districtID: "district-1",
            schoolIDs: ["school-1"],
            role: .schoolAdministrator,
            capabilities: [.studentReadDetail, .studentWriteDetail, .planApprove],
            assignedStudentIDs: ["student-1"],
            isActive: true,
            version: 1
        )
    }

    private func student() -> StudentRecord {
        StudentRecord(
            id: "student-1",
            districtID: "district-1",
            schoolID: "school-1",
            displayName: "Avery Rivera",
            grade: "8",
            studentIdentifier: nil,
            dateOfBirth: nil,
            pronouns: nil,
            assignedMemberIDs: ["member-1"],
            isArchived: false,
            metadata: metadata(createdBy: "member-1")
        )
    }

    private func plan(
        id: String,
        status: PlanRecordStatus = .active,
        model: TMIPlanModel = .chaseYourSpace,
        ownerID: String = "member-1",
        assignedMemberIDs: Set<String> = ["member-1"],
        approverMemberIDs: Set<String> = [],
        targetDate: Date? = nil,
        createdBy: String? = nil
    ) -> PlanRecord {
        PlanRecord(
            id: id,
            districtID: "district-1",
            studentIDs: ["student-1"],
            schoolIDs: ["school-1"],
            assignedMemberIDs: assignedMemberIDs,
            ownerMemberID: ownerID,
            approverMemberIDs: approverMemberIDs,
            status: status,
            model: model,
            title: id == "approval" ? "Build confidence" : "Creative momentum",
            summary: "Student-centered plan",
            startDate: now.addingTimeInterval(-604_800),
            targetDate: targetDate,
            approvalStatus: status == .pendingApproval ? .pending : .approved,
            metadata: metadata(createdBy: createdBy ?? ownerID)
        )
    }

    private func action(id: String, status: ActionStatus, dueDate: Date) -> ActionRecord {
        ActionRecord(
            id: id,
            planID: "owned",
            goalID: "goal-1",
            title: "Check in",
            ownerMemberID: "member-1",
            audience: .staff,
            cadence: .weekly,
            dueDate: dueDate,
            status: status
        )
    }

    private func metadata(createdBy: String) -> CanonicalRecordMetadata {
        CanonicalRecordMetadata(
            schemaVersion: 1,
            recordVersion: 1,
            createdAt: now.addingTimeInterval(-604_800),
            createdBy: createdBy,
            updatedAt: now,
            updatedBy: createdBy
        )
    }
}

@MainActor
private final class PlanListPlanRepository: PlanRecordRepository {
    private let stored: [PlanRecord]

    init(plans: [PlanRecord]) { stored = plans }

    func plans(member: MembershipContext) async throws -> [PlanRecord] { stored }
    func plan(id: String, member: MembershipContext) async throws -> PlanRecord {
        guard let record = stored.first(where: { $0.id == id }) else {
            throw PlanRecordRepositoryError.notFound
        }
        return record
    }
    func create(_ draft: PlanDraft, operationID: UUID, member: MembershipContext) async throws -> PlanRecord { stored[0] }
    func update(id: String, draft: PlanDraft, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord { stored[0] }
    func transition(id: String, to status: PlanRecordStatus, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord { stored[0] }
}

private struct PlanListStudentRepository: StudentRepository {
    let records: [String: StudentRecord]

    func page(_ request: StudentPageRequest, member: MembershipContext) async throws -> StudentPage {
        StudentPage(records: Array(records.values), nextCursor: nil, source: .server)
    }
    func student(id: String, member: MembershipContext) async throws -> StudentRecord {
        guard let record = records[id] else { throw StudentRepositoryError.notFound }
        return record
    }
    func create(_ draft: StudentDraft, operationID: UUID, member: MembershipContext) async throws -> StudentRecord { throw StudentRepositoryError.invalidDraft }
    func reconcilePendingCreates(member: MembershipContext) async throws -> [StudentRecord] { [] }
    func update(id: String, draft: StudentDraft, expectedVersion: Int, operationID: UUID, member: MembershipContext) async throws -> StudentRecord { throw StudentRepositoryError.invalidDraft }
    func archive(id: String, expectedVersion: Int, operationID: UUID, member: MembershipContext) async throws {}
}

@MainActor
private final class PlanListChildRepository: PlanChildRepositoryProtocol {
    let actionsByPlan: [String: [ActionRecord]]

    init(actionsByPlan: [String: [ActionRecord]]) { self.actionsByPlan = actionsByPlan }

    func goals(planID: String, member: MembershipContext) async throws -> [GoalRecord] { [] }
    func actions(planID: String, member: MembershipContext) async throws -> [ActionRecord] { actionsByPlan[planID] ?? [] }
    func progress(planID: String, member: MembershipContext) async throws -> [ProgressRecord] { [] }
    func revisions(planID: String, member: MembershipContext) async throws -> [PlanRevision] { [] }
    func save(goal: GoalRecord, member: MembershipContext) async throws {}
    func save(action: ActionRecord, member: MembershipContext) async throws {}
    func append(progress: ProgressRecord, member: MembershipContext) async throws {}
    func freeze(revision: PlanRevision, member: MembershipContext) async throws {}
}
