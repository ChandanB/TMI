# TMI Authentication Availability Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure every supported build exits startup loading and lets invited staff register or repair an existing account while email verification is temporarily disabled.

**Architecture:** A shared client feature flag controls verification presentation and repository behavior, while the invitation callable receives the matching server policy. `AuthStateModel` bounds every remote authorization attempt and exposes explicit recovery and access-setup states; trusted invitation provisioning remains the only path that can create staff claims and membership.

**Tech Stack:** Swift 6.3, SwiftUI, Observation, Swift Testing, Firebase Auth/Firestore/Functions, TypeScript, Vitest, Firebase Emulator Suite

---

## File map

| Action | Path | Responsibility |
|---|---|---|
| Modify | `TMI/Core/Configuration/FeatureFlags.swift` | Temporary staff email-verification policy |
| Modify | `TMI/Core/Dependencies/AppDependencies.swift` | Inject the same client policy into authentication |
| Modify | `TMI/Features/Authentication/AuthSession.swift` | Evaluate access under the configured verification policy |
| Modify | `TMI/Features/Authentication/AuthenticationRepository.swift` | Immediate provisioning and existing-account onboarding |
| Modify | `TMI/Features/Authentication/FirebaseStaffInvitationProvisioner.swift` | Send authority-free invitation acceptance requests |
| Modify | `TMI/StateModels/AuthStateModel.swift` | Bounded authorization, retry, setup, and sign-out states |
| Create | `TMI/Views/Authentication/StaffAccessSetupView.swift` | Secure invitation repair for existing identities |
| Create | `TMI/Views/Authentication/AuthenticationRecoveryView.swift` | Retry and Sign Out after startup authorization failure |
| Modify | `TMI/App/TMIApp.swift` | Route setup and recovery states without indefinite loading |
| Modify | `TMI/Views/Authentication/AuthenticationView.swift` | Hide verification controls while disabled |
| Modify | `TMI/Views/Authentication/SimplifiedRegistrationView.swift` | Refresh immediately after trusted provisioning |
| Modify | `firebase/src/invitations.ts` | Server verification policy and truthful profile value |
| Modify | `firebase/test/invitations.test.ts` | Backend policy coverage |
| Modify | `TMITests/Features/Authentication/AuthSessionTests.swift` | Repository and session-policy coverage |
| Modify | `TMITests/Features/Authentication/FirebaseStaffInvitationProvisionerTests.swift` | Callable request-shape coverage |
| Modify | `TMITests/StateModels/AuthStateModelMembershipTests.swift` | Timeout, retry, and setup-state coverage |
| Create | `TMIUITests/AuthenticationAvailabilityUITests.swift` | Cross-platform startup recovery acceptance |

## Task 1: Add the temporary client verification policy

**Files:**
- Modify: `TMI/Core/Configuration/FeatureFlags.swift`
- Modify: `TMI/Features/Authentication/AuthSession.swift`
- Modify: `TMITests/Features/Authentication/AuthSessionTests.swift`

- [ ] **Step 1: Write failing session-policy tests**

Add these tests to `AuthSessionTests`:

```swift
@Test("Unverified staff can continue while verification is disabled")
func unverifiedStaffCanContinueWhenVerificationIsDisabled() {
    let session = AuthSession(
        identity: AuthIdentity(
            userID: "staff-1",
            email: "staff@example.edu",
            isEmailVerified: false
        ),
        membership: membership()
    )

    #expect(
        session.access(requiringEmailVerification: false) == .authorized
    )
}

@Test("Unverified staff remain gated when verification is enabled")
func unverifiedStaffRemainGatedWhenVerificationIsEnabled() {
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

@Test("Current production builds disable staff email verification")
func productionDisablesStaffEmailVerification() {
    #expect(FeatureFlags.production.staffEmailVerificationRequired == false)
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-AuthRepair-DD \
  -only-testing:TMITests/AuthSessionTests
```

Expected: compilation fails because `staffEmailVerificationRequired` and `access(requiringEmailVerification:)` do not exist.

- [ ] **Step 3: Implement the minimal flag and policy**

Add the stored flag and set the temporary production value:

