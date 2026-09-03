# Canonical Debug Registration Repair Evidence

- Date: 2026-08-03
- Branch: `codex/auth-registration-session-refresh`
- Base: `a92b3ea0ee1a2391047560ed57508ed4b4e452d9`
- Verified head: `993c9569e3726d67a16c001b970c7bc92bfbf2b2`
- Debug email: `tmi-debug@example.com`
- Debug alias: `TMI-DEBUG-ACCESS-2026`
- Invitation project: `tmi-education`
- Invitation authority: canonical `provisionStaffMembership` callable only

## Automated verification

### Focused Swift authentication gate

Command:

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-DebugRegistration-Root-DD \
  -resultBundlePath /tmp/TMI-DebugRegistration-Root.xcresult \
  -only-testing:TMITests/DebugStaffInvitationProvisionerTests \
  -only-testing:TMITests/AuthSessionTests \
  -only-testing:TMITests/AuthStateModelMembershipTests \
  -only-testing:TMITests/AppDependenciesTests
```

Result: PASS. The result bundle reports 67 passed, 0 failed, and 0 skipped.

### Firebase gate

Command:

```bash
npm --prefix firebase run lint
npm --prefix firebase test
```

Result: PASS. TypeScript lint exited successfully. The emulator-backed suite
reports 11 files and 180 tests passed.

Non-fatal Java deprecation and Admin metadata lookup warnings were present and
match the established successful emulator runs.

### Build matrix

Commands:

```bash
xcodebuild build -quiet -project TMI.xcodeproj -scheme TMI \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/TMI-DebugRegistration-Root-DebugBuild-DD

xcodebuild build -quiet -project TMI.xcodeproj -scheme TMI \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/TMI-DebugRegistration-Root-ReleaseBuild-DD

xcodebuild build -quiet -project TMI.xcodeproj -scheme TMI \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TMI-DebugRegistration-Root-MacRelease-DD
```

Results:

- iOS Simulator Debug: PASS, exit 0.
- iOS Simulator Release: PASS, exit 0.
- macOS arm64 Release: PASS, exit 0.

The Release results confirm that Release compilation does not depend on the
Debug-only invitation translator.

## Live invitation and acceptance gate

Status: BLOCKED BEFORE EXTERNAL WRITE.

The first seed attempt was rejected by local opaque-code validation because the
shell extractor expected a multiline Swift constant. No Firebase initialization
or write occurred. The corrected stdin-only attempt reached Google
authentication and failed because Application Default Credentials are absent.

Firebase CLI is currently authenticated as `chandanbrown2@gmail.com`. A
read-only `firebase projects:list` succeeded, but its accessible projects do not
include `tmi-education`. Therefore this account cannot be used to seed or verify
the invitation project.

The following gates remain unrun and must not be treated as passing:

- Canonical Debug invitation seed in `tmi-education`.
- Ordinary Debug registration reaching the staff workspace.
- Relaunch restoration of the canonical staff session.
- Sign-out and subsequent password sign-in.
- Live confirmation that pending registration clears after refreshed claims.

## Required continuation

Authenticate Application Default Credentials with an account authorized for
`tmi-education`, or grant the current operator access. Then run the documented
silent stdin seed flow, perform ordinary Debug registration, and append the
live results here.

Before GA, revoke or expire the temporary invitation and remove the Debug alias
mapping.

### 2026-09-01 Debug synthetic membership acceptance

Automated gates run on 2026-09-02 against `main` at `fda2937`, macOS 26.4.1,
iPhone 17 Pro simulator (iOS 26.5).

- Focused deterministic tests: PASS — 91 executed, 91 passed, 0 failed, 0 skipped
  (`DebugStaffInvitationProvisionerTests`, `AuthSessionTests`,
  `AuthStateModelMembershipTests`, `StaffRegistrationFlowTests`,
  `SimplifiedRegistrationViewTests`, `AppDependenciesTests`)
- Debug generic iOS Simulator build: PASS (exit 0)
- Release generic iOS Simulator build: PASS (exit 0)
- Release macOS arm64 build: PASS (exit 0)
- Release fixture-string scan: PASS — no match for
  `TMI-DEBUG-ACCESS-2026`, `tmi-debug@example.com`, `district-debug`, or
  `school-debug` in either Release product tree
- UI regression: PASS — 5 executed, 5 passed, 0 failed
  (`AuthenticationAvailabilityUITests`, `SmokeUITests`)
- Live Firebase Auth registration: NOT RUN
- Live sign-out/sign-in: NOT RUN
- Live terminated-app session restoration: NOT RUN
- Cloud Functions invocation for Debug alias: not observed in automated runs;
  live confirmation still outstanding
- Firebase project: `tmi-education`
- Debug identity: `tmi-debug@example.com`
- Warnings: numerous non-fatal `no 'async' operations occur within 'await'
  expression` warnings in `TMITests/Features/Students/StudentRepositoryTests.swift`
  and `TMITests/Features/Surveys/SurveyEngineTests.swift`; ad-hoc codesigning
  notice on the TMI target. No errors.

#### Deviation from the plan

Plan Task 4 Step 4 specified
`TMIUITests/TMIUITests/testStaffInvitationRegistrationFlow` and
`testCredentialSignInFlow`. Neither identifier exists in the current test
target — the plan was written against a stale UI-test layout, and the filtered
run exits 0 while executing zero tests. The equivalent present-day presentation
and routing coverage is `AuthenticationAvailabilityUITests`
(`testRecoveryRetryHasVisibleOutcome`, `testRecoverySignOutReturnsToSignIn`,
`testExistingAccountCanCompleteAccessSetupAndReachRoster`) plus `SmokeUITests`,
which is what was run and recorded above.

#### Outstanding before this gate can be called complete

Task 4 Step 5, the live Firebase Authentication sequence in a Debug build
(register, sign out, sign in, terminate and relaunch), has not been performed.
It requires entering a real account password interactively, so it must be run by
the operator. Until it is recorded here, the Debug synthetic membership gate is
NOT accepted, and no acceptance tag should be created.
