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
                    studentID: "student-1",
                    plan: plan(status: status), goals: [goal()], actions: [], progress: []
                ) == nil,
                "\(status) should not project"
            )
        }
        #expect(
            StudentPlanProjectionBuilder.projection(
                    studentID: "student-1",
                plan: plan(status: .active), goals: [goal()], actions: [], progress: []
            ) != nil
        )
    }

    @Test("An active plan is hidden until it is approved")
    func activeUnapprovedPlanDoesNotProject() {
        var candidate = plan(status: .active)
        candidate.approvalStatus = .pending

        #expect(
            StudentPlanProjectionBuilder.projection(
                    studentID: "student-1",
                plan: candidate, goals: [goal()], actions: [], progress: [], now: now
            ) == nil
        )
    }

    @Test("A student reads wording written for them, never the clinical title")
    func studentReadsTheirOwnWording() throws {
        let projection = try #require(
            StudentPlanProjectionBuilder.projection(
                    studentID: "student-1",
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
                    studentID: "student-1",
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

    @Test("Staff-authored plan titles never reach the student")
    func staffPlanTitleIsAbsent() throws {
        let projection = try #require(
            StudentPlanProjectionBuilder.projection(
                    studentID: "student-1",
                plan: plan(status: .active), goals: [goal()], actions: [], progress: [], now: now
            )
        )

        #expect(projection.planTitle == TMIPlanModel.chaseYourSpace.rawValue)
        #expect(projection.planTitle != "Clinical lunch intervention")
    }

    @Test("Only due, student-visible, non-skipped actions are projected")
    func onlyDueStudentActionsProject() throws {
        let projection = try #require(
            StudentPlanProjectionBuilder.projection(
                    studentID: "student-1",
                plan: plan(status: .active),
                goals: [goal()],
                actions: [
                    action(
                        id: "due",
                        audience: .student,
                        title: "Try today's step",
                        dueDate: now
                    ),
                    action(
                        id: "future",
                        audience: .student,
                        title: "Next month's step",
                        dueDate: now.addingTimeInterval(30 * 24 * 60 * 60)
                    ),
                    action(
                        id: "skipped",
                        audience: .student,
                        title: "Withdrawn step",
                        dueDate: now,
                        status: .skipped
                    ),
                ],
                progress: [],
                now: now
            )
        )

        #expect(projection.goals.flatMap(\.actions).map(\.id) == ["due"])
    }

    @Test("Staff-only observations never reach the student")
    func staffNotesAreAbsent() throws {
        let projection = try #require(
            StudentPlanProjectionBuilder.projection(
                    studentID: "student-1",
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
                    studentID: "student-1",
                plan: plan(status: .active),
                goals: [goal(), goal(id: "goal-2", status: .discontinued)],
                actions: [],
                progress: []
            )
        )
        #expect(projection.goals.map(\.id) == ["goal-1"])
    }

    @Test("Student completion counts only the due actions visible to that student")
    func completionMatchesStaff() throws {
        let actions = [
            action(id: "a1", audience: .student, title: "Invite someone", status: .done),
            action(id: "a2", audience: .staff, title: "Observe", status: .open),
        ]
        let projection = try #require(
            StudentPlanProjectionBuilder.projection(
                    studentID: "student-1",
                plan: plan(status: .active), goals: [goal()], actions: actions, progress: []
            )
        )

        #expect(projection.completionPercentage == 100)
    }

    @Test("A student's projection excludes another student's goals and shared observations")
    func foreignStudentRecordsAreAbsent() throws {
        let otherGoal = GoalRecord(id: "other-goal", planID: "plan-1", studentID: "student-2",
            title: "Private staff wording", studentFacingTitle: "Another student's goal",
            measure: .count, baseline: "0", target: "1", dueDate: now,
            responsibleMemberID: "teacher-1", status: .inProgress)
        let otherNote = ProgressRecord(id: "other-note", planID: "plan-1", studentID: "student-2",
            source: .goal, sourceID: otherGoal.id, measuredValue: nil,
            note: "Another student's shared observation", visibility: .sharedWithStudent,
            authorID: "teacher-1", recordedAt: now)
        let result = try #require(StudentPlanProjectionBuilder.projection(
                    studentID: "student-1",
            plan: plan(status: .active), goals: [goal(), otherGoal], actions: [], progress: [otherNote]))
        #expect(result.goals.map(\.id) == ["goal-1"])
        #expect(result.progress.isEmpty)
    }

    @Test("Missing student wording never falls back to a professional goal title")
    func professionalGoalWordingIsAbsent() throws {
        let staffGoal = GoalRecord(id: "staff-goal", planID: "plan-1", studentID: "student-1",
            title: "Confidential professional need", studentFacingTitle: nil,
            measure: .count, baseline: "0", target: "1", dueDate: now,
            responsibleMemberID: "teacher-1", status: .inProgress)
        let result = try #require(StudentPlanProjectionBuilder.projection(
                    studentID: "student-1",
            plan: plan(status: .active), goals: [staffGoal], actions: [], progress: []))
        #expect(result.goals.isEmpty)
    }

    @Test("Multi-student plans require an explicit student and reject unrelated students")
    func groupPlanIsScoped() throws {
        var group = plan(status: .active)
        group.studentIDs = ["student-1", "student-2"]
        let secondGoal = GoalRecord(id: "goal-2", planID: group.id, studentID: "student-2",
            title: "Professional wording", studentFacingTitle: "Try your next step",
            measure: .count, baseline: "0", target: "1", dueDate: now,
            responsibleMemberID: "teacher-1", status: .inProgress)
        let result = try #require(StudentPlanProjectionBuilder.projection(
            studentID: "student-2", plan: group, goals: [goal(), secondGoal], actions: [], progress: []))
        #expect(result.goals.map(\.id) == ["goal-2"])
        #expect(StudentPlanProjectionBuilder.projection(
            studentID: "unrelated", plan: group, goals: [goal()], actions: [], progress: []) == nil)
    }

    @Test("A foreign plan action cannot enter a matching goal or completion count")
    func foreignPlanActionIsAbsent() throws {
        let wrongPlanAction = ActionRecord(id: "foreign", planID: "other-plan", goalID: "goal-1",
            title: "Another plan's action", ownerMemberID: "teacher-1", audience: .student,
            cadence: .once, dueDate: now, status: .done)
        let result = try #require(StudentPlanProjectionBuilder.projection(
            studentID: "student-1", plan: plan(status: .active), goals: [goal()],
            actions: [wrongPlanAction], progress: [], now: now))
        #expect(result.goals.flatMap(\.actions).isEmpty)
        #expect(result.completionPercentage == 0)
    }

    // MARK: - Fixtures

    private func plan(status: PlanRecordStatus) -> PlanRecord {
        PlanRecord(
            id: "plan-1", districtID: "d1", studentIDs: ["student-1"],
            schoolIDs: ["school-1"], assignedMemberIDs: ["teacher-1"],
            status: status, model: .chaseYourSpace, title: "Clinical lunch intervention",
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
        dueDate: Date? = nil,
        status: ActionStatus = .open
    ) -> ActionRecord {
        ActionRecord(
            id: id, planID: "plan-1", goalID: "goal-1", title: title,
            ownerMemberID: "teacher-1", audience: audience, cadence: .weekly,
            dueDate: dueDate ?? now, status: status
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
