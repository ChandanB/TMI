import Foundation

/// Read-only decoder for authorization fields that existed on editable user
/// profiles before trusted memberships became canonical.
///
/// Migration tooling may inspect this shape. Production profiles never encode
/// it and application authorization never consumes it.
struct LegacyUserAuthorizationRecord: Decodable, Sendable, Equatable {
    let role: UserRole?
    let permissions: [String]
    let dataClassificationAccess: [String]
    let districtID: String?
    let schoolID: String?
    let institutionID: String?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case role
        case permissions
        case dataClassificationAccess
        case districtID = "districtId"
        case schoolID = "schoolId"
        case institutionID
        case isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decodeIfPresent(UserRole.self, forKey: .role)
        permissions = try container.decodeIfPresent([String].self, forKey: .permissions) ?? []
        dataClassificationAccess = try container.decodeIfPresent(
            [String].self,
            forKey: .dataClassificationAccess
        ) ?? []
        districtID = try container.decodeIfPresent(String.self, forKey: .districtID)
        schoolID = try container.decodeIfPresent(String.self, forKey: .schoolID)
        institutionID = try container.decodeIfPresent(String.self, forKey: .institutionID)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
    }
}
