import Foundation

/// Version and attribution fields required on every mutable canonical root.
nonisolated struct CanonicalRecordMetadata: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let recordVersion: Int
    let createdAt: Date
    let createdBy: String
    let updatedAt: Date
    let updatedBy: String
}
