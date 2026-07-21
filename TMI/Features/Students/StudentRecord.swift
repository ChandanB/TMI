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
