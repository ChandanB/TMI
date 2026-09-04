import Foundation
import Testing
@testable import TMI

@Suite("Plan revision history")
struct PlanRevisionTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test("Only commitments freeze a revision")
    func onlyCommitmentsFreeze() {
        // Editing a draft or pausing is not a commitment and leaves no
        // revision, so the timeline stays a record of what was agreed.
        #expect(PlanRevisionHistory.reason(forEntering: .active) == .approved)
        #expect(PlanRevisionHistory.reason(forEntering: .changesRequested) == .changesRequested)
        #expect(PlanRevisionHistory.reason(forEntering: .completed) == .completed)
        #expect(PlanRevisionHistory.reason(forEntering: .draft) == nil)
        #expect(PlanRevisionHistory.reason(forEntering: .pendingApproval) == nil)
        #expect(PlanRevisionHistory.reason(forEntering: .paused) == nil)
        #expect(PlanRevisionHistory.reason(forEntering: .archived) == nil)
    }

    @Test("Freezing a status that is not a commitment is refused")
    func nonCommitmentCannotFreeze() {
        #expect(throws: PlanRevisionError.notFreezable(.paused)) {
            _ = try PlanRevisionHistory.freeze(
                plan, entering: .paused, goalIDs: [], actionIDs: [],
                note: nil, frozenBy: "teacher-1", frozenAt: now, existing: []
            )
        }
    }

    @Test("Requesting changes without a reason is refused")
    func changesRequestedNeedsAReason() {
        // The next person has to know what to fix.
        #expect(throws: PlanRevisionError.emptyNote) {
            _ = try PlanRevisionHistory.freeze(
                plan, entering: .changesRequested, goalIDs: [], actionIDs: [],
                note: "   ", frozenBy: "counselor-1", frozenAt: now, existing: []
            )
        }
    }

    @Test("A revision records what was agreed and who agreed to it")
    func revisionCapturesTheAgreement() throws {
        let revision = try PlanRevisionHistory.freeze(
            plan, entering: .active, goalIDs: ["goal-2", "goal-1"], actionIDs: ["action-1"],
            note: nil, frozenBy: "counselor-1", frozenAt: now, existing: []
        )

        #expect(revision.sequence == 1)
        #expect(revision.reason == .approved)
        #expect(revision.title == "Chase Your Space")
        #expect(revision.goalIDs == ["goal-1", "goal-2"])
        #expect(revision.frozenBy == "counselor-1")
        #expect(revision.frozenAt == now)
    }

    @Test("Sequence advances by one, so a missing revision is visible")
    func sequenceAdvances() throws {
        let first = try PlanRevisionHistory.freeze(
            plan, entering: .active, goalIDs: [], actionIDs: [],
            note: nil, frozenBy: "counselor-1", frozenAt: now, existing: []
        )
        let second = try PlanRevisionHistory.freeze(
            plan, entering: .completed, goalIDs: [], actionIDs: [],
            note: "Goals met.", frozenBy: "teacher-1", frozenAt: now.addingTimeInterval(60),
            existing: [first]
        )

        #expect(second.sequence == 2)
        #expect(second.id == "plan-1__r2")
        #expect(second.note == "Goals met.")
    }

    @Test("History reads newest first")
    func historyReadsNewestFirst() throws {
        let first = try PlanRevisionHistory.freeze(
            plan, entering: .active, goalIDs: [], actionIDs: [],
            note: nil, frozenBy: "c", frozenAt: now, existing: []
        )
        let second = try PlanRevisionHistory.freeze(
            plan, entering: .completed, goalIDs: [], actionIDs: [],
            note: "Done.", frozenBy: "c", frozenAt: now, existing: [first]
        )

        #expect(PlanRevisionHistory.ordered([first, second]).map(\.sequence) == [2, 1])
    }

    @Test("A new cycle is new work, not a continuation")
    func nextCycleStartsClean() {
        let draft = PlanRevisionHistory.nextCycleDraft(
            from: plan,
            startingOn: now.addingTimeInterval(60 * 60 * 24 * 90)
        )

        // Same student, same model, its own dates and its own identity. The
        // completed plan keeps its history rather than being reopened.
        #expect(draft.studentIDs == plan.studentIDs)
        #expect(draft.model == plan.model)
        #expect(draft.startDate == now.addingTimeInterval(60 * 60 * 24 * 90))
        #expect(draft.targetDate == nil)
        #expect(!PlanLifecycle.isLegal(from: .completed, to: .active))
    }

    // MARK: - Fixture

    private var plan: PlanRecord {
        PlanRecord(
            id: "plan-1",
            districtID: "d1",
            studentIDs: ["student-1"],
            schoolIDs: ["school-1"],
            assignedMemberIDs: ["teacher-1"],
            status: .pendingApproval,
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
                createdBy: "teacher-1",
                updatedAt: now,
                updatedBy: "teacher-1"
            )
        )
    }
}
