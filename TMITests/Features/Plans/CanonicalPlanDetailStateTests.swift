import Foundation
import Testing
@testable import TMI

@Suite("Plan detail authority")
@MainActor
struct CanonicalPlanDetailStateTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test("Putting a plan into effect needs approval authority, not write access")
    func activationRequiresApprovalAuthority() async {
        // A teacher may write the plan and still not be the person who decides
        // it takes effect for a child.
        let writer = await state(for: plan(status: .pendingApproval), member: teacher)
        #expect(!writer.contains(.active))
        #expect(!writer.contains(.changesRequested))

        let approver = await state(for: plan(status: .pendingApproval), member: counselor)
        #expect(approver.contains(.active))
        #expect(approver.contains(.changesRequested))
    }

    @Test("Ordinary moves need only write access")
    func ordinaryMovesNeedWriteAccess() async {
        let transitions = await state(for: plan(status: .active), member: teacher)
        #expect(transitions.contains(.paused))
        #expect(transitions.contains(.completed))
    }

    @Test("A reader with neither authority is offered nothing")
    func readerIsOfferedNothing() async {
        let transitions = await state(for: plan(status: .active), member: reader)
        #expect(transitions.isEmpty)
    }

    @Test("An ended plan offers nothing beyond its lifecycle")
    func endedPlanOffersOnlyWhatIsLegal() async {
        // Completed only permits archiving, and archived permits nothing.
        #expect(await state(for: plan(status: .completed), member: counselor) == [.archived])
        #expect(await state(for: plan(status: .archived), member: counselor).isEmpty)
    }

    @Test("Only legal transitions are offered at all")
    func illegalTransitionsAreNeverOffered() async {
        let fromDraft = await state(for: plan(status: .draft), member: counselor)
        // Draft cannot jump straight to completed or paused.
        #expect(!fromDraft.contains(.completed))
        #expect(!fromDraft.contains(.paused))
        #expect(fromDraft.allSatisfy { PlanLifecycle.isLegal(from: .draft, to: $0) })
    }

    // MARK: - Fixtures

    private func state(
        for plan: PlanRecord,
        member: MembershipContext
    ) async -> [PlanRecordStatus] {
        let detail = CanonicalPlanDetailState(
            planID: plan.id,
            repository: StubPlanRepository(plan: plan)
        )
        await detail.load(member: member)
        return detail.availableTransitions(for: member)
    }

    private func member(capabilities: Set<Capability>) -> MembershipContext {
        MembershipContext(
            userID: "member-1",
            districtID: "d1",
            schoolIDs: ["school-1"],
            role: .teacher,
            capabilities: capabilities,
            assignedStudentIDs: [],
            isActive: true,
            version: 1
        )
    }

    private var teacher: MembershipContext {
        member(capabilities: [.studentReadDetail, .studentWriteDetail])
    }

    private var counselor: MembershipContext {
        member(capabilities: [.studentReadDetail, .studentWriteDetail, .planApprove])
    }

    private var reader: MembershipContext {
        member(capabilities: [.studentReadDetail])
    }

    private func plan(status: PlanRecordStatus) -> PlanRecord {
        PlanRecord(
            id: "plan-1",
            districtID: "d1",
            studentIDs: ["student-1"],
            schoolIDs: ["school-1"],
            assignedMemberIDs: ["member-1"],
            status: status,
            model: .chaseYourSpace,
            title: "Chase Your Space",
            summary: nil,
            startDate: now,
            targetDate: nil,
            approvalStatus: .pending,
            metadata: CanonicalRecordMetadata(
                schemaVersion: 1,
                recordVersion: 1,
                createdAt: now,
                createdBy: "member-1",
                updatedAt: now,
                updatedBy: "member-1"
            )
        )
    }
}

@MainActor
private final class StubPlanRepository: PlanRecordRepository {
    private let stored: PlanRecord

    init(plan: PlanRecord) { stored = plan }

    func plans(member: MembershipContext) async throws -> [PlanRecord] { [stored] }
    func plan(id: String, member: MembershipContext) async throws -> PlanRecord { stored }
    func create(_ draft: PlanDraft, operationID: UUID, member: MembershipContext) async throws -> PlanRecord { stored }
    func update(id: String, draft: PlanDraft, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord { stored }
    func transition(id: String, to status: PlanRecordStatus, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord { stored }
}
