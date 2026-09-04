import FirebaseFirestore
import Foundation
import Testing
@testable import TMI

@Suite("Plan child record encoding")
struct PlanChildRepositoryTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test("A goal survives a round trip through Firestore fields")
    func goalRoundTrips() throws {
        let goal = GoalRecord(
            id: "goal-1", planID: "plan-1", studentID: "student-1",
            title: "Increase peer interaction",
            studentFacingTitle: "Sit with someone new at lunch",
            measure: .count,
            baseline: "Sits alone 5 days a week",
            target: "Sits with a peer 3 days a week",
            dueDate: now, responsibleMemberID: "teacher-1", status: .inProgress
        )

        let decoded = try #require(
            PlanChildRepository.goal(id: "goal-1", data: PlanChildRepository.fields(goal))
        )
        #expect(decoded == goal)
    }

    @Test("An action survives a round trip")
    func actionRoundTrips() throws {
        let action = ActionRecord(
            id: "action-1", planID: "plan-1", goalID: "goal-1",
            title: "Lunch check-in", ownerMemberID: "teacher-1",
            audience: .student, cadence: .weekly, dueDate: now, status: .open
        )

        let decoded = try #require(
            PlanChildRepository.action(id: "action-1", data: PlanChildRepository.fields(action))
        )
        #expect(decoded == action)
    }

    @Test("Progress and revisions take their time from the server")
    func serverStampsTheTime() {
        let entry = ProgressRecord(
            id: "p1", planID: "plan-1", studentID: "student-1",
            source: .goal, sourceID: "goal-1", measuredValue: "2",
            note: "Observed.", visibility: .staffOnly,
            authorID: "teacher-1", recordedAt: now
        )

        // The device's own clock is never written, so a wrong clock cannot
        // reorder someone's history.
        #expect(PlanChildRepository.fields(entry)["recordedAt"] is FieldValue)
        #expect(PlanChildRepository.fields(revision)["frozenAt"] is FieldValue)
    }

    @Test("An entry still being written sorts last rather than disappearing")
    func pendingServerTimeSortsLast() throws {
        // A local write has no server timestamp yet. Dropping it would make a
        // just-recorded observation vanish from the person who wrote it.
        var data = PlanChildRepository.fields(ProgressRecord(
            id: "p1", planID: "plan-1", studentID: "student-1",
            source: .goal, sourceID: "goal-1", measuredValue: nil,
            note: "Just written.", visibility: .staffOnly,
            authorID: "teacher-1", recordedAt: now
        ))
        data["recordedAt"] = nil

        let decoded = try #require(PlanChildRepository.progressRecord(id: "p1", data: data))
        #expect(decoded.recordedAt == .distantFuture)
        #expect(decoded.note == "Just written.")
    }

    @Test("A revision survives a round trip with its agreement intact")
    func revisionRoundTrips() throws {
        let decoded = try #require(
            PlanChildRepository.revision(id: revision.id, data: PlanChildRepository.fields(revision))
        )

        #expect(decoded.planID == revision.planID)
        #expect(decoded.sequence == revision.sequence)
        #expect(decoded.reason == .approved)
        #expect(decoded.goalIDs == revision.goalIDs)
        #expect(decoded.frozenBy == revision.frozenBy)
    }

    @Test("A malformed record is dropped rather than guessed at")
    func malformedRecordsAreDropped() {
        // Half a goal is not a goal. Filling in defaults would put invented
        // baselines and targets in front of an educator.
        #expect(PlanChildRepository.goal(id: "goal-1", data: ["planID": "plan-1"]) == nil)
        #expect(PlanChildRepository.action(id: "action-1", data: [:]) == nil)
        #expect(PlanChildRepository.revision(id: "r1", data: ["planID": "plan-1"]) == nil)
        #expect(PlanChildRepository.progressRecord(id: "p1", data: ["planID": "plan-1"]) == nil)
    }

    private var revision: PlanRevision {
        PlanRevision(
            id: "plan-1__r1", planID: "plan-1", sequence: 1, reason: .approved,
            status: .active, model: .chaseYourSpace, title: "Chase Your Space",
            summary: nil, startDate: now, targetDate: nil,
            goalIDs: ["goal-1"], actionIDs: ["action-1"],
            frozenBy: "counselor-1", frozenAt: now, note: nil
        )
    }
}
