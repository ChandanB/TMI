import Foundation
import Testing
@testable import TMI

@MainActor
struct CanonicalStudentDetailRepositoryTests {
    private let member = MembershipContext(userID: "teacher", districtID: "district", schoolIDs: ["school"], role: .teacher, capabilities: [.studentReadDetail], assignedStudentIDs: ["student"], isActive: true, version: 1)
    private var metadata: CanonicalRecordMetadata {
        .init(schemaVersion: 1, recordVersion: 1, createdAt: .now, createdBy: "teacher", updatedAt: .now, updatedBy: "teacher")
    }
    private var student: StudentRecord {
        .init(id: "student", districtID: "district", schoolID: "school", displayName: "Student", grade: "7", studentIdentifier: nil, dateOfBirth: nil, pronouns: nil, assignedMemberIDs: ["teacher"], isArchived: false, metadata: metadata)
    }
    private func plan(_ id: String, status: PlanRecordStatus, approved: Bool = true, studentID: String = "student", districtID: String = "district") -> PlanRecord {
        .init(id: id, districtID: districtID, studentIDs: [studentID], schoolIDs: ["school"], assignedMemberIDs: ["teacher"], status: status, model: .chaseYourSpace, title: id, summary: nil, startDate: .now, targetDate: nil, approvalStatus: approved ? .approved : .notRequested, metadata: metadata)
    }

    @Test func summaryUsesOnlyThisStudentsCanonicalPlans() async throws {
        let records = [plan("active", status: .active), plan("unapproved", status: .active, approved: false), plan("draft", status: .draft), plan("completed", status: .completed), plan("other", status: .active, studentID: "other"), plan("foreign", status: .active, districtID: "foreign")]
        let repository = CanonicalStudentDetailRepository(students: HubStudents(record: student)) { _, _ in
            .init(plans: records, interestIDs: ["music"], savedCareerIDs: ["engineer"], historicalCareerIDs: ["artist"])
        }
        let hub = try await repository.hub(studentID: "student", member: member)
        #expect(hub.activePlanStatus == .active(count: 1))
        #expect(hub.collections.currentItemIDs[.plans] == ["active", "draft", "unapproved"])
        #expect(hub.collections.historyItemIDs[.plans] == ["completed"])
        #expect(hub.collections.currentItemIDs[.interests] == ["music"])
        #expect(hub.collections.currentItemIDs[.careers] == ["engineer"])
        #expect(hub.collections.historyItemIDs[.careers] == ["artist"])
        #expect(hub.lastInteractionAt == nil)
    }

    @Test func studentPlanListNeverShowsAnotherStudentsPlan() async {
        let repository = HubPlans(records: [plan("mine", status: .draft), plan("other", status: .draft, studentID: "other")])
        let state = CanonicalPlanListState(repository: repository, studentID: "student")
        await state.load(member: member)
        #expect(state.visiblePlans.map(\.id) == ["mine"])
        state.showOpenOnly = false
        #expect(state.visiblePlans.map(\.id) == ["mine"])
    }

    @Test func failedReadCannotBecomeAnEmptySummary() async {
        let repository = CanonicalStudentDetailRepository(students: HubStudents(record: student)) { _, _ in throw StudentRepositoryError.unavailable }
        await #expect(throws: StudentRepositoryError.unavailable) {
            try await repository.hub(studentID: "student", member: member)
        }
    }

    @Test func mismatchedStudentIsRejectedBeforeRelatedReads() async {
        let repository = CanonicalStudentDetailRepository(students: HubStudents(record: student)) { _, _ in
            Issue.record("Must not read another student's relationships")
            return .init()
        }
        await #expect(throws: StudentRepositoryError.permissionDenied) {
            try await repository.hub(studentID: "other", member: member)
        }
    }
}

private struct HubStudents: StudentRepository {
    let record: StudentRecord

    func page(
        _: StudentPageRequest,
        member _: MembershipContext
    ) async throws -> StudentPage {
        throw StudentRepositoryError.invalidResponse
    }

    func student(id: String, member: MembershipContext) async throws -> StudentRecord { record }

    func create(
        _: StudentDraft,
        operationID _: UUID,
        member _: MembershipContext
    ) async throws -> StudentRecord {
        throw StudentRepositoryError.invalidResponse
    }

    func reconcilePendingCreates(
        member _: MembershipContext
    ) async throws -> [StudentRecord] {
        throw StudentRepositoryError.invalidResponse
    }

    func update(
        id _: String,
        draft _: StudentDraft,
        expectedVersion _: Int,
        operationID _: UUID,
        member _: MembershipContext
    ) async throws -> StudentRecord {
        throw StudentRepositoryError.invalidResponse
    }

    func archive(
        id _: String,
        expectedVersion _: Int,
        operationID _: UUID,
        member _: MembershipContext
    ) async throws {
        throw StudentRepositoryError.invalidResponse
    }
}

@MainActor
private final class HubPlans: PlanRecordRepository {
    let records: [PlanRecord]
    init(records: [PlanRecord]) { self.records = records }
    func plans(member: MembershipContext) async throws -> [PlanRecord] { records }
    func plan(id: String, member: MembershipContext) async throws -> PlanRecord { throw PlanRecordRepositoryError.unavailable }
    func create(_ draft: PlanDraft, operationID: UUID, member: MembershipContext) async throws -> PlanRecord { throw PlanRecordRepositoryError.unavailable }
    func update(id: String, draft: PlanDraft, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord { throw PlanRecordRepositoryError.unavailable }
    func transition(id: String, to status: PlanRecordStatus, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord { throw PlanRecordRepositoryError.unavailable }
}
