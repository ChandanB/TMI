import Foundation
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseFunctions

nonisolated struct AdminStaffMember: Codable, Sendable, Equatable, Identifiable, Hashable {
    let userID: String
    let email: String?
    let displayName: String?
    let role: StaffRole?
    let schoolIDs: [String]
    let capabilities: [Capability]
    let assignedStudentIDs: [String]
    let isActive: Bool
    let recordVersion: Int
    let isSelf: Bool
    let isManageable: Bool

    var id: String { userID }
    var title: String { displayName ?? email ?? userID }
}

nonisolated enum AdminInvitationStatus: String, Codable, Sendable, CaseIterable {
    case active, consumed, expired, revoked

    var displayName: String {
        switch self {
        case .active: "Active"
        case .consumed: "Redeemed"
        case .expired: "Expired"
        case .revoked: "Revoked"
        }
    }
}

nonisolated struct AdminInvitation: Codable, Sendable, Equatable, Identifiable, Hashable {
    let invitationID: String
    let districtID: String
    let role: StaffRole
    let schoolIDs: [String]
    let capabilities: [Capability]
    let label: String?
    let status: AdminInvitationStatus
    let createdAt: String?
    let expiresAt: String?
    let consumedAt: String?

    var id: String { invitationID }
}

nonisolated struct AdminCreatedInvitation: Codable, Sendable, Equatable, Identifiable {
    let invitationID: String
    let invitationCode: String
    let expiresAt: String

    var id: String { invitationID }
}

nonisolated struct AdminInvitationDraft: Sendable, Equatable {
    var recipientEmail = ""
    var label = ""
    var role: StaffRole = .teacher
    var schoolIDs: [String] = []
    var capabilities: [Capability] = [.studentReadDetail, .studentWriteDetail]
    var expiresInDays = 14
}

nonisolated struct AdminMembershipDraft: Sendable, Equatable {
    let member: AdminStaffMember
    var role: StaffRole
    var schoolIDs: [String]
    var capabilities: [Capability]
    var isActive: Bool

    init(member: AdminStaffMember) {
        self.member = member
        role = member.role ?? .teacher
        schoolIDs = member.schoolIDs
        capabilities = member.capabilities
        isActive = member.isActive
    }
}

nonisolated struct AuditEventSummary: Sendable, Equatable, Identifiable {
    let id: String
    let action: String
    let actorUserID: String
    let targetPath: String
    let createdAt: Date?
    let isOperator: Bool

    /// Plain-language label for known actions.
    var title: String {
        switch action {
        case "staff.membership.provision": "Staff member joined"
        case "membership.mutate", "membership.update": "Staff access changed"
        case "membership.create": "Staff access granted"
        case "staff.invitation.create", "invitation.create": "Invitation created"
        case "staff.invitation.revoke", "invitation.revoke": "Invitation revoked"
        case "invitation.delete": "Invitation deleted"
        case "plan.transition": "Plan status changed"
        case "student.interests.observe": "Interest observation recorded"
        case "student.familyInput.record": "Family input recorded"
        case "survey.interests.approve": "Survey interests approved"
        case "student.detailAccess.grant": "Student access granted"
        case "school.create", "school.update", "district.create", "district.update": "Organization settings changed"
        default: action
        }
    }
}

nonisolated enum StaffAdministrationError: LocalizedError, Equatable, Sendable {
    case notDeployed
    case permissionDenied(String)
    case conflict
    case rejected(String)
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notDeployed: "Staff administration isn't available on this server yet."
        case .permissionDenied(let message): message
        case .conflict: "This staff member changed since you opened them. Refresh and try again."
        case .rejected(let message): message
        case .unavailable: "The server couldn't be reached. Check the connection and try again."
        }
    }

    static func map(_ error: any Error) -> StaffAdministrationError {
        if let error = error as? StaffAdministrationError { return error }
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: nsError.code) else {
            return .unavailable
        }
        let message = nsError.localizedDescription
        switch code {
        case .notFound where message.localizedCaseInsensitiveContains("not found")
            || message.localizedCaseInsensitiveContains("does not exist"):
            return .rejected(message)
        case .notFound: return .notDeployed
        case .permissionDenied, .unauthenticated: return .permissionDenied(message)
        case .aborted: return .conflict
        case .invalidArgument, .failedPrecondition, .alreadyExists: return .rejected(message)
        default: return .unavailable
        }
    }
}

@MainActor
protocol StaffAdministrationRepository: AnyObject {
    func staff(districtID: String) async throws -> [AdminStaffMember]
    func invitations(districtID: String) async throws -> [AdminInvitation]
    func createInvitation(_ draft: AdminInvitationDraft, districtID: String, operationID: String) async throws -> AdminCreatedInvitation
    func revokeInvitation(invitationID: String, districtID: String) async throws
    func updateMembership(_ draft: AdminMembershipDraft, districtID: String, operationID: String) async throws
    func auditEvents(districtID: String) async throws -> [AuditEventSummary]
}

