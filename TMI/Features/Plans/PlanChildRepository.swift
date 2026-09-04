import Foundation
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore

/// Reads and writes the records that live under a plan.
///
/// Goals and actions are editable. Progress and revisions are not: the rules
/// refuse an update or a delete on either, so a correction is a new entry and
/// a history cannot be quietly rewritten.
@MainActor
protocol PlanChildRepositoryProtocol: Sendable {
    func goals(planID: String, member: MembershipContext) async throws -> [GoalRecord]
    func actions(planID: String, member: MembershipContext) async throws -> [ActionRecord]
    func progress(planID: String, member: MembershipContext) async throws -> [ProgressRecord]
    func revisions(planID: String, member: MembershipContext) async throws -> [PlanRevision]

    func save(goal: GoalRecord, member: MembershipContext) async throws
    func save(action: ActionRecord, member: MembershipContext) async throws
    func append(progress: ProgressRecord, member: MembershipContext) async throws
    func freeze(revision: PlanRevision, member: MembershipContext) async throws
}

@MainActor
final class PlanChildRepository: PlanChildRepositoryProtocol {
    private let firestore: Firestore
    private let currentUserID: @Sendable () -> String?

    init(
        firestore: Firestore,
        currentUserID: @escaping @Sendable () -> String? = { Auth.auth().currentUser?.uid }
    ) {
        self.firestore = firestore
        self.currentUserID = currentUserID
    }

    // MARK: - Reads

    func goals(planID: String, member: MembershipContext) async throws -> [GoalRecord] {
        try await read(planID: planID, child: "goals", member: member) { id, data in
            Self.goal(id: id, data: data)
        }
        .sorted { $0.dueDate == $1.dueDate ? $0.id < $1.id : $0.dueDate < $1.dueDate }
    }

    func actions(planID: String, member: MembershipContext) async throws -> [ActionRecord] {
        try await read(planID: planID, child: "actions", member: member) { id, data in
            Self.action(id: id, data: data)
        }
        .sorted { $0.dueDate == $1.dueDate ? $0.id < $1.id : $0.dueDate < $1.dueDate }
    }

    func progress(planID: String, member: MembershipContext) async throws -> [ProgressRecord] {
        let entries = try await read(planID: planID, child: "progress", member: member) { id, data in
            Self.progressRecord(id: id, data: data)
        }
        // Server time decides the order, so a device with a wrong clock cannot
        // reorder someone's history.
        return entries.sorted {
            $0.recordedAt == $1.recordedAt ? $0.id < $1.id : $0.recordedAt < $1.recordedAt
        }
    }

    func revisions(planID: String, member: MembershipContext) async throws -> [PlanRevision] {
        let frozen = try await read(planID: planID, child: "revisions", member: member) { id, data in
            Self.revision(id: id, data: data)
        }
        return PlanRevisionHistory.ordered(frozen)
    }

    // MARK: - Writes

    func save(goal: GoalRecord, member: MembershipContext) async throws {
        try await write(
            planID: goal.planID,
            child: "goals",
            id: goal.id,
            data: Self.fields(goal),
            member: member,
            merge: true
        )
    }

    func save(action: ActionRecord, member: MembershipContext) async throws {
        try await write(
            planID: action.planID,
            child: "actions",
            id: action.id,
            data: Self.fields(action),
            member: member,
            merge: true
        )
    }

    /// Appends one observation. The rules refuse an update, so this can only
    /// ever add to the history.
    func append(progress: ProgressRecord, member: MembershipContext) async throws {
        try await write(
            planID: progress.planID,
            child: "progress",
            id: progress.id,
            data: Self.fields(progress),
            member: member,
            merge: false
        )
    }

    /// Freezes what was agreed. Refused if it names anyone but the caller as
    /// its author, and immutable once written.
    func freeze(revision: PlanRevision, member: MembershipContext) async throws {
        guard revision.frozenBy == member.userID else {
            throw PlanRecordRepositoryError.permissionDenied
        }
        try await write(
            planID: revision.planID,
            child: "revisions",
            id: revision.id,
            data: Self.fields(revision),
            member: member,
            merge: false
        )
    }

