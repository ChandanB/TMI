# Canonical Debug Registration Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Make tmi-debug@example.com plus TMI-DEBUG-ACCESS-2026 complete canonical Firebase registration in Debug builds and enter the app without clearing recoverable state too early.

**Architecture:** A Debug-only decorator translates the memorable alias to an email-bound opaque Firebase invitation and delegates to the trusted callable. AuthenticationRepository force-refreshes and validates claims after provisioning, then clears the encrypted pending record. Release composition remains Firebase-only.

**Tech Stack:** Swift 6.3, Swift Testing, Firebase Auth, Functions, Firestore, Admin SDK, TypeScript 7, Vitest

---

## File Map

- Create TMI/Features/Authentication/DebugStaffInvitationProvisioner.swift for Debug alias translation.
- Create TMITests/Features/Authentication/DebugStaffInvitationProvisionerTests.swift for translation and rejection coverage.
- Modify TMI/Core/Dependencies/AppDependencies.swift and TMITests/Core/AppDependenciesTests.swift for Debug-only composition.
- Modify TMI/Features/Authentication/AuthenticationRepository.swift and TMITests/Features/Authentication/AuthSessionTests.swift for post-provision refresh ordering.
- Create firebase/src/debugInvitation.ts, firebase/test/debug-invitation.test.ts, and firebase/scripts/manage-debug-invitation.mjs for invitation administration.
- Modify firebase/package.json for administration commands.
- Create docs/release-evidence/canonical-debug-registration-repair.md for verification evidence.

## Task 1: Add and compose the Debug invitation translator

**Files:**
- Create: TMI/Features/Authentication/DebugStaffInvitationProvisioner.swift
- Create: TMITests/Features/Authentication/DebugStaffInvitationProvisionerTests.swift
- Modify: TMI/Core/Dependencies/AppDependencies.swift
- Modify: TMITests/Core/AppDependenciesTests.swift

- [ ] **Step 1: Write failing translator tests**

Create a Debug-gated Swift Testing suite with a recording StaffInvitationProvisioning delegate. Cover:

~~~swift
@Test("The Debug alias delegates one canonical opaque invitation")
func aliasDelegatesCanonicalInvitation() async throws {
    let delegate = RecordingStaffInvitationProvisioner()
    let subject = DebugStaffInvitationProvisioner(delegate: delegate)
    let identity = AuthIdentity(
        userID: "debug-user",
        email: "  TMI-DEBUG@EXAMPLE.COM  ",
        isEmailVerified: false
    )
    _ = try await subject.provision(
        request: self.request(invitationCode: "TMI-DEBUG-ACCESS-2026"),
        identity: identity
    )
    #expect(delegate.callCount == 1)
    #expect(delegate.lastIdentity == identity)
    #expect(
        delegate.lastRequest?.invitationCode
            == DebugStaffInvitationProvisioner.opaqueInvitationCode
    )
}

@Test("The Debug alias rejects every other email without calling Firebase")
func aliasRejectsOtherEmail() async {
    let delegate = RecordingStaffInvitationProvisioner()
    let subject = DebugStaffInvitationProvisioner(delegate: delegate)
    await #expect(throws: DebugStaffInvitationError.emailNotAllowed) {
        _ = try await subject.provision(
            request: self.request(invitationCode: "TMI-DEBUG-ACCESS-2026"),
            identity: AuthIdentity(
                userID: "other-user",
                email: "other@example.com",
                isEmailVerified: false
            )
        )
    }
    #expect(delegate.callCount == 0)
}

@Test("Institutional invitations pass through unchanged")
func institutionalInvitationPassesThrough() async throws {
    let delegate = RecordingStaffInvitationProvisioner()
    let subject = DebugStaffInvitationProvisioner(delegate: delegate)
    let request = self.request(invitationCode: "institution-issued-code")
    let identity = AuthIdentity(
        userID: "staff-user",
        email: "staff@example.edu",
        isEmailVerified: false
    )
    _ = try await subject.provision(request: request, identity: identity)
    #expect(delegate.lastRequest == request)
    #expect(delegate.lastIdentity == identity)
}
~~~

