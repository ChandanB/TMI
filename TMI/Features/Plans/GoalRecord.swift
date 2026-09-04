import Foundation

nonisolated enum GoalRecordStatus: String, Codable, Sendable, CaseIterable, Equatable {
    case notStarted
    case inProgress
    case met
    case discontinued

    var displayName: String {
        switch self {
        case .notStarted: "Not started"
        case .inProgress: "In progress"
        case .met: "Met"
        case .discontinued: "Discontinued"
        }
    }
}

/// How a goal is measured, so "improved" is never left to memory.
nonisolated enum GoalMeasure: String, Codable, Sendable, CaseIterable, Equatable {
    case count
    case percentage
    case rating
    case observation

    var displayName: String {
        switch self {
        case .count: "Count"
        case .percentage: "Percentage"
        case .rating: "Rating"
        case .observation: "Observation"
        }
    }
}

nonisolated struct GoalRecord: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let planID: String
    let studentID: String
    /// What staff call it.
    let title: String
    /// What the student sees, in words written for them. Falls back to the
    /// staff title only when nobody has written one.
    let studentFacingTitle: String?
    let measure: GoalMeasure
    /// Where the student is starting from. Without it, progress is unreadable.
    let baseline: String
    let target: String
    let dueDate: Date
    let responsibleMemberID: String
    let status: GoalRecordStatus

    var studentWording: String { studentFacingTitle ?? title }
}

nonisolated enum GoalValidation {
    static func issues(for goal: GoalRecord, startDate: Date) -> [String] {
        var issues: [String] = []
        if goal.title.trimmed.isEmpty {
            issues.append("A goal needs a title.")
        }
        if goal.baseline.trimmed.isEmpty {
            issues.append("A goal needs a baseline, so progress can be read against it.")
        }
        if goal.target.trimmed.isEmpty {
            issues.append("A goal needs a target.")
        }
        if goal.responsibleMemberID.trimmed.isEmpty {
            issues.append("A goal needs a responsible staff member.")
        }
        if goal.dueDate < startDate {
            issues.append("The due date cannot precede the plan's start date.")
        }
        return issues
    }
}

nonisolated extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
