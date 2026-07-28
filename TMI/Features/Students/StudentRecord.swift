import Foundation

/// The canonical roster aggregate stored at
/// `districts/{districtID}/students/{studentID}`.
nonisolated struct StudentRecord: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let districtID: String
    var schoolID: String
    var displayName: String
    var grade: String
    var studentIdentifier: String?
    var dateOfBirth: Date?
    var pronouns: String?
    var assignedMemberIDs: Set<String>
    var isArchived: Bool
    var metadata: CanonicalRecordMetadata
}

nonisolated extension StudentRecord {
    /// Builds the temporary `Student` snapshot required by the legacy plan
    /// model using canonical roster fields only. Plan storage is replaced in
    /// Release 3; until then, records without a canonical birth date fail
    /// closed instead of borrowing caller-controlled legacy values.
    func planStudentSnapshot() -> Student? {
        guard let dateOfBirth else {
            return nil
        }
        return Student(
            id: id,
            name: displayName,
            grade: grade,
            school: schoolID,
            dateOfBirth: dateOfBirth,
            districtId: districtID,
            schoolId: schoolID,
            createdBy: metadata.createdBy,
            createdAt: metadata.createdAt,
            updatedAt: metadata.updatedAt,
            studentID: studentIdentifier
        )
    }
}
