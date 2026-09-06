import Foundation
import Testing
@testable import TMI

@Suite("Career plan attachment")
@MainActor
struct CareerPlanAttachmentTests {
    @Test("Only editable plans for this student, district, and assigned staff member are eligible")
    func filtersEligiblePlans() {
        let eligibleDraft = plan(id: "draft", status: .draft)
        let eligibleChanges = plan(id: "changes", status: .changesRequested)

        let result = CareerPlanAttachmentState.eligiblePlans(
            from: [
                eligibleDraft,
                eligibleChanges,
                plan(id: "active", status: .active),
                plan(id: "other-student", studentIDs: ["student-2"]),
                plan(id: "other-district", districtID: "district-2"),
                plan(id: "other-staff", assignedMemberIDs: ["member-2"]),
            ],
            studentID: "student-1",
            member: member
        )

        #expect(result.map(\.id) == ["changes", "draft"])
        #expect(CareerPlanAttachmentState.eligiblePlans(
            from: [eligibleDraft], studentID: "student-1", member: member(isActive: false)
        ).isEmpty)
        #expect(CareerPlanAttachmentState.eligiblePlans(
            from: [eligibleDraft], studentID: "student-1", member: member(capabilities: [])
        ).isEmpty)
        #expect(CareerPlanAttachmentState.eligiblePlans(
            from: [plan(id: "other-school", schoolIDs: ["school-2"])],
            studentID: "student-1",
            member: member
        ).isEmpty)
    }

    @Test("A failed callable never reports success")
    func failedAttachmentDoesNotConfirm() async {
        let repository = FakePlanRepository(records: [plan(id: "draft")])
        let attacher = FakeCareerPlanAttacher(error: TestError.failed)
        let state = CareerPlanAttachmentState()

        await state.load(studentID: "student-1", member: member, repository: repository)
        await state.attach(
            planID: "draft",
            careerID: "career-1",
            careerTitle: "Frontend Developer",
            studentID: "student-1",
            member: member,
            repository: repository,
            attacher: attacher
        )

        #expect(state.confirmation == nil)
        #expect(state.errorMessage != nil)
        #expect(state.isAttaching == false)
    }

    @Test("Callable response must return the same attachment identities")
    func validatesCallableResponseIdentity() throws {
        let expected = CareerPlanAttachmentRequest(
            districtID: "district-1",
            studentID: "student-1",
            careerID: "career-1",
            planID: "plan-1"
        )
        let valid = try FirebaseCareerPlanAttacher.decode([
            "districtID": "district-1",
            "studentID": "student-1",
            "careerID": "career-1",
            "planID": "plan-1",
        ], expected: expected)
        #expect(valid == expected)

        #expect(throws: CareerPlanAttachmentError.invalidResponse) {
            try FirebaseCareerPlanAttacher.decode([
                "districtID": "district-1",
                "studentID": "student-1",
                "careerID": "other-career",
                "planID": "plan-1",
            ], expected: expected)
        }
    }

    @Test("A successful callable refreshes plans before confirmation")
    func successfulAttachmentRefreshesPlans() async {
        let initial = plan(id: "draft")
        var refreshed = initial
        refreshed.relatedCareerIDs = ["career-1"]
        refreshed.metadata = CanonicalRecordMetadata(
            schemaVersion: 1,
            recordVersion: 2,
            createdAt: refreshed.metadata.createdAt,
            createdBy: refreshed.metadata.createdBy,
            updatedAt: refreshed.metadata.updatedAt,
            updatedBy: refreshed.metadata.updatedBy
        )
        let repository = FakePlanRepository(recordsByLoad: [[initial], [refreshed]])
        let attacher = FakeCareerPlanAttacher()
        let state = CareerPlanAttachmentState()

        await state.load(studentID: "student-1", member: member, repository: repository)
        await state.attach(
            planID: "draft",
            careerID: "career-1",
            careerTitle: "Frontend Developer",
            studentID: "student-1",
            member: member,
            repository: repository,
            attacher: attacher
        )

        #expect(state.confirmation == "Frontend Developer was attached to Draft plan.")
        #expect(state.plans.first?.metadata.recordVersion == 2)
        #expect(repository.loadCount == 2)
        #expect(attacher.requests == [
            CareerPlanAttachmentRequest(
                districtID: "district-1",
                studentID: "student-1",
                careerID: "career-1",
                planID: "draft"
            )
        ])
    }

    private var member: MembershipContext { member() }

    private func member(
        capabilities: Set<Capability> = [.studentReadDetail, .studentWriteDetail],
        isActive: Bool = true
    ) -> MembershipContext {
        MembershipContext(
            userID: "member-1",
            districtID: "district-1",
            schoolIDs: ["school-1"],
            role: .teacher,
            capabilities: capabilities,
            assignedStudentIDs: ["student-1"],
            isActive: isActive,
            version: 1
        )
    }

    private func plan(
        id: String,
        districtID: String = "district-1",
        studentIDs: Set<String> = ["student-1"],
        assignedMemberIDs: Set<String> = ["member-1"],
        schoolIDs: Set<String> = ["school-1"],
        status: PlanRecordStatus = .draft
    ) -> PlanRecord {
        PlanRecord(
            id: id,
            districtID: districtID,
            studentIDs: studentIDs,
            schoolIDs: schoolIDs,
            assignedMemberIDs: assignedMemberIDs,
            ownerMemberID: assignedMemberIDs.first ?? "member-1",
            status: status,
            model: .chaseYourSpace,
            title: id == "draft" ? "Draft plan" : id.capitalized,
            summary: nil,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            targetDate: nil,
            approvalStatus: .notRequested,
            metadata: CanonicalRecordMetadata(
                schemaVersion: 1,
                recordVersion: 1,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                createdBy: "member-1",
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                updatedBy: "member-1"
            )
        )
    }
}

@MainActor
private final class FakeCareerPlanAttacher: CareerPlanAttaching {
    private let error: Error?
    private(set) var requests: [CareerPlanAttachmentRequest] = []

    init(error: Error? = nil) {
        self.error = error
    }

    func attach(_ request: CareerPlanAttachmentRequest) async throws -> CareerPlanAttachmentRequest {
        requests.append(request)
        if let error { throw error }
        return request
    }
}

@MainActor
private final class FakePlanRepository: PlanRecordRepository {
    private let recordsByLoad: [[PlanRecord]]
    private(set) var loadCount = 0

    init(records: [PlanRecord]) {
        self.recordsByLoad = [records]
    }

    init(recordsByLoad: [[PlanRecord]]) {
        self.recordsByLoad = recordsByLoad
    }

    func plans(member _: MembershipContext) async throws -> [PlanRecord] {
        defer { loadCount += 1 }
        return recordsByLoad[min(loadCount, recordsByLoad.count - 1)]
    }

    func plan(id: String, member: MembershipContext) async throws -> PlanRecord {
        guard let record = try await plans(member: member).first(where: { $0.id == id }) else {
            throw PlanRecordRepositoryError.notFound
        }
        return record
    }

    func create(_ draft: PlanDraft, operationID: UUID, member: MembershipContext) async throws -> PlanRecord {
        throw PlanRecordRepositoryError.unavailable
    }

    func update(id: String, draft: PlanDraft, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord {
        throw PlanRecordRepositoryError.unavailable
    }

    func transition(id: String, to status: PlanRecordStatus, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord {
        throw PlanRecordRepositoryError.unavailable
    }
}

private enum TestError: Error {
    case failed
}
