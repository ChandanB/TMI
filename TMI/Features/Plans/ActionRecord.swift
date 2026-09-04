import Foundation

nonisolated enum ActionAudience: String, Codable, Sendable, CaseIterable, Equatable {
    case staff
    case student

    var displayName: String {
        switch self {
        case .staff: "Staff"
        case .student: "Student"
        }
    }
}

nonisolated enum ActionStatus: String, Codable, Sendable, CaseIterable, Equatable {
    case open
    case done
    case skipped

    /// Only a due action counts toward completion; skipped work is neither
    /// done nor still owed.
    var countsTowardCompletion: Bool { self != .skipped }
    var isComplete: Bool { self == .done }
}

nonisolated enum ActionCadence: String, Codable, Sendable, CaseIterable, Equatable {
    case once
    case daily
    case weekly
    case monthly

    var displayName: String {
        switch self {
        case .once: "Once"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }
}

nonisolated struct ActionRecord: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let planID: String
    let goalID: String
    let title: String
    /// Who does it. An action nobody owns does not get done.
    let ownerMemberID: String
    /// Who it is written for; student-facing wording differs from staff wording.
    let audience: ActionAudience
    let cadence: ActionCadence
    let dueDate: Date
    let status: ActionStatus
}

nonisolated enum PlanCompletion {
    /// Completion is the share of due actions actually done.
    ///
    /// It is deliberately something an educator can recount by hand: no hidden
    /// weighting, no score that cannot be explained to a student or a parent.
    /// Skipped actions leave the denominator, because work withdrawn is not
    /// work owed.
    static func percentage(of actions: [ActionRecord]) -> Int {
        let counted = actions.filter { $0.status.countsTowardCompletion }
        guard !counted.isEmpty else { return 0 }
        let done = counted.filter { $0.status.isComplete }.count
        return Int((Double(done) / Double(counted.count) * 100).rounded())
    }
}
