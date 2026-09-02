# Debug Synthetic Staff Membership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the fixed Debug staff identity register, sign in, and restore its session through Firebase Authentication without Cloud Functions, custom claims, or a Firestore membership document, while leaving Release authorization unchanged.

**Architecture:** A Debug-only provisioning decorator owns the canonical fixed membership and locally handles only the approved email and invitation alias. A small protocol policy lets that one eligible registration skip the otherwise mandatory trusted-claim refresh, and a Debug-only session-loader decorator synthesizes the same membership after Firebase sign-in or identity restoration. Production implementations keep the default claim-refresh policy, and Release dependency assembly excludes both decorators and all fixture strings.

**Tech Stack:** Swift 6, SwiftUI dependency assembly, Firebase Authentication, Swift Testing, XCTest/Xcode UI acceptance, `xcodebuild`

---

## File Map

- Modify: `TMI/Features/Authentication/AuthenticationRepository.swift` — add the default post-provision claim-refresh policy and consume it during pending-registration completion.
- Modify: `TMI/Features/Authentication/DebugStaffInvitationProvisioner.swift` — own the exact Debug fixture, synthesize membership/session, bypass Cloud Functions for the eligible alias, and decorate restored-session loading.
- Modify: `TMI/Core/Dependencies/AppDependencies.swift` — select both Debug decorators only inside `#if DEBUG`.
- Modify: `TMITests/Features/Authentication/DebugStaffInvitationProvisionerTests.swift` — prove canonical scope, eligibility, no delegation, session synthesis, and non-Debug delegation.
- Modify: `TMITests/Features/Authentication/AuthSessionTests.swift` — prove Firebase Auth registration uses the local membership, skips claim refresh, clears pending state, and remains retry-safe.
- Modify: `TMITests/Core/AppDependenciesTests.swift` — prove dependency wiring and Release source isolation.
- Verify only: `TMIUITests/TMIUITests.swift` — run the existing invitation-registration and credential-sign-in acceptance coverage without adding fixture-only behavior.
- Update after all gates pass: `docs/release-evidence/canonical-debug-registration-repair.md` — record automated and live acceptance evidence in the parent integration task, not during component implementation.

### Task 1: Canonical Debug Provisioning and Session Loading

**Files:**
- Modify: `TMITests/Features/Authentication/DebugStaffInvitationProvisionerTests.swift`
- Modify: `TMI/Features/Authentication/AuthenticationRepository.swift`
- Modify: `TMI/Features/Authentication/DebugStaffInvitationProvisioner.swift`

- [ ] **Step 1: Replace the old alias-translation expectation with failing canonical-membership tests**

Replace `aliasTranslatesForAllowedEmail()` and add the session-loader tests below inside `DebugStaffInvitationProvisionerTests`:

```swift
@Test("The eligible Debug alias returns the canonical membership without delegation")
func aliasSynthesizesCanonicalMembership() async throws {
    let delegate = RecordingStaffInvitationProvisioner()
    let provisioner = DebugStaffInvitationProvisioner(delegate: delegate)
    let identity = AuthIdentity(
        userID: "firebase-debug-user",
        email: " \nTMI-DEBUG@Example.COM\t ",
        isEmailVerified: false
    )

    let membership = try await provisioner.provision(
        request: aliasRequest,
        identity: identity
    )

    #expect(
        membership == MembershipContext(
            userID: "firebase-debug-user",
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
    #expect(
        provisioner.requiresTrustedClaimRefresh(
            request: aliasRequest,
            identity: identity
        ) == false
    )
}

@Test("The Debug session loader authorizes the Firebase Debug identity locally")
func sessionLoaderSynthesizesEligibleIdentity() async throws {
    let delegate = RecordingAuthenticationSessionLoader()
    let loader = DebugAuthenticationSessionLoader(delegate: delegate)
    let identity = AuthIdentity(
        userID: "firebase-debug-user",
        email: "TMI-DEBUG@EXAMPLE.COM",
        isEmailVerified: false
    )

    let session = try await loader.session(for: identity)

    #expect(delegate.callCount == 0)
    #expect(session.access(requiringEmailVerification: false) == .authorized)
    #expect(session.identity?.userID == identity.userID)
    #expect(session.identity?.districtID == "district-debug")
    #expect(session.membership?.capabilities == [
        .studentReadDetail,
        .studentWriteDetail,
    ])
}

@Test("The Debug session loader delegates every other identity unchanged")
func sessionLoaderDelegatesOtherIdentity() async throws {
    let delegatedSession = AuthSession(
        identity: AuthIdentity(
            userID: "ordinary-user",
            email: "ordinary@example.edu",
            isEmailVerified: true,
            districtID: "district-a"
        ),
        membership: RecordingStaffInvitationProvisioner().membership
    )
    let delegate = RecordingAuthenticationSessionLoader(session: delegatedSession)
    let loader = DebugAuthenticationSessionLoader(delegate: delegate)
    let identity = AuthIdentity(
        userID: "ordinary-user",
        email: "ordinary@example.edu",
        isEmailVerified: true
    )

    let session = try await loader.session(for: identity)

    #expect(delegate.callCount == 1)
    #expect(delegate.lastIdentity == identity)
    #expect(session == delegatedSession)
}
```