The request helper uses current policy versions. Implement the recording delegate as:

~~~swift
@MainActor
private final class RecordingStaffInvitationProvisioner: StaffInvitationProvisioning {
    private(set) var callCount = 0
    private(set) var lastRequest: StaffInvitationAcceptanceRequest?
    private(set) var lastIdentity: AuthIdentity?

    func provision(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) async throws -> MembershipContext {
        self.callCount += 1
        self.lastRequest = request
        self.lastIdentity = identity
        return MembershipContext(
            userID: identity.userID,
            districtID: "district-debug",
            schoolIDs: ["school-debug"],
            role: .teacher,
            capabilities: [.studentReadDetail, .studentWriteDetail],
            assignedStudentIDs: [],
            isActive: true,
            version: 1
        )
    }
}
~~~

- [ ] **Step 2: Verify RED**

Run:

~~~bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/TMI-DebugRegistration-DD -only-testing:TMITests/DebugStaffInvitationProvisionerTests
~~~

Expected: compilation fails because the translator does not exist.

- [ ] **Step 3: Implement the minimal translator**

Create the file enclosed completely by conditional Debug compilation:

~~~swift
import Foundation

nonisolated enum DebugStaffInvitationError: Error, Equatable {
    case emailNotAllowed
}

@MainActor
final class DebugStaffInvitationProvisioner: StaffInvitationProvisioning {
    static let invitationAlias = "TMI-DEBUG-ACCESS-2026"
    static let allowedEmail = "tmi-debug@example.com"
    static let opaqueInvitationCode =
        "VE1JLURlYnVnLUNhbm9uaWNhbC1JbnZpdGUtMjAyNiE"

    private let delegate: any StaffInvitationProvisioning

    init(delegate: any StaffInvitationProvisioning) {
        self.delegate = delegate
    }

    func provision(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) async throws -> MembershipContext {
        guard request.invitationCode == Self.invitationAlias else {
            return try await self.delegate.provision(request: request, identity: identity)
        }
        let email = identity.email?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard email == Self.allowedEmail else {
            throw DebugStaffInvitationError.emailNotAllowed
        }
        return try await self.delegate.provision(
            request: StaffInvitationAcceptanceRequest(
                displayName: request.displayName,
                invitationCode: Self.opaqueInvitationCode,
                privacyPolicyVersion: request.privacyPolicyVersion,
                acceptableUsePolicyVersion: request.acceptableUsePolicyVersion
            ),
            identity: identity
        )
    }
}
~~~

- [ ] **Step 4: Write the failing composition contract**

Add an AppDependenciesTests source assertion for a whitespace-free conditional Debug block that wraps FirebaseStaffInvitationProvisioner in DebugStaffInvitationProvisioner, with the alternate branch using Firebase directly. Run AppDependenciesTests and expect failure.

- [ ] **Step 5: Compose and verify**

In AppDependencies.production(firestore:), construct the Firebase provisioner, select invitationProvisioner with the tested compile-time block, and inject it. Run:

~~~bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/TMI-DebugRegistration-DD -only-testing:TMITests/DebugStaffInvitationProvisionerTests -only-testing:TMITests/AppDependenciesTests
~~~

Expected: both suites pass.

- [ ] **Step 6: Commit**

~~~bash
git add TMI/Features/Authentication/DebugStaffInvitationProvisioner.swift TMITests/Features/Authentication/DebugStaffInvitationProvisionerTests.swift TMI/Core/Dependencies/AppDependencies.swift TMITests/Core/AppDependenciesTests.swift
git commit -m "feat: add canonical debug invitation alias"
~~~

## Task 2: Refresh claims before pending-registration cleanup

**Files:**
- Modify: TMITests/Features/Authentication/AuthSessionTests.swift
- Modify: TMI/Features/Authentication/AuthenticationRepository.swift

