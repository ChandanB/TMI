import Foundation
import FirebaseFirestore
import FirebaseFunctions
import Testing
@testable import TMI

@MainActor
struct CanonicalPlanRepositoryTests {
    private let member = MembershipContext(
        userID: "teacher-1", districtID: "district-1", schoolIDs: ["school-1"],
        role: .teacher, capabilities: [.studentReadDetail, .studentWriteDetail],
        assignedStudentIDs: ["student-1"], isActive: true, version: 1
    )
    private let date = Date(timeIntervalSince1970: 1_000)

    private func draft() -> PlanDraft {
        PlanDraft(
            studentIDs: ["student-1"], schoolIDs: ["school-1"], assignedMemberIDs: ["teacher-1"],
            ownerMemberID: "teacher-1",
            model: .chaseYourSpace, title: "A plan", summary: "Summary", startDate: date,
            targetDate: date.addingTimeInterval(1_000)
        )
    }

    private func repository(_ transport: MemoryPlanTransport) -> CanonicalPlanRepository {
        CanonicalPlanRepository(transport: transport, currentUserID: { "teacher-1" }, now: { self.date })
    }

    @Test("Create replay preserves subsequent edits and lifecycle metadata")
    func createReplay() async throws {
        let transport = MemoryPlanTransport()
        let repository = repository(transport)
        let operation = UUID()
        let first = try await repository.create(draft(), operationID: operation, member: member)
        transport.document?["title"] = "Subsequent edit"
        transport.document?["recordVersion"] = 5
        transport.document?["status"] = "active"
        var replacement = draft()
        replacement.title = ""
        let replay = try await repository.create(replacement, operationID: operation, member: member)
        #expect(replay.id == first.id)
        #expect(replay.title == "Subsequent edit")
        #expect(replay.status == .active)
        #expect(replay.metadata.recordVersion == 5)
        #expect(transport.writes == 1)
        #expect(transport.transactionIDs == [first.id, first.id])
    }

    @Test("Update removes optional values and preserves creation metadata")
    func clearsOptionals() async throws {
        let transport = MemoryPlanTransport()
        let repository = repository(transport)
        let first = try await repository.create(draft(), operationID: UUID(), member: member)
        var edit = draft()
        edit.summary = "   "
        edit.targetDate = nil
        let updated = try await repository.update(id: first.id, draft: edit, expectedVersion: 1, member: member)
        #expect(transport.lastFields?["summary"] is FieldValue)
        #expect(transport.lastFields?["targetDate"] is FieldValue)
        #expect(updated.summary == nil)
        #expect(updated.targetDate == nil)
        #expect(updated.metadata.createdAt == first.metadata.createdAt)
        #expect(updated.metadata.recordVersion == 2)
        let refreshed = try await repository.plan(id: first.id, member: member)
        #expect(refreshed == updated)
    }