Add this test double below the existing recording provisioner:

```swift
@MainActor
private final class RecordingAuthenticationSessionLoader:
    AuthenticationSessionLoading {
    let delegatedSession: AuthSession
    private(set) var callCount = 0
    private(set) var lastIdentity: AuthIdentity?

    init(session: AuthSession = .signedOut) {
        delegatedSession = session
    }

    func session(for identity: AuthIdentity) async throws -> AuthSession {
        callCount += 1
        lastIdentity = identity
        return delegatedSession
    }
}
```

Keep the existing wrong-email, missing-email, and non-alias tests. Extend `nonAliasDelegatesUnchanged()` with:

```swift
#expect(
    provisioner.requiresTrustedClaimRefresh(
        request: request,
        identity: identity
    )
)
```

- [ ] **Step 2: Run the Debug provisioner suite and confirm RED**

Run:

```bash
xcodebuild test -quiet \
  -project TMI.xcodeproj \
  -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-DebugSynthetic-Task1-RED-DD \
  -only-testing:TMITests/DebugStaffInvitationProvisionerTests
```

Expected: FAIL because `requiresTrustedClaimRefresh` and `DebugAuthenticationSessionLoader` do not exist, and the eligible alias still delegates to Cloud Functions.

- [ ] **Step 3: Add a default trusted-claim refresh policy to the provisioning protocol**

In `TMI/Features/Authentication/AuthenticationRepository.swift`, extend `StaffInvitationProvisioning` and provide the production-safe default:

```swift
@MainActor
protocol StaffInvitationProvisioning {
    func provision(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) async throws -> MembershipContext

    func requiresTrustedClaimRefresh(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) -> Bool
}

extension StaffInvitationProvisioning {
    func requiresTrustedClaimRefresh(
        request _: StaffInvitationAcceptanceRequest,
        identity _: AuthIdentity
    ) -> Bool {
        true
    }
}
```

No production provisioner or existing test double overrides this method.

- [ ] **Step 4: Replace the Debug translator with the canonical local fixture and add the session-loader decorator**

Replace `TMI/Features/Authentication/DebugStaffInvitationProvisioner.swift` with:

```swift
#if DEBUG
import Foundation

nonisolated enum DebugStaffInvitationError: Error, Equatable {
    case emailNotAllowed
}

@MainActor
final class DebugStaffInvitationProvisioner: StaffInvitationProvisioning {
    static let invitationAlias = "TMI-DEBUG-ACCESS-2026"
    static let allowedEmail = "tmi-debug@example.com"
    static let districtID = "district-debug"
    static let schoolID = "school-debug"

    private let delegate: any StaffInvitationProvisioning

    init(delegate: any StaffInvitationProvisioning) {
        self.delegate = delegate
    }

    func provision(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) async throws -> MembershipContext {
        guard request.invitationCode == Self.invitationAlias else {
            return try await delegate.provision(request: request, identity: identity)
        }
        guard Self.isAllowed(identity) else {
            throw DebugStaffInvitationError.emailNotAllowed
        }
        return Self.membership(userID: identity.userID)
    }

    func requiresTrustedClaimRefresh(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) -> Bool {
        !(request.invitationCode == Self.invitationAlias && Self.isAllowed(identity))
    }

    static func isAllowed(_ identity: AuthIdentity) -> Bool {
        identity.email?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == allowedEmail
    }

    static func membership(userID: String) -> MembershipContext {
        MembershipContext(
            userID: userID,
            districtID: districtID,
            schoolIDs: [schoolID],
            role: .teacher,
            capabilities: [.studentReadDetail, .studentWriteDetail],
            assignedStudentIDs: [],
            isActive: true,
            version: 1
        )
    }

    static func session(for identity: AuthIdentity) -> AuthSession {
        let trustedIdentity = AuthIdentity(
            userID: identity.userID,
            email: identity.email,
            isEmailVerified: identity.isEmailVerified,
            districtID: districtID
        )
        return AuthSession(
            identity: trustedIdentity,
            membership: membership(userID: identity.userID)
        )
    }
}

@MainActor
final class DebugAuthenticationSessionLoader: AuthenticationSessionLoading {
    private let delegate: any AuthenticationSessionLoading

    init(delegate: any AuthenticationSessionLoading) {
        self.delegate = delegate
    }

    func session(for identity: AuthIdentity) async throws -> AuthSession {
        guard DebugStaffInvitationProvisioner.isAllowed(identity) else {
            return try await delegate.session(for: identity)
        }
        return DebugStaffInvitationProvisioner.session(for: identity)
    }
}
#endif
```

