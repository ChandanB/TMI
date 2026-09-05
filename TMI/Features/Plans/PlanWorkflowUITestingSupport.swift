#if DEBUG
import SwiftUI

/// Explicit UI-test fixtures never enter production dependency construction.
@MainActor
struct PlanWorkflowUITestingContent: View {
    let failsDetails: Bool
    private let member = MembershipContext(userID: "fixture-owner", districtID: "fixture-district",
        schoolIDs: ["fixture-school"], role: .counselor,
        capabilities: [.studentReadDetail, .studentWriteDetail, .planApprove, .reportExport],
        assignedStudentIDs: ["fixture-student"], isActive: true, version: 1)

    var body: some View {
        let store = PlanWorkflowFixture(failsDetails: failsDetails)
        let students = UnavailableStudentRepository()
        NavigationStack {
            CanonicalPlanDetailView(planID: "fixture-plan", member: member)
        }
        .environment(\.appDependencies, AppDependencies(runtime: .preview, flags: .production,
            membership: InMemoryMembershipProvider(memberships: [member]), authentication: nil,
            studentRepository: students, studentDetailRepository: Release1StudentDetailRepository(students: students),
            planRepository: store, planChildRepository: store, planExportAuditing: FixturePlanAuditing(),
            logger: TMILogger(category: "PlanUITesting")))
        .tint(TMIColors.teal)
    }
}

@MainActor
private final class PlanWorkflowFixture: PlanRecordRepository, PlanChildRepositoryProtocol {
    let failsDetails: Bool
    var record = PlanRecord(id: "fixture-plan", districtID: "fixture-district", studentIDs: ["fixture-student"],
        schoolIDs: ["fixture-school"], assignedMemberIDs: ["fixture-owner"], status: .draft,
        model: .chaseYourSpace, title: "Build a creative routine", summary: "Explore an interest through weekly activities.",
        startDate: Date(timeIntervalSince1970: 1_700_000_000), targetDate: nil, approvalStatus: .notRequested,
        metadata: CanonicalRecordMetadata(schemaVersion: 1, recordVersion: 1,
            createdAt: .now, createdBy: "fixture-owner", updatedAt: .now, updatedBy: "fixture-owner"))
    var storedGoals = [GoalRecord(id: "fixture-goal", planID: "fixture-plan", studentID: "fixture-student",
        title: "Complete a creative activity", studentFacingTitle: "Try one creative activity",
        measure: .count, baseline: "0 per week", target: "1 per week", dueDate: .now,
        responsibleMemberID: "fixture-owner", status: .notStarted)]
    var storedActions = [ActionRecord(id: "fixture-action", planID: "fixture-plan", goalID: "fixture-goal",
        title: "Choose an activity", ownerMemberID: "fixture-owner", audience: .student,
        cadence: .weekly, dueDate: .now, status: .open)]
    var entries: [ProgressRecord] = []
    init(failsDetails: Bool) { self.failsDetails = failsDetails }
    func plans(member: MembershipContext) async throws -> [PlanRecord] { [record] }
    func plan(id: String, member: MembershipContext) async throws -> PlanRecord { record }
    func create(_ draft: PlanDraft, operationID: UUID, member: MembershipContext) async throws -> PlanRecord { record }
    func update(id: String, draft: PlanDraft, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord {
        record.title = draft.title
        record.summary = draft.summary
        return record
    }
    func transition(id: String, to status: PlanRecordStatus, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord {
        guard PlanLifecycle.isLegal(from: record.status, to: status) else {
            throw PlanRecordRepositoryError.illegalTransition(from: record.status, to: status)
        }
        record.status = status
        if status == .approved { record.approvalStatus = .approved }
        return record
    }
    func goals(planID: String, member: MembershipContext) async throws -> [GoalRecord] {
        if failsDetails { throw PlanRecordRepositoryError.unavailable }
        return storedGoals
    }
    func actions(planID: String, member: MembershipContext) async throws -> [ActionRecord] { storedActions }
    func progress(planID: String, member: MembershipContext) async throws -> [ProgressRecord] { entries }
    func revisions(planID: String, member: MembershipContext) async throws -> [PlanRevision] { [] }
    func save(goal: GoalRecord, member: MembershipContext) async throws {
        storedGoals.removeAll { $0.id == goal.id }; storedGoals.append(goal)
    }
    func save(action: ActionRecord, member: MembershipContext) async throws {
        storedActions.removeAll { $0.id == action.id }; storedActions.append(action)
    }
    func append(progress: ProgressRecord, member: MembershipContext) async throws { entries.append(progress) }
    func freeze(revision: PlanRevision, member: MembershipContext) async throws { throw PlanRecordRepositoryError.permissionDenied }
}

private struct FixturePlanAuditing: PlanExportAuditing {
    func recordExport(planID: String, studentID: String, kind: PlanExportKind, districtID: String) async throws -> String {
        "fixture-export-audit"
    }
}
#endif
