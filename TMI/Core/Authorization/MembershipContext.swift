nonisolated struct MembershipContext: Codable, Sendable, Equatable {
    let userID: String
    let districtID: String
    let schoolIDs: Set<String>
    let role: StaffRole
    let capabilities: Set<Capability>
    let assignedStudentIDs: Set<String>
    let isActive: Bool
    let version: Int
}