- [ ] **Step 5: Run the Debug provisioner suite and confirm GREEN**

Run the Step 2 command with `-derivedDataPath /tmp/TMI-DebugSynthetic-Task1-GREEN-DD`.

Expected: PASS; the exact canonical membership is returned, eligible paths record zero delegate calls, and ordinary identities/invitations delegate.

- [ ] **Step 6: Commit Task 1**

```bash
git add \
  TMI/Features/Authentication/AuthenticationRepository.swift \
  TMI/Features/Authentication/DebugStaffInvitationProvisioner.swift \
  TMITests/Features/Authentication/DebugStaffInvitationProvisionerTests.swift
git commit -m "feat: synthesize debug staff membership"
```

### Task 2: Registration Completion Without Custom Claims

**Files:**
- Modify: `TMITests/Features/Authentication/AuthSessionTests.swift`
- Modify: `TMI/Features/Authentication/AuthenticationRepository.swift`

- [ ] **Step 1: Add failing tests for eligible registration and cleanup retry safety**

Inside `AuthSessionTests`, under `#if DEBUG`, add:

```swift
@Test("Debug registration authorizes without Cloud Functions or claim refresh")
func debugRegistrationSynthesizesAuthorizedSession() async throws {
    let backend = AuthenticationBackendSpy()
    backend.identityEmail = DebugStaffInvitationProvisioner.allowedEmail
    backend.identityDistrictID = nil
    backend.identityIsVerified = false
    let delegate = InvitationProvisionerStub(result: .failure(
        AuthenticationTestError.provisioningFailed
    ))
    let provisioner = DebugStaffInvitationProvisioner(delegate: delegate)
    let pendingStore = InMemoryPendingStaffRegistrationStore()
    let repository = AuthenticationRepository(
        backend: backend,
        sessionLoader: SessionLoaderStub(session: .signedOut),
        invitationProvisioner: provisioner,
        pendingRegistrationStore: pendingStore,
        requiresEmailVerification: false
    )

    let session = try await repository.register(
        StaffRegistrationRequest(
            displayName: "Debug Teacher",
            email: DebugStaffInvitationProvisioner.allowedEmail,
            password: "Correct-Horse-9",
            requestedRole: .teacher,
            invitationCode: DebugStaffInvitationProvisioner.invitationAlias,
            privacyPolicyVersion: StaffPolicyVersions.privacyPolicyVersion,
            acceptableUsePolicyVersion: StaffPolicyVersions.acceptableUsePolicyVersion
        )
    )

    #expect(backend.createUserCallCount == 1)
    #expect(backend.refreshIdentityCallCount == 0)
    #expect(backend.deleteCurrentUserCallCount == 0)
    #expect(delegate.provisionCallCount == 0)
    #expect(await pendingStore.pendingRegistration() == nil)
    #expect(session.access(requiringEmailVerification: false) == .authorized)
    #expect(session.identity?.districtID == "district-debug")
    #expect(session.membership?.userID == "staff-1")
}

@Test("Debug registration cleanup failure returns access and preserves retry state")
func debugRegistrationCleanupFailureRemainsRetryable() async throws {
    let backend = AuthenticationBackendSpy()
    backend.identityEmail = DebugStaffInvitationProvisioner.allowedEmail
    backend.identityDistrictID = nil
    backend.identityIsVerified = false
    let pendingStore = FailOnceClearingPendingRegistrationStore()
    let repository = AuthenticationRepository(
        backend: backend,
        sessionLoader: SessionLoaderStub(session: .signedOut),
        invitationProvisioner: DebugStaffInvitationProvisioner(
            delegate: InvitationProvisionerStub(
                result: .failure(AuthenticationTestError.provisioningFailed)
            )
        ),
        pendingRegistrationStore: pendingStore,
        requiresEmailVerification: false
    )

    let session = try await repository.register(
        StaffRegistrationRequest(
            displayName: "Debug Teacher",
            email: DebugStaffInvitationProvisioner.allowedEmail,
            password: "Correct-Horse-9",
            requestedRole: .teacher,
            invitationCode: DebugStaffInvitationProvisioner.invitationAlias,
            privacyPolicyVersion: StaffPolicyVersions.privacyPolicyVersion,
            acceptableUsePolicyVersion: StaffPolicyVersions.acceptableUsePolicyVersion
        )
    )

    #expect(session.access(requiringEmailVerification: false) == .authorized)
    #expect(backend.refreshIdentityCallCount == 0)
    #expect(backend.deleteCurrentUserCallCount == 0)
    #expect(await pendingStore.pendingRegistration() != nil)

    let retriedSession = try await repository.refresh()

    #expect(retriedSession.access(requiringEmailVerification: false) == .authorized)
    #expect(backend.refreshIdentityCallCount == 1)
    #expect(backend.deleteCurrentUserCallCount == 0)
    #expect(await pendingStore.pendingRegistration() == nil)
}

@Test("Debug sign-in uses Firebase Auth and bypasses production membership loading")
func debugSignInSynthesizesMembershipAfterAuthentication() async throws {
    let backend = AuthenticationBackendSpy()
    backend.identityEmail = DebugStaffInvitationProvisioner.allowedEmail
    backend.identityDistrictID = nil
    backend.identityIsVerified = false
    let productionLoader = RecordingAuthenticationSessionLoaderForRepository()
    let repository = AuthenticationRepository(
        backend: backend,
        sessionLoader: DebugAuthenticationSessionLoader(
            delegate: productionLoader
        ),
        invitationProvisioner: InvitationProvisionerStub(
            result: .failure(AuthenticationTestError.provisioningFailed)
        ),
        requiresEmailVerification: false
    )

    let session = try await repository.signIn(
        email: DebugStaffInvitationProvisioner.allowedEmail,
        password: "Correct-Horse-9"
    )

    #expect(backend.signInCallCount == 1)
    #expect(productionLoader.callCount == 0)
    #expect(session.access(requiringEmailVerification: false) == .authorized)
}

@Test("Debug restored Firebase identity bypasses production membership loading")
func debugRefreshSynthesizesRestoredSession() async throws {
    let backend = AuthenticationBackendSpy()
    backend.identityEmail = DebugStaffInvitationProvisioner.allowedEmail
    backend.identityDistrictID = nil
    backend.identityIsVerified = false
    let productionLoader = RecordingAuthenticationSessionLoaderForRepository()
    let repository = AuthenticationRepository(
        backend: backend,
        sessionLoader: DebugAuthenticationSessionLoader(
            delegate: productionLoader
        ),
        invitationProvisioner: InvitationProvisionerStub(
            result: .failure(AuthenticationTestError.provisioningFailed)
        ),
        requiresEmailVerification: false
    )

    let session = try await repository.refresh()

    #expect(backend.refreshIdentityCallCount == 1)
    #expect(productionLoader.callCount == 0)
    #expect(session.access(requiringEmailVerification: false) == .authorized)
}
#endif
```

