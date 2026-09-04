import Foundation

/// A plan as it stood at the moment someone committed to it.
///
/// Revisions are frozen at approval and at completion. They are never edited:
/// the point of a revision is to answer "what did we agree to, and when",
/// which an editable record cannot do. A plan whose history can be rewritten
/// is not evidence of anything.
nonisolated struct PlanRevision: Identifiable, Sendable, Equatable {
    let id: String
    let planID: String
    /// Increments by one per frozen revision, so gaps are visible.
    let sequence: Int
    let reason: PlanRevisionReason
    let status: PlanRecordStatus
    let model: TMIPlanModel
    let title: String
    let summary: String?
    let startDate: Date
    let targetDate: Date?
    let goalIDs: [String]
    let actionIDs: [String]
    /// Who committed to it, and when the server recorded that.
    let frozenBy: String
    let frozenAt: Date
    /// Present when the transition carried an explanation, such as the reason
    /// changes were requested or the outcome a plan completed with.
    let note: String?
}

nonisolated enum PlanRevisionReason: String, Codable, Sendable, CaseIterable, Equatable {
    case approved
    case changesRequested
    case completed

    var displayName: String {
        switch self {
        case .approved: "Approved"
        case .changesRequested: "Changes requested"
        case .completed: "Completed"
        }
    }
}

nonisolated enum PlanRevisionError: Error, Equatable, Sendable {
    case notFreezable(PlanRecordStatus)
    case emptyNote
}

nonisolated enum PlanRevisionHistory {
    /// The transitions that freeze what was agreed.
    ///
    /// Everything else is ordinary editing and leaves no revision, so the
    /// timeline stays a record of commitments rather than keystrokes.
    static func reason(forEntering status: PlanRecordStatus) -> PlanRevisionReason? {
        switch status {
        case .active: .approved
        case .changesRequested: .changesRequested
        case .completed: .completed
        case .draft, .pendingApproval, .paused, .archived: nil
        }
    }

    static func freeze(
        _ plan: PlanRecord,
        entering status: PlanRecordStatus,
        goalIDs: [String],
        actionIDs: [String],
        note: String?,
        frozenBy: String,
        frozenAt: Date,
        existing: [PlanRevision]
    ) throws -> PlanRevision {
        guard let reason = reason(forEntering: status) else {
            throw PlanRevisionError.notFreezable(status)
        }
        // Requesting changes without saying why leaves the next person guessing
        // at what to fix.
        if reason == .changesRequested, note?.trimmed.isEmpty != false {
            throw PlanRevisionError.emptyNote
        }
        let sequence = (existing.map(\.sequence).max() ?? 0) + 1
        return PlanRevision(
            id: "\(plan.id)__r\(sequence)",
            planID: plan.id,
            sequence: sequence,
            reason: reason,
            status: status,
            model: plan.model,
            title: plan.title,
            summary: plan.summary,
            startDate: plan.startDate,
            targetDate: plan.targetDate,
            goalIDs: goalIDs.sorted(),
            actionIDs: actionIDs.sorted(),
            frozenBy: frozenBy,
            frozenAt: frozenAt,
            note: note?.trimmed.isEmpty == true ? nil : note?.trimmed
        )
    }

    /// Newest first, which is the order a reader wants a history in.
    static func ordered(_ revisions: [PlanRevision]) -> [PlanRevision] {
        revisions.sorted {
            $0.sequence == $1.sequence ? $0.id > $1.id : $0.sequence > $1.sequence
        }
    }

    /// What a completed plan carries into its next cycle.
    ///
    /// A new cycle starts as a fresh draft with its own identity and no
    /// history, because it is new work rather than a continuation of a plan
    /// that already ended.
    static func nextCycleDraft(from plan: PlanRecord, startingOn startDate: Date) -> PlanDraft {
        PlanDraft(
            studentIDs: plan.studentIDs,
            schoolIDs: plan.schoolIDs,
            assignedMemberIDs: plan.assignedMemberIDs,
            model: plan.model,
            title: plan.title,
            summary: plan.summary,
            startDate: startDate,
            targetDate: nil
        )
    }
}
