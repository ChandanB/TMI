#if DEBUG
import Foundation
@preconcurrency import FirebaseFunctions

/// Operator-only administration backed by the `dev*` callables. The server is
/// the authority: every call is rejected unless the signed-in account has an
/// active `platformOperators/{uid}` record, so this DEBUG-only client grants
/// nothing by itself.
@MainActor
protocol DeveloperConsoleRepository: AnyObject {
    func status() async throws -> DeveloperConsoleStatus
    func tenants() async throws -> [DevTenant]
    func upsertDistrict(
        districtID: String,
        name: String,
        organizationKind: OrganizationKind,
        programType: ProgramType
    ) async throws
    func upsertSchool(
        districtID: String,
        schoolID: String,
        name: String,
        programType: ProgramType?
    ) async throws
    func invitations(districtID: String?) async throws -> [DevInvitation]
    func createInvitation(_ draft: DevInvitationDraft) async throws -> DevCreatedInvitation
    func revokeInvitation(invitationID: String) async throws
    func deleteInvitation(invitationID: String) async throws
    func members(districtID: String) async throws -> [DevMember]
    func upsertMembership(_ draft: DevMembershipDraft) async throws -> Int
}

nonisolated enum DeveloperConsoleError: LocalizedError, Equatable, Sendable {
    case notDeployed
    case notOperator
    case disabled(String)
    case appCheckRequired
    case signInRequired
    case rejected(String)
    case notFound(String)
    case unavailable
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notDeployed:
            "The developer console functions aren't deployed to this Firebase project yet."
        case .notOperator:
            "This account isn't a platform operator. Grant it with `npm --prefix functions run operator:grant -- --email <email>`."
        case .disabled(let message), .rejected(let message), .notFound(let message):
            message
        case .appCheckRequired:
            "The server requires an App Check token. Register this device's App Check debug token in the Firebase console."
        case .signInRequired:
            "Sign in to use the developer console."
        case .unavailable:
            "The server couldn't be reached. Check the connection and try again."
        case .invalidResponse:
            "The server returned an unexpected response."
        }
    }

    static func map(_ error: any Error) -> DeveloperConsoleError {
        if let error = error as? DeveloperConsoleError {
            return error
        }
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: nsError.code) else {
            return .unavailable
        }
        let message = nsError.localizedDescription
        switch code {
        case .notFound where message.localizedCaseInsensitiveContains("does not exist")
            || message.localizedCaseInsensitiveContains("no account"):
            return .notFound(message)
        case .notFound:
            return .notDeployed
        case .permissionDenied:
            return .notOperator
        case .unauthenticated:
            return .signInRequired
        case .failedPrecondition where message.localizedCaseInsensitiveContains("app check"):
            return .appCheckRequired
        case .failedPrecondition where message.localizedCaseInsensitiveContains("disabled"):
            return .disabled(message)
        case .unavailable, .deadlineExceeded:
            return .unavailable
        case .invalidArgument, .failedPrecondition, .alreadyExists, .aborted:
            return .rejected(message)
        default:
            return .unavailable
        }
    }
}

@MainActor
final class FirebaseDeveloperConsoleRepository: DeveloperConsoleRepository {
    private let functions: Functions

    init(functions: Functions = Functions.functions(region: "us-central1")) {
        self.functions = functions
    }

    func status() async throws -> DeveloperConsoleStatus {
        try await call("devConsoleStatus", DevWireEmpty())
    }

    func tenants() async throws -> [DevTenant] {
        let response: DevWireTenantsResponse = try await call("devListTenants", DevWireEmpty())
        return response.tenants
    }

    func upsertDistrict(
        districtID: String,
        name: String,
        organizationKind: OrganizationKind,
        programType: ProgramType
    ) async throws {
        let _: DevWireCreatedResponse = try await call(
            "devUpsertDistrict",
            DevWireUpsertDistrictRequest(
                districtID: districtID,
                name: name,
                organizationKind: organizationKind,
                programType: programType
            )
        )
    }

    func upsertSchool(
        districtID: String,
        schoolID: String,
        name: String,
        programType: ProgramType?
    ) async throws {
        let _: DevWireCreatedResponse = try await call(
            "devUpsertSchool",
            DevWireUpsertSchoolRequest(
                districtID: districtID,
                schoolID: schoolID,
                name: name,
                programType: programType
            )
        )
    }

    func invitations(districtID: String?) async throws -> [DevInvitation] {
        let response: DevWireInvitationsResponse = try await call(
            "devListInvitations",
            DevDistrictFilter(districtID: districtID)
        )
        return response.invitations
    }

    func createInvitation(_ draft: DevInvitationDraft) async throws -> DevCreatedInvitation {
        let label = draft.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await call(
            "devCreateInvitation",
            DevWireCreateInvitationRequest(
                districtID: draft.districtID,
                schoolIDs: draft.schoolIDs,
                role: draft.role,
                capabilities: draft.capabilities,
                recipientEmail: draft.recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                expiresInDays: draft.expiresInDays,
                label: label.isEmpty ? nil : label
            )
        )
    }