Make the existing backend spy's identity and sign-in call count configurable by adding:

```swift
var signInCallCount = 0
var identityEmail = "staff@example.edu"
var identityDistrictID: String? = "district-a"
```

Replace the spy's sign-in method and identity property with:

```swift
func signIn(email: String, password: String) async throws -> AuthIdentity {
    signInCallCount += 1
    return identity
}

private var identity: AuthIdentity {
    AuthIdentity(
        userID: "staff-1",
        email: identityEmail,
        isEmailVerified: identityIsVerified,
        districtID: identityDistrictID
    )
}
```

Replace the hard-coded email and district in `currentIdentity()` with the same `identityEmail` and `identityDistrictID` properties:

```swift
func currentIdentity() async throws -> AuthIdentity {
    currentIdentityCallCount += 1
    return AuthIdentity(
        userID: "staff-1",
        email: identityEmail,
        isEmailVerified: identityIsVerified,
        districtID: identityDistrictID
    )
}
```

Add this repository-local production loader spy below `SessionLoaderStub`:

```swift
@MainActor
private final class RecordingAuthenticationSessionLoaderForRepository:
    AuthenticationSessionLoading {
    private(set) var callCount = 0

    func session(for identity: AuthIdentity) async throws -> AuthSession {
        callCount += 1
        return AuthSession(identity: identity, membership: nil)
    }
}
```

