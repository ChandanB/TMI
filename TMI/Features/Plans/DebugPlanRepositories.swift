#if DEBUG
import Foundation

@MainActor
final class DebugPlanStore {
    private var plansByID: [String: PlanRecord] = [:]
    private var goalsByPlanID: [String: [String: GoalRecord]] = [:]
    private var actionsByPlanID: [String: [String: ActionRecord]] = [:]
    private var progressByPlanID: [String: [String: ProgressRecord]] = [:]
    private var revisionsByPlanID: [String: [String: PlanRevision]] = [:]

    func plans(member: MembershipContext) throws -> [PlanRecord] {
        try authorizeRead(member)
        return plansByID.values
            .filter { $0.districtID == member.districtID && !$0.schoolIDs.isDisjoint(with: member.schoolIDs) }
            .sorted { $0.metadata.updatedAt > $1.metadata.updatedAt }
    }

    func plan(id: String, member: MembershipContext) throws -> PlanRecord {
        try authorizeRead(member)
        guard let record = plansByID[id] else {
            throw PlanRecordRepositoryError.notFound
        }
        guard record.districtID == member.districtID,
              !record.schoolIDs.isDisjoint(with: member.schoolIDs) else {
            throw PlanRecordRepositoryError.permissionDenied
        }
        return record
    }

    func create(
        _ draft: PlanDraft,
        operationID: UUID,
        member: MembershipContext
    ) throws -> PlanRecord {
        try authorizeWrite(member)
        let id = "plan_\(operationID.uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
        if let existing = plansByID[id] {
            return existing
        }

        let draft = draft.normalized
        guard PlanValidation.issues(for: draft, member: member).isEmpty else {
            throw PlanRecordRepositoryError.invalidDraft
        }
        let timestamp = Date()
        let record = PlanRecord(
            id: id,
            districtID: member.districtID,
            studentIDs: draft.studentIDs,
            schoolIDs: draft.schoolIDs,
            assignedMemberIDs: draft.assignedMemberIDs,
            status: .draft,
            model: draft.model,
            title: draft.title,
            summary: draft.summary,
            startDate: draft.startDate,
            targetDate: draft.targetDate,
            approvalStatus: .notRequested,
            metadata: CanonicalRecordMetadata(
                schemaVersion: 1,
                recordVersion: 1,
                createdAt: timestamp,
                createdBy: member.userID,
                updatedAt: timestamp,
                updatedBy: member.userID
            )
        )
        plansByID[id] = record
        return record
    }

    func update(
        id: String,
        draft: PlanDraft,
        expectedVersion: Int,
        member: MembershipContext
    ) throws -> PlanRecord {
        try authorizeWrite(member)
        guard let existing = plansByID[id] else {
            throw PlanRecordRepositoryError.notFound
        }
        try authorizeWrite(member, plan: existing)
        guard existing.metadata.recordVersion == expectedVersion else {
            throw PlanRecordRepositoryError.versionConflict(
                expected: expectedVersion,
                actual: existing.metadata.recordVersion
            )
        }

        let draft = draft.normalized
        guard existing.status.isEditable,
              draft.studentIDs == existing.studentIDs,
              draft.schoolIDs == existing.schoolIDs,
              PlanValidation.issues(for: draft, member: member).isEmpty else {
            throw PlanRecordRepositoryError.invalidDraft
        }

        let updated = PlanRecord(
            id: existing.id,
            districtID: existing.districtID,
            studentIDs: existing.studentIDs,
            schoolIDs: existing.schoolIDs,
            assignedMemberIDs: draft.assignedMemberIDs,
            status: existing.status,
            model: draft.model,
            title: draft.title,
            summary: draft.summary,
            startDate: draft.startDate,
            targetDate: draft.targetDate,
            approvalStatus: existing.approvalStatus,
            metadata: CanonicalRecordMetadata(
                schemaVersion: existing.metadata.schemaVersion,
                recordVersion: expectedVersion + 1,
                createdAt: existing.metadata.createdAt,
                createdBy: existing.metadata.createdBy,
                updatedAt: Date(),
                updatedBy: member.userID
            )
        )
        plansByID[id] = updated
        return updated
    }

