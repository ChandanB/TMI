import Foundation
import Testing
@testable import TMI

@Suite("Student plan projection")
struct StudentPlanProjectionTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test("Only an active plan is shown to the student as their work")
    func onlyActivePlansProject() {
        for status in PlanRecordStatus.allCases where status != .active {
            #expect(
                StudentPlanProjectionBuilder.projection(
                    plan: plan(status: status), goals: [goal()], actions: [], progress: []
                ) == nil,
                "\(status) should not project"
            )
        }
        #expect(
            StudentPlanProjectionBuilder.projection(
                plan: plan(status: .active), goals: [goal()], actions: [], progress: []
            ) != nil
        )
    }

    @Test("A student reads wording written for them, never the clinical title")
    func studentReadsTheirOwnWording() throws {
        let projection = try #require(
            StudentPlanProjectionBuilder.projection(
                plan: plan(status: .active), goals: [goal()], actions: [], progress: []
            )
        )

        #expect(projection.goals.map(\.wording) == ["Sit with someone new at lunch"])
        // The professional framing does not travel.
        #expect(!projection.goals.contains { $0.wording.contains("peer interaction") })
    }

    @Test("Staff-facing actions are absent from the student's list")
    func staffActionsAreAbsent() throws {
        let projection = try #require(
            StudentPlanProjectionBuilder.projection(
                plan: plan(status: .active),
                goals: [goal()],
                actions: [
                    action(id: "a1", audience: .student, title: "Invite someone to sit with you"),
                    action(id: "a2", audience: .staff, title: "Log lunchroom observation"),
                ],
                progress: []
            )
        )

        let titles = projection.goals.flatMap(\.actions).map(\.title)
        #expect(titles == ["Invite someone to sit with you"])
        #expect(!titles.contains("Log lunchroom observation"))
    }

    @Test("Staff-only observations never reach the student")
    func staffNotesAreAbsent() throws {
        let projection = try #require(
            StudentPlanProjectionBuilder.projection(
                plan: plan(status: .active),
                goals: [goal()],
                actions: [],
                progress: [
                    entry(id: "p1", note: "Concern raised by lunch staff.", visibility: .staffOnly),
                    entry(id: "p2", note: "You sat with someone new today.", visibility: .sharedWithStudent),
                ]
            )
        )

        #expect(projection.progress.map(\.text) == ["You sat with someone new today."])
    }

    @Test("A discontinued goal is not current work")
    func discontinuedGoalsAreAbsent() throws {
        let projection = try #require(
            StudentPlanProjectionBuilder.projection(
                plan: plan(status: .active),
                goals: [goal(), goal(id: "goal-2", status: .discontinued)],
                actions: [],
                progress: []
            )
        )
        #expect(projection.goals.map(\.id) == ["goal-1"])
    }

    @Test("The student sees the same completion number staff do")
    func completionMatchesStaff() throws {
        let actions = [
            action(id: "a1", audience: .student, title: "Invite someone", status: .done),
            action(id: "a2", audience: .staff, title: "Observe", status: .open),
        ]
        let projection = try #require(
            StudentPlanProjectionBuilder.projection(
                plan: plan(status: .active), goals: [goal()], actions: actions, progress: []
            )
        )

        // Nobody is working from a different number than the student is
        // looking at, even though the student sees only their own actions.
        #expect(projection.completionPercentage == PlanCompletion.percentage(of: actions))
        #expect(projection.completionPercentage == 50)
    }

    // MARK: - Fixtures

    private func plan(status: PlanRecordStatus) -> PlanRecord {
        PlanRecord(
            id: "plan-1", districtID: "d1", studentIDs: ["student-1"],
            schoolIDs: ["school-1"], assignedMemberIDs: ["teacher-1"],
            status: status, model: .chaseYourSpace, title: "Chase Your Space",
            summary: nil, startDate: now, targetDate: nil, approvalStatus: .approved,
            metadata: CanonicalRecordMetadata(
                schemaVersion: 1, recordVersion: 1, createdAt: now,
                createdBy: "teacher-1", updatedAt: now, updatedBy: "teacher-1"
            )
        )
    }

    private func goal(
        id: String = "goal-1",
        status: GoalRecordStatus = .inProgress
    ) -> GoalRecord {
        GoalRecord(
            id: id, planID: "plan-1", studentID: "student-1",
            title: "Increase peer interaction",
            studentFacingTitle: "Sit with someone new at lunch",
            measure: .count, baseline: "Sits alone", target: "Sits with a peer",
            dueDate: now, responsibleMemberID: "teacher-1", status: status
        )
    }

    private func action(
        id: String,
        audience: ActionAudience,
        title: String,
        status: ActionStatus = .open
    ) -> ActionRecord {
        ActionRecord(
            id: id, planID: "plan-1", goalID: "goal-1", title: title,
            ownerMemberID: "teacher-1", audience: audience, cadence: .weekly,
            dueDate: now, status: status
        )
    }

    private func entry(
        id: String,
        note: String,
        visibility: ProgressVisibility
    ) -> ProgressRecord {
        ProgressRecord(
            id: id, planID: "plan-1", studentID: "student-1",
            source: .goal, sourceID: "goal-1", measuredValue: nil,
            note: note, visibility: visibility, authorID: "teacher-1", recordedAt: now
        )
    }
}
