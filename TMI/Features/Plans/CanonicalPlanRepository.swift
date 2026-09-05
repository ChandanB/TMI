import Foundation
import CryptoKit
@preconcurrency import FirebaseFunctions
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore

@MainActor
protocol PlanRecordRepository: Sendable {
    func plans(member: MembershipContext) async throws -> [PlanRecord]
    func plan(id: String, member: MembershipContext) async throws -> PlanRecord
    func create(
        _ draft: PlanDraft,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> PlanRecord
    func update(
        id: String,
        draft: PlanDraft,
        expectedVersion: Int,
        member: MembershipContext
    ) async throws -> PlanRecord
    func transition(
        id: String,
        to status: PlanRecordStatus,
        expectedVersion: Int,
        member: MembershipContext
    ) async throws -> PlanRecord
    func transition(id: String, to status: PlanRecordStatus, expectedVersion: Int,
                    note: String?, member: MembershipContext) async throws -> PlanRecord

}

extension PlanRecordRepository {
    func transition(id: String, to status: PlanRecordStatus, expectedVersion: Int,
                    note: String?, member: MembershipContext) async throws -> PlanRecord {
        try await transition(id: id, to: status, expectedVersion: expectedVersion, member: member)
    }
}

/// Canonical writes are transactional; lifecycle mutations are server-authorized.
@MainActor
final class CanonicalPlanRepository: PlanRecordRepository {
    private let transport: any CanonicalPlanTransport
    private let currentUserID: @Sendable () -> String?
    private let now: @Sendable () -> Date

    init(
        firestore: Firestore,
        currentUserID: @escaping @Sendable () -> String? = { Auth.auth().currentUser?.uid },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = FirebaseCanonicalPlanTransport(firestore: firestore)
        self.currentUserID = currentUserID
        self.now = now
    }

    init(
        transport: any CanonicalPlanTransport,
        currentUserID: @escaping @Sendable () -> String?,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = transport
        self.currentUserID = currentUserID
        self.now = now
    }

    func plans(member: MembershipContext) async throws -> [PlanRecord] {
        try authorize(member)
        do {
            let documents = try await transport.plans(member: member)
            try authorize(member)
            return try documents.map { document in
                try Self.decode(id: document.id, data: document.data, member: member)
            }.sorted { $0.metadata.updatedAt > $1.metadata.updatedAt }
        } catch { throw Self.mapped(error) }
    }

    func plan(id: String, member: MembershipContext) async throws -> PlanRecord {
        try authorize(member)
        do {
            let data = try await transport.plan(id: id, districtID: member.districtID)
            try authorize(member)
            guard let data else { throw PlanRecordRepositoryError.notFound }
            return try Self.decode(id: id, data: data, member: member)
        } catch { throw Self.mapped(error) }
    }

    func create(
        _ draft: PlanDraft, operationID: UUID, member: MembershipContext
    ) async throws -> PlanRecord {
        try authorize(member)
        let draft = draft.normalized
        let id = "plan_\(operationID.uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
        let timestamp = now()
        do {
            let result = try await transport.transaction(id: id, districtID: member.districtID) { data in
                // A replay must never reset edits or lifecycle state, even if the
                // caller's draft has changed since the original attempt.
                if let data {
                    return CanonicalPlanMutation(record: try Self.decode(id: id, data: data, member: member))
                }
                guard PlanValidation.issues(for: draft, member: member).isEmpty else {
                    throw PlanRecordRepositoryError.invalidDraft
                }
                var fields = Self.fields(from: draft, districtID: member.districtID)
                fields["status"] = PlanRecordStatus.draft.rawValue
                fields["approvalStatus"] = PlanApprovalState.notRequested.rawValue
                fields["schemaVersion"] = 1
                fields["recordVersion"] = 1
                fields["createdAt"] = Timestamp(date: timestamp)
                fields["createdBy"] = member.userID
                fields["updatedAt"] = Timestamp(date: timestamp)
                fields["updatedBy"] = member.userID
                return CanonicalPlanMutation(
                    record: try Self.decode(id: id, data: fields, member: member),
                    fields: fields, creates: true
                )
            }
            try authorize(member)
            return result
        } catch { throw Self.mapped(error) }
    }

