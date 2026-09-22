import Foundation
import FirebaseFirestore
import Observation
import SwiftUI

/// Loads the server-owned organization and site documents the signed-in member
/// can read. Clients never write these documents.
nonisolated protocol OrganizationDirectory: Sendable {
    func profile(for membership: MembershipContext) async throws -> OrganizationProfile
}

nonisolated struct FirestoreOrganizationDirectory: OrganizationDirectory, @unchecked Sendable {
    private let firestore: Firestore

    init(firestore: Firestore) {
        self.firestore = firestore
    }

    func profile(for membership: MembershipContext) async throws -> OrganizationProfile {
        let districtID = membership.districtID
        let district = try await firestore
            .document(FirestorePaths.district(districtID: districtID))
            .getDocument()
        let data = district.data() ?? [:]
        // Members may only read the sites they belong to (administrators may
        // read all), so fetch each assigned site directly.
        var sites: [OrganizationProfile.Site] = []
        for schoolID in membership.schoolIDs.sorted() {
            let school = try? await firestore
                .document(FirestorePaths.school(districtID: districtID, schoolID: schoolID))
                .getDocument()
            let schoolData = school?.data() ?? [:]
            sites.append(OrganizationProfile.Site(
                id: schoolID,
                name: (schoolData["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? schoolID,
                programOverride: (schoolData["programType"] as? String).flatMap(ProgramType.init(rawValue:))
            ))
        }
        return OrganizationProfile(
            organizationID: districtID,
            name: (data["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? districtID,
            kind: (data["organizationKind"] as? String).flatMap(OrganizationKind.init(rawValue:)) ?? .schoolDistrict,
            defaultProgram: (data["programType"] as? String).flatMap(ProgramType.init(rawValue:)) ?? .k12,
            sites: sites
        )
    }
}

/// Fixed profile for previews, tests, and UI-test fixtures.
nonisolated struct StaticOrganizationDirectory: OrganizationDirectory {
    let program: ProgramType

    func profile(for membership: MembershipContext) async throws -> OrganizationProfile {
        OrganizationProfile(
            organizationID: membership.districtID,
            name: membership.districtID,
            kind: program == .earlyChildhood ? .earlyLearningProvider : .schoolDistrict,
            defaultProgram: program,
            sites: membership.schoolIDs.sorted().map {
                OrganizationProfile.Site(id: $0, name: $0, programOverride: nil)
            }
        )
    }
}

#if DEBUG
/// The synthetic Debug tenant never touches Firestore; its program can be
/// switched from Developer Mode to preview the early-childhood flow.
nonisolated struct DebugOrganizationDirectory: OrganizationDirectory {
    static let programKey = "debug.tenant.programType"

    let delegate: any OrganizationDirectory

    static var debugProgram: ProgramType {
        get {
            UserDefaults.standard.string(forKey: programKey).flatMap(ProgramType.init(rawValue:)) ?? .k12
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: programKey)
        }
    }

    func profile(for membership: MembershipContext) async throws -> OrganizationProfile {
        guard membership.districtID == DebugStaffInvitationProvisioner.districtID else {
            return try await delegate.profile(for: membership)
        }
        let program = Self.debugProgram
        return OrganizationProfile(
            organizationID: membership.districtID,
            name: program == .earlyChildhood ? "Sunshine Early Learning (Debug)" : "Debug School District",
            kind: program == .earlyChildhood ? .earlyLearningProvider : .schoolDistrict,
            defaultProgram: program,
            sites: [
                OrganizationProfile.Site(
                    id: DebugStaffInvitationProvisioner.schoolID,
                    name: program == .earlyChildhood ? "Sunshine East Center" : "Lincoln Elementary",
                    programOverride: nil
                ),
            ]
        )
    }
}
#endif

/// App-wide, observable program context: which program each site runs and
/// the terminology and feature switches that follow from it. Until the
/// organization loads (or if it cannot), the K-12 profile applies, which is
/// the pre-existing behavior.
@Observable
@MainActor
final class ProgramContextStore {
    private let directory: any OrganizationDirectory
    private(set) var organization: OrganizationProfile?
    private(set) var loadedMembership: MembershipContext?

    init(directory: any OrganizationDirectory = StaticOrganizationDirectory(program: .k12)) {
        self.directory = directory
    }

    /// A store whose organization is already known (previews, UI-test fixtures).
    init(organization: OrganizationProfile) {
        self.directory = StaticOrganizationDirectory(program: organization.defaultProgram)
        self.organization = organization
    }

    static func fixture(program: ProgramType, schoolIDs: [String]) -> ProgramContextStore {
        ProgramContextStore(organization: OrganizationProfile(
            organizationID: "district-fixture",
            name: program == .earlyChildhood ? "Sunshine Early Learning" : "Fixture District",
            kind: program == .earlyChildhood ? .earlyLearningProvider : .schoolDistrict,
            defaultProgram: program,
            sites: schoolIDs.map {
                OrganizationProfile.Site(
                    id: $0,
                    name: program == .earlyChildhood ? "Sunshine East Center" : "Lincoln Middle School",
                    programOverride: nil
                )
            }
        ))
    }

    func load(for membership: MembershipContext?) async {
        guard let membership else {
            organization = nil
            loadedMembership = nil
            return
        }
        guard membership != loadedMembership || organization == nil else { return }
        do {
            let profile = try await directory.profile(for: membership)
            organization = profile
            loadedMembership = membership
        } catch {
            Log.firebase.warning("organization_profile_unavailable")
            organization = nil
        }
    }

    /// Re-reads the organization, e.g. after Developer Mode changes a program.
    func reload() async {
        let membership = loadedMembership
        loadedMembership = nil
        await load(for: membership)
    }

    /// Profile for organization-wide screens (tabs, dashboard).
    var shell: ProgramProfile {
        ProgramProfile.for(organization?.shellProgram ?? .k12)
    }

    /// Profile for screens about one learner at one site.
    func profile(forSchoolID schoolID: String?) -> ProgramProfile {
        ProgramProfile.for(organization?.program(forSchoolID: schoolID) ?? .k12)
    }

    func siteName(_ schoolID: String) -> String {
        organization?.siteName(schoolID) ?? schoolID
    }

    /// Sites the member works in, with display names, for pickers.
    func sites(for membership: MembershipContext) -> [OrganizationProfile.Site] {
        let known = organization?.sites ?? []
        return membership.schoolIDs.sorted().map { schoolID in
            known.first { $0.id == schoolID }
                ?? OrganizationProfile.Site(id: schoolID, name: schoolID, programOverride: nil)
        }
    }
}

private struct ProgramContextKey: EnvironmentKey {
    @MainActor static let defaultValue = ProgramContextStore()
}

extension EnvironmentValues {
    var programContext: ProgramContextStore {
        get { self[ProgramContextKey.self] }
        set { self[ProgramContextKey.self] = newValue }
    }
}
