# Registration Presentation Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the staff-registration form across Firebase identity callbacks, recover ambiguous post-commit registrations without creating another account, and dismiss only for the exact trusted identity created by the attempt.

**Architecture:** `ContentView` owns the sheet lifetime and passes presentation state into the form. A small form-owned `StaffRegistrationFlow` state machine owns submission/recovery phases and identity matching; `AuthStateModel` remains the sole authorization authority and `AuthenticationRepository` remains the sole account/provisioning transaction owner.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing, XCTest UI testing, Firebase Auth/Functions/Firestore.

---

## File map

- Create `TMI/Features/Authentication/StaffRegistrationFlow.swift`: form-scoped submission and recovery state machine; no UI rendering and no authority synthesis.
- Create `TMITests/Features/Authentication/StaffRegistrationFlowTests.swift`: deterministic unit coverage for terminal failure, `claimRefreshPending`, identity matching, and duplicate-create prevention.
- Modify `TMI/Features/Authentication/AuthSession.swift`: add standard staff-registration recovery copy.
- Modify `TMI/Views/Authentication/SimplifiedRegistrationView.swift`: bind the form to the root presentation, drive the flow state machine, gate cancellation, and close only for the matching trusted session.
- Modify `TMI/Views/Authentication/AuthenticationView.swift`: replace local sheet ownership with an `onCreateAccount` action.
- Modify `TMI/App/TMIApp.swift`: own the production registration sheet across all authentication routing branches.
- Modify `TMI/Features/Authentication/AuthenticationAcceptanceUITestingSupport.swift`: mirror root ownership in the acceptance fixture and provide a deterministic intermediate-auth delay.
- Modify `TMITests/Views/SimplifiedRegistrationViewTests.swift`: enforce source composition and interactive-dismiss boundaries.
- Modify `TMIUITests/Release1AcceptanceUITests.swift`: prove the form survives the intermediate callback and cannot be cancelled during submission.
- Modify `docs/release-evidence/canonical-debug-registration-repair.md`: record the new focused and build results without changing the still-blocked live Firebase gate.

### Task 1: Form-owned registration flow state machine

**Files:**
- Create: `TMI/Features/Authentication/StaffRegistrationFlow.swift`
- Create: `TMITests/Features/Authentication/StaffRegistrationFlowTests.swift`
- Modify: `TMI/Features/Authentication/AuthSession.swift:104-119`

- [ ] **Step 1: Write failing state-machine tests**

Add `StaffRegistrationFlowTests` with a `@MainActor` fake `AuthenticationProviding` that counts `register` and `refresh` calls and returns queued results. Cover these exact cases:

```swift
@Test("Successful registration waits for its exact trusted identity")
func successWaitsForMatchingIdentity() async {
    let repository = RegistrationFlowAuthenticationFake(
        registerResults: [.success(session(userID: "created-user"))]
    )
    let flow = StaffRegistrationFlow()

    await flow.submit(request(), using: repository)

    #expect(flow.phase == .awaitingAuthorization(userID: "created-user"))
    #expect(flow.isOperationActive)
    #expect(flow.acceptPublishedIdentity("other-user") == false)
    #expect(flow.phase == .awaitingAuthorization(userID: "created-user"))
    #expect(flow.acceptPublishedIdentity("created-user"))
    #expect(flow.phase == .complete)
}

@Test("Terminal registration failure permits correction without recovery")
func terminalFailureStopsOperation() async {
    let repository = RegistrationFlowAuthenticationFake(
        registerResults: [.failure(RegistrationFlowTestError.terminal)]
    )
    let flow = StaffRegistrationFlow()

    await flow.submit(request(), using: repository)

    #expect(flow.phase == .failed(
        message: AuthenticationPresentationPolicy.registrationFailureMessage,
        recoveryAvailable: false
    ))
    #expect(flow.isOperationActive == false)
    #expect(repository.registerCallCount == 1)
    #expect(repository.refreshCallCount == 0)
}

@Test("Ambiguous result recovers without creating a second identity")
func ambiguousResultUsesRefreshOnly() async {
    let repository = RegistrationFlowAuthenticationFake(
        registerResults: [.failure(StaffInvitationProvisioningError.claimRefreshPending)],
        refreshResults: [
            .failure(StaffInvitationProvisioningError.claimRefreshPending),
            .success(session(userID: "created-user")),
        ]
    )
    let flow = StaffRegistrationFlow()

    await flow.submit(request(), using: repository)
    #expect(flow.recoveryAvailable)
    #expect(repository.registerCallCount == 1)
    #expect(repository.refreshCallCount == 1)

    await flow.retryRecovery(using: repository)

    #expect(flow.phase == .awaitingAuthorization(userID: "created-user"))
    #expect(repository.registerCallCount == 1)
    #expect(repository.refreshCallCount == 2)
}

@Test("Finished authorization fails closed for a missing identity")
func missingAuthorizedIdentityFailsClosed() async {
    let repository = RegistrationFlowAuthenticationFake(
        registerResults: [.success(session(userID: "created-user"))]
    )
    let flow = StaffRegistrationFlow()
    await flow.submit(request(), using: repository)

    #expect(flow.finishAuthorization(with: nil) == false)
    #expect(flow.isOperationActive == false)
    #expect(flow.errorMessage == AuthStateModel.organizationAccessErrorMessage)
}
```

