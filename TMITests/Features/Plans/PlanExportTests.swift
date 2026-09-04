import Foundation
import Testing
@testable import TMI

@Suite("Permission-safe plan exports")
struct PlanExportTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    @Test("Reading a plan on screen does not authorize exporting it")
    func exportIsItsOwnPermission() {
        // Taking a record out of the building is a separate decision from
        // being able to read it.
        #expect(throws: PlanExportProjectionError.notAuthorized) {
            _ = try PlanExportProjection.document(
                kind: .professionalPlan,
                material: material(),
                capabilities: [.studentReadDetail],
                auditID: "audit-1"
            )
        }

        #expect(throws: PlanExportProjectionError.notAuthorized) {
            _ = try PlanExportProjection.document(
                kind: .professionalPlan,
                material: material(),
                capabilities: [.reportExport],
                auditID: "audit-1"
            )
        }
    }

    @Test("Restricted observations are never placed in an unauthorized export")
    func restrictedContentIsAbsentNotHidden() throws {
        let document = try PlanExportProjection.document(
            kind: .progressReport,
            material: material(),
            capabilities: [.reportExport, .studentReadDetail],
            auditID: "audit-1"
        )

        // Absent from the document itself, so no rendering or layout decision
        // can put it back.
        let summaries = document.progress.map(\.summary)
        #expect(!summaries.contains("Staff-only concern noted."))
        #expect(summaries == ["Tried something new today."])
    }

    @Test("A restricted-read holder gets the fuller record, marked as such")
    func restrictedReadIncludesEverything() throws {
        let document = try PlanExportProjection.document(
            kind: .progressReport,
            material: material(),
            capabilities: [.reportExport, .studentReadDetail, .studentRestrictedRead],
            auditID: "audit-1"
        )

        #expect(document.progress.count == 2)
        // The page says what it carries, so a copy separated from its context
        // still declares itself.
        #expect(document.classification.contains("restricted"))
    }

    @Test("Student-facing wording stays out of the professional record")
    func studentWordingIsNotExported() throws {
        let document = try PlanExportProjection.document(
            kind: .professionalPlan,
            material: material(),
            capabilities: [.reportExport, .studentReadDetail, .studentRestrictedRead],
            auditID: "audit-1"
        )

        // The exported goal uses the staff title. Wording written for a child
        // to read with a trusted adult is not documentation.
        #expect(document.goals.map(\.title) == ["Increase peer interaction"])
        #expect(!document.goals.contains { $0.title == "Sit with someone new at lunch" })
    }

    @Test("Every export is classified and carries its audit identifier")
    func exportsAreClassifiedAndAudited() throws {
        let document = try PlanExportProjection.document(
            kind: .mtssSummary,
            material: material(),
            capabilities: [.reportExport, .studentReadDetail],
            auditID: "audit-42"
        )

        #expect(document.classification == "Confidential student record")
        #expect(document.auditID == "audit-42")
        #expect(document.studentDisplayName == "Ava Stone")
    }

    @Test("Progress ordering is by server time, not arrival order")
    func progressOrdersByServerTime() throws {
        let document = try PlanExportProjection.document(
            kind: .progressReport,
            material: material(),
            capabilities: [.reportExport, .studentReadDetail, .studentRestrictedRead],
            auditID: "audit-1"
        )

        #expect(document.progress.map(\.recordedAt) == document.progress.map(\.recordedAt).sorted())
    }

    @Test("Completion travels as a number an educator can recount")
    func completionIsCarried() throws {
        let document = try PlanExportProjection.document(
            kind: .mtssSummary,
            material: material(),
            capabilities: [.reportExport, .studentReadDetail],
            auditID: "audit-1"
        )
        #expect(document.completionPercentage == 50)
    }

    // MARK: - Fixtures

    private func material() -> PlanExportMaterial {
        PlanExportMaterial(
            planID: "plan-1",
            studentID: "student-1",
            studentDisplayName: "Ava Stone",
            model: .chaseYourSpace,
            rationale: ["A staff member identified Belonging."],
            goals: [
                GoalRecord(
                    id: "goal-1",
                    planID: "plan-1",
                    studentID: "student-1",
                    title: "Increase peer interaction",
                    studentFacingTitle: "Sit with someone new at lunch",
                    measure: .count,
                    baseline: "Sits alone 5 days a week",
                    target: "Sits with a peer 3 days a week",
                    dueDate: start.addingTimeInterval(60 * 60 * 24 * 30),
                    responsibleMemberID: "teacher-1",
                    status: .inProgress
                ),
            ],
            actions: [
                ActionRecord(
                    id: "action-1", planID: "plan-1", goalID: "goal-1",
                    title: "Lunch check-in", ownerMemberID: "teacher-1",
                    audience: .staff, cadence: .weekly,
                    dueDate: start, status: .done
                ),
                ActionRecord(
                    id: "action-2", planID: "plan-1", goalID: "goal-1",
                    title: "Invite a peer", ownerMemberID: "teacher-1",
                    audience: .student, cadence: .weekly,
                    dueDate: start, status: .open
                ),
            ],
            progress: [
                ProgressRecord(
                    id: "p2", planID: "plan-1", studentID: "student-1",
                    source: .goal, sourceID: "goal-1", measuredValue: "1",
                    note: "Staff-only concern noted.", visibility: .staffOnly,
                    authorID: "teacher-1", recordedAt: start.addingTimeInterval(20)
                ),
                ProgressRecord(
                    id: "p1", planID: "plan-1", studentID: "student-1",
                    source: .goal, sourceID: "goal-1", measuredValue: "2",
                    note: "Tried something new today.", visibility: .sharedWithStudent,
                    authorID: "teacher-1", recordedAt: start.addingTimeInterval(10)
                ),
            ],
            restrictedNotes: ["Counselor note."]
        )
    }
}