- [ ] **Step 2: Run AuthSessionTests and confirm RED**

Run:

```bash
xcodebuild test -quiet \
  -project TMI.xcodeproj \
  -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-DebugSynthetic-Task2-RED-DD \
  -only-testing:TMITests/AuthSessionTests
```

Expected: FAIL because `completePendingRegistration` still calls `refreshIdentity()`, which has no Debug district claim.

- [ ] **Step 3: Make pending-registration completion honor the provisioner's policy**

In `AuthenticationRepository.completePendingRegistration`, replace the unconditional `refreshedIdentity` assignment with:

```swift
let resolvedIdentity: AuthIdentity
if invitationProvisioner.requiresTrustedClaimRefresh(
    request: pendingRegistration.invitationAcceptanceRequest,
    identity: identity
) {
    resolvedIdentity = try await refreshedIdentity(
        afterProvisioning: membership,
        expectedIdentityID: pendingRegistration.identityID
    )
} else {
    resolvedIdentity = AuthIdentity(
        userID: identity.userID,
        email: identity.email,
        isEmailVerified: identity.isEmailVerified,
        districtID: membership.districtID
    )
}
do {
    try await pendingRegistrationStore.clear()
} catch {
    try? await pendingRegistrationStore.save(pendingRegistration)
}
return AuthSession(identity: resolvedIdentity, membership: membership)
```

Do not change `completeStaffOnboarding`; it continues to require a server claim refresh because it is not registration through the fixed Debug identity contract.

- [ ] **Step 4: Run focused authentication tests and confirm GREEN**

Run:

```bash
xcodebuild test -quiet \
  -project TMI.xcodeproj \
  -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-DebugSynthetic-Task2-GREEN-DD \
  -only-testing:TMITests/DebugStaffInvitationProvisionerTests \
  -only-testing:TMITests/AuthSessionTests
```

Expected: PASS. Existing ordinary provisioning tests must still observe one claim refresh, and Debug registration must observe zero.

- [ ] **Step 5: Commit Task 2**

```bash
git add \
  TMI/Features/Authentication/AuthenticationRepository.swift \
  TMITests/Features/Authentication/AuthSessionTests.swift
git commit -m "fix: authorize debug registration locally"
```

### Task 3: Debug-Only Dependency Assembly

**Files:**
- Modify: `TMITests/Core/AppDependenciesTests.swift`
- Modify: `TMI/Core/Dependencies/AppDependencies.swift`

- [ ] **Step 1: Strengthen the source-assembly test before implementation**

Replace `productionGatesDebugInvitationAlias()` with:

```swift
@Test("Production assembly gates both Debug authentication decorators")
func productionGatesDebugAuthenticationDecorators() throws {
    let source = try self.source(
        "TMI/Core/Dependencies/AppDependencies.swift",
        root: self.repositoryRoot
    )
    let compactSource = source.removingWhitespace

    #expect(compactSource.contains(
        """
        letfirebaseInvitationProvisioner=FirebaseStaffInvitationProvisioner()
        letfirebaseSessionLoader=FirebaseAuthenticationSessionLoader(
        membershipProvider:membership,
        requiresEmailVerification:flags.staffEmailVerificationRequired
        )
        #ifDEBUG
        letinvitationProvisioner:anyStaffInvitationProvisioning=DebugStaffInvitationProvisioner(delegate:firebaseInvitationProvisioner)
        letsessionLoader:anyAuthenticationSessionLoading=DebugAuthenticationSessionLoader(delegate:firebaseSessionLoader)
        #else
        letinvitationProvisioner:anyStaffInvitationProvisioning=firebaseInvitationProvisioner
        letsessionLoader:anyAuthenticationSessionLoading=firebaseSessionLoader
        #endif
        """.removingWhitespace
    ))
    #expect(compactSource.contains("sessionLoader:sessionLoader"))
    #expect(compactSource.contains("invitationProvisioner:invitationProvisioner"))
}
```

