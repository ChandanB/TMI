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
    let recordVersion: Int
    let createdAt: Date
    let createdBy: String
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
        updatedBy: String,
        recordVersion: Int = 1,
        createdAt: Date? = nil,
        createdBy: String? = nil
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
        self.recordVersion = max(1, recordVersion)
        self.createdAt = createdAt ?? updatedAt
        self.createdBy = createdBy ?? updatedBy
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
    }

    /// Viewing a career is not an opinion about it.
    var hasStudentOpinion: Bool { isSaved || isDismissed }

    func settingSaved(_ value: Bool, at date: Date, by userID: String) -> Self {
        copy(
            isSaved: value,
            isDismissed: value ? false : isDismissed,
            at: date,
            by: userID
        )
    }

    func settingDismissed(_ value: Bool, at date: Date, by userID: String) -> Self {
        copy(
            isSaved: value ? false : isSaved,
            isDismissed: value,
            at: date,
            by: userID
        )
    }

    func settingCompared(_ value: Bool, at date: Date, by userID: String) -> Self {
        copy(isCompared: value, at: date, by: userID)
    }

    func markingViewed(at date: Date, by userID: String) -> Self {
        copy(lastViewedAt: date, at: date, by: userID)
    }

    private func copy(
        isSaved: Bool? = nil,
        isDismissed: Bool? = nil,
        isCompared: Bool? = nil,
        lastViewedAt: Date? = nil,
        at date: Date,
        by userID: String
    ) -> Self {
        Self(
            studentID: studentID,
            careerID: careerID,
            isSaved: isSaved ?? self.isSaved,
            isDismissed: isDismissed ?? self.isDismissed,
            isCompared: isCompared ?? self.isCompared,
            linkedPlanIDs: linkedPlanIDs,
            lastViewedAt: lastViewedAt ?? self.lastViewedAt,
            updatedAt: date,
            updatedBy: userID,
            recordVersion: recordVersion + 1,
            createdAt: createdAt,
            createdBy: createdBy
        )
    }
}
