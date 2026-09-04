import Foundation

nonisolated enum ProgressSource: String, Codable, Sendable, CaseIterable, Equatable {
    case goal
    case action
}

nonisolated enum ProgressVisibility: String, Codable, Sendable, CaseIterable, Equatable {
    /// Written by staff, for staff.
    case staffOnly
    /// Written for, or by, the student.
    case sharedWithStudent
}

/// One observation, recorded once.
///
/// Progress is a record of what someone saw on a given day. It is never
/// edited or overwritten: a correction is another entry, so the history of
/// what was believed and when stays readable. That history is often the whole
/// evidence base for a decision about a child.
nonisolated struct ProgressRecord: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let planID: String
    let studentID: String
    let source: ProgressSource
    /// The goal or action this was recorded against.
    let sourceID: String
    let measuredValue: String?
    let note: String?
    let visibility: ProgressVisibility
    let authorID: String
    /// Set by the server, not the device, so an ordering cannot be forged by a
    /// wrong clock.
    let recordedAt: Date
}

nonisolated enum ProgressHistory {
    /// Appends an entry, keeping history in the order it was recorded.
    ///
    /// There is no update and no delete. An entry that turns out to be wrong
    /// is corrected by recording another one.
    static func appending(
        _ entry: ProgressRecord,
        to history: [ProgressRecord]
    ) -> [ProgressRecord] {
        guard !history.contains(where: { $0.id == entry.id }) else { return history }
        return (history + [entry]).sorted {
            $0.recordedAt == $1.recordedAt ? $0.id < $1.id : $0.recordedAt < $1.recordedAt
        }
    }

    /// What a student is allowed to read back.
    static func visibleToStudent(_ history: [ProgressRecord]) -> [ProgressRecord] {
        history.filter { $0.visibility == .sharedWithStudent }
    }

    static func latest(
        for sourceID: String,
        in history: [ProgressRecord]
    ) -> ProgressRecord? {
        history
            .filter { $0.sourceID == sourceID }
            .max {
                $0.recordedAt == $1.recordedAt ? $0.id < $1.id : $0.recordedAt < $1.recordedAt
            }
    }
}
