import Foundation

/// What a student has done with a career.
///
/// A recommendation is never stored here. A match is derived from approved
/// interests every time it is shown, so a stale score cannot harden into a
/// claim about a child. What persists is only what the student or their
/// educator actually did: saved it, dismissed it, compared it, looked at it,
/// or linked it to a plan.
nonisolated struct CareerRelationship: Identifiable, Codable, Sendable, Equatable {
    var id: String { careerID }

    let studentID: String
    let careerID: String
    let isSaved: Bool
    let isDismissed: Bool
    let isCompared: Bool
    let linkedPlanIDs: [String]
    let lastViewedAt: Date?
    let updatedAt: Date
    let updatedBy: String

    init(
        studentID: String,
        careerID: String,
        isSaved: Bool = false,
        isDismissed: Bool = false,
        isCompared: Bool = false,
        linkedPlanIDs: [String] = [],
        lastViewedAt: Date? = nil,
        updatedAt: Date,
        updatedBy: String
    ) {
        self.studentID = studentID
        self.careerID = careerID
        // Saving and dismissing are opposite answers to the same question, so
        // holding both would leave the student's own choice ambiguous.
        self.isSaved = isSaved && !isDismissed
        self.isDismissed = isDismissed
        self.isCompared = isCompared
        self.linkedPlanIDs = Array(Set(linkedPlanIDs)).sorted()
        self.lastViewedAt = lastViewedAt
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
    }

    /// Viewing a career is not an opinion about it.
    var hasStudentOpinion: Bool { isSaved || isDismissed }
}
