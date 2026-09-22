#if DEBUG
import Foundation

/// Deterministic admin data for previews and the `staff-administration`
/// UI-test fixture.
@MainActor
final class InMemoryStaffAdministrationRepository: StaffAdministrationRepository {
    private var members: [AdminStaffMember] = [
        AdminStaffMember(userID: "admin-fixture", email: "principal@example.test", displayName: "Jordan Principal", role: .schoolAdministrator, schoolIDs: ["school-fixture"], capabilities: StaffRole.schoolAdministrator.defaultCapabilities, assignedStudentIDs: [], isActive: true, recordVersion: 2, isSelf: true, isManageable: false),
        AdminStaffMember(userID: "teacher-1", email: "riley@example.test", displayName: "Riley Teacher", role: .teacher, schoolIDs: ["school-fixture"], capabilities: StaffRole.teacher.defaultCapabilities, assignedStudentIDs: ["student-1"], isActive: true, recordVersion: 3, isSelf: false, isManageable: true),
        AdminStaffMember(userID: "teacher-2", email: "sam@example.test", displayName: "Sam Assistant", role: .teacher, schoolIDs: ["school-fixture"], capabilities: [.studentReadDetail], assignedStudentIDs: [], isActive: false, recordVersion: 1, isSelf: false, isManageable: true),
    ]
    private var storedInvitations: [AdminInvitation] = [
        AdminInvitation(invitationID: String(repeating: "c", count: 64), districtID: "district-fixture", role: .teacher, schoolIDs: ["school-fixture"], capabilities: StaffRole.teacher.defaultCapabilities, label: "Room 4 lead", status: .active, createdAt: "2026-09-20T15:00:00Z", expiresAt: "2026-10-04T15:00:00Z", consumedAt: nil),
    ]

    func staff(districtID: String) async throws -> [AdminStaffMember] { members }
    func invitations(districtID: String) async throws -> [AdminInvitation] { storedInvitations }

    func createInvitation(_ draft: AdminInvitationDraft, districtID: String, operationID: String) async throws -> AdminCreatedInvitation {
        let id = String(format: "%064d", storedInvitations.count + 1)
        storedInvitations.insert(AdminInvitation(invitationID: id, districtID: districtID, role: draft.role, schoolIDs: draft.schoolIDs, capabilities: draft.capabilities, label: draft.label.isEmpty ? nil : draft.label, status: .active, createdAt: "2026-09-22T15:00:00Z", expiresAt: "2026-10-06T15:00:00Z", consumedAt: nil), at: 0)
        return AdminCreatedInvitation(invitationID: id, invitationCode: "FIXTURE-CODE-" + id.suffix(4), expiresAt: "2026-10-06T15:00:00Z")
    }

    func revokeInvitation(invitationID: String, districtID: String) async throws {
        storedInvitations = storedInvitations.map { invitation in
            guard invitation.invitationID == invitationID else { return invitation }
            return AdminInvitation(invitationID: invitation.invitationID, districtID: invitation.districtID, role: invitation.role, schoolIDs: invitation.schoolIDs, capabilities: invitation.capabilities, label: invitation.label, status: .revoked, createdAt: invitation.createdAt, expiresAt: invitation.expiresAt, consumedAt: nil)
        }
    }

    func updateMembership(_ draft: AdminMembershipDraft, districtID: String, operationID: String) async throws {
        members = members.map { member in
            guard member.userID == draft.member.userID else { return member }
            return AdminStaffMember(userID: member.userID, email: member.email, displayName: member.displayName, role: draft.role, schoolIDs: draft.schoolIDs, capabilities: draft.capabilities, assignedStudentIDs: member.assignedStudentIDs, isActive: draft.isActive, recordVersion: member.recordVersion + 1, isSelf: member.isSelf, isManageable: member.isManageable)
        }
    }

    func auditEvents(districtID: String) async throws -> [AuditEventSummary] {
        [
            AuditEventSummary(id: "a1", action: "staff.invitation.create", actorUserID: "admin-fixture", targetPath: "staffInvitations/c", createdAt: Date(timeIntervalSince1970: 1_790_000_000), isOperator: false),
            AuditEventSummary(id: "a2", action: "membership.mutate", actorUserID: "admin-fixture", targetPath: "districts/district-fixture/members/teacher-2", createdAt: Date(timeIntervalSince1970: 1_789_990_000), isOperator: false),
        ]
    }
}
#endif