The fake must implement every protocol requirement, pop results in call order, and expose counters as `private(set)` properties. Its `register` and `refresh` methods are the only methods used by these tests; all other protocol methods may throw `RegistrationFlowTestError.unexpectedCall`.

- [ ] **Step 2: Run the new tests and verify RED**

Run:

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-RegistrationPresentation-DD \
  -only-testing:TMITests/StaffRegistrationFlowTests
```

Expected: FAIL because `StaffRegistrationFlow` does not exist.

- [ ] **Step 3: Add the minimal state machine and recovery message**

Create this form-scoped model:

```swift
import Observation

@MainActor
@Observable
final class StaffRegistrationFlow {
    enum Phase: Equatable {
        case idle
        case submitting
        case recovering
        case awaitingAuthorization(userID: String)
        case failed(message: String, recoveryAvailable: Bool)
        case complete
    }

    private(set) var phase: Phase = .idle

    var isOperationActive: Bool {
        switch phase {
        case .submitting, .recovering, .awaitingAuthorization:
            true
        case .idle, .failed, .complete:
            false
        }
    }

    var recoveryAvailable: Bool {
        if case .failed(_, let recoveryAvailable) = phase {
            return recoveryAvailable
        }
        return false
    }

    var errorMessage: String? {
        if case .failed(let message, _) = phase {
            return message
        }
        return nil
    }

    var expectedIdentityID: String? {
        if case .awaitingAuthorization(let userID) = phase {
            return userID
        }
        return nil
    }

    func submit(
        _ request: StaffRegistrationRequest,
        using authentication: any AuthenticationProviding
    ) async {
        guard !isOperationActive else { return }
        phase = .submitting
        do {
            try accept(try await authentication.register(request))
        } catch StaffInvitationProvisioningError.claimRefreshPending {
            await recover(using: authentication)
        } catch {
            phase = .failed(
                message: AuthenticationPresentationPolicy.registrationMessage(for: error),
                recoveryAvailable: false
            )
        }
    }

    func retryRecovery(using authentication: any AuthenticationProviding) async {
        guard recoveryAvailable else { return }
        await recover(using: authentication)
    }

    func acceptPublishedIdentity(_ userID: String?) -> Bool {
        guard case .awaitingAuthorization(let expectedUserID) = phase,
              userID == expectedUserID else {
            return false
        }
        phase = .complete
        return true
    }

    func finishAuthorization(with userID: String?) -> Bool {
        guard case .awaitingAuthorization = phase else { return false }
        if acceptPublishedIdentity(userID) { return true }
        phase = .failed(
            message: AuthStateModel.organizationAccessErrorMessage,
            recoveryAvailable: false
        )
        return false
    }

    private func recover(using authentication: any AuthenticationProviding) async {
        phase = .recovering
        do {
            try accept(try await authentication.refresh())
        } catch StaffInvitationProvisioningError.claimRefreshPending {
            phase = .failed(
                message: AuthenticationPresentationPolicy.registrationRecoveryMessage,
                recoveryAvailable: true
            )
        } catch {
            phase = .failed(
                message: AuthenticationPresentationPolicy.registrationMessage(for: error),
                recoveryAvailable: false
            )
        }
    }

    private func accept(_ session: AuthSession) throws {
        guard let userID = session.identity?.userID,
              !userID.isEmpty else {
            throw AuthenticationRepositoryError.registrationRollbackFailed
        }
        phase = .awaitingAuthorization(userID: userID)
    }
}
```

Add to `AuthenticationPresentationPolicy`:

```swift
static let registrationRecoveryMessage =
    "Your account was created, but organization access is still being prepared. Continue setup to retry securely."
