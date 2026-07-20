import Foundation
import Testing
@testable import TMI

@Suite("Auth State Model Trusted Membership", .serialized)
@MainActor
struct AuthStateModelMembershipTests {
    @Test("Editable profile authority cannot elevate the trusted membership")
    func profileAuthorityCannotElevateMembership() async {
        let identity = AuthenticatedIdentity(userID: "user-1", isEmailVerified: true)
        let identityProvider = FakeAuthenticationIdentityProvider(
            identity: identity,
            claims: ["user-1": trustedClaim(userID: "user-1", version: 1)]
        )
        let profile = makeUser(
            id: "user-1",
            role: .districtAdmin,
            districtID: "attacker-district"
        )
        let membership = makeMembership(
            userID: "user-1",
            districtID: "trusted-district",
            role: .teacher,
            version: 1
        )
        let model = makeModel(
            identityProvider: identityProvider,
            profiles: ["user-1": profile],
            membershipProvider: ImmediateMembershipProvider(
                memberships: ["user-1": membership]
            )
        )

        await model.fetch()

        #expect(model.isLoggedIn)
        #expect(model.currentUser?.role == .districtAdmin)
        #expect(model.currentUser?.districtId == "attacker-district")
        #expect(model.currentMembership?.role == .teacher)
        #expect(model.currentMembership?.districtID == "trusted-district")
        #expect(model.currentAuthState == .authenticated(
            AuthenticatedSession(
                profile: profile,
                claim: trustedClaim(
                    userID: "user-1",
                    districtID: "trusted-district",
                    version: 1
                ),
                membership: membership
            )
        ))
    }

    @Test("Missing, malformed, inactive, and cross-tenant access fail with one safe error")
    func unverifiedAccessUsesStandardError() async {
        let identity = AuthenticatedIdentity(userID: "user-1", isEmailVerified: true)
        let profile = makeUser(id: "user-1")
        let scenarios: [MembershipScenario] = [
            .claimFailure,
            .membershipFailure,
            .membership(makeMembership(userID: "user-1", isActive: false)),
            .membership(makeMembership(userID: "other-user")),
            .membership(makeMembership(userID: "user-1", districtID: "other-district")),
            .membership(makeMembership(userID: "user-1", version: 2)),
        ]

        for scenario in scenarios {
            let identityProvider = FakeAuthenticationIdentityProvider(
                identity: identity,
                claims: ["user-1": trustedClaim(userID: "user-1", version: 1)]
            )
            let membershipProvider: any MembershipProviding

            switch scenario {
            case .claimFailure:
                identityProvider.claimError = AuthMembershipTestError.unavailable
                membershipProvider = ImmediateMembershipProvider(memberships: [:])
            case .membershipFailure:
                membershipProvider = ImmediateMembershipProvider(
                    memberships: [:],
                    error: AuthMembershipTestError.unavailable
                )
            case .membership(let membership):
                membershipProvider = ImmediateMembershipProvider(
                    memberships: ["user-1": membership]
                )
            }

            let model = makeModel(
                identityProvider: identityProvider,
                profiles: ["user-1": profile],
                membershipProvider: membershipProvider
            )
            await model.fetch()
            let currentAuthenticationError: AuthenticationError? = model.currentError

            #expect(model.isLoggedIn == false)
            #expect(model.authenticatedSession == nil)
            #expect(model.currentUser == nil)
            #expect(model.currentMembership == nil)
            #expect(currentAuthenticationError?.message == AuthStateModel.organizationAccessErrorMessage)
            #expect(currentAuthenticationError?.traumaInformedMessage == AuthStateModel.organizationAccessErrorMessage)
        }
    }

    @Test("A same-user auth callback refreshes membership version and policy state")
    func sameUserCallbackRefreshesMembership() async {
        let identity = AuthenticatedIdentity(userID: "user-1", isEmailVerified: true)
        let identityProvider = FakeAuthenticationIdentityProvider(
            identity: identity,
            claims: ["user-1": trustedClaim(userID: "user-1", version: 1)]
        )
        let membershipProvider = VersionedMembershipProvider(
            memberships: [
                1: makeMembership(userID: "user-1", role: .teacher, version: 1),
                2: makeMembership(
                    userID: "user-1",
                    role: .counselor,
                    version: 2
                ),
            ]
        )
        let model = makeModel(
            identityProvider: identityProvider,
            profiles: ["user-1": makeUser(id: "user-1")],
            membershipProvider: membershipProvider
        )

        await model.fetch()
        #expect(model.currentMembership?.version == 1)
        #expect(model.currentMembership?.role == .teacher)

        identityProvider.claims["user-1"] = trustedClaim(userID: "user-1", version: 2)
        identityProvider.emit(identity)

        #expect(await eventually {
            model.currentMembership?.version == 2
                && model.currentMembership?.role == .counselor
        })
    }

    @Test("Sign-out invalidates a suspended membership result")
    func signOutInvalidatesSuspendedMembership() async {
        let identity = AuthenticatedIdentity(userID: "user-1", isEmailVerified: true)
        let identityProvider = FakeAuthenticationIdentityProvider(
            identity: identity,
            claims: ["user-1": trustedClaim(userID: "user-1", version: 1)]
        )
        let membershipProvider = ControllableMembershipProvider()
        let model = makeModel(
            identityProvider: identityProvider,
            profiles: ["user-1": makeUser(id: "user-1")],
            membershipProvider: membershipProvider,
            signOutOperation: {
                identityProvider.currentIdentity = nil
            }
        )

        let fetchTask = Task { await model.fetch() }
        #expect(await eventually {
            await membershipProvider.hasPendingRequest(for: "user-1")
        })

        #expect(model.signOut())
        await membershipProvider.resume(
            userID: "user-1",
            with: makeMembership(userID: "user-1")
        )
        await fetchTask.value

        #expect(model.isLoggedIn == false)
        #expect(model.currentAuthState == .unauthenticated)
        #expect(model.authenticatedSession == nil)
    }

    @Test("A late user A result cannot replace a newer user B session")
    func latePriorUserCannotReplaceNewSession() async {
        let identityA = AuthenticatedIdentity(userID: "user-a", isEmailVerified: true)
        let identityB = AuthenticatedIdentity(userID: "user-b", isEmailVerified: true)
        let identityProvider = FakeAuthenticationIdentityProvider(
            identity: identityA,
            claims: [
                "user-a": trustedClaim(userID: "user-a", version: 1),
                "user-b": trustedClaim(userID: "user-b", version: 1),
            ]
        )
        let membershipProvider = ControllableMembershipProvider(
            immediateMemberships: [
                "user-b": makeMembership(userID: "user-b", role: .counselor)
            ]
        )
        let model = makeModel(
            identityProvider: identityProvider,
            profiles: [
                "user-a": makeUser(id: "user-a"),
                "user-b": makeUser(id: "user-b", role: .counselor),
            ],
            membershipProvider: membershipProvider
        )

        let fetchTask = Task { await model.fetch() }
        #expect(await eventually {
            await membershipProvider.hasPendingRequest(for: "user-a")
        })

        identityProvider.emit(identityB)
        #expect(await eventually {
            model.currentMembership?.userID == "user-b"
        })

        await membershipProvider.resume(
            userID: "user-a",
            with: makeMembership(userID: "user-a", role: .districtAdministrator)
        )
        await fetchTask.value

        #expect(model.currentUser?.userID == "user-b")
        #expect(model.currentMembership?.userID == "user-b")
        #expect(model.currentMembership?.role == .counselor)
    }

    @Test("Repeated fetch calls retain exactly one auth listener")
    func repeatedFetchInstallsOneListener() async {
        let identity = AuthenticatedIdentity(userID: "user-1", isEmailVerified: true)
        let identityProvider = FakeAuthenticationIdentityProvider(
            identity: identity,
            claims: ["user-1": trustedClaim(userID: "user-1", version: 1)]
        )
        let model = makeModel(
            identityProvider: identityProvider,
            profiles: ["user-1": makeUser(id: "user-1")],
            membershipProvider: ImmediateMembershipProvider(
                memberships: ["user-1": makeMembership(userID: "user-1")]
            )
        )

        await model.fetch()
        await model.fetch()
        await model.fetch()

        #expect(identityProvider.listenerInstallCount == 1)
        #expect(model.isLoggedIn)
    }

    @Test("Auth listener removal is idempotent")
    func authListenerRemovalIsIdempotent() {
        var removalCount = 0
        let handle = AuthStateListenerHandle {
            removalCount += 1
        }

        handle.remove()
        handle.remove()

        #expect(removalCount == 1)
    }

    @Test("Failed sign-out preserves the complete trusted session")
    func failedSignOutPreservesCompleteSession() async {
        let identity = AuthenticatedIdentity(userID: "user-1", isEmailVerified: true)
        let identityProvider = FakeAuthenticationIdentityProvider(
            identity: identity,
            claims: ["user-1": trustedClaim(userID: "user-1", version: 1)]
        )
        let model = makeModel(
            identityProvider: identityProvider,
            profiles: ["user-1": makeUser(id: "user-1")],
            membershipProvider: ImmediateMembershipProvider(
                memberships: ["user-1": makeMembership(userID: "user-1")]
            ),
            signOutOperation: {
                throw AuthMembershipTestError.unavailable
            }
        )
        await model.fetch()
        let priorSession = model.authenticatedSession

        #expect(model.signOut() == false)
        #expect(model.authenticatedSession == priorSession)
        #expect(model.currentUser == priorSession?.profile)
        #expect(model.currentClaim == priorSession?.claim)
        #expect(model.currentMembership == priorSession?.membership)
        #expect(model.currentAuthState == priorSession.map(AuthenticationState.authenticated))
    }

    @Test("Successful sign-out clears every trusted session field")
    func successfulSignOutClearsCompleteSession() async {
        let identity = AuthenticatedIdentity(userID: "user-1", isEmailVerified: true)
        let identityProvider = FakeAuthenticationIdentityProvider(
            identity: identity,
            claims: ["user-1": trustedClaim(userID: "user-1", version: 1)]
        )
        let model = makeModel(
            identityProvider: identityProvider,
            profiles: ["user-1": makeUser(id: "user-1")],
            membershipProvider: ImmediateMembershipProvider(
                memberships: ["user-1": makeMembership(userID: "user-1")]
            ),
            signOutOperation: {
                identityProvider.currentIdentity = nil
            }
        )
        await model.fetch()
        #expect(model.authenticatedSession != nil)

        #expect(model.signOut())
        #expect(model.authenticatedSession == nil)
        #expect(model.currentUser == nil)
        #expect(model.currentClaim == nil)
        #expect(model.currentMembership == nil)
        #expect(model.currentAuthState == .unauthenticated)

        identityProvider.emit(identity)
        #expect(await eventually {
            model.isLoggedIn && model.sessionID != nil
        })
    }

    private func makeModel(
        identityProvider: FakeAuthenticationIdentityProvider,
        profiles: [String: TMIUser],
        membershipProvider: any MembershipProviding,
        signOutOperation: (@MainActor () throws -> Void)? = nil
    ) -> AuthStateModel {
        AuthStateModel(
            signOutOperation: signOutOperation,
            identityProvider: identityProvider,
            profileProvider: FakeUserProfileProvider(profiles: profiles),
            membershipProvider: membershipProvider,
            automaticallyStart: false
        )
    }

    private func trustedClaim(
        userID: String,
        districtID: String = "trusted-district",
        version: Int
    ) -> TrustedTenantClaim {
        TrustedTenantClaim(
            userID: userID,
            districtID: districtID,
            accessClass: .staff,
            membershipVersion: version
        )
    }

    private func makeUser(
        id: String,
        role: UserRole = .teacher,
        districtID: String? = nil
    ) -> TMIUser {
        TMIUser(
            id: id,
            userID: id,
            displayName: "Test Educator",
            email: "educator@example.com",
            role: role,
            districtId: districtID,
            createdAt: .distantPast
        )
    }

    private func makeMembership(
        userID: String,
        districtID: String = "trusted-district",
        role: StaffRole = .teacher,
        isActive: Bool = true,
        version: Int = 1
    ) -> MembershipContext {
        MembershipContext(
            userID: userID,
            districtID: districtID,
            schoolIDs: ["school-1"],
            role: role,
            capabilities: [.studentReadDetail],
            assignedStudentIDs: ["student-1"],
            isActive: isActive,
            version: version
        )
    }

    private func eventually(
        _ predicate: @escaping @MainActor () async -> Bool
    ) async -> Bool {
        for _ in 0..<400 {
            if await predicate() {
                return true
            }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        return await predicate()
    }
}