    func transition(
        id: String,
        to status: PlanRecordStatus,
        expectedVersion: Int,
        note: String?,
        member: MembershipContext
    ) throws -> PlanRecord {
        guard var existing = plansByID[id] else {
            throw PlanRecordRepositoryError.notFound
        }
        try authorizeWrite(member, plan: existing)
        guard existing.metadata.recordVersion == expectedVersion else {
            throw PlanRecordRepositoryError.versionConflict(
                expected: expectedVersion,
                actual: existing.metadata.recordVersion
            )
        }
        guard PlanLifecycle.isLegal(from: existing.status, to: status) else {
            throw PlanRecordRepositoryError.illegalTransition(from: existing.status, to: status)
        }

        let isApproval = existing.status == .pendingApproval
            && (status == .approved || status == .changesRequested)
        if isApproval {
            guard member.capabilities.contains(.planApprove) else {
                throw PlanRecordRepositoryError.permissionDenied
            }
        } else {
            try authorizeWrite(member)
        }
        if existing.status == .approved, status == .active,
           existing.metadata.createdBy != member.userID {
            throw PlanRecordRepositoryError.permissionDenied
        }
        if (status == .changesRequested || status == .completed), note?.trimmed.isEmpty != false {
            throw PlanRecordRepositoryError.invalidDraft
        }

        if PlanRevisionHistory.reason(forEntering: status) != nil {
            let revision = try PlanRevisionHistory.freeze(
                existing,
                entering: status,
                goalIDs: Array(goalsByPlanID[id]?.keys ?? Dictionary<String, GoalRecord>().keys),
                actionIDs: Array(actionsByPlanID[id]?.keys ?? Dictionary<String, ActionRecord>().keys),
                note: note,
                frozenBy: member.userID,
                frozenAt: Date(),
                existing: Array(revisionsByPlanID[id]?.values ?? Dictionary<String, PlanRevision>().values)
            )
            revisionsByPlanID[id, default: [:]][revision.id] = revision
        }

        existing.status = status
        existing.approvalStatus = switch status {
        case .pendingApproval: .pending
        case .changesRequested: .changesRequested
        case .draft: .notRequested
        case .approved: .approved
        case .active, .paused, .completed, .archived: existing.approvalStatus
        }
        existing.metadata = CanonicalRecordMetadata(
            schemaVersion: existing.metadata.schemaVersion,
            recordVersion: expectedVersion + 1,
            createdAt: existing.metadata.createdAt,
            createdBy: existing.metadata.createdBy,
            updatedAt: Date(),
            updatedBy: member.userID
        )
        plansByID[id] = existing
        return existing
    }

    func goals(planID: String, member: MembershipContext) throws -> [GoalRecord] {
        _ = try plan(id: planID, member: member)
        return (goalsByPlanID[planID]?.values ?? Dictionary<String, GoalRecord>().values)
            .sorted { $0.dueDate == $1.dueDate ? $0.id < $1.id : $0.dueDate < $1.dueDate }
    }

    func actions(planID: String, member: MembershipContext) throws -> [ActionRecord] {
        _ = try plan(id: planID, member: member)
        return (actionsByPlanID[planID]?.values ?? Dictionary<String, ActionRecord>().values)
            .sorted { $0.dueDate == $1.dueDate ? $0.id < $1.id : $0.dueDate < $1.dueDate }
    }

    func progress(planID: String, member: MembershipContext) throws -> [ProgressRecord] {
        _ = try plan(id: planID, member: member)
        return (progressByPlanID[planID]?.values ?? Dictionary<String, ProgressRecord>().values)
            .sorted {
                $0.recordedAt == $1.recordedAt ? $0.id < $1.id : $0.recordedAt < $1.recordedAt
            }
    }

    func revisions(planID: String, member: MembershipContext) throws -> [PlanRevision] {
        _ = try plan(id: planID, member: member)
        return PlanRevisionHistory.ordered(
            Array(revisionsByPlanID[planID]?.values ?? Dictionary<String, PlanRevision>().values)
        )
    }

    func save(goal: GoalRecord, member: MembershipContext) throws {
        let parent = try plan(id: goal.planID, member: member)
        try authorizeWrite(member, plan: parent)
        guard parent.studentIDs.contains(goal.studentID),
              GoalValidation.issues(for: goal, startDate: parent.startDate).isEmpty else {
            throw PlanRecordRepositoryError.invalidDraft
        }

        if parent.status.acceptsProgress {
            guard let existing = goalsByPlanID[goal.planID]?[goal.id],
                  Self.sameGoalContent(existing, goal) else {
                throw PlanRecordRepositoryError.permissionDenied
            }
        } else {
            guard parent.status.isEditable else {
                throw PlanRecordRepositoryError.permissionDenied
            }
        }
        goalsByPlanID[goal.planID, default: [:]][goal.id] = goal
    }