```

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run the Step 2 command. Expected: PASS with all `StaffRegistrationFlowTests` successful.

- [ ] **Step 5: Commit Task 1**

```bash
git add TMI/Features/Authentication/StaffRegistrationFlow.swift \
  TMI/Features/Authentication/AuthSession.swift \
  TMITests/Features/Authentication/StaffRegistrationFlowTests.swift
git commit -m "fix: model recoverable staff registration"
```

### Task 2: Root-owned presentation and identity-gated form dismissal

**Files:**
- Modify: `TMI/App/TMIApp.swift:284-326`
- Modify: `TMI/Views/Authentication/AuthenticationView.swift:8-22,177-203,231-238`
- Modify: `TMI/Views/Authentication/SimplifiedRegistrationView.swift:55-285`
- Modify: `TMITests/Views/SimplifiedRegistrationViewTests.swift`

- [ ] **Step 1: Write failing composition tests**

Extend `SimplifiedRegistrationViewTests` to read `TMIApp.swift` and assert:

```swift
@Test("The app root owns registration presentation across auth routing changes")
func rootOwnsRegistrationPresentation() throws {
    let root = projectRoot()
    let app = try source("TMI/App/TMIApp.swift", root: root)
    let signIn = try source(
        "TMI/Views/Authentication/AuthenticationView.swift",
        root: root
    )
    let registration = try source(
        "TMI/Views/Authentication/SimplifiedRegistrationView.swift",
        root: root
    )

    #expect(app.contains("@State private var isRegistrationPresented = false"))
    #expect(app.contains(".sheet(isPresented: $isRegistrationPresented)"))
    #expect(app.contains(".interactiveDismissDisabled(isRegistrationOperationActive)"))
    #expect(signIn.contains("onCreateAccount()"))
    #expect(signIn.contains(".sheet(isPresented: $showingRegistration)") == false)
    #expect(registration.contains("flow.acceptPublishedIdentity"))
    #expect(registration.contains("authStateModel.authenticatedSession?.profile.userID"))
}
```

Refactor the existing repeated root calculation into:

```swift
private func projectRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func source(_ path: String, root: URL) throws -> String {
    try String(contentsOf: root.appending(path: path), encoding: .utf8)
}
```

- [ ] **Step 2: Run the composition test and verify RED**

Run:

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-RegistrationPresentation-DD \
  -only-testing:TMITests/SimplifiedRegistrationViewTests
```

Expected: FAIL because `AuthenticationView` still owns the sheet.

- [ ] **Step 3: Move presentation state to `ContentView`**

Add root state:

```swift
@State private var isRegistrationPresented = false
@State private var isRegistrationOperationActive = false
```

Change the unauthenticated branch to:

```swift
AuthenticationView(onCreateAccount: {
    self.isRegistrationPresented = true
})
```

Attach the sheet to the outer routing group, after its foreground modifiers:

```swift
.sheet(isPresented: $isRegistrationPresented) {
    SimplifiedRegistrationView(
        isPresented: $isRegistrationPresented,
        isOperationActive: $isRegistrationOperationActive
    )
    .tmiSheetStyle()
    .interactiveDismissDisabled(isRegistrationOperationActive)
}
```

- [ ] **Step 4: Make `AuthenticationView` presentation-agnostic**

Replace local `showingRegistration` state with:

```swift
let onCreateAccount: @MainActor () -> Void

init(onCreateAccount: @escaping @MainActor () -> Void = {}) {
    self.onCreateAccount = onCreateAccount
}
```

Change the Create Account button action to `onCreateAccount`, then remove the local `.sheet` modifier entirely.

- [ ] **Step 5: Bind `SimplifiedRegistrationView` to the flow and root**

Replace `isRegistering`, `errorMessage`, and `@Environment(\.dismiss)` with:

```swift
@Binding private var isPresented: Bool
@Binding private var isOperationActive: Bool
@State private var flow = StaffRegistrationFlow()
@State private var validationErrorMessage: String?

init(
    isPresented: Binding<Bool> = .constant(true),
    isOperationActive: Binding<Bool> = .constant(false)
) {
    _isPresented = isPresented
    _isOperationActive = isOperationActive
}

private var errorMessage: String? {
    validationErrorMessage ?? flow.errorMessage
}
```