    // MARK: - Plumbing

    private func collection(
        districtID: String,
        planID: String,
        child: String
    ) -> CollectionReference {
        firestore
            .collection("districts").document(districtID)
            .collection("plans").document(planID)
            .collection(child)
    }

    private func read<T>(
        planID: String,
        child: String,
        member: MembershipContext,
        transform: (String, [String: Any]) -> T?
    ) async throws -> [T] {
        do {
            let snapshot = try await collection(
                districtID: member.districtID,
                planID: planID,
                child: child
            ).getDocuments()
            return snapshot.documents.compactMap { transform($0.documentID, $0.data()) }
        } catch {
            throw Self.mapped(error)
        }
    }

    private func write(
        planID: String,
        child: String,
        id: String,
        data: [String: Any],
        member: MembershipContext,
        merge: Bool
    ) async throws {
        guard currentUserID() != nil else {
            throw PlanRecordRepositoryError.permissionDenied
        }
        do {
            try await collection(districtID: member.districtID, planID: planID, child: child)
                .document(id)
                .setData(data, merge: merge)
        } catch {
            throw Self.mapped(error)
        }
    }

    private static func mapped(_ error: Error) -> PlanRecordRepositoryError {
        let nsError = error as NSError
        guard nsError.domain == FirestoreErrorDomain else { return .invalidResponse }
        switch FirestoreErrorCode.Code(rawValue: nsError.code) {
        case .permissionDenied: return .permissionDenied
        case .notFound: return .notFound
        case .unavailable: return .unavailable
        default: return .invalidResponse
        }
    }
}

// MARK: - Encoding

