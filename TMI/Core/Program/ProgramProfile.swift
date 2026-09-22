import Foundation

/// What a program turns on or off. Every early-childhood difference in the
/// app is expressed through one of these switches so screens never branch on
/// `ProgramType` directly.
nonisolated struct ProgramProfile: Sendable, Equatable {
    let program: ProgramType
    let terminology: Terminology
    /// Career exploration, matching, and career-to-plan links.
    let showsCareers: Bool
    /// Students answer surveys and write their own words; otherwise caregivers
    /// observe and families contribute.
    let learnerSelfReports: Bool
    /// Date of birth is required so age groups and milestones make sense.
    let requiresDateOfBirth: Bool
    /// Family "All About My Child" intake via guardian respondent sessions.
    let usesFamilyIntake: Bool
    /// Goals are tagged with a developmental domain.
    let usesDevelopmentalDomains: Bool

    static let k12 = ProgramProfile(
        program: .k12,
        terminology: .k12,
        showsCareers: true,
        learnerSelfReports: true,
        requiresDateOfBirth: false,
        usesFamilyIntake: false,
        usesDevelopmentalDomains: false
    )

    static let earlyChildhood = ProgramProfile(
        program: .earlyChildhood,
        terminology: .earlyChildhood,
        showsCareers: false,
        learnerSelfReports: false,
        requiresDateOfBirth: true,
        usesFamilyIntake: true,
        usesDevelopmentalDomains: true
    )

    static func `for`(_ program: ProgramType) -> ProgramProfile {
        switch program {
        case .k12: .k12
        case .earlyChildhood: .earlyChildhood
        }
    }

    var gradeChoices: [String] { GradeLevel.choices(for: program) }
}

/// Server-owned organization and site metadata for the signed-in member.
nonisolated struct OrganizationProfile: Sendable, Equatable {
    nonisolated struct Site: Sendable, Equatable, Identifiable {
        let id: String
        let name: String
        let programOverride: ProgramType?
    }

    let organizationID: String
    let name: String
    let kind: OrganizationKind
    let defaultProgram: ProgramType
    let sites: [Site]

    func site(_ schoolID: String) -> Site? {
        sites.first { $0.id == schoolID }
    }

    func program(forSchoolID schoolID: String?) -> ProgramType {
        let site = schoolID.flatMap(self.site)
        return ProgramType.resolve(site: site?.programOverride, organization: defaultProgram)
    }

    func siteName(_ schoolID: String) -> String {
        site(schoolID)?.name ?? schoolID
    }

    /// The program for organization-wide screens: early childhood only when
    /// every site the member works in is early childhood.
    var shellProgram: ProgramType {
        let programs = Set(sites.map { program(forSchoolID: $0.id) })
        if programs.isEmpty { return defaultProgram }
        return programs == [.earlyChildhood] ? .earlyChildhood : .k12
    }
}