```swift
nonisolated struct FeatureFlags: Sendable, Equatable {
    let independentStudentAccounts: Bool
    let guardianAccounts: Bool
    let aiSuggestions: Bool
    let institutionalSSO: Bool
    let staffEmailVerificationRequired: Bool

    static let production = FeatureFlags(
        independentStudentAccounts: false,
        guardianAccounts: false,
        aiSuggestions: false,
        institutionalSSO: false,
        staffEmailVerificationRequired: false
    )
}
```

Update every explicit `FeatureFlags(...)` construction to provide the intended value. Test-only configurations that exercise the old behavior must pass `true`.

Replace the fixed `AuthSession.access` implementation with:

```swift
var access: AppAccessState {
    access(requiringEmailVerification: true)
}

func access(requiringEmailVerification: Bool) -> AppAccessState {
    guard let identity else {
        return .signedOut
    }
    if requiringEmailVerification && !identity.isEmailVerified {
        return .emailVerificationRequired
    }

    switch membershipState {
    case .missing:
        return .membershipRequired
    case .inactive:
        return .membershipInactive
    case .active(let membership):
        guard membership.isActive,
              membership.version > 0,
              membership.userID == identity.userID,
              identity.districtID.map({ $0 == membership.districtID }) ?? true else {
            return .membershipRequired
        }
        return .authorized
    }
}
```

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run the Step 2 command. Expected: `AuthSessionTests` passes.

- [ ] **Step 5: Commit**

```bash
git add TMI/Core/Configuration/FeatureFlags.swift \
  TMI/Features/Authentication/AuthSession.swift \
  TMITests/Features/Authentication/AuthSessionTests.swift
git commit -m "feat: make staff email verification configurable"
```

## Task 2: Provision registration immediately while verification is disabled

**Files:**
- Modify: `TMI/Core/Dependencies/AppDependencies.swift`
- Modify: `TMI/Features/Authentication/AuthenticationRepository.swift`
- Modify: `TMITests/Features/Authentication/AuthSessionTests.swift`

- [ ] **Step 1: Write failing repository tests**

Add:

```swift
@Test("Disabled verification skips email and provisions registration immediately")
func disabledVerificationProvisionsImmediately() async throws {
    let backend = AuthenticationBackendSpy()
    backend.identityIsVerified = false
    let provisioner = InvitationProvisionerStub(
        result: .success(membership())
    )
    let repository = AuthenticationRepository(
        backend: backend,
        sessionLoader: SessionLoaderStub(session: .signedOut),
        invitationProvisioner: provisioner,
        pendingRegistrationStore: InMemoryPendingStaffRegistrationStore(),
        requiresEmailVerification: false
    )

    let session = try await repository.register(
        registrationRequest(invitationCode: "invite-a")
    )

    #expect(backend.sendVerificationCallCount == 0)
    #expect(provisioner.provisionCallCount == 1)
    #expect(
        session.access(requiringEmailVerification: false) == .authorized
    )
}

@Test("Enabled verification preserves pending registration")
func enabledVerificationPreservesPendingRegistration() async throws {
    let backend = AuthenticationBackendSpy()
    backend.identityIsVerified = false
    let pendingStore = InMemoryPendingStaffRegistrationStore()
    let repository = AuthenticationRepository(
        backend: backend,
        sessionLoader: SessionLoaderStub(session: .signedOut),
        invitationProvisioner: InvitationProvisionerStub(
            result: .success(membership())
        ),
        pendingRegistrationStore: pendingStore,
        requiresEmailVerification: true
    )

    let session = try await repository.register(
        registrationRequest(invitationCode: "invite-a")
    )

    #expect(backend.sendVerificationCallCount == 1)
    #expect(session.access == .emailVerificationRequired)
    #expect(await pendingStore.pendingRegistration() != nil)
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run the Task 1 Step 2 command. Expected: compilation fails because `AuthenticationRepository` has no policy initializer.

- [ ] **Step 3: Implement policy-backed provisioning**

Add `requiresEmailVerification` to `AuthenticationRepository`:

```swift
private let requiresEmailVerification: Bool