Use `flow.isOperationActive` for button loading/disabled state. Change Cancel to:

```swift
Button("Cancel") {
    guard !flow.isOperationActive else { return }
    isPresented = false
}
.disabled(flow.isOperationActive)
.accessibilityIdentifier("authentication.registration.cancel")
```

Add recovery UI directly below the error text:

```swift
if flow.recoveryAvailable {
    TMIButton(
        text: "Continue Account Setup",
        icon: "arrow.clockwise.circle",
        style: .secondary,
        isLoading: flow.isOperationActive,
        action: retryRecovery
    )
    .accessibilityIdentifier("authentication.registration.retryRecovery")
}
```

Replace the submission task with:

```swift
private func submit(_ request: StaffRegistrationRequest) async {
    guard let authentication = dependencies.authentication else {
        validationErrorMessage = AuthenticationPresentationPolicy.registrationFailureMessage
        return
    }
    await flow.submit(request, using: authentication)
    clearSecrets()
    await authorizeIfReady()
}

private func retryRecovery() {
    Task { @MainActor in
        guard let authentication = self.dependencies.authentication else { return }
        await self.flow.retryRecovery(using: authentication)
        await self.authorizeIfReady()
    }
}

private func authorizeIfReady() async {
    guard flow.expectedIdentityID != nil else { return }
    await authStateModel.fetch()
    if flow.finishAuthorization(
        with: authStateModel.authenticatedSession?.profile.userID
    ) {
        isPresented = false
    }
}

private func acceptPublishedIdentity(_ userID: String?) {
    if flow.acceptPublishedIdentity(userID) {
        isPresented = false
    }
}
```

Synchronize the root's dismissal lock and accept listener-driven success:

```swift
.onChange(of: flow.isOperationActive, initial: true) { _, isActive in
    isOperationActive = isActive
}
.onChange(of: authStateModel.authenticatedSession?.profile.userID) { _, userID in
    acceptPublishedIdentity(userID)
}
```

All validation branches must assign `validationErrorMessage`; successful validation clears it before launching `Task { @MainActor in await self.submit(request) }`. `clearSecrets()` clears password, confirmation, and invitation code exactly once per repository attempt.

- [ ] **Step 6: Run focused tests and build**

Run:

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-RegistrationPresentation-DD \
  -only-testing:TMITests/StaffRegistrationFlowTests \
  -only-testing:TMITests/SimplifiedRegistrationViewTests \
  -only-testing:TMITests/AuthStateModelMembershipTests
```

Expected: PASS. Then run:

```bash
xcodebuild build -quiet -project TMI.xcodeproj -scheme TMI \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/TMI-RegistrationPresentation-Debug-DD
```

Expected: `** BUILD SUCCEEDED **` or exit code 0 under `-quiet`.

- [ ] **Step 7: Commit Task 2**

```bash
git add TMI/App/TMIApp.swift \
  TMI/Views/Authentication/AuthenticationView.swift \
  TMI/Views/Authentication/SimplifiedRegistrationView.swift \
  TMITests/Views/SimplifiedRegistrationViewTests.swift
git commit -m "fix: preserve registration across auth callbacks"
```

### Task 3: Acceptance fixture and interaction coverage

**Files:**
- Modify: `TMI/Features/Authentication/AuthenticationAcceptanceUITestingSupport.swift:49-122,332-397`
- Modify: `TMIUITests/Release1AcceptanceUITests.swift:52-97`

- [ ] **Step 1: Write a failing UI assertion for intermediate presentation**

In `testInvitationOnboardingSubmitsTheStaffInvitation`, after submitting, assert that the form and disabled Cancel button remain during the fixture's deterministic provisioning pause:

```swift
let cancel = app.buttons["authentication.registration.cancel"]
XCTAssertTrue(cancel.waitForExistence(timeout: 2))
XCTAssertFalse(cancel.isEnabled)
XCTAssertTrue(
    element("authentication.registration.screen", in: app).exists,
    "The root-owned registration form must survive the intermediate Firebase identity callback."
)
#if !os(macOS)
app.swipeDown()
XCTAssertTrue(
    element("authentication.registration.screen", in: app).exists,
    "Interactive dismissal must be disabled while registration is active."
)
#endif
```

Keep the existing final assertion that the staff workspace appears.

- [ ] **Step 2: Run the UI test and verify RED**

Run:

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-RegistrationPresentation-UI-DD \
  -only-testing:TMIUITests/Release1AcceptanceUITests/testInvitationOnboardingSubmitsTheStaffInvitation
```