- [ ] **Step 1: Write failing regressions**

Add tests proving:

~~~swift
@Test("Registration refreshes claims before clearing pending state")
func registrationRefreshesClaimsBeforeCleanup() async throws {
    let events = AuthenticationEventRecorder()
    let backend = AuthenticationBackendSpy(events: events)
    let store = RecordingPendingRegistrationStore(events: events)
    let repository = AuthenticationRepository(
        backend: backend,
        sessionLoader: SessionLoaderStub(session: .signedOut),
        invitationProvisioner: InvitationProvisionerStub(
            result: .success(self.membership())
        ),
        pendingRegistrationStore: store,
        requiresEmailVerification: false
    )
    let session = try await repository.register(
        self.registrationRequest(invitationCode: "invite-a")
    )
    #expect(session.access(requiringEmailVerification: false) == .authorized)
    #expect(backend.refreshIdentityCallCount == 1)
    #expect(await events.values == ["save", "refresh", "clear"])
}

@Test("A post-provision refresh failure preserves identity and pending state")
func postProvisionRefreshFailureIsRecoverable() async {
    let backend = AuthenticationBackendSpy()
    backend.refreshError = AuthenticationTestError.tokenRefreshFailed
    let store = InMemoryPendingStaffRegistrationStore()
    let repository = AuthenticationRepository(
        backend: backend,
        sessionLoader: SessionLoaderStub(session: .signedOut),
        invitationProvisioner: InvitationProvisionerStub(
            result: .success(self.membership())
        ),
        pendingRegistrationStore: store,
        requiresEmailVerification: false
    )
    await #expect(throws: StaffInvitationProvisioningError.claimRefreshPending) {
        _ = try await repository.register(
            self.registrationRequest(invitationCode: "invite-a")
        )
    }
    #expect(backend.deleteCurrentUserCallCount == 0)
    #expect(await store.pendingRegistration() != nil)
}

@Test("Staff Access Setup refreshes claims after provisioning")
func staffAccessSetupRefreshesClaims() async throws {
    let backend = AuthenticationBackendSpy()
    let repository = AuthenticationRepository(
        backend: backend,
        sessionLoader: SessionLoaderStub(session: .signedOut),
        invitationProvisioner: InvitationProvisionerStub(
            result: .success(self.membership())
        ),
        requiresEmailVerification: false
    )
    try await repository.completeStaffOnboarding(
        StaffOnboardingRequest(
            displayName: "Morgan Lee",
            invitationCode: "invite-a",
            privacyPolicyVersion: StaffPolicyVersions.privacyPolicyVersion,
            acceptableUsePolicyVersion: StaffPolicyVersions.acceptableUsePolicyVersion
        )
    )
    #expect(backend.refreshIdentityCallCount == 1)
}
~~~

Extend the backend spy with refreshIdentityCallCount and an optional actor recorder that appends refresh. Add:

~~~swift
private actor AuthenticationEventRecorder {
    private(set) var values: [String] = []
    func append(_ value: String) { self.values.append(value) }
}

private actor RecordingPendingRegistrationStore: PendingStaffRegistrationStoring {
    private var registration: PendingStaffRegistration?
    private let events: AuthenticationEventRecorder
    init(events: AuthenticationEventRecorder) { self.events = events }
    func save(_ registration: PendingStaffRegistration) async {
        self.registration = registration
        await self.events.append("save")
    }
    func pendingRegistration() -> PendingStaffRegistration? { self.registration }
    func clear() async {
        self.registration = nil
        await self.events.append("clear")
    }
}
~~~

AuthenticationBackendSpy receives the recorder in a new initializer. Its refreshIdentity increments refreshIdentityCallCount, awaits events.append("refresh"), then preserves the existing error and identity behavior.

- [ ] **Step 2: Verify RED**

~~~bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/TMI-DebugRegistration-DD -only-testing:TMITests/AuthSessionTests
~~~