    func update(
        id: String, draft: PlanDraft, expectedVersion: Int, member: MembershipContext
    ) async throws -> PlanRecord {
        try authorize(member)
        let draft = draft.normalized
        guard PlanValidation.issues(for: draft, member: member).isEmpty,
              expectedVersion > 0, expectedVersion < Int.max else {
            throw PlanRecordRepositoryError.invalidDraft
        }
        let timestamp = now()
        do {
            let result = try await transport.transaction(id: id, districtID: member.districtID) { data in
                guard let data else { throw PlanRecordRepositoryError.notFound }
                let existing = try Self.decode(id: id, data: data, member: member)
                guard existing.metadata.recordVersion == expectedVersion else {
                    throw PlanRecordRepositoryError.versionConflict(
                        expected: expectedVersion, actual: existing.metadata.recordVersion
                    )
                }
                guard existing.status == .draft || existing.status == .changesRequested,
                      draft.studentIDs == existing.studentIDs,
                      draft.schoolIDs == existing.schoolIDs else {
                    throw PlanRecordRepositoryError.invalidDraft
                }
                var fields = Self.fields(from: draft, districtID: member.districtID)
                fields.removeValue(forKey: "studentIDs")
                fields.removeValue(forKey: "schoolIDs")
                fields.removeValue(forKey: "districtId")
                fields["recordVersion"] = expectedVersion + 1
                fields["updatedAt"] = Timestamp(date: timestamp)
                fields["updatedBy"] = member.userID
                var result = data.merging(fields) { _, new in new }
                if draft.summary == nil {
                    fields["summary"] = FieldValue.delete()
                    result.removeValue(forKey: "summary")
                }
                if draft.targetDate == nil {
                    fields["targetDate"] = FieldValue.delete()
                    result.removeValue(forKey: "targetDate")
                }
                return CanonicalPlanMutation(
                    record: try Self.decode(id: id, data: result, member: member), fields: fields
                )
            }
            try authorize(member)
            return result
        } catch { throw Self.mapped(error) }
    }

    func transition(
        id: String, to status: PlanRecordStatus, expectedVersion: Int, member: MembershipContext
    ) async throws -> PlanRecord {
        try await transition(id: id, to: status, expectedVersion: expectedVersion, note: nil, member: member)
    }

    func transition(id: String, to status: PlanRecordStatus, expectedVersion: Int,
                    note: String?, member: MembershipContext) async throws -> PlanRecord {
        try authorize(member)
        guard expectedVersion > 0, expectedVersion < Int.max else {
            throw PlanRecordRepositoryError.invalidDraft
        }
        // Include actor and district because audit replay is bound to both.
        // JSON framing avoids ambiguity and SHA256 meets requireIdentifier's
        // alphabet and length limits regardless of the plan ID's length.
        let key = Self.transitionKey(id: id, status: status, version: expectedVersion, member: member, note: note)
        do {
            var payload: [String: Any] = [
                "districtID": member.districtID,
                "planID": id,
                "nextStatus": status.rawValue,
                "expectedRecordVersion": expectedVersion,
                "idempotencyKey": key,
                "reasonCode": "educator-plan-transition"
            ]
            if let note, !note.trimmed.isEmpty { payload["note"] = note.trimmed }
            try await transport.transition(payload: payload)
        } catch { throw Self.mapped(error) }
        // Do not pre-read/version-check: successful retries must reach the
        // callable's replay path even after the original version has advanced.
        return try await plan(id: id, member: member)
    }

