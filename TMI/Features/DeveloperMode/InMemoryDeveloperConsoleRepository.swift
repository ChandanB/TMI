#if DEBUG
import Foundation
import SwiftUI

/// Deterministic, in-memory console for previews and the `developer-mode`
/// UI-test fixture. Mirrors the server's lifecycle rules closely enough to
/// exercise every screen without Firebase.
@MainActor
final class InMemoryDeveloperConsoleRepository: DeveloperConsoleRepository {
    private var storedTenants: [DevTenant]
    private var storedInvitations: [DevInvitation]
    private var storedMembers: [String: [DevMember]]
    private var nextCode = 1

    init() {
        storedTenants = [
            DevTenant(
                districtID: "riverside-usd",
                name: "Riverside Unified School District",
                organizationKind: .schoolDistrict,
                programType: .k12,
                memberCount: 2,
                schools: [
                    DevSchool(schoolID: "lincoln-middle", name: "Lincoln Middle School", programType: nil),
                    DevSchool(schoolID: "riverside-prek", name: "Riverside Pre-K Center", programType: .earlyChildhood),
                ]
            ),
            DevTenant(
                districtID: "sunshine-early-learning",
                name: "Sunshine Early Learning",
                organizationKind: .earlyLearningProvider,
                programType: .earlyChildhood,
                memberCount: 0,
                schools: [DevSchool(schoolID: "sunshine-east", name: "Sunshine East Center", programType: nil)]
            ),
        ]
        storedInvitations = [
            DevInvitation(invitationID: String(repeating: "a", count: 64), districtID: "riverside-usd", role: .teacher, schoolIDs: ["lincoln-middle"], capabilities: [.studentReadDetail, .studentWriteDetail], label: "Grade 7 team lead", status: .active, createdAt: "2026-09-20T15:00:00Z", createdBy: "operator", expiresAt: "2026-10-04T15:00:00Z", consumedAt: nil, consumedByUserID: nil, revokedAt: nil),
            DevInvitation(invitationID: String(repeating: "b", count: 64), districtID: "riverside-usd", role: .schoolAdministrator, schoolIDs: ["lincoln-middle"], capabilities: DeveloperConsoleDefaults.capabilities(for: .schoolAdministrator), label: "Principal", status: .consumed, createdAt: "2026-09-10T15:00:00Z", createdBy: "operator", expiresAt: "2026-09-24T15:00:00Z", consumedAt: "2026-09-11T15:00:00Z", consumedByUserID: "user-principal", revokedAt: nil),
        ]
        storedMembers = [
            "riverside-usd": [
                DevMember(userID: "user-principal", email: "principal@example.test", displayName: "Jordan Principal", role: .schoolAdministrator, schoolIDs: ["lincoln-middle"], capabilities: DeveloperConsoleDefaults.capabilities(for: .schoolAdministrator), assignedStudentCount: 0, isActive: true, version: 1, claimDistrictID: "riverside-usd"),
                DevMember(userID: "user-teacher", email: "teacher@example.test", displayName: "Riley Teacher", role: .teacher, schoolIDs: ["lincoln-middle"], capabilities: DeveloperConsoleDefaults.capabilities(for: .teacher), assignedStudentCount: 12, isActive: true, version: 3, claimDistrictID: "riverside-usd"),
            ],
        ]
    }

    func status() async throws -> DeveloperConsoleStatus {
        DeveloperConsoleStatus(isEnabled: true, isOperator: true, projectID: "in-memory")
    }

    func tenants() async throws -> [DevTenant] { storedTenants }

    func upsertDistrict(districtID: String, name: String, organizationKind: OrganizationKind, programType: ProgramType) async throws {
        let existing = storedTenants.first { $0.districtID == districtID }
        let tenant = DevTenant(districtID: districtID, name: name, organizationKind: organizationKind, programType: programType, memberCount: existing?.memberCount ?? 0, schools: existing?.schools ?? [])
        storedTenants.removeAll { $0.districtID == districtID }
        storedTenants.append(tenant)
        storedTenants.sort { $0.name < $1.name }
    }

