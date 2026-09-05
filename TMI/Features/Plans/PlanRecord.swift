import Foundation

/// The canonical plan aggregate stored at
/// `districts/{districtID}/plans/{planID}`.
///
/// The legacy `TMIPlan` model writes to `users/{uid}/tmiPlans`, which the rules
/// deny. This is the shape the rules actually authorize.
nonisolated struct PlanRecord: Identifiable, Sendable, Equatable {
    let id: String
    let districtID: String
    var studentIDs: Set<String>
    var schoolIDs: Set<String>
    var assignedMemberIDs: Set<String>
    var status: PlanRecordStatus
    var model: TMIPlanModel
    var title: String
    var summary: String?
    var startDate: Date
    var targetDate: Date?
    var approvalStatus: PlanApprovalState
    var metadata: CanonicalRecordMetadata
}

nonisolated enum PlanRecordStatus: String, CaseIterable, Codable, Sendable {
    case draft
    case pendingApproval
    case changesRequested
    case approved
    case active
    case paused
    case completed
    case archived

    var displayName: String {
        switch self {
        case .draft: "Draft"
        case .pendingApproval: "Pending approval"
        case .changesRequested: "Changes requested"
        case .approved: "Approved"
        case .active: "Active"
        case .paused: "Paused"
        case .completed: "Completed"
        case .archived: "Archived"
        }
    }

    var isEditable: Bool { self == .draft || self == .changesRequested }
    var acceptsProgress: Bool { self == .active || self == .paused }

    var isOpen: Bool {
        switch self {
        case .draft, .pendingApproval, .changesRequested, .approved, .active, .paused: true
        case .completed, .archived: false
        }
    }
}

nonisolated enum PlanApprovalState: String, Codable, Sendable {
    case notRequested
    case pending
    case approved
    case changesRequested
}

nonisolated enum PlanLifecycle {
    /// Mirrors the trusted transitionPlan callable. Firestore denies direct
    /// status writes; approval and activation are distinct audited decisions.
    static func allowedTransitions(from status: PlanRecordStatus) -> Set<PlanRecordStatus> {
        switch status {
        case .draft: [.pendingApproval, .archived]
        case .pendingApproval: [.draft, .changesRequested, .approved]
        case .changesRequested: [.draft, .archived]
        case .approved: [.active]
        case .active: [.paused, .completed]
        case .paused: [.active, .completed]
        // A completed plan is duplicated into a new cycle, never reopened.
        case .completed: [.archived]
        case .archived: []
        }
    }

    static func isLegal(from: PlanRecordStatus, to: PlanRecordStatus) -> Bool {
        allowedTransitions(from: from).contains(to)
    }
}

/// The six intervention models are brand-fixed. `TMIPlanModel` carries the
/// display name as its raw value, which is not a safe storage key, so canonical
/// records persist a stable identifier instead.
nonisolated enum PlanModelIdentifier {
    static func identifier(for model: TMIPlanModel) -> String {
        switch model {
        case .chaseYourSpace: "chaseYourSpace"
        case .acknowledgeInterests: "acknowledgeInterests"
        case .alignYourMind: "alignYourMind"
        case .directAndCorrect: "directAndCorrect"
        case .bullyToBoss: "bullyToBoss"
        case .meekToProtector: "meekToProtector"
        }
    }

    static func model(for identifier: String) -> TMIPlanModel? {
        TMIPlanModel.allCases.first { self.identifier(for: $0) == identifier }
    }
}

nonisolated struct PlanDraft: Sendable, Equatable {
    var studentIDs: Set<String>
    var schoolIDs: Set<String>
    var assignedMemberIDs: Set<String>
    var model: TMIPlanModel
    var title: String
    var summary: String?
    var startDate: Date
    var targetDate: Date?

    var normalized: PlanDraft {
        var copy = self
        copy.title = title
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        copy.summary = summary?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        return copy
    }
}

private nonisolated extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

nonisolated enum PlanRecordRepositoryError: Error, Equatable {
    case invalidDraft
    case notFound
    case permissionDenied
    case illegalTransition(from: PlanRecordStatus, to: PlanRecordStatus)
    case versionConflict(expected: Int, actual: Int)
    case unavailable
    case invalidResponse
}

nonisolated enum PlanValidation {
    static func issues(for draft: PlanDraft, member: MembershipContext) -> [String] {
        var issues: [String] = []
        let draft = draft.normalized
        if draft.title.isEmpty {
            issues.append("A plan needs a title.")
        }
        if draft.studentIDs.isEmpty {
            issues.append("A plan needs at least one student.")
        }
        if draft.schoolIDs.isEmpty {
            issues.append("A plan needs at least one school.")
        }
        if !draft.schoolIDs.isSubset(of: member.schoolIDs) {
            issues.append("A plan cannot reach outside your schools.")
        }
        if !draft.assignedMemberIDs.contains(member.userID) {
            issues.append("You must be assigned to a plan you create.")
        }
        if let targetDate = draft.targetDate, targetDate < draft.startDate {
            issues.append("The target date cannot precede the start date.")
        }
        return issues
    }
}

/// The rules that shape a plan as it is started, kept out of the view so they
/// can be exercised directly.
nonisolated enum PlanCreation {
    /// Creating a plan writes to the district, so it needs the same authority
    /// the roster write requires.
    static func isAvailable(to member: MembershipContext) -> Bool {
        member.isActive && member.capabilities.contains(.studentWriteDetail)
    }

    /// The title tracks the chosen model until the educator makes it their own.
    /// A title still matching the model it came from is untouched; anything
    /// else is theirs to keep.
    static func title(
        movingFrom oldModel: TMIPlanModel,
        to newModel: TMIPlanModel,
        currentTitle: String
    ) -> String {
        let trimmed = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty || trimmed == oldModel.rawValue else { return currentTitle }
        return newModel.rawValue
    }

    /// A plan's scope comes from the student's roster record, which is what the
    /// rules authorize the write against.
    static func draft(
        studentID: String,
        schoolID: String,
        member: MembershipContext,
        model: TMIPlanModel,
        title: String,
        summary: String,
        startDate: Date,
        targetDate: Date?
    ) -> PlanDraft {
        PlanDraft(
            studentIDs: [studentID],
            schoolIDs: [schoolID],
            assignedMemberIDs: [member.userID],
            model: model,
            title: title,
            summary: summary,
            startDate: startDate,
            targetDate: targetDate
        )
        .normalized
    }
}
