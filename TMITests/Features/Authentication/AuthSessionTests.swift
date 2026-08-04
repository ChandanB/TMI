import Foundation
import Testing
@testable import TMI

@Suite("Verified staff authentication")
@MainActor
struct AuthSessionTests {
    @Test("Client policy versions match the invitation callable contract")
    func policyVersionsMatchCallableContract() {
        #expect(StaffPolicyVersions.privacyPolicyVersion == "2026-07-20")
        #expect(StaffPolicyVersions.acceptableUsePolicyVersion == "2026-07-20")
    }

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

    @Test("Unverified active staff can enter when email verification is disabled")
    func unverifiedActiveStaffCanEnterWhenVerificationIsDisabled() {
        let session = AuthSession(
            identity: AuthIdentity(
                userID: "staff-1",
                email: "staff@example.edu",
                isEmailVerified: false
            ),
            membership: membership()
        )

        #expect(session.access(requiringEmailVerification: false) == .authorized)
    }

    @Test("Unverified active staff is blocked when email verification is required")
    func unverifiedActiveStaffIsBlockedWhenVerificationIsRequired() {
        let session = AuthSession(
            identity: AuthIdentity(
                userID: "staff-1",
                email: "staff@example.edu",
                isEmailVerified: false
            ),
            membership: membership()
        )

        #expect(
            session.access(requiringEmailVerification: true)
                == .emailVerificationRequired
        )
    }

    @Test("Production temporarily disables staff email verification")
    func productionDisablesStaffEmailVerification() {
        #expect(FeatureFlags.production.staffEmailVerificationRequired == false)
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

    @Test("An existing authenticated identity accepts an invitation without client authority")
    func existingIdentityCompletesStaffOnboarding() async throws {
        let backend = AuthenticationBackendSpy()
        backend.identityIsVerified = false
        let trustedMembership = membership(districtID: "trusted-district")
        backend.refreshedIdentity = AuthIdentity(
            userID: "staff-1",
            email: "staff@example.edu",
            isEmailVerified: false,
            districtID: trustedMembership.districtID
        )
        let provisioner = InvitationProvisionerStub(
            result: .success(trustedMembership)
        )
        let repository = AuthenticationRepository(
            backend: backend,
            sessionLoader: SessionLoaderStub(session: .signedOut),
            invitationProvisioner: provisioner,
            requiresEmailVerification: false
        )
        let request = StaffOnboardingRequest(
            displayName: "  Morgan   Lee  ",
            invitationCode: "  opaque-invitation  ",
            privacyPolicyVersion: "2026-07-20",
            acceptableUsePolicyVersion: "2026-07-20"
        )

        let result: Void = try await repository.completeStaffOnboarding(request)

        _ = result
        #expect(backend.currentIdentityCallCount == 1)
        #expect(provisioner.provisionCallCount == 1)
        #expect(
            provisioner.lastRequest
                == StaffInvitationAcceptanceRequest(
                    displayName: "Morgan Lee",
                    invitationCode: "opaque-invitation",
                    privacyPolicyVersion: "2026-07-20",
                    acceptableUsePolicyVersion: "2026-07-20"
                )
        )
        #expect(provisioner.lastProvisionedMembership == trustedMembership)
        #expect(backend.refreshIdentityCallCount == 1)
    }

    @Test("Staff Access Setup refresh failure is recoverable")
    func staffAccessSetupRefreshFailureIsRecoverable() async {
        let backend = AuthenticationBackendSpy()
        backend.refreshError = AuthenticationTestError.tokenRefreshFailed
        let repository = AuthenticationRepository(
            backend: backend,
            sessionLoader: SessionLoaderStub(session: .signedOut),
            invitationProvisioner: InvitationProvisionerStub(
                result: .success(membership())
            ),
            requiresEmailVerification: false
        )

        await #expect(throws: StaffInvitationProvisioningError.claimRefreshPending) {
            try await repository.completeStaffOnboarding(
                StaffOnboardingRequest(
                    displayName: "Morgan Lee",
                    invitationCode: "invite-a",
                    privacyPolicyVersion: StaffPolicyVersions.privacyPolicyVersion,
                    acceptableUsePolicyVersion:
                        StaffPolicyVersions.acceptableUsePolicyVersion
                )
            )
        }
        #expect(backend.refreshIdentityCallCount == 1)
        #expect(backend.deleteCurrentUserCallCount == 0)
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
        #expect(backend.refreshIdentityCallCount == 0)
        #expect(backend.deleteCurrentUserCallCount == 1)
    }

    @Test("Cleanup failure after provisioning keeps the identity and retries safely")
    func cleanupFailureAfterProvisioningIsRetryable() async throws {
        let backend = AuthenticationBackendSpy()
        let provisioner = InvitationProvisionerStub(
            result: .success(membership())
        )
        let pendingStore = FailOnceClearingPendingRegistrationStore()
        let repository = AuthenticationRepository(
            backend: backend,
            sessionLoader: SessionLoaderStub(session: .signedOut),
            invitationProvisioner: provisioner,
            pendingRegistrationStore: pendingStore
        )

        var returnedSession: AuthSession?
        var registrationError: Error?
        do {
            returnedSession = try await repository.register(
                registrationRequest(invitationCode: "invite-a")
            )
        } catch {
            registrationError = error
        }

        #expect(registrationError == nil)
        #expect(returnedSession?.access == .authorized)
        #expect(backend.deleteCurrentUserCallCount == 0)
        #expect(provisioner.provisionCallCount == 1)
        #expect(await pendingStore.pendingRegistration() != nil)

        let retriedSession = try await repository.refresh()

        #expect(retriedSession.access == .authorized)
        #expect(backend.deleteCurrentUserCallCount == 0)
        #expect(provisioner.provisionCallCount == 2)
        #expect(await pendingStore.pendingRegistration() == nil)
    }

    @Test("Invitation provisioning waits for verified email and resumes on refresh")
    func invitationProvisioningWaitsForVerification() async throws {
        let backend = AuthenticationBackendSpy()
        backend.identityIsVerified = false
        let provisioner = InvitationProvisionerStub(
            result: .success(membership())
        )
        let pendingStore = InMemoryPendingStaffRegistrationStore()
        let repository = AuthenticationRepository(
            backend: backend,
            sessionLoader: SessionLoaderStub(session: .signedOut),
            invitationProvisioner: provisioner,
            pendingRegistrationStore: pendingStore,
            requiresEmailVerification: true
        )

        let pendingSession = try await repository.register(
            registrationRequest(invitationCode: "invite-a")
        )

        #expect(pendingSession.access == .emailVerificationRequired)
        #expect(backend.sendVerificationCallCount == 1)
        #expect(provisioner.provisionCallCount == 0)
        #expect(await pendingStore.pendingRegistration() != nil)

        backend.identityIsVerified = true
        let authorizedSession = try await repository.refresh()

        #expect(authorizedSession.access == .authorized)
        #expect(provisioner.provisionCallCount == 1)
        #expect(await pendingStore.pendingRegistration() == nil)
    }

    @Test("Registration provisions unverified staff when verification is disabled")
    func registrationProvisionsWhenVerificationIsDisabled() async throws {
        let events = AuthenticationEventRecorder()
        let refreshedIdentity = AuthIdentity(
            userID: "staff-1",
            email: "refreshed@example.edu",
            isEmailVerified: false,
            districtID: "district-a"
        )
        let backend = AuthenticationBackendSpy(events: events)
        backend.identityIsVerified = false
        backend.refreshedIdentity = refreshedIdentity
        let provisioner = InvitationProvisionerStub(
            result: .success(membership()),
            events: events
        )
        let pendingStore = RecordingPendingRegistrationStore(events: events)
        let repository = AuthenticationRepository(
            backend: backend,
            sessionLoader: SessionLoaderStub(session: .signedOut),
            invitationProvisioner: provisioner,
            pendingRegistrationStore: pendingStore,
            requiresEmailVerification: false
        )

        let session = try await repository.register(
            registrationRequest(invitationCode: "invite-a")
        )

        #expect(backend.sendVerificationCallCount == 0)
        #expect(provisioner.provisionCallCount == 1)
        #expect(backend.refreshIdentityCallCount == 1)
        #expect(session.identity == refreshedIdentity)
        #expect(session.membership == membership())
        #expect(session.access(requiringEmailVerification: false) == .authorized)
        #expect(await events.values == ["save", "provision", "refresh", "clear"])
        #expect(await pendingStore.pendingRegistration() == nil)
    }

    @Test("A post-provision refresh failure preserves identity and pending state")
    func postProvisionRefreshFailureIsRecoverable() async {
        let backend = AuthenticationBackendSpy()
        backend.refreshError = AuthenticationTestError.tokenRefreshFailed
        let pendingStore = InMemoryPendingStaffRegistrationStore()
        let repository = AuthenticationRepository(
            backend: backend,
            sessionLoader: SessionLoaderStub(session: .signedOut),
            invitationProvisioner: InvitationProvisionerStub(
                result: .success(membership())
            ),
            pendingRegistrationStore: pendingStore,
            requiresEmailVerification: false
        )

        await #expect(throws: StaffInvitationProvisioningError.claimRefreshPending) {
            _ = try await repository.register(
                registrationRequest(invitationCode: "invite-a")
            )
        }
        #expect(backend.refreshIdentityCallCount == 1)
        #expect(backend.deleteCurrentUserCallCount == 0)
        #expect(await pendingStore.pendingRegistration() != nil)
    }

    @Test("Mismatched refreshed claims preserve identity and pending state")
    func mismatchedRefreshedClaimsAreRecoverable() async {
        let mismatchedIdentities = [
            AuthIdentity(
                userID: "different-staff",
                email: "staff@example.edu",
                isEmailVerified: true,
                districtID: "district-a"
            ),
            AuthIdentity(
                userID: "staff-1",
                email: "staff@example.edu",
                isEmailVerified: true,
                districtID: nil
            ),
            AuthIdentity(
                userID: "staff-1",
                email: "staff@example.edu",
                isEmailVerified: true,
                districtID: "district-b"
            )
        ]

        for mismatchedIdentity in mismatchedIdentities {
            let backend = AuthenticationBackendSpy()
            backend.refreshedIdentity = mismatchedIdentity
            let pendingStore = InMemoryPendingStaffRegistrationStore()
            let repository = AuthenticationRepository(
                backend: backend,
                sessionLoader: SessionLoaderStub(session: .signedOut),
                invitationProvisioner: InvitationProvisionerStub(
                    result: .success(membership())
                ),
                pendingRegistrationStore: pendingStore,
                requiresEmailVerification: false
            )

            await #expect(throws: StaffInvitationProvisioningError.claimRefreshPending) {
                _ = try await repository.register(
                    registrationRequest(invitationCode: "invite-a")
                )
            }
            #expect(backend.refreshIdentityCallCount == 1)
            #expect(backend.deleteCurrentUserCallCount == 0)
            #expect(await pendingStore.pendingRegistration() != nil)
        }
    }

    @Test("A foreign provisioned membership preserves identity and pending state")
    func foreignProvisionedMembershipIsRecoverable() async {
        let backend = AuthenticationBackendSpy()
        let pendingStore = InMemoryPendingStaffRegistrationStore()
        let repository = AuthenticationRepository(
            backend: backend,
            sessionLoader: SessionLoaderStub(session: .signedOut),
            invitationProvisioner: InvitationProvisionerStub(
                result: .success(membership(userID: "different-staff"))
            ),
            pendingRegistrationStore: pendingStore,
            requiresEmailVerification: false
        )

        await #expect(throws: StaffInvitationProvisioningError.claimRefreshPending) {
            _ = try await repository.register(
                registrationRequest(invitationCode: "invite-a")
            )
        }
        #expect(backend.refreshIdentityCallCount == 1)
        #expect(backend.deleteCurrentUserCallCount == 0)
        #expect(await pendingStore.pendingRegistration() != nil)
    }

    @Test("Signing in after email verification completes pending invitation provisioning")
    func signInCompletesPendingRegistration() async throws {
        let backend = AuthenticationBackendSpy()
        backend.identityIsVerified = true
        let provisioner = InvitationProvisionerStub(
            result: .success(membership())
        )
        let pendingStore = InMemoryPendingStaffRegistrationStore()
        await pendingStore.save(
            PendingStaffRegistration(
                identity: AuthIdentity(
                    userID: "staff-1",
                    email: "staff@example.edu",
                    isEmailVerified: false
                ),
                request: registrationRequest(invitationCode: "invite-a")
            )
        )
        let repository = AuthenticationRepository(
            backend: backend,
            sessionLoader: SessionLoaderStub(session: .signedOut),
            invitationProvisioner: provisioner,
            pendingRegistrationStore: pendingStore
        )

        let session = try await repository.signIn(
            email: "staff@example.edu",
            password: "Correct-Horse-9"
        )

        #expect(session.access == .authorized)
        #expect(provisioner.provisionCallCount == 1)
        #expect(await pendingStore.pendingRegistration() == nil)
    }

    @Test("Ambiguous provisioning failure preserves Auth and pending registration")
    func ambiguousProvisioningFailureRemainsRepairable() async throws {
        let backend = AuthenticationBackendSpy()
        backend.identityIsVerified = false
        let pendingStore = InMemoryPendingStaffRegistrationStore()
        let repository = AuthenticationRepository(
            backend: backend,
            sessionLoader: SessionLoaderStub(session: .signedOut),
            invitationProvisioner: InvitationProvisionerStub(
                result: .failure(StaffInvitationProvisioningError.claimRefreshPending)
            ),
            pendingRegistrationStore: pendingStore
        )

        _ = try await repository.register(
            registrationRequest(invitationCode: "invite-a")
        )
        backend.identityIsVerified = true

        await #expect(throws: StaffInvitationProvisioningError.claimRefreshPending) {
            _ = try await repository.refresh()
        }
        #expect(backend.deleteCurrentUserCallCount == 0)
        #expect(await pendingStore.pendingRegistration() != nil)
    }

    @Test("Disabled or unconfigured institutional SSO is unavailable")
    func institutionalSSOIsFailClosed() async {
        let disabled = InstitutionalSSOCoordinator(
            flags: .production,
            provider: nil
        )
        let enabledWithoutProvider = InstitutionalSSOCoordinator(
            flags: FeatureFlags(
                independentStudentAccounts: false,
                guardianAccounts: false,
                aiSuggestions: false,
                institutionalSSO: true,
                staffEmailVerificationRequired: false
            ),
            provider: nil
        )

        #expect(disabled.availability == .unavailable)
        #expect(enabledWithoutProvider.availability == .unavailable)
        await #expect(throws: InstitutionalSSOError.unavailable) {
            _ = try await disabled.beginSignIn(configurationID: "district-a")
        }
    }

    @Test("Authentication presentation errors never reveal account existence")
    func presentationErrorsDoNotEnumerateAccounts() {
        let existingEmailError = NSError(
            domain: "test",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "The email address is already in use."
            ]
        )
        let missingEmailError = NSError(
            domain: "test",
            code: 2,
            userInfo: [
                NSLocalizedDescriptionKey: "No account exists for that email."
            ]
        )

        #expect(
            AuthenticationPresentationPolicy.registrationMessage(
                for: existingEmailError
            ) == AuthenticationPresentationPolicy.registrationFailureMessage
        )
        #expect(
            AuthenticationPresentationPolicy.registrationMessage(
                for: missingEmailError
            ) == AuthenticationPresentationPolicy.registrationFailureMessage
        )
        #expect(
            AuthenticationPresentationPolicy.passwordResetConfirmation
                .contains("If an account matches")
        )
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
    var currentIdentityCallCount = 0
    var deleteCurrentUserCallCount = 0
    var sendVerificationCallCount = 0
    var refreshIdentityCallCount = 0
    var refreshError: Error?
    var refreshedIdentity: AuthIdentity?
    var identityIsVerified = true
    private let events: AuthenticationEventRecorder?

    init(events: AuthenticationEventRecorder? = nil) {
        self.events = events
    }

    func signIn(email: String, password: String) async throws -> AuthIdentity {
        identity
    }

    func createUser(email: String, password: String) async throws -> AuthIdentity {
        createUserCallCount += 1
        return identity
    }

    func currentIdentity() async throws -> AuthIdentity {
        currentIdentityCallCount += 1
        return AuthIdentity(
            userID: "staff-1",
            email: "staff@example.edu",
            isEmailVerified: identityIsVerified
        )
    }

    func deleteCurrentUser() async throws {
        deleteCurrentUserCallCount += 1
    }

    func sendPasswordReset(email: String) async throws {}
    func sendVerification() async throws {
        sendVerificationCallCount += 1
    }

    func refreshIdentity() async throws -> AuthIdentity {
        refreshIdentityCallCount += 1
        await events?.append("refresh")
        if let refreshError {
            throw refreshError
        }
        return refreshedIdentity ?? identity
    }

    func reauthenticate(password: String) async throws {}
    func signOut() async throws {}

    private var identity: AuthIdentity {
        AuthIdentity(
            userID: "staff-1",
            email: "staff@example.edu",
            isEmailVerified: identityIsVerified,
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

private actor FailOnceClearingPendingRegistrationStore:
    PendingStaffRegistrationStoring {
    private var registration: PendingStaffRegistration?
    private var shouldFailNextClear = true

    func save(_ registration: PendingStaffRegistration) {
        self.registration = registration
    }

    func pendingRegistration() -> PendingStaffRegistration? {
        registration
    }

    func clear() throws {
        if shouldFailNextClear {
            shouldFailNextClear = false
            registration = nil
            throw AuthenticationTestError.pendingRegistrationCleanupFailed
        }
        registration = nil
    }
}

private actor AuthenticationEventRecorder {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}

private actor RecordingPendingRegistrationStore:
    PendingStaffRegistrationStoring {
    private var registration: PendingStaffRegistration?
    private let events: AuthenticationEventRecorder

    init(events: AuthenticationEventRecorder) {
        self.events = events
    }

    func save(_ registration: PendingStaffRegistration) async {
        self.registration = registration
        await events.append("save")
    }

    func pendingRegistration() -> PendingStaffRegistration? {
        registration
    }

    func clear() async {
        registration = nil
        await events.append("clear")
    }
}

@MainActor
private final class InvitationProvisionerStub: StaffInvitationProvisioning {
    let result: Result<MembershipContext, Error>
    let events: AuthenticationEventRecorder?
    private(set) var provisionCallCount = 0
    private(set) var lastRequest: StaffInvitationAcceptanceRequest?
    private(set) var lastProvisionedMembership: MembershipContext?

    init(
        result: Result<MembershipContext, Error>,
        events: AuthenticationEventRecorder? = nil
    ) {
        self.result = result
        self.events = events
    }

    func provision(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) async throws -> MembershipContext {
        provisionCallCount += 1
        lastRequest = request
        let membership = try result.get()
        await events?.append("provision")
        lastProvisionedMembership = membership
        return membership
    }
}

private enum AuthenticationTestError: Error {
    case tokenRefreshFailed
    case provisioningFailed
    case pendingRegistrationCleanupFailed
}
