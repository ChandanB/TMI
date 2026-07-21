import Foundation
import Testing
@testable import TMI

@Suite("Verified staff authentication")
@MainActor
struct AuthSessionTests {
    @Test("Unverified email cannot enter student records")
    func unverifiedEmailCannotEnterStudentRecords() {
        let session = AuthSession(
            identity: AuthIdentity(
                userID: "staff-1",
                email: "staff@example.edu",
                isEmailVerified: false
            ),
            membership: membership()
        )

        #expect(session.access == .emailVerificationRequired)
    }

    @Test("An active verified member can enter")
    func activeVerifiedMemberCanEnter() {
        let session = AuthSession(
            identity: AuthIdentity(
                userID: "staff-1",
                email: "staff@example.edu",
                isEmailVerified: true
            ),
            membership: membership()
        )

        #expect(session.access == .authorized)
    }

    @Test("Missing and inactive memberships fail closed")
    func membershipRequirementsFailClosed() {
        let identity = AuthIdentity(
            userID: "staff-1",
            email: "staff@example.edu",
            isEmailVerified: true
        )

        #expect(AuthSession(identity: identity, membership: nil).access == .membershipRequired)
        #expect(
            AuthSession(
                identity: identity,
                membership: membership(isActive: false)
            ).access == .membershipInactive
        )
    }

    @Test("A tenant or identity mismatch cannot authorize the session")
    func tenantMismatchCannotAuthorize() {
        let identity = AuthIdentity(
            userID: "staff-1",
            email: "staff@example.edu",
            isEmailVerified: true,
            districtID: "district-a"
        )

        #expect(
            AuthSession(
                identity: identity,
                membership: membership(districtID: "district-b")
            ).access == .membershipRequired
        )
        #expect(
            AuthSession(
                identity: identity,
                membership: membership(userID: "staff-2")
            ).access == .membershipRequired
        )
    }

    @Test("Registration requires an invitation before creating an Auth account")
    func registrationRequiresInvitation() async {
        let backend = AuthenticationBackendSpy()
        let repository = AuthenticationRepository(
            backend: backend,
            sessionLoader: SessionLoaderStub(session: .signedOut),
            invitationProvisioner: InvitationProvisionerStub(
                result: .success(membership())
            )
        )

        await #expect(throws: AuthenticationRepositoryError.invitationRequired) {
            _ = try await repository.register(registrationRequest(invitationCode: "  "))
        }
        #expect(backend.createUserCallCount == 0)
    }

    @Test("A token refresh failure never returns a partial session")
    func tokenRefreshFailureIsReported() async {
        let backend = AuthenticationBackendSpy()
        backend.refreshError = AuthenticationTestError.tokenRefreshFailed
        let repository = AuthenticationRepository(
            backend: backend,
            sessionLoader: SessionLoaderStub(session: .signedOut),
            invitationProvisioner: InvitationProvisionerStub(
                result: .success(membership())
            )
        )

        await #expect(throws: AuthenticationTestError.tokenRefreshFailed) {
            _ = try await repository.refresh()
        }
    }

    @Test("Provisioning failure rolls back the newly created Auth account")
    func provisioningFailureRollsBackRegistration() async {
        let backend = AuthenticationBackendSpy()
        let repository = AuthenticationRepository(
            backend: backend,
            sessionLoader: SessionLoaderStub(session: .signedOut),
            invitationProvisioner: InvitationProvisionerStub(
                result: .failure(AuthenticationTestError.provisioningFailed)
            )
        )

        await #expect(throws: AuthenticationTestError.provisioningFailed) {
            _ = try await repository.register(registrationRequest(invitationCode: "invite-a"))
        }
        #expect(backend.createUserCallCount == 1)
        #expect(backend.deleteCurrentUserCallCount == 1)
    }

    private func membership(
        userID: String = "staff-1",
        districtID: String = "district-a",
        isActive: Bool = true
    ) -> MembershipContext {
        MembershipContext(
            userID: userID,
            districtID: districtID,
            schoolIDs: ["school-a"],
            role: .teacher,
            capabilities: [.studentReadDetail],
            assignedStudentIDs: ["student-a"],
            isActive: isActive,
            version: 1
        )
    }

    private func registrationRequest(invitationCode: String) -> StaffRegistrationRequest {
        StaffRegistrationRequest(
            displayName: "Morgan Lee",
            email: "morgan@example.edu",
            password: "Correct-Horse-9",
            requestedRole: .teacher,
            invitationCode: invitationCode,
            privacyPolicyVersion: "2026-07-20",
            acceptableUsePolicyVersion: "2026-07-20"
        )
    }
}

@MainActor
private final class AuthenticationBackendSpy: AuthenticationBackend {
    var createUserCallCount = 0
    var deleteCurrentUserCallCount = 0
    var refreshError: Error?

    func signIn(email: String, password: String) async throws -> AuthIdentity {
        identity
    }

    func createUser(email: String, password: String) async throws -> AuthIdentity {
        createUserCallCount += 1
        return identity
    }

    func deleteCurrentUser() async throws {
        deleteCurrentUserCallCount += 1
    }

    func sendPasswordReset(email: String) async throws {}
    func sendVerification() async throws {}

    func refreshIdentity() async throws -> AuthIdentity {
        if let refreshError {
            throw refreshError
        }
        return identity
    }

    func reauthenticate(password: String) async throws {}
    func signOut() async throws {}

    private var identity: AuthIdentity {
        AuthIdentity(
            userID: "staff-1",
            email: "staff@example.edu",
            isEmailVerified: true,
            districtID: "district-a"
        )
    }
}

private struct SessionLoaderStub: AuthenticationSessionLoading {
    let session: AuthSession

    func session(for identity: AuthIdentity) async throws -> AuthSession {
        session
    }
}

private struct InvitationProvisionerStub: StaffInvitationProvisioning {
    let result: Result<MembershipContext, Error>

    func provision(
        request: StaffRegistrationRequest,
        identity: AuthIdentity
    ) async throws -> MembershipContext {
        try result.get()
    }
}

private enum AuthenticationTestError: Error {
    case tokenRefreshFailed
    case provisioningFailed
}