    func upsertSchool(districtID: String, schoolID: String, name: String, programType: ProgramType?) async throws {
        guard let index = storedTenants.firstIndex(where: { $0.districtID == districtID }) else {
            throw DeveloperConsoleError.notFound("The district does not exist.")
        }
        let tenant = storedTenants[index]
        var schools = tenant.schools.filter { $0.schoolID != schoolID }
        schools.append(DevSchool(schoolID: schoolID, name: name, programType: programType))
        schools.sort { $0.name < $1.name }
        storedTenants[index] = DevTenant(districtID: tenant.districtID, name: tenant.name, organizationKind: tenant.organizationKind, programType: tenant.programType, memberCount: tenant.memberCount, schools: schools)
    }

    func invitations(districtID: String?) async throws -> [DevInvitation] {
        storedInvitations.filter { districtID == nil || $0.districtID == districtID }
    }

    func createInvitation(_ draft: DevInvitationDraft) async throws -> DevCreatedInvitation {
        let id = String(format: "%064d", nextCode)
        let code = String(repeating: "X", count: 40) + String(format: "%03d", nextCode)
        nextCode += 1
        storedInvitations.insert(DevInvitation(invitationID: id, districtID: draft.districtID, role: draft.role, schoolIDs: draft.schoolIDs, capabilities: draft.capabilities, label: draft.label.isEmpty ? nil : draft.label, status: .active, createdAt: "2026-09-22T15:00:00Z", createdBy: "operator", expiresAt: "2026-10-06T15:00:00Z", consumedAt: nil, consumedByUserID: nil, revokedAt: nil), at: 0)
        return DevCreatedInvitation(invitationID: id, invitationCode: code, expiresAt: "2026-10-06T15:00:00Z")
    }

    func revokeInvitation(invitationID: String) async throws {
        guard let index = storedInvitations.firstIndex(where: { $0.invitationID == invitationID }) else { return }
        let invitation = storedInvitations[index]
        guard invitation.status != .consumed else {
            throw DeveloperConsoleError.rejected("A consumed invitation cannot be revoked; change the membership instead.")
        }
        storedInvitations[index] = DevInvitation(invitationID: invitation.invitationID, districtID: invitation.districtID, role: invitation.role, schoolIDs: invitation.schoolIDs, capabilities: invitation.capabilities, label: invitation.label, status: .revoked, createdAt: invitation.createdAt, createdBy: invitation.createdBy, expiresAt: invitation.expiresAt, consumedAt: nil, consumedByUserID: nil, revokedAt: "2026-09-22T15:05:00Z")
    }

    func deleteInvitation(invitationID: String) async throws {
        storedInvitations.removeAll { $0.invitationID == invitationID && $0.status.canDelete }
    }

    func members(districtID: String) async throws -> [DevMember] { storedMembers[districtID] ?? [] }

    func upsertMembership(_ draft: DevMembershipDraft) async throws -> Int {
        var members = storedMembers[draft.districtID] ?? []
        let existing = members.first { $0.userID == draft.userID || (draft.userID == nil && $0.email == draft.email) }
        let version = (existing?.version ?? 0) + 1
        let userID = existing?.userID ?? draft.userID ?? "user-\(members.count + 1)"
        members.removeAll { $0.userID == userID }
        members.append(DevMember(userID: userID, email: existing?.email ?? draft.email, displayName: existing?.displayName, role: draft.role, schoolIDs: draft.schoolIDs, capabilities: draft.capabilities, assignedStudentCount: existing?.assignedStudentCount ?? 0, isActive: draft.isActive, version: version, claimDistrictID: draft.districtID))
        storedMembers[draft.districtID] = members
        return version
    }
}

#Preview("Developer Mode") {
    NavigationStack {
        DeveloperModeView(repository: InMemoryDeveloperConsoleRepository())
    }
}
#endif