    @Test("Transaction retries recheck a competing writer's version")
    func retryChecksVersion() async throws {
        let transport = MemoryPlanTransport()
        let repository = repository(transport)
        let first = try await repository.create(draft(), operationID: UUID(), member: member)
        transport.retryWithVersion = 2
        await #expect(throws: PlanRecordRepositoryError.versionConflict(expected: 1, actual: 2)) {
            try await repository.update(id: first.id, draft: self.draft(), expectedVersion: 1, member: self.member)
        }
        #expect(transport.writes == 1)
    }

    @Test("Only draft and changesRequested permit content edits")
    func editability() async throws {
        for status in PlanRecordStatus.allCases {
            let transport = MemoryPlanTransport()
            let repository = repository(transport)
            let first = try await repository.create(draft(), operationID: UUID(), member: member)
            transport.document?["status"] = status.rawValue
            if status == .draft || status == .changesRequested {
                let result = try await repository.update(id: first.id, draft: draft(), expectedVersion: 1, member: member)
                #expect(result.status == status)
            } else {
                await #expect(throws: PlanRecordRepositoryError.invalidDraft) {
                    try await repository.update(id: first.id, draft: self.draft(), expectedVersion: 1, member: self.member)
                }
                #expect(transport.writes == 1)
            }
        }
    }

    @Test("Missing, wrong, and inactive identity cannot access any operation")
    func authorization() async throws {
        for uid: String? in [nil, "someone-else", "teacher-1"] {
            let transport = MemoryPlanTransport()
            let repository = CanonicalPlanRepository(transport: transport, currentUserID: { uid })
            let context = MembershipContext(
                userID: member.userID, districtID: member.districtID, schoolIDs: member.schoolIDs,
                role: member.role, capabilities: member.capabilities, assignedStudentIDs: [],
                isActive: uid != "teacher-1", version: 1
            )
            await #expect(throws: PlanRecordRepositoryError.permissionDenied) {
                try await repository.plans(member: context)
            }
            await #expect(throws: PlanRecordRepositoryError.permissionDenied) {
                try await repository.plan(id: "plan", member: context)
            }
            await #expect(throws: PlanRecordRepositoryError.permissionDenied) {
                try await repository.create(self.draft(), operationID: UUID(), member: context)
            }
            await #expect(throws: PlanRecordRepositoryError.permissionDenied) {
                try await repository.update(id: "plan", draft: self.draft(), expectedVersion: 1, member: context)
            }
            await #expect(throws: PlanRecordRepositoryError.permissionDenied) {
                try await repository.transition(id: "plan", to: .active, expectedVersion: 1, member: context)
            }
            #expect(transport.calls == 0)
        }
    }

    @Test("Malformed documents fail the entire list and individual reads")
    func malformedReads() async throws {
        let transport = MemoryPlanTransport()
        let repository = repository(transport)
        _ = try await repository.create(draft(), operationID: UUID(), member: member)
        transport.extraDocuments = [(id: "broken", data: ["title": "Broken"])]
        await #expect(throws: PlanRecordRepositoryError.invalidResponse) {
            try await repository.plans(member: self.member)
        }
        transport.document?["targetDate"] = "not a timestamp"
        await #expect(throws: PlanRecordRepositoryError.invalidResponse) {
            try await repository.plan(id: "plan", member: self.member)
        }
        transport.document = nil
        await #expect(throws: PlanRecordRepositoryError.notFound) {
            try await repository.plan(id: "plan", member: self.member)
        }
    }

    @Test("Canonical plans persist an owner while legacy creator ownership remains readable")
    func ownershipAndApprovalAssignment() async throws {
        let transport = MemoryPlanTransport()
        let repository = repository(transport)
        let created = try await repository.create(draft(), operationID: UUID(), member: member)

        #expect(created.ownerMemberID == "teacher-1")
        #expect(created.approverMemberIDs.isEmpty)
        #expect(transport.document?["ownerMemberID"] as? String == "teacher-1")
        #expect(transport.document?["approverMemberIDs"] as? [String] == [])

        transport.document?.removeValue(forKey: "ownerMemberID")
        let legacy = try await repository.plan(id: created.id, member: member)
        #expect(legacy.ownerMemberID == "teacher-1")

        transport.document?["ownerMemberID"] = 123
        await #expect(throws: PlanRecordRepositoryError.invalidResponse) {
            try await repository.plan(id: created.id, member: self.member)
        }

        transport.document?["ownerMemberID"] = "teacher-1"
        transport.document?["approverMemberIDs"] = ["approver-2", "approver-1"]
        let refreshed = try await repository.plan(id: created.id, member: member)
        #expect(refreshed.ownerMemberID == "teacher-1")
        #expect(refreshed.approverMemberIDs == ["approver-1", "approver-2"])
    }

    @Test("Transition calls server before refreshing and reuses a stable key")
    func transitionReplay() async throws {
        let transport = MemoryPlanTransport()
        let repository = repository(transport)
        let first = try await repository.create(draft(), operationID: UUID(), member: member)
        transport.transitionStatus = .active
        let result = try await repository.transition(id: first.id, to: .active, expectedVersion: 1, member: member)
        #expect(result.status == .active)
        #expect(result.metadata.recordVersion == 2)
        _ = try await repository.transition(id: first.id, to: .active, expectedVersion: 1, member: member)
        #expect(transport.events.suffix(4) == ["transition", "read", "transition", "read"])
        let payload = try #require(transport.payloads.first)
        #expect(payload["idempotencyKey"] as? String == transport.payloads.last?["idempotencyKey"] as? String)
        #expect(payload["districtID"] as? String == member.districtID)
        #expect(payload["planID"] as? String == first.id)
        #expect(payload["nextStatus"] as? String == "active")
        #expect(payload["expectedRecordVersion"] as? Int == 1)
        #expect(payload["reasonCode"] as? String == "educator-plan-transition")
        let key = try #require(payload["idempotencyKey"] as? String)
        #expect(key.utf8.count <= 128)
        #expect(key != CanonicalPlanRepository.transitionKey(id: first.id, status: .active, version: 2, member: member))
        #expect(key != CanonicalPlanRepository.transitionKey(id: first.id, status: .paused, version: 1, member: member))
    }

    @Test("Callable failure never returns a cached record or writes directly")
    func transitionFailure() async throws {
        let transport = MemoryPlanTransport()
        let repository = repository(transport)
        transport.transitionError = NSError(domain: FunctionsErrorDomain, code: FunctionsErrorCode.unavailable.rawValue)
        await #expect(throws: PlanRecordRepositoryError.unavailable) {
            try await repository.transition(id: "plan", to: .active, expectedVersion: 1, member: self.member)
        }
        #expect(transport.events == ["transition"])
        #expect(transport.writes == 0)
    }

    @Test("Error mapping respects domains and backend conflict details")
    func errorMappings() {
        #expect(CanonicalPlanRepository.mapped(NSError(domain: "unrelated", code: 7)) == .invalidResponse)
        #expect(CanonicalPlanRepository.mapped(NSError(domain: FunctionsErrorDomain, code: 5)) == .unavailable)
        #expect(CanonicalPlanRepository.mapped(NSError(domain: FirestoreErrorDomain, code: 5)) == .notFound)
        #expect(CanonicalPlanRepository.mapped(NSError(domain: FunctionsErrorDomain, code: 16)) == .permissionDenied)
        #expect(CanonicalPlanRepository.mapped(NSError(domain: FunctionsErrorDomain, code: 10, userInfo: [
            FunctionsErrorDetailsKey: ["kind": "record-version-conflict", "expectedRecordVersion": 1, "actualRecordVersion": 3]
        ])) == .versionConflict(expected: 1, actual: 3))
        #expect(CanonicalPlanRepository.mapped(NSError(domain: FunctionsErrorDomain, code: 10)) == .invalidResponse)
    }
}