private enum MembershipScenario {
    case claimFailure
    case membershipFailure
    case membership(MembershipContext)
}

@MainActor
private final class FakeAuthenticationIdentityProvider: AuthenticationIdentityProviding {
    var currentIdentity: AuthenticatedIdentity?
    var claims: [String: TrustedTenantClaim]
    var claimError: Error?
    private var listener: (@MainActor (AuthenticatedIdentity?) -> Void)?
    private(set) var listenerInstallCount = 0

    init(
        identity: AuthenticatedIdentity?,
        claims: [String: TrustedTenantClaim]
    ) {
        currentIdentity = identity
        self.claims = claims
    }

    func trustedClaim(for identity: AuthenticatedIdentity) async throws -> TrustedTenantClaim {
        if let claimError {
            throw claimError
        }
        guard let claim = claims[identity.userID] else {
            throw AuthMembershipTestError.missingClaim
        }
        return claim
    }

    func addStateDidChangeListener(
        _ listener: @escaping @MainActor (AuthenticatedIdentity?) -> Void
    ) -> AuthStateListenerHandle {
        listenerInstallCount += 1
        self.listener = listener
        return AuthStateListenerHandle { [weak self] in
            self?.listener = nil
        }
    }

    func emit(_ identity: AuthenticatedIdentity?) {
        currentIdentity = identity
        listener?(identity)
    }
}

