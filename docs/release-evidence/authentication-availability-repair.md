# Authentication Availability Repair Release Evidence

The implementation is verified except for the macOS UI permission gate described below. This record contains no credentials, production identifiers, or student PII.

## Verification identity

- Verification date: July 30, 2026 (CDT)
- Branch: `codex/authentication-availability-repair`
- Final repair source HEAD: `f0bc76e`
- Baseline: `eb14a988b2928f46ffe4c14ce1417d5a4ae47e88`
- Release-gate correction: the fresh macOS gate exposed native `TextInputAutocapitalization` use in a cross-platform component. A source-contract regression test was observed failing before a minimal `TMITextInputAutocapitalization` compatibility adapter was added. The correction and this evidence are recorded together in the evidence commit.
- Durable RED reproduction: `docs/release-evidence/logs/authentication-availability-repair-macos-red.txt` records the exact detached `8084cb0` command, exit code 65, and compiler diagnostics.
- Final-review partial-state RED: six new invitation-reconciliation tests initially failed because the callable rejected every pre-existing onboarding document, and four client regressions initially lacked the missing-claim state and setup transitions.

## Focused authentication and accessibility gate

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,id=30138155-B4F2-4628-850A-BEFE4A6FC2AA' \
  -resultBundlePath /tmp/TMI-AuthRepair-Partial-Focused-2.xcresult \
  -only-testing:TMITests/MembershipRepositoryTests \
  -only-testing:TMITests/AuthStateModelMembershipTests \
  CODE_SIGNING_ALLOWED=NO
```

Final-source rerun at `f0bc76e`: `Passed`, 35 passed, 0 skipped, 0 failed.

Result bundle: `/tmp/TMI-AuthRepair-Final-Focused.xcresult`

Earlier focused bundles covered `AuthSessionTests`, `FirebaseStaffInvitationProvisionerTests`, `SignOutCallSiteTests`, `TMIComponentAccessibilityTests`, and `UITestingLaunchConfigurationTests` before the partial-state repair. The adapter additionally has UIKit behavioral coverage for all four mappings: `never`, `sentences`, `words`, and `characters`. The mapping test was first observed failing to compile because `TMITextInputAutocapitalization` had no `uiKitValue`; the GREEN component bundle reports 3 logical tests and 6 passed executions at `/tmp/TMI-AuthRepair-Capitalization-Green-3.xcresult`.

## Firebase gate

```bash
cd firebase
npm test
```

Result after replay-hardening review: 8 test files passed, 100 tests passed, 0 failed. The invitation suite now includes 29 tests, including partial-state reconciliation and post-transaction claim-retry mutation regressions for every canonical artifact, including membership schema integrity. No dependency audit fix was run.

The local Java runtime emitted the known deprecated `sun.misc.Unsafe` warning, and Firebase Admin emitted metadata lookup warnings without live credentials. The `demo-tmi` emulator suite completed successfully.

## Full platform gates

### iOS

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath '/tmp/TMI-AuthRepair-Full macOS DD' \
  -resultBundlePath /tmp/TMI-AuthRepair-Full-iOS.xcresult
```

Historical pre-partial-state result at `8084cb0`: `Passed`, 516 total, 513 passed, 3 expected hosted SecureStorage skips, 0 failed. The later Swift source changes are covered by the final-source focused gate above; this bundle is not represented as a full-suite run at `f0bc76e`.

Result bundle: `/tmp/TMI-AuthRepair-Full-iOS.xcresult`

### macOS unit and integration tests

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=macOS' \
  -derivedDataPath '/tmp/TMI-AuthRepair-Full macOS DD' \
  -resultBundlePath /tmp/TMI-AuthRepair-Full-macOS.xcresult \
  -only-testing:TMITests
