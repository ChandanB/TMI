import Foundation
@preconcurrency import FirebaseFunctions

nonisolated enum FirebaseStaffInvitationProvisioningError: Error, Equatable {
    case invalidResponse
    case identityMismatch
}

@MainActor
final class FirebaseStaffInvitationProvisioner: StaffInvitationProvisioning {
    typealias Callable = @MainActor ([String: Any]) async throws -> Any

    private let call: Callable

    init(
        functions: Functions = Functions.functions(region: "us-central1")
    ) {
        call = { request in
            guard let invitationCode = request["invitationCode"] as? String,
                  let displayName = request["displayName"] as? String,
                  let privacyPolicyVersion = request["privacyPolicyVersion"] as? String,
                  let acceptableUsePolicyVersion = request["acceptableUsePolicyVersion"] as? String else {
                throw FirebaseStaffInvitationProvisioningError.invalidResponse
            }
            let sendableRequest: [String: String] = [
                "invitationCode": invitationCode,
                "displayName": displayName,
                "privacyPolicyVersion": privacyPolicyVersion,
                "acceptableUsePolicyVersion": acceptableUsePolicyVersion,
            ]
            return try await functions
                .httpsCallable("provisionStaffMembership")
                .call(sendableRequest)
                .data
        }
    }

    init(call: @escaping Callable) {
        self.call = call
    }

    func provision(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) async throws -> MembershipContext {
        let response: Any
        do {
            response = try await call([
                "invitationCode": request.invitationCode,
                "displayName": request.displayName,
                "privacyPolicyVersion": request.privacyPolicyVersion,
                "acceptableUsePolicyVersion": request.acceptableUsePolicyVersion,
            ])
        } catch {
            let functionsError = error as NSError
            // An undeployed callable answers NOT_FOUND. Say so plainly instead
            // of reporting a generic registration failure the user cannot act
            // on; provisioning needs the Admin SDK either way.
            if functionsError.domain == FunctionsErrorDomain,
               functionsError.code == FunctionsErrorCode.notFound.rawValue {
                throw AuthenticationRepositoryError.provisioningUnavailable
            }
            if functionsError.domain == FunctionsErrorDomain,
               Self.terminalFunctionErrorCodes.contains(functionsError.code) {
                throw error
            }
            throw StaffInvitationProvisioningError.claimRefreshPending
        }

        do {
            return try Self.membership(from: response, identity: identity)
        } catch {
            // A response is received only after the server transaction. Preserve
            // the Auth identity so an idempotent retry can validate and repair it.
            throw StaffInvitationProvisioningError.claimRefreshPending
        }
    }

    private static let terminalFunctionErrorCodes: Set<Int> = [
        FunctionsErrorCode.invalidArgument.rawValue,
        FunctionsErrorCode.notFound.rawValue,
        FunctionsErrorCode.alreadyExists.rawValue,
        FunctionsErrorCode.permissionDenied.rawValue,
        FunctionsErrorCode.failedPrecondition.rawValue,
        FunctionsErrorCode.outOfRange.rawValue,
        FunctionsErrorCode.dataLoss.rawValue,
        FunctionsErrorCode.unauthenticated.rawValue,
    ]

    private static func membership(
        from response: Any,
        identity: AuthIdentity
    ) throws -> MembershipContext {
        guard let data = response as? [String: Any],
              let userID = data["userID"] as? String,
              let districtID = data["districtID"] as? String,
              let schoolIDs = data["schoolIDs"] as? [String],
              let roleValue = data["role"] as? String,
              let role = StaffRole(rawValue: roleValue),
              let capabilityValues = data["capabilities"] as? [String],
              let assignedStudentIDs = data["assignedStudentIDs"] as? [String],
              let isActive = data["isActive"] as? Bool,
              let version = data["version"] as? Int,
              TrustedIdentifier.isValid(userID),
              TrustedIdentifier.isValid(districtID),
              schoolIDs.allSatisfy(TrustedIdentifier.isValid),
              assignedStudentIDs.allSatisfy(TrustedIdentifier.isValid),
              Set(schoolIDs).count == schoolIDs.count,
              Set(assignedStudentIDs).count == assignedStudentIDs.count,
              version > 0 else {
            throw FirebaseStaffInvitationProvisioningError.invalidResponse
        }

        let capabilities = capabilityValues.compactMap(Capability.init(rawValue:))
        guard capabilities.count == capabilityValues.count,
              Set(capabilities).count == capabilities.count else {
            throw FirebaseStaffInvitationProvisioningError.invalidResponse
        }
        guard userID == identity.userID else {
            throw FirebaseStaffInvitationProvisioningError.identityMismatch
        }

        return MembershipContext(
            userID: userID,
            districtID: districtID,
            schoolIDs: Set(schoolIDs),
            role: role,
            capabilities: Set(capabilities),
            assignedStudentIDs: Set(assignedStudentIDs),
            isActive: isActive,
            version: version
        )
    }
}