Expected: FAIL because the fixture has no root-owned sheet and no deterministic in-flight interval.

- [ ] **Step 3: Root-own the sheet in the acceptance fixture**

Add these states to `AuthenticationAcceptanceUITestingContent`:

```swift
@State private var isRegistrationPresented = false
@State private var isRegistrationOperationActive = false
```

Change its sign-in branch and attach the same sheet contract used by `ContentView`:

```swift
AuthenticationView(onCreateAccount: {
    self.isRegistrationPresented = true
})

.sheet(isPresented: $isRegistrationPresented) {
    SimplifiedRegistrationView(
        isPresented: $isRegistrationPresented,
        isOperationActive: $isRegistrationOperationActive
    )
    .tmiSheetStyle()
    .interactiveDismissDisabled(isRegistrationOperationActive)
}
```

- [ ] **Step 4: Add a deterministic intermediate-auth interval**

After `identityProvider.authenticate` in the successful acceptance repository registration, add:

```swift
try await Task.sleep(for: .seconds(1))
```

This intentionally gives the auth listener time to replace the underlying route while the root-owned sheet must remain visible. Do not add sleeps to production code.

- [ ] **Step 5: Run the UI acceptance test and verify GREEN**

Run the Step 2 command. Expected: PASS; Cancel is disabled during submission, the registration screen survives, and the staff workspace eventually appears.

- [ ] **Step 6: Commit Task 3**

```bash
git add TMI/Features/Authentication/AuthenticationAcceptanceUITestingSupport.swift \
  TMIUITests/Release1AcceptanceUITests.swift
git commit -m "test: cover registration callback presentation"
```

### Task 4: Full verification and evidence

**Files:**
- Modify: `docs/release-evidence/canonical-debug-registration-repair.md`

- [ ] **Step 1: Run the focused authentication gate**

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-RegistrationPresentation-Final-DD \
  -resultBundlePath /tmp/TMI-RegistrationPresentation-Final.xcresult \
  -only-testing:TMITests/StaffRegistrationFlowTests \
  -only-testing:TMITests/SimplifiedRegistrationViewTests \
  -only-testing:TMITests/AuthSessionTests \
  -only-testing:TMITests/AuthStateModelMembershipTests \
  -only-testing:TMITests/DebugStaffInvitationProvisionerTests \
  -only-testing:TMITests/AppDependenciesTests
```

Expected: exit 0 with zero failed tests.

- [ ] **Step 2: Run Firebase regression tests**

```bash
npm --prefix firebase run lint
npm --prefix firebase test
```

Expected: both commands exit 0; no invitation or callable regressions.

- [ ] **Step 3: Run Debug and Release builds**

```bash
xcodebuild build -quiet -project TMI.xcodeproj -scheme TMI \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/TMI-RegistrationPresentation-Final-Debug-DD

xcodebuild build -quiet -project TMI.xcodeproj -scheme TMI \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/TMI-RegistrationPresentation-Final-Release-DD

xcodebuild build -quiet -project TMI.xcodeproj -scheme TMI \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/TMI-RegistrationPresentation-Final-macOS-DD
```

Expected: every command exits 0. Confirm the Release binaries do not contain `TMI-DEBUG-ACCESS-2026`.

- [ ] **Step 4: Update evidence without overstating the live gate**

Append exact commands, dates, result counts, and build outcomes to `docs/release-evidence/canonical-debug-registration-repair.md`. State explicitly that the live invitation seed/register/relaunch/sign-in gate remains **BLOCKED** until an operator with `tmi-education` access supplies Application Default Credentials. Do not mark live registration fixed from automated tests alone.

- [ ] **Step 5: Commit verification evidence**

```bash
git add docs/release-evidence/canonical-debug-registration-repair.md
git commit -m "docs: verify registration presentation recovery"
```

## Integration gate

Do not merge this branch into `main` until:

1. All automated gates above pass.
2. An authorized operator seeds the canonical Debug invitation in `tmi-education` through the stdin-only administration script.
3. Live Debug registration for `tmi-debug@example.com` reaches the staff workspace.
4. Relaunch and ordinary sign-in restore the same trusted session.
5. The evidence document records those live results.
