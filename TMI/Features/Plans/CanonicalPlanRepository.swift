import Foundation
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
}

/// Reads and writes canonical plans directly against Firestore.
///
/// `transitionPlan` is the authoritative path for status changes wherever
/// Cloud Functions are deployed. With Functions unavailable the transition
/// table lives in `firestore.rules` and is mirrored by `PlanLifecycle`, so an
/// illegal transition fails locally before it is attempted and is refused
/// server-side regardless.
@MainActor
final class CanonicalPlanRepository: PlanRecordRepository {
    private let firestore: Firestore
    private let currentUserID: @Sendable () -> String?
    private let now: @Sendable () -> Date

    init(
        firestore: Firestore,
        currentUserID: @escaping @Sendable () -> String? = { Auth.auth().currentUser?.uid },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.firestore = firestore
        self.currentUserID = currentUserID
        self.now = now
    }

    func plans(member: MembershipContext) async throws -> [PlanRecord] {
        let query = collection(districtID: member.districtID)
            .whereField("assignedMemberIDs", arrayContains: member.userID)
        do {
            let snapshot = try await query.getDocuments()
            return snapshot.documents.compactMap { document in
                Self.record(id: document.documentID, data: document.data())
            }
            .sorted { $0.metadata.updatedAt > $1.metadata.updatedAt }
        } catch {
            throw Self.mapped(error)
        }
    }

    func plan(id: String, member: MembershipContext) async throws -> PlanRecord {
        let snapshot: DocumentSnapshot
        do {
            snapshot = try await reference(districtID: member.districtID, planID: id)
                .getDocument()
        } catch {
            throw Self.mapped(error)
        }
        guard let data = snapshot.data(),
              let record = Self.record(id: snapshot.documentID, data: data) else {
            throw PlanRecordRepositoryError.notFound
        }
        return record
    }

    func create(
        _ draft: PlanDraft,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> PlanRecord {
        let draft = draft.normalized
        guard PlanValidation.issues(for: draft, member: member).isEmpty else {
            throw PlanRecordRepositoryError.invalidDraft
        }
        let userID = try requireUserID()
        let planID = "plan_\(operationID.uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
        let reference = reference(districtID: member.districtID, planID: planID)
        let timestamp = now()

        var fields = Self.fields(from: draft, districtID: member.districtID)
        fields["status"] = PlanRecordStatus.draft.rawValue
        fields["approvalStatus"] = PlanApprovalState.notRequested.rawValue
        fields["schemaVersion"] = 1
        fields["recordVersion"] = 1
        fields["createdAt"] = Timestamp(date: timestamp)
        fields["createdBy"] = userID
        fields["updatedAt"] = Timestamp(date: timestamp)
        fields["updatedBy"] = userID

        do {
            try await reference.setData(fields)
        } catch {
            throw Self.mapped(error)
        }
        return try await plan(id: planID, member: member)
    }

    func update(
        id: String,
        draft: PlanDraft,
        expectedVersion: Int,
        member: MembershipContext
    ) async throws -> PlanRecord {
        let draft = draft.normalized
        guard PlanValidation.issues(for: draft, member: member).isEmpty else {
            throw PlanRecordRepositoryError.invalidDraft
        }
        let userID = try requireUserID()
        let existing = try await plan(id: id, member: member)
        guard existing.metadata.recordVersion == expectedVersion else {
            throw PlanRecordRepositoryError.versionConflict(
                expected: expectedVersion,
                actual: existing.metadata.recordVersion
            )
        }
        // Scope is immutable once a plan exists; the rules reject any change to
        // it, so refuse locally rather than sending a doomed write.
        guard draft.studentIDs == existing.studentIDs,
              draft.schoolIDs == existing.schoolIDs else {
            throw PlanRecordRepositoryError.invalidDraft
        }

        var fields = Self.fields(from: draft, districtID: member.districtID)
        fields.removeValue(forKey: "studentIDs")
        fields.removeValue(forKey: "schoolIDs")
        fields.removeValue(forKey: "districtId")
        fields["recordVersion"] = expectedVersion + 1
        fields["updatedAt"] = Timestamp(date: now())
        fields["updatedBy"] = userID

        do {
            try await reference(districtID: member.districtID, planID: id)
                .updateData(fields)
        } catch {
            throw Self.mapped(error)
        }
        return try await plan(id: id, member: member)
    }

    func transition(
        id: String,
        to status: PlanRecordStatus,
        expectedVersion: Int,
        member: MembershipContext
    ) async throws -> PlanRecord {
        let userID = try requireUserID()
        let existing = try await plan(id: id, member: member)
        guard existing.metadata.recordVersion == expectedVersion else {
            throw PlanRecordRepositoryError.versionConflict(
                expected: expectedVersion,
                actual: existing.metadata.recordVersion
            )
        }
        guard PlanLifecycle.isLegal(from: existing.status, to: status) else {
            throw PlanRecordRepositoryError.illegalTransition(
                from: existing.status,
                to: status
            )
        }

        do {
            try await reference(districtID: member.districtID, planID: id)
                .updateData([
                    "status": status.rawValue,
                    "recordVersion": expectedVersion + 1,
                    "updatedAt": Timestamp(date: now()),
                    "updatedBy": userID
                ])
        } catch {
            throw Self.mapped(error)
        }
        return try await plan(id: id, member: member)
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
              let status = (data["status"] as? String).flatMap(PlanRecordStatus.init(rawValue:)),
              let createdBy = data["createdBy"] as? String,
              let recordVersion = data["recordVersion"] as? Int, recordVersion > 0 else {
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

    // MARK: - Firestore access

    private func collection(districtID: String) -> CollectionReference {
        firestore.collection("districts").document(districtID).collection("plans")
    }

    private func reference(districtID: String, planID: String) -> DocumentReference {
        collection(districtID: districtID).document(planID)
    }

    private func requireUserID() throws -> String {
        guard let userID = currentUserID(), !userID.isEmpty else {
            throw PlanRecordRepositoryError.permissionDenied
        }
        return userID
    }

    nonisolated private static func mapped(_ error: Error) -> PlanRecordRepositoryError {
        if let planError = error as? PlanRecordRepositoryError {
            return planError
        }
        switch FirestoreErrorCode.Code(rawValue: (error as NSError).code) {
        case .permissionDenied: return .permissionDenied
        case .notFound: return .notFound
        case .unavailable, .deadlineExceeded: return .unavailable
        default: return .invalidResponse
        }
    }
}