    func save(action: ActionRecord, member: MembershipContext) throws {
        let parent = try plan(id: action.planID, member: member)
        try authorizeWrite(member, plan: parent)
        guard !action.title.trimmed.isEmpty,
              !action.ownerMemberID.trimmed.isEmpty,
              action.dueDate >= parent.startDate,
              goalsByPlanID[action.planID]?[action.goalID] != nil else {
            throw PlanRecordRepositoryError.invalidDraft
        }

        if parent.status.acceptsProgress {
            guard let existing = actionsByPlanID[action.planID]?[action.id],
                  Self.sameActionContent(existing, action) else {
                throw PlanRecordRepositoryError.permissionDenied
            }
        } else {
            guard parent.status.isEditable else {
                throw PlanRecordRepositoryError.permissionDenied
            }
        }
        actionsByPlanID[action.planID, default: [:]][action.id] = action
    }

    func append(progress: ProgressRecord, member: MembershipContext) throws {
        let parent = try plan(id: progress.planID, member: member)
        try authorizeWrite(member, plan: parent)
        guard parent.status.acceptsProgress,
              parent.studentIDs.contains(progress.studentID),
              progress.authorID == member.userID else {
            throw PlanRecordRepositoryError.permissionDenied
        }

        if let existing = progressByPlanID[progress.planID]?[progress.id] {
            guard Self.sameProgressPayload(existing, progress) else {
                throw PlanRecordRepositoryError.invalidDraft
            }
            return
        }
        progressByPlanID[progress.planID, default: [:]][progress.id] = progress
    }

    private func authorizeRead(_ member: MembershipContext) throws {
        guard member.isActive,
              member.capabilities.contains(.studentReadDetail),
              member.districtID == DebugStaffInvitationProvisioner.districtID,
              member.schoolIDs == [DebugStaffInvitationProvisioner.schoolID] else {
            throw PlanRecordRepositoryError.permissionDenied
        }
    }

    private func authorizeWrite(_ member: MembershipContext) throws {
        try authorizeRead(member)
        guard member.capabilities.contains(.studentWriteDetail) else {
            throw PlanRecordRepositoryError.permissionDenied
        }
    }

    private func authorizeWrite(_ member: MembershipContext, plan: PlanRecord) throws {
        try authorizeRead(member)
        guard plan.districtID == member.districtID,
              plan.schoolIDs.isSubset(of: member.schoolIDs) else {
            throw PlanRecordRepositoryError.permissionDenied
        }
        let isAdministrator = member.role == .districtAdministrator || member.role == .schoolAdministrator
        guard isAdministrator || plan.assignedMemberIDs.contains(member.userID) else {
            throw PlanRecordRepositoryError.permissionDenied
        }
    }

    private static func sameGoalContent(_ lhs: GoalRecord, _ rhs: GoalRecord) -> Bool {
        lhs.id == rhs.id
            && lhs.planID == rhs.planID
            && lhs.studentID == rhs.studentID
            && lhs.title == rhs.title
            && lhs.studentFacingTitle == rhs.studentFacingTitle
            && lhs.measure == rhs.measure
            && lhs.baseline == rhs.baseline
            && lhs.target == rhs.target
            && lhs.dueDate == rhs.dueDate
            && lhs.responsibleMemberID == rhs.responsibleMemberID
    }

    private static func sameActionContent(_ lhs: ActionRecord, _ rhs: ActionRecord) -> Bool {
        lhs.id == rhs.id
            && lhs.planID == rhs.planID
            && lhs.goalID == rhs.goalID
            && lhs.title == rhs.title
            && lhs.ownerMemberID == rhs.ownerMemberID
            && lhs.audience == rhs.audience
            && lhs.cadence == rhs.cadence
            && lhs.dueDate == rhs.dueDate
    }

    private static func sameProgressPayload(_ lhs: ProgressRecord, _ rhs: ProgressRecord) -> Bool {
        lhs.id == rhs.id
            && lhs.planID == rhs.planID
            && lhs.studentID == rhs.studentID
            && lhs.source == rhs.source
            && lhs.sourceID == rhs.sourceID
            && lhs.measuredValue == rhs.measuredValue
            && lhs.note == rhs.note
            && lhs.visibility == rhs.visibility
            && lhs.authorID == rhs.authorID
    }
}

@MainActor
final class DebugPlanRepository: PlanRecordRepository {
    private let delegate: any PlanRecordRepository
    private let store: DebugPlanStore

    init(delegate: any PlanRecordRepository, store: DebugPlanStore) {
        self.delegate = delegate
        self.store = store
    }

