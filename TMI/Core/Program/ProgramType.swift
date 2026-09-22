import Foundation

/// The kind of learners a site serves. Stored server-side on
/// `districts/{id}` (organization default) and `schools/{id}` (per-site
/// override); clients can never write either document.
nonisolated enum ProgramType: String, Codable, Sendable, CaseIterable, Equatable {
    case k12
    case earlyChildhood

    var displayName: String {
        switch self {
        case .k12: "K-12"
        case .earlyChildhood: "Early childhood"
        }
    }

    /// The effective program for a site: its own override, else the
    /// organization default, else K-12.
    static func resolve(site: ProgramType?, organization: ProgramType?) -> ProgramType {
        site ?? organization ?? .k12
    }
}

/// What an organization (tenant) is, used for administrative terminology.
nonisolated enum OrganizationKind: String, Codable, Sendable, CaseIterable, Equatable {
    case schoolDistrict
    case earlyLearningProvider

    var displayName: String {
        switch self {
        case .schoolDistrict: "School district"
        case .earlyLearningProvider: "Early learning provider"
        }
    }
}