init(
    backend: any AuthenticationBackend,
    sessionLoader: any AuthenticationSessionLoading,
    invitationProvisioner: any StaffInvitationProvisioning,
    pendingRegistrationStore: any PendingStaffRegistrationStoring =
        InMemoryPendingStaffRegistrationStore(),
    requiresEmailVerification: Bool = true
) {
    self.backend = backend
    self.sessionLoader = sessionLoader
    self.invitationProvisioner = invitationProvisioner
    self.pendingRegistrationStore = pendingRegistrationStore
    self.requiresEmailVerification = requiresEmailVerification
}
```

In `register`, replace the unconditional verification branch with:

```swift
try await pendingRegistrationStore.save(pendingRegistration)
if requiresEmailVerification {
    try await backend.sendVerification()
    guard identity.isEmailVerified else {
        return AuthSession(identity: identity, membership: nil)
    }
}
return try await completePendingRegistration(
    pendingRegistration,
    identity: identity
)
```

Change the guard in `completePendingRegistration` to:

```swift
guard (!requiresEmailVerification || identity.isEmailVerified),
      pendingRegistration.identityID == identity.userID else {
    return AuthSession(identity: identity, membership: nil)
}
```

Use the same policy in `signIn` and `refresh` when deciding whether pending onboarding may complete.

In `AppDependencies.production(firestore:)`, create one local flags value and inject it:

```swift
let flags = FeatureFlags.production
let authentication = AuthenticationRepository(
    backend: FirebaseAuthenticationBackend(),
    sessionLoader: FirebaseAuthenticationSessionLoader(
        membershipProvider: membership,
        requiresEmailVerification: flags.staffEmailVerificationRequired
    ),
    invitationProvisioner: FirebaseStaffInvitationProvisioner(),
    pendingRegistrationStore: SecurePendingStaffRegistrationStore(),
    requiresEmailVerification: flags.staffEmailVerificationRequired
)
```

Add the same Boolean to `FirebaseAuthenticationSessionLoader` and use `session.access(requiringEmailVerification:)` semantics instead of returning early solely because `identity.isEmailVerified` is false.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the Task 1 Step 2 command. Expected: all authentication repository and session tests pass.

- [ ] **Step 5: Commit**

```bash
git add TMI/Core/Dependencies/AppDependencies.swift \
  TMI/Features/Authentication/AuthenticationRepository.swift \
  TMITests/Features/Authentication/AuthSessionTests.swift
git commit -m "fix: provision staff without temporary email gate"
```

## Task 3: Align trusted invitation provisioning on the backend

**Files:**
- Modify: `firebase/src/invitations.ts`
- Modify: `firebase/test/invitations.test.ts`

- [ ] **Step 1: Write failing backend policy tests**

Add a `requireVerifiedEmail` argument to the test handler factory, then add:

```typescript
it("accepts an unverified invited user when verification is disabled", async () => {
  authUser = { ...authUser, emailVerified: false };

  const result = await makeHandler(false)(callableRequest());

  expect(result.userID).toBe(userID);
  expect(claimsWrites).toHaveLength(1);
  const profile = await firestore.doc(`users/${userID}/private/profile`).get();
  expect(profile.data()?.isEmailVerified).toBe(false);
});