@MainActor
final class FirebaseStaffAdministrationRepository: StaffAdministrationRepository {
    // Resolved on use: `Functions.functions()` traps without a configured
    // FirebaseApp (UI-test fixtures and previews construct this type).
    private let makeFunctions: @Sendable () -> Functions
    private var functions: Functions { makeFunctions() }
    private let makeFirestore: @MainActor () -> Firestore
    private var firestore: Firestore { makeFirestore() }

    init(
        functions: @autoclosure @escaping @Sendable () -> Functions = Functions.functions(region: "us-central1"),
        firestore: @autoclosure @escaping @MainActor () -> Firestore = FirebaseManager.shared.firestore
    ) {
        self.makeFunctions = functions
        self.makeFirestore = firestore
    }

    func staff(districtID: String) async throws -> [AdminStaffMember] {
        let response: StaffResponse = try await call("adminListStaff", DistrictRequest(districtID: districtID))
        return response.staff
    }

    func invitations(districtID: String) async throws -> [AdminInvitation] {
        let response: InvitationsResponse = try await call("adminListInvitations", DistrictRequest(districtID: districtID))
        return response.invitations
    }

    func createInvitation(_ draft: AdminInvitationDraft, districtID: String, operationID: String) async throws -> AdminCreatedInvitation {
        let label = draft.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await call("adminCreateInvitation", CreateRequest(
            districtID: districtID,
            idempotencyKey: operationID,
            schoolIDs: draft.schoolIDs,
            role: draft.role,
            capabilities: draft.capabilities,
            recipientEmail: draft.recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            expiresInDays: draft.expiresInDays,
            label: label.isEmpty ? nil : label
        ))
    }

    func revokeInvitation(invitationID: String, districtID: String) async throws {
        let _: RevokeResponse = try await call(
            "adminRevokeInvitation",
            RevokeRequest(districtID: districtID, invitationID: invitationID)
        )
    }

    func updateMembership(_ draft: AdminMembershipDraft, districtID: String, operationID: String) async throws {
        let _: MutationResponse = try await call("mutateMembership", MutateRequest(
            districtID: districtID,
            expectedRecordVersion: draft.member.recordVersion,
            idempotencyKey: operationID,
            reasonCode: "staff-administration",
            targetUserID: draft.member.userID,
            role: draft.role,
            schoolIDs: draft.schoolIDs,
            capabilities: draft.capabilities,
            assignedStudentIDs: draft.member.assignedStudentIDs,
            isActive: draft.isActive
        ))
    }

    func auditEvents(districtID: String) async throws -> [AuditEventSummary] {
        let snapshot = try await firestore
            .collection("districts").document(districtID)
            .collection("auditEvents")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        return snapshot.documents.map { document in
            let data = document.data()
            return AuditEventSummary(
                id: document.documentID,
                action: data["action"] as? String ?? "unknown",
                actorUserID: data["actorUserID"] as? String ?? "",
                targetPath: data["targetPath"] as? String ?? "",
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                isOperator: (data["actorKind"] as? String) == "platformOperator"
            )
        }
    }

    private func call<Request: Encodable & Sendable, Response: Decodable & Sendable>(
        _ name: String,
        _ request: Request
    ) async throws -> Response {
        do {
            let callable: Callable<Request, Response> = functions.httpsCallable(name)
            return try await callable.call(request)
        } catch is DecodingError {
            throw StaffAdministrationError.unavailable
        } catch {
            throw StaffAdministrationError.map(error)
        }
    }
}

private nonisolated struct DistrictRequest: Encodable, Sendable { let districtID: String }
private nonisolated struct StaffResponse: Decodable, Sendable { let staff: [AdminStaffMember] }
private nonisolated struct InvitationsResponse: Decodable, Sendable { let invitations: [AdminInvitation] }
private nonisolated struct RevokeRequest: Encodable, Sendable { let districtID: String; let invitationID: String }
private nonisolated struct RevokeResponse: Decodable, Sendable { let revoked: Bool }
private nonisolated struct MutationResponse: Decodable, Sendable { let operationID: String; let recordVersion: Int; let replayed: Bool }

private nonisolated struct CreateRequest: Encodable, Sendable {
    let districtID: String
    let idempotencyKey: String
    let schoolIDs: [String]
    let role: StaffRole
    let capabilities: [Capability]
    let recipientEmail: String
    let expiresInDays: Int
    let label: String?
}

private nonisolated struct MutateRequest: Encodable, Sendable {
    let districtID: String
    let expectedRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: String
    let targetUserID: String
    let role: StaffRole
    let schoolIDs: [String]
    let capabilities: [Capability]
    let assignedStudentIDs: [String]
    let isActive: Bool
}