Expected: refresh count is zero and the event order lacks refresh.

- [ ] **Step 3: Implement one validated refresh helper**

~~~swift
private func refreshedIdentity(
    afterProvisioning membership: MembershipContext,
    expectedIdentityID: String
) async throws -> AuthIdentity {
    let identity: AuthIdentity
    do {
        identity = try await self.backend.refreshIdentity()
    } catch {
        throw StaffInvitationProvisioningError.claimRefreshPending
    }
    guard identity.userID == expectedIdentityID,
          identity.districtID == membership.districtID else {
        throw StaffInvitationProvisioningError.claimRefreshPending
    }
    return identity
}
~~~

Call it after provisioning and before pending cleanup, returning the refreshed identity. Call it after Staff Access Setup provisioning before returning. Do not translate terminal invitation errors.

- [ ] **Step 4: Verify and commit**

~~~bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/TMI-DebugRegistration-DD -only-testing:TMITests/AuthSessionTests -only-testing:TMITests/AuthStateModelMembershipTests
git add TMI/Features/Authentication/AuthenticationRepository.swift TMITests/Features/Authentication/AuthSessionTests.swift
git commit -m "fix: refresh claims after staff provisioning"
~~~

Expected: both suites pass.

## Task 3: Add explicit invitation administration

**Files:**
- Create: firebase/src/debugInvitation.ts
- Create: firebase/test/debug-invitation.test.ts
- Create: firebase/scripts/manage-debug-invitation.mjs
- Modify: firebase/package.json

- [ ] **Step 1: Write the failing Vitest contract**

Test buildDebugInvitationRecord(code, now) with the opaque code. Assert the document ID and email hash use existing invitation helpers, scope is district-debug and school-debug, role is teacher, capabilities are read/write detail, consumption fields are null, and expiration is exactly 30 days later. Assert a short code throws 43-character opaque invitation.

- [ ] **Step 2: Verify RED**

~~~bash
npm --prefix firebase run test:unit -- debug-invitation.test.ts
~~~

Expected: module-not-found for src/debugInvitation.ts.

- [ ] **Step 3: Implement the builder**

Export the project, email, district, school, and capability scope and:

~~~typescript
export const buildDebugInvitationRecord = (code: string, now: Date) => {
  if (!/^[A-Za-z0-9_-]{43}$/.test(code)) {
    throw new Error("Debug access requires a 43-character opaque invitation.");
  }
  return {
    documentID: hashInvitationCode(code),
    data: {
      schemaVersion: 1,
      recordVersion: 1,
      districtID: debugInvitationScope.districtID,
      recipientEmailHash: hashInvitationRecipientEmail(code, debugInvitationScope.email),
      role: "teacher" as const,
      schoolIDs: [...debugInvitationScope.schoolIDs],
      capabilities: [...debugInvitationScope.capabilities],
      isActive: true,
      expiresAt: Timestamp.fromDate(new Date(now.getTime() + 30 * 86_400_000)),
      consumedByUserID: null,
      consumedAt: null,
    },
  };
};
~~~

- [ ] **Step 4: Add the Admin manager**

Keep `firebase/scripts/manage-debug-invitation.mjs` as a thin, import-safe ESM
adapter over the compiled helpers in `firebase/src/debugInvitation.ts`:

- Pass the action arguments to `parseDebugInvitationArguments`. It accepts
  exactly one value, `seed` or `revoke`, and rejects missing or extra arguments.
- Call `requireDebugInvitationProject` for the exact
  `TMI_DEBUG_INVITATION_PROJECT=tmi-education` guard.
- Read the invitation code from file descriptor 0 with `readFileSync`, then pass
  the input to `readDebugInvitationCode`, which trims it and enforces the exact
  43-character opaque format. Never accept the code in argv or an environment
  variable.
- Complete action, project, and code validation and build the canonical record
  before calling `applicationDefault`, `initializeApp`, or `getFirestore`.