it("still requires verification when the policy is enabled", async () => {
  authUser = { ...authUser, emailVerified: false };

  await expectHttpsError(
    makeHandler(true)(callableRequest()),
    "failed-precondition",
  );

  expect(claimsWrites).toEqual([]);
  await expectInvitationToRemainActive();
});
```

- [ ] **Step 2: Run the backend test and verify RED**

```bash
npm --prefix firebase test -- invitations.test.ts
```

Expected: TypeScript fails because the handler policy does not exist, or the unverified-user test returns `failed-precondition`.

- [ ] **Step 3: Implement server policy without falsifying profile data**

Extend the dependencies:

```typescript
export interface ProvisionStaffMembershipDependencies {
  readonly firestore: Firestore;
  readonly now: () => Date;
  readonly requireVerifiedEmail: boolean;
  readonly getAuthUser: (userID: string) => Promise<ProvisioningAuthUser>;
  readonly setCustomUserClaims: (
    userID: string,
    claims: Readonly<Record<string, unknown>>,
  ) => Promise<void>;
}
```

Pass the policy into validation:

```typescript
const normalizedEmail = validateAuthUser(
  authUser,
  userID,
  dependencies.requireVerifiedEmail,
);
```

Update validation:

```typescript
const validateAuthUser = (
  authUser: ProvisioningAuthUser,
  requestedUserID: string,
  requireVerifiedEmail: boolean,
): string => {
  if (
    authUser.userID !== requestedUserID ||
    authUser.disabled ||
    typeof authUser.email !== "string" ||
    authUser.email.trim().length === 0
  ) {
    throw new HttpsError(
      "permission-denied",
      "The authenticated account cannot accept an invitation.",
    );
  }
  if (requireVerifiedEmail && !authUser.emailVerified) {
    throw new HttpsError(
      "failed-precondition",
      "Verify the account email before accepting an invitation.",
    );
  }
  return normalizeEmail(authUser.email);
};
```

Persist the actual value:

```typescript
email: normalizedEmail,
isEmailVerified: authUser.emailVerified,
```

Set the temporary production dependency explicitly:

```typescript
requireVerifiedEmail: false,
```

Test helpers must pass `true` by default so all prior verification-sensitive tests retain their original meaning.

- [ ] **Step 4: Run backend tests and verify GREEN**

```bash
npm --prefix firebase test
```

Expected: all Firebase test files and tests pass.

- [ ] **Step 5: Commit**

```bash
git add firebase/src/invitations.ts firebase/test/invitations.test.ts
git commit -m "fix: align temporary invitation verification policy"
```

## Task 4: Bound startup authorization and expose recovery

**Files:**
- Modify: `TMI/StateModels/AuthStateModel.swift`
- Create: `TMI/Views/Authentication/AuthenticationRecoveryView.swift`
- Modify: `TMI/App/TMIApp.swift`
- Modify: `TMITests/StateModels/AuthStateModelMembershipTests.swift`

- [ ] **Step 1: Write failing timeout and retry tests**

Add a suspending profile provider and tests:

```swift
@Test("A stalled persisted session exits startup loading")
func stalledSessionExitsLoading() async {
    let identity = AuthenticatedIdentity(
        userID: "staff-1",
        isEmailVerified: false
    )
    let identityProvider = FakeAuthenticationIdentityProvider(
        identity: identity,
        claims: [:]
    )
    let model = AuthStateModel(
        identityProvider: identityProvider,
        profileProvider: SuspendingUserProfileProvider(),
        membershipProvider: ImmediateMembershipProvider(memberships: [:]),
        featureFlags: FeatureFlags(
            independentStudentAccounts: false,
            guardianAccounts: false,
            aiSuggestions: false,
            institutionalSSO: false,
            staffEmailVerificationRequired: false
        ),
        authorizationTimeoutSeconds: 0.01,
        automaticallyStart: false
    )

    await model.fetch()

    #expect(model.isCheckingAuth == false)
    #expect(model.canRetryAuthorization)
    #expect(model.isLoggedIn == false)
}

@Test("Retry starts a fresh authorization attempt")
func retryStartsFreshAuthorization() async {
    let profileProvider = SequencedUserProfileProvider(
        results: [
            .failure(ConcurrencyError.timeout),
            .success(makeUser(id: "staff-1")),
        ]
    )
    let model = makeRecoverableModel(profileProvider: profileProvider)

    await model.fetch()
    await model.retryAuthorization()

    #expect(profileProvider.callCount == 2)
    #expect(model.isLoggedIn)
}
```

The suspending provider must use this cancellation-aware operation:

```swift
struct SuspendingUserProfileProvider: UserProfileProviding {
    func profile(for identity: AuthenticatedIdentity) async throws -> TMIUser? {
        try await Task.sleep(for: .seconds(60))
        return nil
    }
}
```

- [ ] **Step 2: Run state-model tests and verify RED**

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-AuthRepair-DD \
  -only-testing:TMITests/AuthStateModelMembershipTests
```

Expected: compilation fails because the flags, timeout, and retry API do not exist.

- [ ] **Step 3: Implement bounded authorization**

Add:

```swift
private let featureFlags: FeatureFlags
private let authorizationTimeoutSeconds: TimeInterval

var canRetryAuthorization: Bool {
    identityProvider.currentIdentity != nil
        && currentError?.type == .institutionVerificationFailed
}
```

Extend the initializer:

```swift
featureFlags: FeatureFlags = .production,
authorizationTimeoutSeconds: TimeInterval = 10,
```

In `authorize`, replace the fixed verification guard with:

```swift
if featureFlags.staffEmailVerificationRequired && !identity.isEmailVerified {
    guard isCurrentAuthorization(identity, generation: generation) else {
        return
    }
    updateState(.loaded(.verifying(.institutionalEmail)))
    authorizationTask = nil
    return
}
```

Wrap each remote boundary:

```swift
let profile = try await withTimeout(seconds: authorizationTimeoutSeconds) {
    try await self.profileProvider.profile(for: identity)
}
let claim = try await withTimeout(seconds: authorizationTimeoutSeconds) {
    try await self.identityProvider.trustedClaim(for: identity)
}
let membership = try await withTimeout(seconds: authorizationTimeoutSeconds) {
    try await self.membershipProvider.membership(for: claim)
}
```

Add retry:

```swift
func retryAuthorization() async {
    guard let identity = identityProvider.currentIdentity else {
        transitionToUnauthenticated(logLogout: false)
        return
    }
    let task = startAuthorization(for: identity)
    await task.value
}
```

Create `AuthenticationRecoveryView`:

```swift
struct AuthenticationRecoveryView: View {
    let retry: @MainActor () async -> Void
    let signOut: @MainActor () -> Bool
    @State private var isRetrying = false
    @State private var signOutFailed = false

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .auth)

            ContentUnavailableView {
                Label("Unable to Finish Signing In", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check your connection, then retry or sign out.")
            } actions: {
                Button("Retry") {
                    Task { @MainActor in
                        isRetrying = true
                        await retry()
                        isRetrying = false
                    }
                }
                .disabled(isRetrying)
                Button("Sign Out") {
                    signOutFailed = !signOut()
                }
            }
        }
        .alert("Couldn’t Sign Out", isPresented: $signOutFailed) {
            Button("OK", role: .cancel) { }
        }
    }
}
```

Apply these identifiers to the container and buttons:

```swift
"authentication.recovery.screen"
"authentication.recovery.retry"
"authentication.recovery.signOut"
```

Route `ContentView` before the ordinary `AuthenticationView`:

```swift
if authStateModel.isCheckingAuth {
    LoadingView()
} else if authStateModel.isLoggedIn {
    authenticatedContent
} else if authStateModel.canRetryAuthorization {
    AuthenticationRecoveryView(
        retry: authStateModel.retryAuthorization,
        signOut: authStateModel.signOut
    )
} else {
    AuthenticationView()
}
```

- [ ] **Step 4: Run state-model tests and verify GREEN**

Run the Step 2 command. Expected: all `AuthStateModelMembershipTests` pass and no test remains suspended.

- [ ] **Step 5: Commit**

```bash
git add TMI/StateModels/AuthStateModel.swift \
  TMI/Views/Authentication/AuthenticationRecoveryView.swift \
  TMI/App/TMIApp.swift \
  TMITests/StateModels/AuthStateModelMembershipTests.swift
git commit -m "fix: make startup authentication recoverable"
```

## Task 5: Add secure access setup for existing identities

**Files:**
- Modify: `TMI/Features/Authentication/AuthenticationRepository.swift`
- Modify: `TMI/Features/Authentication/FirebaseStaffInvitationProvisioner.swift`
- Modify: `TMI/StateModels/AuthStateModel.swift`
- Create: `TMI/Views/Authentication/StaffAccessSetupView.swift`
- Modify: `TMI/App/TMIApp.swift`
- Modify: `TMITests/Features/Authentication/AuthSessionTests.swift`
- Modify: `TMITests/Features/Authentication/FirebaseStaffInvitationProvisionerTests.swift`
- Modify: `TMITests/StateModels/AuthStateModelMembershipTests.swift`

- [ ] **Step 1: Write failing onboarding-repair tests**

Add a focused request type and repository expectation:

```swift
@Test("Existing identity can complete trusted invitation onboarding")
func existingIdentityCompletesInvitationOnboarding() async throws {
    let identity = AuthIdentity(
        userID: "staff-1",
        email: "staff@example.edu",
        isEmailVerified: false
    )
    let backend = AuthenticationBackendSpy()
    backend.currentIdentity = identity
    let provisioner = InvitationProvisionerStub(
        result: .success(membership())
    )
    let repository = AuthenticationRepository(
        backend: backend,
        sessionLoader: SessionLoaderStub(session: .signedOut),
        invitationProvisioner: provisioner,
        requiresEmailVerification: false
    )

    let session = try await repository.completeStaffOnboarding(
        StaffOnboardingRequest(
            displayName: "Existing Staff",
            invitationCode: "invite-a",
            privacyPolicyVersion: StaffPolicyVersions.privacyPolicyVersion,
            acceptableUsePolicyVersion: StaffPolicyVersions.acceptableUsePolicyVersion
        )
    )

    #expect(provisioner.provisionCallCount == 1)
    #expect(
        session.access(requiringEmailVerification: false) == .authorized
    )
}
```