- [ ] **Step 2: Run AppDependenciesTests and confirm RED**

Run:

```bash
xcodebuild test -quiet \
  -project TMI.xcodeproj \
  -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-DebugSynthetic-Task3-RED-DD \
  -only-testing:TMITests/AppDependenciesTests
```

Expected: FAIL because dependency assembly still injects `FirebaseAuthenticationSessionLoader` directly.

- [ ] **Step 3: Wire both decorators in the existing Debug conditional**

In `AppDependencies.production(firestore:)`, replace the provisioner/session construction with:

```swift
let firebaseInvitationProvisioner = FirebaseStaffInvitationProvisioner()
let firebaseSessionLoader = FirebaseAuthenticationSessionLoader(
    membershipProvider: membership,
    requiresEmailVerification: flags.staffEmailVerificationRequired
)
#if DEBUG
let invitationProvisioner: any StaffInvitationProvisioning =
    DebugStaffInvitationProvisioner(delegate: firebaseInvitationProvisioner)
let sessionLoader: any AuthenticationSessionLoading =
    DebugAuthenticationSessionLoader(delegate: firebaseSessionLoader)
#else
let invitationProvisioner: any StaffInvitationProvisioning =
    firebaseInvitationProvisioner
let sessionLoader: any AuthenticationSessionLoading = firebaseSessionLoader
#endif
let authentication = AuthenticationRepository(
    backend: FirebaseAuthenticationBackend(),
    sessionLoader: sessionLoader,
    invitationProvisioner: invitationProvisioner,
    pendingRegistrationStore: SecurePendingStaffRegistrationStore(),
    requiresEmailVerification: flags.staffEmailVerificationRequired
)
```

- [ ] **Step 4: Run all focused deterministic tests and confirm GREEN**

Run:

```bash
xcodebuild test -quiet \
  -project TMI.xcodeproj \
  -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-DebugSynthetic-Task3-GREEN-DD \
  -only-testing:TMITests/DebugStaffInvitationProvisionerTests \
  -only-testing:TMITests/AuthSessionTests \
  -only-testing:TMITests/AuthStateModelMembershipTests \
  -only-testing:TMITests/StaffRegistrationFlowTests \
  -only-testing:TMITests/AppDependenciesTests
```

Expected: PASS with zero failures.

- [ ] **Step 5: Commit Task 3**

```bash
git add \
  TMI/Core/Dependencies/AppDependencies.swift \
  TMITests/Core/AppDependenciesTests.swift
git commit -m "feat: wire debug authentication bypass"
```

### Task 4: Build Isolation and Acceptance Gate

**Files:**
- Verify: `TMI/Features/Authentication/DebugStaffInvitationProvisioner.swift`
- Verify: `TMI/Core/Dependencies/AppDependencies.swift`
- Verify: `TMIUITests/TMIUITests.swift`
- Update after acceptance: `docs/release-evidence/canonical-debug-registration-repair.md`

- [ ] **Step 1: Run a fresh focused test gate**

```bash
rm -rf /tmp/TMI-DebugSynthetic-Final-DD /tmp/TMI-DebugSynthetic-Final.xcresult
xcodebuild test -quiet \
  -project TMI.xcodeproj \
  -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-DebugSynthetic-Final-DD \
  -resultBundlePath /tmp/TMI-DebugSynthetic-Final.xcresult \
  -only-testing:TMITests/DebugStaffInvitationProvisionerTests \
  -only-testing:TMITests/AuthSessionTests \
  -only-testing:TMITests/AuthStateModelMembershipTests \
  -only-testing:TMITests/StaffRegistrationFlowTests \
  -only-testing:TMITests/SimplifiedRegistrationViewTests \
  -only-testing:TMITests/AppDependenciesTests
```

Expected: command exits 0 and the result bundle reports zero failed tests.

- [ ] **Step 2: Build Debug iOS and Release iOS/macOS from clean DerivedData paths**