- Inside one Firestore transaction, pass the snapshot data to
  `planDebugInvitationAdministration`. An absent seed creates version 1; an
  existing unconsumed seed or revoke increments a valid positive safe-integer
  version; consumed seeds and malformed, non-positive, unsafe, or max-safe
  versions fail closed without writing; an absent revoke is a no-op.
- Apply only the returned `set` or `update` mutation, emit only the action and
  project via `debugInvitationLogMessage`, and guard `main()` so importing the
  script performs no initialization or mutation.

Add package scripts:

~~~json
"debug-invitation:seed": "npm run build --silent && node scripts/manage-debug-invitation.mjs seed",
"debug-invitation:revoke": "npm run build --silent && node scripts/manage-debug-invitation.mjs revoke"
~~~

- [ ] **Step 5: Verify and commit**

~~~bash
npm --prefix firebase run lint
npm --prefix firebase test
git add firebase/src/debugInvitation.ts firebase/test/debug-invitation.test.ts firebase/scripts/manage-debug-invitation.mjs firebase/package.json
git commit -m "feat: manage canonical debug invitation"
~~~

Expected: TypeScript and all Firebase tests pass.

## Task 4: Release gate and live acceptance

**Files:**
- Create: docs/release-evidence/canonical-debug-registration-repair.md

- [ ] **Step 1: Run focused Swift tests**

~~~bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/TMI-DebugRegistration-DD -only-testing:TMITests/DebugStaffInvitationProvisionerTests -only-testing:TMITests/AuthSessionTests -only-testing:TMITests/AuthStateModelMembershipTests -only-testing:TMITests/AppDependenciesTests
~~~

- [ ] **Step 2: Build Debug and Release**

Run:

~~~bash
xcodebuild build -quiet -project TMI.xcodeproj -scheme TMI -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/TMI-DebugRegistration-Build-DD
xcodebuild build -quiet -project TMI.xcodeproj -scheme TMI -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/TMI-DebugRegistration-Release-DD
xcodebuild build -quiet -project TMI.xcodeproj -scheme TMI -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/TMI-DebugRegistration-Mac-DD
~~~

Expected: all succeed; Release compilation does not require the Debug type.

- [ ] **Step 3: Seed the invitation**

With authorized Application Default Credentials:

~~~bash
printf 'Debug invitation code: ' >&2
IFS= read -r -s TMI_DEBUG_INVITATION_CODE
printf '\n' >&2
printf '%s' "$TMI_DEBUG_INVITATION_CODE" | TMI_DEBUG_INVITATION_PROJECT=tmi-education npm --prefix firebase run debug-invitation:seed
unset TMI_DEBUG_INVITATION_CODE
~~~

Expected: success without printing the token.

For the GA revoke/remove action, use the same stdin-only flow:

~~~bash
printf 'Debug invitation code for revocation: ' >&2
IFS= read -r -s TMI_DEBUG_INVITATION_CODE
printf '\n' >&2
printf '%s' "$TMI_DEBUG_INVITATION_CODE" | TMI_DEBUG_INVITATION_PROJECT=tmi-education npm --prefix firebase run debug-invitation:revoke
unset TMI_DEBUG_INVITATION_CODE
~~~

- [ ] **Step 4: Run ordinary Debug acceptance**

Register tmi-debug@example.com with TMI-DEBUG-ACCESS-2026 and a valid password. Verify the staff workspace appears, relaunch restores it, and sign-out/sign-in works. Confirm pending state clears only after token refresh.

- [ ] **Step 5: Record evidence, review, and integrate**

Record exact commands, result bundles, pass/fail counts, invitation project, live results, and the GA revoke/remove action. Never mark an unrun gate as passing.

~~~bash
git add docs/release-evidence/canonical-debug-registration-repair.md
git commit -m "docs: record debug registration repair"
git status --short
git diff --check main...HEAD
~~~

Expected: clean worktree and no whitespace errors. Request code review, address verified findings, then fast-forward main only after every gate passes.