    func revokeInvitation(invitationID: String) async throws {
        let _: DevWireRevokeResponse = try await call(
            "devRevokeInvitation",
            InvitationTarget(invitationID: invitationID)
        )
    }

    func deleteInvitation(invitationID: String) async throws {
        let _: DevWireDeleteResponse = try await call(
            "devDeleteInvitation",
            InvitationTarget(invitationID: invitationID)
        )
    }

    func members(districtID: String) async throws -> [DevMember] {
        let response: DevWireMembersResponse = try await call(
            "devListMembers",
            DistrictTarget(districtID: districtID)
        )
        return response.members
    }

    func upsertMembership(_ draft: DevMembershipDraft) async throws -> Int {
        let email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let response: DevWireMembershipResponse = try await call(
            "devUpsertMembership",
            DevWireUpsertMembershipRequest(
                districtID: draft.districtID,
                userID: draft.userID,
                email: draft.userID == nil ? email : nil,
                role: draft.role,
                schoolIDs: draft.schoolIDs,
                capabilities: draft.capabilities,
                isActive: draft.isActive
            )
        )
        return response.version
    }

    private func call<Request: Encodable & Sendable, Response: Decodable & Sendable>(
        _ name: String,
        _ request: Request
    ) async throws -> Response {
        do {
            let callable: Callable<Request, Response> = functions.httpsCallable(name)
            return try await callable.call(request)
        } catch let error as DecodingError {
            _ = error
            throw DeveloperConsoleError.invalidResponse
        } catch {
            throw DeveloperConsoleError.map(error)
        }
    }
}

/// Used when Firebase isn't configured (previews, UI-test fixtures).
@MainActor
final class UnconfiguredDeveloperConsoleRepository: DeveloperConsoleRepository {
    private let error = DeveloperConsoleError.disabled("Firebase isn't configured in this launch mode.")

    func status() async throws -> DeveloperConsoleStatus { throw error }
    func tenants() async throws -> [DevTenant] { throw error }
    func upsertDistrict(districtID: String, name: String, organizationKind: OrganizationKind, programType: ProgramType) async throws { throw error }
    func upsertSchool(districtID: String, schoolID: String, name: String, programType: ProgramType?) async throws { throw error }
    func invitations(districtID: String?) async throws -> [DevInvitation] { throw error }
    func createInvitation(_ draft: DevInvitationDraft) async throws -> DevCreatedInvitation { throw error }
    func revokeInvitation(invitationID: String) async throws { throw error }
    func deleteInvitation(invitationID: String) async throws { throw error }
    func members(districtID: String) async throws -> [DevMember] { throw error }
    func upsertMembership(_ draft: DevMembershipDraft) async throws -> Int { throw error }
}

// MARK: - Wire types

private nonisolated struct DevWireEmpty: Codable, Sendable {}

private nonisolated struct DevWireTenantsResponse: Decodable, Sendable {
    let tenants: [DevTenant]
}

private nonisolated struct DevWireInvitationsResponse: Decodable, Sendable {
    let invitations: [DevInvitation]
}

private nonisolated struct DevWireMembersResponse: Decodable, Sendable {
    let members: [DevMember]
}

private nonisolated struct DevWireCreatedResponse: Decodable, Sendable {
    let created: Bool
}

private nonisolated struct DevWireRevokeResponse: Decodable, Sendable {
    let invitation: DevInvitation
}

private nonisolated struct DevWireDeleteResponse: Decodable, Sendable {
    let deleted: Bool
}

private nonisolated struct DevWireMembershipResponse: Decodable, Sendable {
    let userID: String
    let version: Int
}

private nonisolated struct DevDistrictFilter: Encodable, Sendable {
    let districtID: String?
}

private nonisolated struct DistrictTarget: Encodable, Sendable {
    let districtID: String
}

private nonisolated struct InvitationTarget: Encodable, Sendable {
    let invitationID: String
}

private nonisolated struct DevWireUpsertDistrictRequest: Encodable, Sendable {
    let districtID: String
    let name: String
    let organizationKind: OrganizationKind
    let programType: ProgramType
}

private nonisolated struct DevWireUpsertSchoolRequest: Encodable, Sendable {
    let districtID: String
    let schoolID: String
    let name: String
    let programType: ProgramType?
}

private nonisolated struct DevWireCreateInvitationRequest: Encodable, Sendable {
    let districtID: String
    let schoolIDs: [String]
    let role: StaffRole
    let capabilities: [Capability]
    let recipientEmail: String
    let expiresInDays: Int
    let label: String?
}

private nonisolated struct DevWireUpsertMembershipRequest: Encodable, Sendable {
    let districtID: String
    let userID: String?
    let email: String?
    let role: StaffRole
    let schoolIDs: [String]
    let capabilities: [Capability]
    let isActive: Bool
}
#endif