Add state tests proving that a missing profile produces setup and that successful setup refetches the trusted session:

```swift
@Test("Missing canonical profile requests staff access setup")
func missingProfileRequestsAccessSetup() async {
    let model = makeModel(
        identityProvider: verifiedIdentityProvider(),
        profiles: [:],
        membershipProvider: ImmediateMembershipProvider(memberships: [:])
    )

    await model.fetch()

    #expect(model.requiresStaffAccessSetup)
    #expect(model.isCheckingAuth == false)
    #expect(model.isLoggedIn == false)
}
```

- [ ] **Step 2: Run focused tests and verify RED**

Run both Task 1 Step 2 and Task 4 Step 2 commands. Expected: compilation fails because onboarding repair and setup state do not exist.

- [ ] **Step 3: Implement the existing-identity repository boundary**

Define authority-free invitation input:

```swift
nonisolated struct StaffOnboardingRequest: Sendable, Equatable {
    let displayName: String
    let invitationCode: String
    let privacyPolicyVersion: String
    let acceptableUsePolicyVersion: String
}

nonisolated struct StaffInvitationAcceptanceRequest: Sendable, Equatable {
    let displayName: String
    let invitationCode: String
    let privacyPolicyVersion: String
    let acceptableUsePolicyVersion: String
}
```

Extend protocols:

```swift
func currentIdentity() async throws -> AuthIdentity
func completeStaffOnboarding(
    _ request: StaffOnboardingRequest
) async throws -> AuthSession

func provision(
    request: StaffInvitationAcceptanceRequest,
    identity: AuthIdentity
) async throws -> MembershipContext
```

Implement `FirebaseAuthenticationBackend.currentIdentity()` from `auth.currentUser` without accepting a caller-supplied UID. Change `StaffInvitationProvisioning` and `FirebaseStaffInvitationProvisioner` to accept `StaffInvitationAcceptanceRequest`; its callable payload remains exactly `invitationCode`, `displayName`, and the two policy versions.

Add this conversion for new registrations:

```swift
extension PendingStaffRegistration {
    var invitationAcceptanceRequest: StaffInvitationAcceptanceRequest {
        StaffInvitationAcceptanceRequest(
            displayName: displayName,
            invitationCode: invitationCode,
            privacyPolicyVersion: privacyPolicyVersion,
            acceptableUsePolicyVersion: acceptableUsePolicyVersion
        )
    }
}
```

Implement existing-account repair:

```swift
func completeStaffOnboarding(
    _ request: StaffOnboardingRequest
) async throws -> AuthSession {
    let identity = try await backend.currentIdentity()
    let membership = try await invitationProvisioner.provision(
        request: StaffInvitationAcceptanceRequest(
            displayName: request.displayName,
            invitationCode: request.invitationCode,
            privacyPolicyVersion: request.privacyPolicyVersion,
            acceptableUsePolicyVersion: request.acceptableUsePolicyVersion
        ),
        identity: identity
    )
    let trustedIdentity = AuthIdentity(
        userID: identity.userID,
        email: identity.email,
        isEmailVerified: identity.isEmailVerified,
        districtID: membership.districtID
    )
    return AuthSession(identity: trustedIdentity, membership: membership)
}
```

Update pending registration provisioning to pass `pendingRegistration.invitationAcceptanceRequest`. The trusted invitation remains the source of role, district, school, and capabilities.

The callable request already ignores client role authority; do not add role, district, school, or capabilities to `StaffOnboardingRequest`.

- [ ] **Step 4: Implement state and UI**

Add:

```swift
var requiresStaffAccessSetup: Bool {
    if case .loaded(.registering(.institutionVerification)) = state {
        return true
    }
    return false
}
```

When the profile is absent, transition to `.registering(.institutionVerification)`.

Store this injected onboarding closure:

```swift
private let completeStaffOnboardingOperation:
    @MainActor (StaffOnboardingRequest) async throws -> AuthSession
```

Resolve it in the initializer from the injected `authentication` dependency, falling back to a closure that throws `UnconfiguredAuthenticationDependencyError.unavailable`. Then add:

```swift
func completeStaffAccessSetup(
    displayName: String,
    invitationCode: String
) async throws {
    _ = try await completeStaffOnboardingOperation(
        StaffOnboardingRequest(
            displayName: displayName,
            invitationCode: invitationCode,
            privacyPolicyVersion: StaffPolicyVersions.privacyPolicyVersion,
            acceptableUsePolicyVersion: StaffPolicyVersions.acceptableUsePolicyVersion
        )
    )
    await fetch()
}
```

Create `StaffAccessSetupView` with full name and invitation fields, a submit button, non-enumerating error text, and Sign Out. Required identifiers:

```swift
"authentication.accessSetup.screen"
"authentication.accessSetup.name"
"authentication.accessSetup.invitation"
"authentication.accessSetup.submit"
"authentication.accessSetup.signOut"
```

Route it in `ContentView` before recovery:

```swift
} else if authStateModel.requiresStaffAccessSetup {
    StaffAccessSetupView(
        complete: authStateModel.completeStaffAccessSetup,
        signOut: authStateModel.signOut
    )
} else if authStateModel.canRetryAuthorization {
```

- [ ] **Step 5: Run focused tests and verify GREEN**

Run both focused Swift commands. Expected: all authentication repository and state-model tests pass.

- [ ] **Step 6: Commit**

```bash
git add TMI/Features/Authentication/AuthenticationRepository.swift \
  TMI/Features/Authentication/FirebaseStaffInvitationProvisioner.swift \
  TMI/StateModels/AuthStateModel.swift \
  TMI/Views/Authentication/StaffAccessSetupView.swift \
  TMI/App/TMIApp.swift \
  TMITests/Features/Authentication/AuthSessionTests.swift \
  TMITests/Features/Authentication/FirebaseStaffInvitationProvisionerTests.swift \
  TMITests/StateModels/AuthStateModelMembershipTests.swift
git commit -m "feat: repair existing staff onboarding"
```

## Task 6: Remove disabled verification presentation and add acceptance fixtures

**Files:**
- Modify: `TMI/Views/Authentication/AuthenticationView.swift`
- Modify: `TMI/Views/Authentication/SimplifiedRegistrationView.swift`
- Modify: `TMI/Core/Configuration/UITestingLaunchConfiguration.swift`
- Modify: `TMI/App/TMIApp.swift`
- Modify: `TMI/Features/Authentication/AuthenticationAcceptanceUITestingSupport.swift`
- Create: `TMIUITests/AuthenticationAvailabilityUITests.swift`

- [ ] **Step 1: Write failing UI acceptance tests**

Create:

```swift
import XCTest

final class AuthenticationAvailabilityUITests: XCTestCase {
    func testStalledPersistedSessionOffersRetryAndSignOut() {
        let app = launch(fixture: "authenticationRecovery")
        XCTAssertTrue(app.otherElements["authentication.recovery.screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["authentication.recovery.retry"].isHittable)
        XCTAssertTrue(app.buttons["authentication.recovery.signOut"].isHittable)
    }

    func testExistingIdentityCanSubmitAccessSetup() {
        let app = launch(fixture: "authenticationAccessSetup")
        let name = app.textFields["authentication.accessSetup.name"]
        let invitation = app.textFields["authentication.accessSetup.invitation"]
        name.tap()
        name.typeText("Existing Staff")
        invitation.tap()
        invitation.typeText("DISTRICT-INVITE-2026")
        app.buttons["authentication.accessSetup.submit"].tap()
        XCTAssertTrue(app.otherElements["students.roster.screen"].waitForExistence(timeout: 5))
    }

    func testRegistrationDoesNotPresentEmailVerification() {
        let app = launch(fixture: "authenticationAcceptance")
        app.buttons["authentication.signIn.createAccount"].tap()
        completeRegistration(in: app)
        XCTAssertFalse(app.staticTexts["Verify Your Email"].exists)
        XCTAssertTrue(app.otherElements["students.roster.screen"].waitForExistence(timeout: 5))
    }
}
```

Implement `launch(fixture:)` and `completeRegistration(in:)` using the established helpers and acceptance credentials in `Release1AcceptanceUITests`; do not duplicate launch arguments that already have a shared helper.

- [ ] **Step 2: Run UI tests and verify RED**

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-AuthRepair-UI-DD \
  -resultBundlePath /tmp/TMI-AuthRepair-UI-RED.xcresult \
  -only-testing:TMIUITests/AuthenticationAvailabilityUITests