    nonisolated static func transitionKey(
        id: String, status: PlanRecordStatus, version: Int, member: MembershipContext, note: String? = nil
    ) -> String {
        let parts = [member.districtID, member.userID, id, String(version), status.rawValue, note?.trimmed ?? ""]
        let framed = parts.map { "\($0.utf8.count):\($0)" }.joined()
        return "transition_" + SHA256.hash(data: Data(framed.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    private func authorize(_ member: MembershipContext) throws {
        guard member.isActive, !member.userID.isEmpty, !member.districtID.isEmpty,
              currentUserID() == member.userID else {
            throw PlanRecordRepositoryError.permissionDenied
        }
    }

    nonisolated private static func decode(
        id: String, data: [String: Any], member: MembershipContext
    ) throws -> PlanRecord {
        guard let record = record(id: id, data: data) else {
            throw PlanRecordRepositoryError.invalidResponse
        }
        guard record.districtID == member.districtID else {
            throw PlanRecordRepositoryError.permissionDenied
        }
        return record
    }

    // MARK: - Mapping

    nonisolated static func fields(from draft: PlanDraft, districtID: String) -> [String: Any] {
        var fields: [String: Any] = [
            "districtId": districtID,
            "studentIDs": draft.studentIDs.sorted(),
            "schoolIDs": draft.schoolIDs.sorted(),
            "assignedMemberIDs": draft.assignedMemberIDs.sorted(),
            "modelID": PlanModelIdentifier.identifier(for: draft.model),
            "title": draft.title,
            "startDate": Timestamp(date: draft.startDate)
        ]
        if let summary = draft.summary {
            fields["summary"] = summary
        }
        if let targetDate = draft.targetDate {
            fields["targetDate"] = Timestamp(date: targetDate)
        }
        return fields
    }

    nonisolated static func record(id: String, data: [String: Any]) -> PlanRecord? {
        guard let districtID = data["districtId"] as? String,
              let studentIDs = data["studentIDs"] as? [String], !studentIDs.isEmpty,
              let schoolIDs = data["schoolIDs"] as? [String], !schoolIDs.isEmpty,
              let title = data["title"] as? String,
              let modelID = data["modelID"] as? String,
              let model = PlanModelIdentifier.model(for: modelID),
              let status = (data["status"] as? String).flatMap({ PlanRecordStatus(rawValue: $0 == "submitted" ? "pendingApproval" : $0) }),
              let createdBy = data["createdBy"] as? String,
              let recordVersion = data["recordVersion"] as? Int, recordVersion > 0 else {
            return nil
        }
        // Older records may omit metadata, but a present malformed value is
        // never treated as an absent optional or replaced with a default.
        guard !id.isEmpty, !districtID.isEmpty, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !createdBy.isEmpty,
              data["summary"] == nil || data["summary"] is String,
              data["targetDate"] == nil || data["targetDate"] is Timestamp,
              data["startDate"] == nil || data["startDate"] is Timestamp,
              data["createdAt"] == nil || data["createdAt"] is Timestamp,
              data["updatedAt"] == nil || data["updatedAt"] is Timestamp,
              data["updatedBy"] == nil || data["updatedBy"] is String,
              data["assignedMemberIDs"] == nil || data["assignedMemberIDs"] is [String],
              data["schemaVersion"] == nil || (data["schemaVersion"] as? Int).map({ $0 > 0 }) == true,
              data["approvalStatus"] == nil || (data["approvalStatus"] as? String)
                .flatMap(PlanApprovalState.init(rawValue:)) != nil else {
            return nil
        }
        let approval = (data["approvalStatus"] as? String)
            .flatMap(PlanApprovalState.init(rawValue:)) ?? .notRequested
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        return PlanRecord(
            id: id,
            districtID: districtID,
            studentIDs: Set(studentIDs),
            schoolIDs: Set(schoolIDs),
            assignedMemberIDs: Set((data["assignedMemberIDs"] as? [String]) ?? []),
            status: status,
            model: model,
            title: title,
            summary: data["summary"] as? String,
            startDate: (data["startDate"] as? Timestamp)?.dateValue() ?? createdAt,
            targetDate: (data["targetDate"] as? Timestamp)?.dateValue(),
            approvalStatus: approval,
            metadata: CanonicalRecordMetadata(
                schemaVersion: (data["schemaVersion"] as? Int) ?? 1,
                recordVersion: recordVersion,
                createdAt: createdAt,
                createdBy: createdBy,
                updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt,
                updatedBy: (data["updatedBy"] as? String) ?? createdBy
            )
        )
    }

    nonisolated static func mapped(_ error: Error) -> PlanRecordRepositoryError {
        if let error = error as? PlanRecordRepositoryError { return error }
        let error = error as NSError
        if error.domain == FunctionsErrorDomain {
            switch FunctionsErrorCode(rawValue: error.code) {
            case .permissionDenied, .unauthenticated: return .permissionDenied
            // A missing callable is unavailable; do not claim the plan is absent.
            case .notFound, .unavailable, .deadlineExceeded: return .unavailable
            case .invalidArgument: return .invalidDraft
            case .aborted:
                if let details = error.userInfo[FunctionsErrorDetailsKey] as? [String: Any],
                   details["kind"] as? String == "record-version-conflict",
                   let expected = details["expectedRecordVersion"] as? Int,
                   let actual = details["actualRecordVersion"] as? Int,
                   expected > 0, actual > 0 {
                    return .versionConflict(expected: expected, actual: actual)
                }
                return .invalidResponse
            default: return .invalidResponse
            }
        }
        guard error.domain == FirestoreErrorDomain else { return .invalidResponse }
        switch FirestoreErrorCode.Code(rawValue: error.code) {
        case .permissionDenied, .unauthenticated: return .permissionDenied
        case .notFound: return .notFound
        case .unavailable, .deadlineExceeded: return .unavailable
        default: return .invalidResponse
        }
    }
}

/// The transaction callback is shared by production and tests. It must be pure:
/// Firestore may invoke it again after a competing writer commits.
nonisolated struct CanonicalPlanMutation {
    let record: PlanRecord
    var fields: [String: Any]? = nil
    var creates = false
}

@MainActor
protocol CanonicalPlanTransport {
    func plans(member: MembershipContext) async throws -> [(id: String, data: [String: Any])]
    func plan(id: String, districtID: String) async throws -> [String: Any]?
    func transaction(
        id: String, districtID: String,
        mutation: @escaping @Sendable ([String: Any]?) throws -> CanonicalPlanMutation
    ) async throws -> PlanRecord
    func transition(payload: [String: Any]) async throws
}

@MainActor
private final class FirebaseCanonicalPlanTransport: CanonicalPlanTransport {
    private let firestore: Firestore

    init(firestore: Firestore) { self.firestore = firestore }

    private func collection(_ districtID: String) -> CollectionReference {
        firestore.collection("districts").document(districtID).collection("plans")
    }

    func plans(member: MembershipContext) async throws -> [(id: String, data: [String: Any])] {
        let plans = collection(member.districtID)

        switch member.role {
        case .districtAdministrator:
            let snapshot = try await plans.getDocuments(source: .server)
            return snapshot.documents.map { (id: $0.documentID, data: $0.data()) }

        case .teacher, .schoolAdministrator:
            return try await schoolScopedPlans(in: plans, member: member, requiresAssignment: false)

        case .counselor, .socialWorker:
            return try await schoolScopedPlans(in: plans, member: member, requiresAssignment: true)
        }
    }

    private func schoolScopedPlans(
        in plans: CollectionReference,
        member: MembershipContext,
        requiresAssignment: Bool
    ) async throws -> [(id: String, data: [String: Any])] {
        var documentsByID: [String: [String: Any]] = [:]

        for schoolID in member.schoolIDs.sorted() {
            var query: Query = plans.whereField("schoolIDs", isEqualTo: [schoolID])
            if requiresAssignment {
                query = query.whereField("assignedMemberIDs", arrayContains: member.userID)
            }
            let snapshot = try await query.getDocuments(source: .server)
            for document in snapshot.documents {
                documentsByID[document.documentID] = document.data()
            }
        }

        return documentsByID.map { (id: $0.key, data: $0.value) }
    }

    func plan(id: String, districtID: String) async throws -> [String: Any]? {
        try await collection(districtID).document(id).getDocument(source: .server).data()
    }

    func transaction(
        id: String, districtID: String,
        mutation: @escaping @Sendable ([String: Any]?) throws -> CanonicalPlanMutation
    ) async throws -> PlanRecord {
        let reference = collection(districtID).document(id)
        let block: @Sendable (Transaction, NSErrorPointer) -> Any? = { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(reference)
                let decision = try mutation(snapshot.data())
                if let fields = decision.fields {
                    if decision.creates {
                        transaction.setData(fields, forDocument: reference)
                    } else {
                        transaction.updateData(fields, forDocument: reference)
                    }
                }
                return decision.record
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.firestore.runTransaction(block) { result, error in
                if let error { continuation.resume(throwing: error) }
                else if let record = result as? PlanRecord { continuation.resume(returning: record) }
                else { continuation.resume(throwing: PlanRecordRepositoryError.invalidResponse) }
            }
        }
    }

    func transition(payload: [String: Any]) async throws {
        let encoded = try JSONSerialization.data(withJSONObject: payload)
        let receipt = try await Self.invokeTransition(encoded: encoded)
        guard receipt.operationID == payload["idempotencyKey"] as? String,
              let expected = payload["expectedRecordVersion"] as? Int,
              receipt.version == expected + 1 else {
            throw PlanRecordRepositoryError.invalidResponse
        }
    }

    // Only serialized bytes cross actors; Firebase's untyped payload stays local.
    @concurrent
    nonisolated private static func invokeTransition(encoded: Data) async throws -> (operationID: String, version: Int) {
        let payload = try JSONSerialization.jsonObject(with: encoded)
        let result = try await Functions.functions(region: "us-central1")
            .httpsCallable("transitionPlan").call(payload)
        guard let data = result.data as? [String: Any],
              let operationID = data["operationID"] as? String,
              let version = data["recordVersion"] as? Int else {
            throw PlanRecordRepositoryError.invalidResponse
        }
        return (operationID, version)
    }
}
