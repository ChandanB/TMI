import Testing
@testable import TMI

#if DEBUG
@Suite("Debug staff invitation provisioning")
@MainActor
struct DebugStaffInvitationProvisionerTests {
    @Test("The Debug alias and allowed email synthesize canonical membership")
    func aliasSynthesizesMembershipForAllowedEmail() async throws {
        let delegate = RecordingStaffInvitationProvisioner()
        let provisioner = DebugStaffInvitationProvisioner(delegate: delegate)
        let identity = AuthIdentity(
            userID: "staff-1",
            email: " \nTMI-DEBUG@Example.COM\t ",
            isEmailVerified: true
        )
        let request = StaffInvitationAcceptanceRequest(
            displayName: "Morgan Lee",
            invitationCode: DebugStaffInvitationProvisioner.invitationAlias,
            privacyPolicyVersion: "privacy-v3",
            acceptableUsePolicyVersion: "aup-v4"
        )

        let membership = try await provisioner.provision(
            request: request,
            identity: identity
        )

        #expect(
            membership == MembershipContext(
                userID: identity.userID,
                districtID: "district-debug",
                schoolIDs: ["school-debug"],
                role: .teacher,
                capabilities: [.studentReadDetail, .studentWriteDetail],
                assignedStudentIDs: [],
                isActive: true,
                version: 1
            )
        )
        #expect(delegate.provisionCallCount == 0)
    }

    @Test("Canonical Debug provisioning does not require trusted claim refresh")
    func canonicalDebugProvisioningSkipsTrustedClaimRefresh() {
        let delegate = RecordingStaffInvitationProvisioner()
        let provisioner = DebugStaffInvitationProvisioner(delegate: delegate)
        let identity = AuthIdentity(
            userID: "staff-1",
            email: " TMI-DEBUG@Example.COM ",
            isEmailVerified: true
        )

        #expect(
            provisioner.requiresTrustedClaimRefresh(
                request: self.aliasRequest,
                identity: identity
            ) == false
        )
        #expect(
            provisioner.requiresTrustedClaimRefresh(
                request: StaffInvitationAcceptanceRequest(
                    displayName: "Morgan Lee",
                    invitationCode: "ordinary-opaque-invitation",
                    privacyPolicyVersion: "privacy-v3",
                    acceptableUsePolicyVersion: "aup-v4"
                ),
                identity: identity
            )
        )
    }

    @Test("The Debug session loader synthesizes an authorized canonical session")
    func sessionLoaderSynthesizesCanonicalSession() async throws {
        let delegate = RecordingAuthenticationSessionLoader()
        let loader = DebugAuthenticationSessionLoader(delegate: delegate)
        let identity = AuthIdentity(
            userID: "staff-1",
            email: "\nTMI-DEBUG@Example.COM\t",
            isEmailVerified: false
        )

        let session = try await loader.session(for: identity)

        #expect(session.access(requiringEmailVerification: false) == .authorized)
        #expect(
            session.identity == AuthIdentity(
                userID: identity.userID,
                email: identity.email,
                isEmailVerified: false,
                districtID: "district-debug"
            )
        )
        #expect(session.membership == DebugStaffInvitationProvisioner.membership(for: identity))
        #expect(delegate.sessionCallCount == 0)
    }

    @Test("The Debug session loader delegates other identities unchanged")
    func sessionLoaderDelegatesOtherIdentities() async throws {
        let delegate = RecordingAuthenticationSessionLoader()
        let loader = DebugAuthenticationSessionLoader(delegate: delegate)
        let identity = AuthIdentity(
            userID: "staff-5",
            email: "other@example.com",
            isEmailVerified: true,
            districtID: "district-a"
        )

        let session = try await loader.session(for: identity)

        #expect(session == delegate.session)
        #expect(delegate.sessionCallCount == 1)
        #expect(delegate.lastIdentity == identity)
    }

    @Test("The Debug alias rejects the wrong email without delegation")
    func aliasRejectsWrongEmail() async {
        let delegate = RecordingStaffInvitationProvisioner()
        let provisioner = DebugStaffInvitationProvisioner(delegate: delegate)

        await #expect(throws: DebugStaffInvitationError.emailNotAllowed) {
            _ = try await provisioner.provision(
                request: self.aliasRequest,
                identity: AuthIdentity(
                    userID: "staff-2",
                    email: "other@example.com",
                    isEmailVerified: true
                )
            )
        }
        #expect(delegate.provisionCallCount == 0)
    }

    @Test("The Debug alias rejects a missing email without delegation")
    func aliasRejectsMissingEmail() async {
        let delegate = RecordingStaffInvitationProvisioner()
        let provisioner = DebugStaffInvitationProvisioner(delegate: delegate)

        await #expect(throws: DebugStaffInvitationError.emailNotAllowed) {
            _ = try await provisioner.provision(
                request: self.aliasRequest,
                identity: AuthIdentity(
                    userID: "staff-3",
                    isEmailVerified: true
                )
            )
        }
        #expect(delegate.provisionCallCount == 0)
    }

    @Test("A non-alias invitation delegates the request and identity unchanged")
    func nonAliasDelegatesUnchanged() async throws {
        let delegate = RecordingStaffInvitationProvisioner()
        let provisioner = DebugStaffInvitationProvisioner(delegate: delegate)
        let request = StaffInvitationAcceptanceRequest(
            displayName: "Taylor Kim",
            invitationCode: "ordinary-opaque-invitation",
            privacyPolicyVersion: "privacy-v5",
            acceptableUsePolicyVersion: "aup-v6"
        )
        let identity = AuthIdentity(
            userID: "staff-4",
            isEmailVerified: false,
            districtID: "district-a"
        )

        let membership = try await provisioner.provision(
            request: request,
            identity: identity
        )

        #expect(membership == delegate.membership)
        #expect(delegate.provisionCallCount == 1)
        #expect(delegate.lastRequest == request)
        #expect(delegate.lastIdentity == identity)
    }

    private var aliasRequest: StaffInvitationAcceptanceRequest {
        StaffInvitationAcceptanceRequest(
            displayName: "Morgan Lee",
            invitationCode: DebugStaffInvitationProvisioner.invitationAlias,
            privacyPolicyVersion: "privacy-v3",
            acceptableUsePolicyVersion: "aup-v4"
        )
    }
}

@MainActor
private final class RecordingStaffInvitationProvisioner: StaffInvitationProvisioning {
    let membership = MembershipContext(
        userID: "staff-1",
        districtID: "district-a",
        schoolIDs: ["school-a"],
        role: .teacher,
        capabilities: [.studentReadDetail],
        assignedStudentIDs: ["student-a"],
        isActive: true,
        version: 1
    )
    private(set) var provisionCallCount = 0
    private(set) var lastRequest: StaffInvitationAcceptanceRequest?
    private(set) var lastIdentity: AuthIdentity?

    func provision(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) async throws -> MembershipContext {
        provisionCallCount += 1
        lastRequest = request
        lastIdentity = identity
        return membership
    }
}

@MainActor
private final class RecordingAuthenticationSessionLoader: AuthenticationSessionLoading {
    let session = AuthSession(
        identity: AuthIdentity(
            userID: "delegate-user",
            isEmailVerified: true,
            districtID: "delegate-district"
        ),
        membership: nil
    )
    private(set) var sessionCallCount = 0
    private(set) var lastIdentity: AuthIdentity?

    func session(for identity: AuthIdentity) async throws -> AuthSession {
        sessionCallCount += 1
        lastIdentity = identity
        return session
    }
}
#endif