```bash
xcodebuild build -quiet \
  -project TMI.xcodeproj \
  -scheme TMI \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/TMI-DebugSynthetic-Debug-iOS-DD

xcodebuild build -quiet \
  -project TMI.xcodeproj \
  -scheme TMI \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/TMI-DebugSynthetic-Release-iOS-DD

xcodebuild build -quiet \
  -project TMI.xcodeproj \
  -scheme TMI \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/TMI-DebugSynthetic-Release-macOS-DD
```

Expected: all three commands exit 0. Record warnings separately; any error blocks acceptance.

- [ ] **Step 3: Verify Release products exclude every Debug credential and scope string**

```bash
if rg -a -l \
  'TMI-DEBUG-ACCESS-2026|tmi-debug@example\.com|district-debug|school-debug' \
  /tmp/TMI-DebugSynthetic-Release-iOS-DD/Build/Products/Release-iphonesimulator \
  /tmp/TMI-DebugSynthetic-Release-macOS-DD/Build/Products/Release; then
  echo 'FAIL: Debug fixture leaked into a Release product' >&2
  exit 1
else
  echo 'PASS: Release products exclude Debug fixture strings'
fi
```

Expected: only `PASS: Release products exclude Debug fixture strings`; no matching product path.

- [ ] **Step 4: Run existing local UI regression coverage**

```bash
xcodebuild test -quiet \
  -project TMI.xcodeproj \
  -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-DebugSynthetic-UI-DD \
  -only-testing:TMIUITests/TMIUITests/testStaffInvitationRegistrationFlow \
  -only-testing:TMIUITests/TMIUITests/testCredentialSignInFlow
```

Expected: both existing acceptance fixtures pass. These tests validate presentation and routing but do not replace the live Firebase Auth gate.

- [ ] **Step 5: Complete the live Firebase Authentication gate in a Debug build**

Using Firebase project `tmi-education`, launch the Debug app without authentication fixture launch arguments and perform this exact sequence:

1. Register `tmi-debug@example.com` with invitation `TMI-DEBUG-ACCESS-2026` and a password supplied interactively but never committed or logged.
2. Confirm Firebase Authentication creates or recognizes the real identity and the app enters `MainTabView` without calling `provisionStaffMembership`.
3. Sign out, sign in with the same email and password, and confirm the app enters `MainTabView`.
4. Terminate and relaunch the app, then confirm the existing Firebase session restores directly into `MainTabView`.

If the account already exists, first verify sign-in, use the app's normal personal-account deletion flow to remove only that Debug Auth identity, then repeat registration. Do not delete institutional records or broaden deletion scope. Any return to the sign-in screen, membership-required screen, stuck loading screen, Cloud Functions call, or missing Firebase Auth identity fails the gate.

- [ ] **Step 6: Record evidence only after every automated and live check passes**

Append a dated `2026-09-01 Debug synthetic membership acceptance` section to `docs/release-evidence/canonical-debug-registration-repair.md` containing:

```markdown
### 2026-09-01 Debug synthetic membership acceptance

- Focused deterministic tests: PASS (record executed/passed/failed counts from the xcresult)
- Debug generic iOS Simulator build: PASS
- Release generic iOS Simulator build: PASS
- Release macOS arm64 build: PASS
- Release fixture-string scan: PASS
- Invitation registration UI regression: PASS
- Credential sign-in UI regression: PASS
- Live Firebase Auth registration: PASS
- Live sign-out/sign-in: PASS
- Live terminated-app session restoration: PASS
- Cloud Functions invocation for Debug alias: none observed
- Firebase project: `tmi-education`
- Debug identity: `tmi-debug@example.com`
- Warnings: list exact warnings, or `None`
```

Do not record PASS from an interrupted command, inferred behavior, or fixture-only UI run.

- [ ] **Step 7: Commit verified release evidence**

```bash
git add docs/release-evidence/canonical-debug-registration-repair.md
git commit -m "docs: verify debug authentication bypass"
```

- [ ] **Step 8: Final branch review before integration**

```bash
git status --short
git diff --check main...HEAD
git log --oneline main..HEAD
```

Expected: clean worktree, no whitespace errors, and only the approved registration repair, Debug-only bypass, tests, design/plan, and evidence commits. Merge or fast-forward to `main` only after the live gate in Step 5 and an independent final code review both pass.