private actor FakeUserProfileProvider: UserProfileProviding {
    private let profiles: [String: TMIUser]

    init(profiles: [String: TMIUser]) {
        self.profiles = profiles
    }

    func profile(for identity: AuthenticatedIdentity) async throws -> TMIUser? {
        profiles[identity.userID]
    }
}

private actor ImmediateMembershipProvider: MembershipProviding {
    private let memberships: [String: MembershipContext]
    private let error: Error?

    init(
        memberships: [String: MembershipContext],
        error: Error? = nil
    ) {
        self.memberships = memberships
        self.error = error
    }

    func membership(for claim: TrustedTenantClaim) async throws -> MembershipContext {
        if let error {
            throw error
        }
        guard let membership = memberships[claim.userID] else {
            throw AuthMembershipTestError.missingMembership
        }
        return membership
    }
}

private actor VersionedMembershipProvider: MembershipProviding {
    private let memberships: [Int: MembershipContext]

    init(memberships: [Int: MembershipContext]) {
        self.memberships = memberships
    }

    func membership(for claim: TrustedTenantClaim) async throws -> MembershipContext {
        guard let membership = memberships[claim.membershipVersion] else {
            throw AuthMembershipTestError.missingMembership
        }
        return membership
    }
}

private actor ControllableMembershipProvider: MembershipProviding {
    private let immediateMemberships: [String: MembershipContext]
    private var continuations: [
        String: CheckedContinuation<MembershipContext, any Error>
    ] = [:]

    init(immediateMemberships: [String: MembershipContext] = [:]) {
        self.immediateMemberships = immediateMemberships
    }

    func membership(for claim: TrustedTenantClaim) async throws -> MembershipContext {
        if let membership = immediateMemberships[claim.userID] {
            return membership
        }

        return try await withCheckedThrowingContinuation { continuation in
            continuations[claim.userID] = continuation
        }
    }

    func hasPendingRequest(for userID: String) -> Bool {
        continuations[userID] != nil
    }

    func resume(userID: String, with membership: MembershipContext) {
        continuations.removeValue(forKey: userID)?.resume(returning: membership)
    }
}

private enum AuthMembershipTestError: Error {
    case missingClaim
    case missingMembership
    case unavailable
}