```

Expected: tests fail because recovery/setup fixtures and identifiers do not exist.

- [ ] **Step 3: Gate verification presentation and implement deterministic fixtures**

Show `emailVerificationStatus` only when both conditions hold:

```swift
if dependencies.flags.staffEmailVerificationRequired,
   stateModel.requiresVerification {
    emailVerificationStatus
}
```

Update registration success comments and state handling to describe immediate trusted provisioning. Add `.authenticationRecovery` and `.authenticationAccessSetup` fixtures. Recovery retry must deterministically transition to the signed-out view or authorized fixture; access setup must use the acceptance invitation only inside the UI-test provider.

- [ ] **Step 4: Run UI tests on all supported platforms**

Run the Step 2 command with result path `/tmp/TMI-AuthRepair-iPhone.xcresult`, then:

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
  -derivedDataPath /tmp/TMI-AuthRepair-iPad-DD \
  -resultBundlePath /tmp/TMI-AuthRepair-iPad.xcresult \
  -only-testing:TMIUITests/AuthenticationAvailabilityUITests

xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TMI-AuthRepair-Mac-DD \
  -resultBundlePath /tmp/TMI-AuthRepair-Mac.xcresult \
  -only-testing:TMIUITests/AuthenticationAvailabilityUITests
```

Expected: all availability UI tests pass with zero failures or skips.

- [ ] **Step 5: Commit**

```bash
git add TMI/Views/Authentication/AuthenticationView.swift \
  TMI/Views/Authentication/SimplifiedRegistrationView.swift \
  TMI/Core/Configuration/UITestingLaunchConfiguration.swift \
  TMI/App/TMIApp.swift \
  TMI/Features/Authentication/AuthenticationAcceptanceUITestingSupport.swift \
  TMIUITests/AuthenticationAvailabilityUITests.swift
git commit -m "test: cover recoverable staff authentication"
```

## Task 7: Run the repair release gate

**Files:**
- Create: `docs/release-evidence/authentication-availability-repair.md`

- [ ] **Step 1: Run focused Swift and backend suites**

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-AuthRepair-DD \
  -only-testing:TMITests/AuthSessionTests \
  -only-testing:TMITests/AuthStateModelMembershipTests

npm --prefix firebase test
```

Expected: all focused client and backend tests pass.

- [ ] **Step 2: Run full iOS and macOS suites**

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-Full-DerivedData \
  -resultBundlePath /tmp/TMI-AuthRepair-Full-iOS.xcresult

xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TMI-Full-Mac-DerivedData \
  -resultBundlePath /tmp/TMI-AuthRepair-Full-macOS.xcresult \
  -only-testing:TMITests
```

Expected: zero failures; only the previously documented hosted Keychain/Local Authentication skips are allowed.

- [ ] **Step 3: Build Release configurations**

```bash
xcodebuild build -quiet -project TMI.xcodeproj -scheme TMI \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/TMI-AuthRepair-Release-DD \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build -quiet -project TMI.xcodeproj -scheme TMI \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TMI-AuthRepair-Release-DD \
  CODE_SIGNING_ALLOWED=NO
```

Expected: both builds exit 0 with no Swift concurrency errors.

- [ ] **Step 4: Review security and logging boundaries**

```bash
git diff --check tmi-release-1-accepted...HEAD
git diff --unified=0 tmi-release-1-accepted...HEAD -- TMI firebase | \
  rg '^\+[^+].*(print\(|debugPrint\(|dump\()' || true
git diff --unified=0 tmi-release-1-accepted...HEAD -- TMI firebase | \
  rg '^\+[^+].*(districtID|schoolIDs|capabilities|requestedRole)' || true
```

Expected: no new raw logging. Every authority-bearing match is confined to trusted server results, existing membership validation, or test fixtures; the access-setup request contains none.

- [ ] **Step 5: Record evidence and commit**

Create `docs/release-evidence/authentication-availability-repair.md` with:

- verified commit and date;
- feature-flag values on client and server;
- focused/full test counts and result bundles;
- iPhone, iPad, and macOS recovery/setup UI results;
- backend invitation results;
- Release build results;
- security review;
- explicit note that Functions must deploy with the client;
- explicit note that real staff invitations must be created operationally.

Then:

```bash
git add docs/release-evidence/authentication-availability-repair.md
git commit -m "docs: record authentication availability repair"
```
