import Foundation
import Testing
@testable import TMI

@Suite("Plan export auditing")
@MainActor
struct PlanExportAuditingTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test("An export that cannot be recorded is not produced")
    func unrecordableExportIsRefused() async {
        // A child's record does not leave the building without something,
        // somewhere, recording that it did.
        let state = CanonicalPlanDetailState(
            planID: "plan-1",
            repository: StubPlanRepo(plan: plan),
            children: ExportChildren(),
            auditing: FailingAuditing(error: .unavailable)
        )
        await state.load(member: exporter)
        await state.export(kind: .professionalPlan, member: exporter)

        #expect(state.exportedPDF == nil)
        let message = try? #require(state.exportMessage)
        #expect(message?.contains("administrator") == true)
        #expect(message?.contains("deploy") == true)
    }

    @Test("Exporting is a separate permission from reading the plan")
    func exportNeedsItsOwnPermission() async {
        let state = CanonicalPlanDetailState(
            planID: "plan-1",
            repository: StubPlanRepo(plan: plan),
            children: ExportChildren(),
            auditing: FailingAuditing(error: .unavailable)
        )
        await state.load(member: exporter)

        #expect(state.canExport(exporter))
        #expect(!state.canExport(reader))
    }

    @Test("A recorded export carries the identifier the server issued")
    func recordedExportUsesServerIdentifier() async throws {
        let state = CanonicalPlanDetailState(
            planID: "plan-1",
            repository: StubPlanRepo(plan: plan),
            children: ExportChildren(),
            auditing: StubAuditing(auditID: "audit-server-1")
        )
        await state.load(member: exporter)
        await state.export(kind: .professionalPlan, member: exporter)

        #expect(state.exportedPDF != nil)
        // The identifier printed on the export is the one that was recorded,
        // never one the device made up.
        #expect(state.exportMessage?.contains("audit-server-1") == true)
    }

    // MARK: - Fixtures

    private func member(capabilities: Set<Capability>) -> MembershipContext {
        MembershipContext(
            userID: "member-1", districtID: "d1", schoolIDs: ["school-1"],
            role: .counselor, capabilities: capabilities,
            assignedStudentIDs: [], isActive: true, version: 1
        )
    }

    private var exporter: MembershipContext {
        member(capabilities: [.studentReadDetail, .reportExport])
    }

    private var reader: MembershipContext {
        member(capabilities: [.studentReadDetail])
    }

    private var plan: PlanRecord {
        PlanRecord(
            id: "plan-1", districtID: "d1", studentIDs: ["student-1"],
            schoolIDs: ["school-1"], assignedMemberIDs: ["member-1"],
            status: .active, model: .chaseYourSpace, title: "Chase Your Space",
            summary: nil, startDate: now, targetDate: nil, approvalStatus: .approved,
            metadata: CanonicalRecordMetadata(
                schemaVersion: 1, recordVersion: 1, createdAt: now,
                createdBy: "member-1", updatedAt: now, updatedBy: "member-1"
            )
        )
    }
}

private struct FailingAuditing: PlanExportAuditing {
    let error: PlanExportAuditError
    func recordExport(
        planID: String, studentID: String, kind: PlanExportKind, districtID: String
    ) async throws -> String { throw error }
}

private struct StubAuditing: PlanExportAuditing {
    let auditID: String
    func recordExport(
        planID: String, studentID: String, kind: PlanExportKind, districtID: String
    ) async throws -> String { auditID }
}

@MainActor
private final class StubPlanRepo: PlanRecordRepository {
    private let stored: PlanRecord
    init(plan: PlanRecord) { stored = plan }
    func plans(member: MembershipContext) async throws -> [PlanRecord] { [stored] }
    func plan(id: String, member: MembershipContext) async throws -> PlanRecord { stored }
    func create(_ draft: PlanDraft, operationID: UUID, member: MembershipContext) async throws -> PlanRecord { stored }
    func update(id: String, draft: PlanDraft, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord { stored }
    func transition(id: String, to status: PlanRecordStatus, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord { stored }
}

@MainActor
private final class ExportChildren: PlanChildRepositoryProtocol {
    func goals(planID: String, member: MembershipContext) async throws -> [GoalRecord] { [] }
    func actions(planID: String, member: MembershipContext) async throws -> [ActionRecord] { [] }
    func progress(planID: String, member: MembershipContext) async throws -> [ProgressRecord] { [] }
    func revisions(planID: String, member: MembershipContext) async throws -> [PlanRevision] { [] }
    func save(goal: GoalRecord, member: MembershipContext) async throws {}
    func save(action: ActionRecord, member: MembershipContext) async throws {}
    func append(progress: ProgressRecord, member: MembershipContext) async throws {}
    func freeze(revision: PlanRevision, member: MembershipContext) async throws {}
}