@MainActor
private final class MemoryPlanTransport: CanonicalPlanTransport {
    var document: [String: Any]?
    var extraDocuments: [(id: String, data: [String: Any])] = []
    var lastFields: [String: Any]?
    var writes = 0
    var calls = 0
    var transactionIDs: [String] = []
    var retryWithVersion: Int?
    var events: [String] = []
    var payloads: [[String: Any]] = []
    var transitionStatus: PlanRecordStatus?
    var transitionError: Error?

    func plans(member: MembershipContext) async throws -> [(id: String, data: [String: Any])] {
        calls += 1
        return (document.map { [(id: "plan", data: $0)] } ?? []) + extraDocuments
    }

    func plan(id: String, districtID: String) async throws -> [String: Any]? {
        calls += 1
        events.append("read")
        return document
    }

    func transaction(
        id: String, districtID: String,
        mutation: @escaping @Sendable ([String: Any]?) throws -> CanonicalPlanMutation
    ) async throws -> PlanRecord {
        calls += 1
        transactionIDs.append(id)
        var decision = try mutation(document)
        if let version = retryWithVersion {
            document?["recordVersion"] = version
            retryWithVersion = nil
            decision = try mutation(document)
        }
        if let fields = decision.fields {
            writes += 1
            lastFields = fields
            if decision.creates { document = fields }
            else {
                for (key, value) in fields {
                    if value is FieldValue { document?.removeValue(forKey: key) }
                    else { document?[key] = value }
                }
            }
        }
        return decision.record
    }

    func transition(payload: [String: Any]) async throws {
        calls += 1
        events.append("transition")
        payloads.append(payload)
        if let transitionError { throw transitionError }
        if let transitionStatus, let expected = payload["expectedRecordVersion"] as? Int {
            document?["status"] = transitionStatus.rawValue
            document?["recordVersion"] = expected + 1
        }
    }
}
