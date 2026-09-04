import Foundation
import Testing
@testable import TMI

@Suite("Goals, actions and progress")
struct GoalProgressTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - Goals

    @Test("A goal without a baseline cannot be read as progress")
    func goalRequiresBaseline() {
        let issues = GoalValidation.issues(
            for: goal(baseline: "   "),
            startDate: start
        )
        #expect(issues.contains("A goal needs a baseline, so progress can be read against it."))
    }

    @Test("A goal needs a target, an owner and a title")
    func goalRequiresTheRest() {
        let issues = GoalValidation.issues(
            for: goal(title: " ", target: "", responsibleMemberID: ""),
            startDate: start
        )

        #expect(issues.contains("A goal needs a title."))
        #expect(issues.contains("A goal needs a target."))
        #expect(issues.contains("A goal needs a responsible staff member."))
    }

    @Test("A due date cannot precede the plan it belongs to")
    func dueDateCannotPrecedeStart() {
        let issues = GoalValidation.issues(
            for: goal(dueDate: start.addingTimeInterval(-60)),
            startDate: start
        )
        #expect(issues.contains("The due date cannot precede the plan's start date."))
        #expect(GoalValidation.issues(for: goal(), startDate: start).isEmpty)
    }

    @Test("A student reads wording written for them, or the staff title if none")
    func studentWordingFallsBack() {
        #expect(goal(studentFacingTitle: "Sit with someone new at lunch").studentWording
            == "Sit with someone new at lunch")
        // Never blank: a student is not shown an empty goal.
        #expect(goal(studentFacingTitle: nil).studentWording == "Increase peer interaction")
    }

    // MARK: - Completion

    @Test("Completion is the share of due actions actually done")
    func completionCountsDueActions() {
        let actions = [
            action(id: "a", status: .done),
            action(id: "b", status: .done),
            action(id: "c", status: .open),
            action(id: "d", status: .open),
        ]
        #expect(PlanCompletion.percentage(of: actions) == 50)
    }

    @Test("Withdrawn work is not work owed")
    func skippedActionsLeaveTheDenominator() {
        let actions = [
            action(id: "a", status: .done),
            action(id: "b", status: .skipped),
            action(id: "c", status: .skipped),
        ]
        // One of one due action is done, not one of three.
        #expect(PlanCompletion.percentage(of: actions) == 100)
        #expect(PlanCompletion.percentage(of: []) == 0)
        #expect(PlanCompletion.percentage(of: [action(id: "a", status: .skipped)]) == 0)
    }

    // MARK: - Progress

    @Test("Progress is appended, never overwritten")
    func progressIsAppendOnly() {
        let first = entry(id: "p1", note: "Sat alone at lunch.", at: 10)
        let correction = entry(id: "p2", note: "Correction: sat with one peer.", at: 20)

        var history = ProgressHistory.appending(first, to: [])
        history = ProgressHistory.appending(correction, to: history)

        // Both readings survive. What was believed, and when, stays readable.
        #expect(history.map(\.id) == ["p1", "p2"])
        #expect(history.map(\.note) == ["Sat alone at lunch.", "Correction: sat with one peer."])
    }

    @Test("Recording the same entry twice does not duplicate it")
    func appendingIsIdempotent() {
        let first = entry(id: "p1", note: "Observed.", at: 10)
        let history = ProgressHistory.appending(first, to: ProgressHistory.appending(first, to: []))
        #expect(history.count == 1)
    }

    @Test("History reads in the order it was recorded, whatever order it arrives in")
    func historyIsOrderedByServerTime() {
        let later = entry(id: "p2", note: "Second.", at: 20)
        let earlier = entry(id: "p1", note: "First.", at: 10)

        var history = ProgressHistory.appending(later, to: [])
        history = ProgressHistory.appending(earlier, to: history)

        #expect(history.map(\.id) == ["p1", "p2"])
        #expect(ProgressHistory.latest(for: "goal-1", in: history)?.id == "p2")
    }

    @Test("A student only reads what was shared with them")
    func studentSeesOnlySharedEntries() {
        let history = [
            entry(id: "p1", note: "Staff observation.", at: 10, visibility: .staffOnly),
            entry(id: "p2", note: "You tried something new today.", at: 20, visibility: .sharedWithStudent),
        ]

        let visible = ProgressHistory.visibleToStudent(history)
        #expect(visible.map(\.id) == ["p2"])
    }

    @Test("Every entry says what it was recorded against and who wrote it")
    func entriesCarryAttribution() {
        let recorded = entry(id: "p1", note: "Observed.", at: 10)
        #expect(recorded.source == .goal)
        #expect(recorded.sourceID == "goal-1")
        #expect(recorded.authorID == "teacher-1")
    }

    // MARK: - Fixtures

    private func goal(
        title: String = "Increase peer interaction",
        studentFacingTitle: String? = nil,
        baseline: String = "Sits alone at lunch 5 days a week",
        target: String = "Sits with a peer 3 days a week",
        responsibleMemberID: String = "teacher-1",
        dueDate: Date? = nil
    ) -> GoalRecord {
        GoalRecord(
            id: "goal-1",
            planID: "plan-1",
            studentID: "student-1",
            title: title,
            studentFacingTitle: studentFacingTitle,
            measure: .count,
            baseline: baseline,
            target: target,
            dueDate: dueDate ?? start.addingTimeInterval(60 * 60 * 24 * 30),
            responsibleMemberID: responsibleMemberID,
            status: .inProgress
        )
    }

    private func action(id: String, status: ActionStatus) -> ActionRecord {
        ActionRecord(
            id: id,
            planID: "plan-1",
            goalID: "goal-1",
            title: "Check in at lunch",
            ownerMemberID: "teacher-1",
            audience: .staff,
            cadence: .weekly,
            dueDate: start.addingTimeInterval(60 * 60 * 24 * 7),
            status: status
        )
    }

    private func entry(
        id: String,
        note: String,
        at offset: TimeInterval,
        visibility: ProgressVisibility = .staffOnly
    ) -> ProgressRecord {
        ProgressRecord(
            id: id,
            planID: "plan-1",
            studentID: "student-1",
            source: .goal,
            sourceID: "goal-1",
            measuredValue: "2",
            note: note,
            visibility: visibility,
            authorID: "teacher-1",
            recordedAt: start.addingTimeInterval(offset)
        )
    }
}