    func plans(member: MembershipContext) async throws -> [PlanRecord] {
        guard Self.isDebug(member) else {
            return try await delegate.plans(member: member)
        }
        return try store.plans(member: member)
    }

    func plan(id: String, member: MembershipContext) async throws -> PlanRecord {
        guard Self.isDebug(member) else {
            return try await delegate.plan(id: id, member: member)
        }
        return try store.plan(id: id, member: member)
    }

    func create(
        _ draft: PlanDraft,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> PlanRecord {
        guard Self.isDebug(member) else {
            return try await delegate.create(draft, operationID: operationID, member: member)
        }
        return try store.create(draft, operationID: operationID, member: member)
    }

    func update(
        id: String,
        draft: PlanDraft,
        expectedVersion: Int,
        member: MembershipContext
    ) async throws -> PlanRecord {
        guard Self.isDebug(member) else {
            return try await delegate.update(
                id: id,
                draft: draft,
                expectedVersion: expectedVersion,
                member: member
            )
        }
        return try store.update(id: id, draft: draft, expectedVersion: expectedVersion, member: member)
    }

    func transition(
        id: String,
        to status: PlanRecordStatus,
        expectedVersion: Int,
        member: MembershipContext
    ) async throws -> PlanRecord {
        try await transition(
            id: id,
            to: status,
            expectedVersion: expectedVersion,
            note: nil,
            member: member
        )
    }

    func transition(
        id: String,
        to status: PlanRecordStatus,
        expectedVersion: Int,
        note: String?,
        member: MembershipContext
    ) async throws -> PlanRecord {
        guard Self.isDebug(member) else {
            return try await delegate.transition(
                id: id,
                to: status,
                expectedVersion: expectedVersion,
                note: note,
                member: member
            )
        }
        return try store.transition(
            id: id,
            to: status,
            expectedVersion: expectedVersion,
            note: note,
            member: member
        )
    }

    static func isDebug(_ member: MembershipContext) -> Bool {
        member.districtID == DebugStaffInvitationProvisioner.districtID
            && member.schoolIDs == [DebugStaffInvitationProvisioner.schoolID]
    }
}

@MainActor
final class DebugPlanChildRepository: PlanChildRepositoryProtocol {
    private let delegate: any PlanChildRepositoryProtocol
    private let store: DebugPlanStore

    init(delegate: any PlanChildRepositoryProtocol, store: DebugPlanStore) {
        self.delegate = delegate
        self.store = store
    }

    func goals(planID: String, member: MembershipContext) async throws -> [GoalRecord] {
        guard DebugPlanRepository.isDebug(member) else {
            return try await delegate.goals(planID: planID, member: member)
        }
        return try store.goals(planID: planID, member: member)
    }

    func actions(planID: String, member: MembershipContext) async throws -> [ActionRecord] {
        guard DebugPlanRepository.isDebug(member) else {
            return try await delegate.actions(planID: planID, member: member)
        }
        return try store.actions(planID: planID, member: member)
    }

    func progress(planID: String, member: MembershipContext) async throws -> [ProgressRecord] {
        guard DebugPlanRepository.isDebug(member) else {
            return try await delegate.progress(planID: planID, member: member)
        }
        return try store.progress(planID: planID, member: member)
    }

    func revisions(planID: String, member: MembershipContext) async throws -> [PlanRevision] {
        guard DebugPlanRepository.isDebug(member) else {
            return try await delegate.revisions(planID: planID, member: member)
        }
        return try store.revisions(planID: planID, member: member)
    }

    func save(goal: GoalRecord, member: MembershipContext) async throws {
        guard DebugPlanRepository.isDebug(member) else {
            try await delegate.save(goal: goal, member: member)
            return
        }
        try store.save(goal: goal, member: member)
    }

    func save(action: ActionRecord, member: MembershipContext) async throws {
        guard DebugPlanRepository.isDebug(member) else {
            try await delegate.save(action: action, member: member)
            return
        }
        try store.save(action: action, member: member)
    }

    func append(progress: ProgressRecord, member: MembershipContext) async throws {
        guard DebugPlanRepository.isDebug(member) else {
            try await delegate.append(progress: progress, member: member)
            return
        }
        try store.append(progress: progress, member: member)
    }

    func freeze(revision: PlanRevision, member: MembershipContext) async throws {
        guard DebugPlanRepository.isDebug(member) else {
            try await delegate.freeze(revision: revision, member: member)
            return
        }
        throw PlanRecordRepositoryError.permissionDenied
    }
}
#endif