```

Historical pre-partial-state result at `8084cb0`: `Passed`, 487 total, 483 passed, 4 expected hosted Keychain or Local Authentication skips, 0 failed. The later Swift source changes are covered by the final-source focused gate above; this bundle is not represented as a full-suite run at `f0bc76e`.

Result bundle: `/tmp/TMI-AuthRepair-Full-macOS.xcresult`

Xcode selected the first identical local macOS destination. Swift test compilation also emitted existing redundant-`await` warnings.

### Release builds

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

Result: both commands exited 0.

## UI and accessibility evidence

These iPhone/iPad review bundles validate the authentication recovery UI at repair HEAD `8084cb0`. Later changes added the cross-platform capitalization adapter and partial-state authorization routing; those changes are covered by their focused unit gates, not by these UI bundles. UI acceptance at final source remains conditional on rerunning these checks if release policy requires a single final-HEAD UI bundle.

- iPhone 17 Pro, iOS 26.5: 13 passed, 0 skipped, 0 failed: 9 unit checks plus 4 UI checks. Bundle: `/tmp/TMI-AuthRepair-Review-iPhone.xcresult`
- iPad Pro 13-inch (M5), iPadOS 26.5: 4 UI checks passed, 0 skipped, 0 failed. Bundle: `/tmp/TMI-AuthRepair-Review-iPad.xcresult`

macOS UI did **not** pass. Two attempts compiled but executed no UI test because macOS presented the authorization modal `XCTest is trying to Enable UI Automation — Touch ID or enter your password to allow this`. Each result reports a runner initialization failure after timing out while enabling automation mode:

- `/tmp/TMI-AuthRepair-Verify-macOS.xcresult`
- `/tmp/TMI-AuthRepair-Verify-macOS-Retry.xcresult`

This is an environment blocker and remains an outstanding manual release gate. A human must authorize UI automation and rerun the four authentication-availability UI checks on macOS.

## Policy, timeout, and retry behavior

- Production temporarily sets both the client `staffEmailVerificationRequired` flag and the trusted Functions `requireVerifiedEmail` dependency to `false`; the client and server policy agree.
- Staff setup sends only invitation code, display name, privacy-policy version, and acceptable-use-policy version. It sends no role, district, school, membership, or capability authority.
- The callable rejects unexpected request fields and derives role, district, school assignments, and capabilities from the trusted server-side invitation.
- Existing authenticated staff without a canonical profile can accept a real invitation and reload the canonical session without recreating the Auth identity.
- A profile-present identity with all trusted claim keys absent, or a valid matching claim with no canonical membership, enters Access Setup Required. Partial/malformed claims, unavailable authorization, inactive membership, and version or identity mismatches remain denied or recoverable and never enter setup.
- An active, email-bound, unconsumed invitation can reconcile compatible partial canonical state transactionally. Existing membership authority must exactly match the invitation and preserves its version and assigned students; compatible profiles and non-authority preferences are preserved; missing profile, membership, acknowledgements, preferences, and audit records are created without overwriting compatible records.
- Existing trusted claims are accepted only when district, staff access class, and membership version exactly match the reconciled canonical membership. Partial or conflicting claims and incompatible profiles, memberships, acknowledgements, preferences, or audit records deny provisioning before invitation consumption.
- Startup authorization has a bounded deadline, leaves loading with recoverable guidance, and retry starts a fresh authorization generation. Stale completions cannot mutate a signed-out or replacement identity.
- Provisioning transport or ambiguous response failures preserve the authenticated identity and surface an idempotent retry; terminal invitation errors remain terminal.
- Sign-out failures remain visible and retryable, including the post-account-deletion sign-out path.

## Security and static review

```bash
BASE=$(git merge-base main HEAD)
git diff --check "$BASE"

git diff --unified=0 "$BASE" -- TMI firebase |
  rg '^\+[^+]' |
  rg '(^|[^[:alnum:]_])(print|debugPrint|dump)[[:space:]]*\('
```

Results:

- `git diff --check` completed with no whitespace errors.
- Added raw logging calls at an identifier boundary: 0.
- Authority-bearing additions were inspected. The client submits no authority-bearing role, district, school, membership, or capabilities; it validates the trusted callable response and authenticated user ID.
- `AuthenticationAcceptanceUITestingSupport.swift` and `UITestingLaunchConfiguration.swift` are enclosed in `#if DEBUG`.
- Production staff email verification flags are false on both client and Functions.
- No mock invitation provider or fixture is compiled into Release code.
- The invitation is operational data: a real trusted `staffInvitations/{sha256(code)}` record must exist, be active, unexpired, and bound to the authenticated email.

## Deployment note

The client and Firebase Functions changes must ship together so email-verification policy and the callable request contract remain aligned. Real staff invitations must be provisioned operationally before onboarding. No deployment was performed as part of this verification.

## Decision

**Implementation verified except macOS UI permission gate.** Focused authentication tests, the full Firebase suite, full iOS tests, full macOS `TMITests`, iPhone/iPad UI evidence, security review, and both Release builds satisfy their gates. Release acceptance remains conditional on manually authorizing macOS UI automation and passing the outstanding macOS authentication-availability UI run; this is not a fully accepted release.