nonisolated extension PlanChildRepository {
    static func fields(_ goal: GoalRecord) -> [String: Any] {
        [
            "schemaVersion": 1,
            "planID": goal.planID,
            "studentID": goal.studentID,
            "title": goal.title,
            "studentFacingTitle": goal.studentFacingTitle as Any,
            "measure": goal.measure.rawValue,
            "baseline": goal.baseline,
            "target": goal.target,
            "dueDate": Timestamp(date: goal.dueDate),
            "responsibleMemberID": goal.responsibleMemberID,
            "status": goal.status.rawValue,
        ]
    }

    static func fields(_ action: ActionRecord) -> [String: Any] {
        [
            "schemaVersion": 1,
            "planID": action.planID,
            "goalID": action.goalID,
            "title": action.title,
            "ownerMemberID": action.ownerMemberID,
            "audience": action.audience.rawValue,
            "cadence": action.cadence.rawValue,
            "dueDate": Timestamp(date: action.dueDate),
            "status": action.status.rawValue,
        ]
    }

    static func fields(_ entry: ProgressRecord) -> [String: Any] {
        [
            "schemaVersion": 1,
            "planID": entry.planID,
            "studentID": entry.studentID,
            "source": entry.source.rawValue,
            "sourceID": entry.sourceID,
            "measuredValue": entry.measuredValue as Any,
            "note": entry.note as Any,
            "visibility": entry.visibility.rawValue,
            "authorID": entry.authorID,
            // The server stamps the time an entry is recorded, so ordering does
            // not depend on the device's clock.
            "recordedAt": FieldValue.serverTimestamp(),
        ]
    }

    static func fields(_ revision: PlanRevision) -> [String: Any] {
        [
            "schemaVersion": 1,
            "planID": revision.planID,
            "sequence": revision.sequence,
            "reason": revision.reason.rawValue,
            "status": revision.status.rawValue,
            "model": revision.model.rawValue,
            "title": revision.title,
            "summary": revision.summary as Any,
            "startDate": Timestamp(date: revision.startDate),
            "targetDate": revision.targetDate.map { Timestamp(date: $0) } as Any,
            "goalIDs": revision.goalIDs,
            "actionIDs": revision.actionIDs,
            "frozenBy": revision.frozenBy,
            "frozenAt": FieldValue.serverTimestamp(),
            "note": revision.note as Any,
        ]
    }

    // MARK: - Decoding

    static func goal(id: String, data: [String: Any]) -> GoalRecord? {
        guard let planID = data["planID"] as? String,
              let studentID = data["studentID"] as? String,
              let title = data["title"] as? String,
              let measure = (data["measure"] as? String).flatMap(GoalMeasure.init(rawValue:)),
              let baseline = data["baseline"] as? String,
              let target = data["target"] as? String,
              let dueDate = (data["dueDate"] as? Timestamp)?.dateValue(),
              let responsibleMemberID = data["responsibleMemberID"] as? String,
              let status = (data["status"] as? String).flatMap(GoalRecordStatus.init(rawValue:))
        else { return nil }
        return GoalRecord(
            id: id,
            planID: planID,
            studentID: studentID,
            title: title,
            studentFacingTitle: data["studentFacingTitle"] as? String,
            measure: measure,
            baseline: baseline,
            target: target,
            dueDate: dueDate,
            responsibleMemberID: responsibleMemberID,
            status: status
        )
    }

    static func action(id: String, data: [String: Any]) -> ActionRecord? {
        guard let planID = data["planID"] as? String,
              let goalID = data["goalID"] as? String,
              let title = data["title"] as? String,
              let ownerMemberID = data["ownerMemberID"] as? String,
              let audience = (data["audience"] as? String).flatMap(ActionAudience.init(rawValue:)),
              let cadence = (data["cadence"] as? String).flatMap(ActionCadence.init(rawValue:)),
              let dueDate = (data["dueDate"] as? Timestamp)?.dateValue(),
              let status = (data["status"] as? String).flatMap(ActionStatus.init(rawValue:))
        else { return nil }
        return ActionRecord(
            id: id,
            planID: planID,
            goalID: goalID,
            title: title,
            ownerMemberID: ownerMemberID,
            audience: audience,
            cadence: cadence,
            dueDate: dueDate,
            status: status
        )
    }

    static func progressRecord(id: String, data: [String: Any]) -> ProgressRecord? {
        guard let planID = data["planID"] as? String,
              let studentID = data["studentID"] as? String,
              let source = (data["source"] as? String).flatMap(ProgressSource.init(rawValue:)),
              let sourceID = data["sourceID"] as? String,
              let visibility = (data["visibility"] as? String)
                .flatMap(ProgressVisibility.init(rawValue:)),
              let authorID = data["authorID"] as? String
        else { return nil }
        return ProgressRecord(
            id: id,
            planID: planID,
            studentID: studentID,
            source: source,
            sourceID: sourceID,
            measuredValue: data["measuredValue"] as? String,
            note: data["note"] as? String,
            visibility: visibility,
            authorID: authorID,
            // An entry still being written has no server time yet; it sorts
            // last rather than being dropped.
            recordedAt: (data["recordedAt"] as? Timestamp)?.dateValue() ?? .distantFuture
        )
    }

    static func revision(id: String, data: [String: Any]) -> PlanRevision? {
        guard let planID = data["planID"] as? String,
              let sequence = data["sequence"] as? Int,
              let reason = (data["reason"] as? String).flatMap(PlanRevisionReason.init(rawValue:)),
              let status = (data["status"] as? String).flatMap(PlanRecordStatus.init(rawValue:)),
              let model = (data["model"] as? String).flatMap(TMIPlanModel.init(rawValue:)),
              let title = data["title"] as? String,
              let startDate = (data["startDate"] as? Timestamp)?.dateValue(),
              let frozenBy = data["frozenBy"] as? String
        else { return nil }
        return PlanRevision(
            id: id,
            planID: planID,
            sequence: sequence,
            reason: reason,
            status: status,
            model: model,
            title: title,
            summary: data["summary"] as? String,
            startDate: startDate,
            targetDate: (data["targetDate"] as? Timestamp)?.dateValue(),
            goalIDs: data["goalIDs"] as? [String] ?? [],
            actionIDs: data["actionIDs"] as? [String] ?? [],
            frozenBy: frozenBy,
            frozenAt: (data["frozenAt"] as? Timestamp)?.dateValue() ?? .distantFuture,
            note: data["note"] as? String
        )
    }
}
