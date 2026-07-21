# TMI Gate 0 Acceptance Evidence

Gate 0 is accepted for the verified application source identified below. This record contains no credentials, production identifiers, or student PII; Firebase validation used the synthetic `demo-tmi` project and repository fixtures.

## Acceptance identity

- Verification date: July 21, 2026 (CDT)
- Verified source commit: `b511502acbaf5d47358c791b5fc5a923a7521a15`
- Acceptance tag: `tmi-gate-0-accepted` (annotated on this evidence commit)
- Xcode: 26.6, build 17F113
- Swift: 6.3.3 (`swiftlang-6.3.3.1.3`, `clang-2100.1.1.101`)
- Local Node/npm: 23.10.0 / 11.3.0
- Local Java: OpenJDK 25; CI pins the supported Node 22 and Java 21 toolchain
- CI workflow lint: `actionlint .github/workflows/*.yml` completed with zero findings

## Universal release gate

### Full iOS suite

```bash
xcodebuild test -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-Full-DerivedData \
  -resultBundlePath /tmp/TMI-Full-Results.xcresult
```

Result: `TEST SUCCEEDED`, 315 total, 312 passed, 3 skipped, 0 failed. The skips are hosted SecureStorage behaviors that cannot be made deterministic in the simulator: clear-all, delete-existing-key, and biometric retrieval. No test was skipped because Firebase was unavailable.

Result bundle: `/tmp/TMI-Full-Results.xcresult`

### Full macOS unit and integration suite

```bash
xcodebuild test -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TMI-Full-Mac-DerivedData \
  -resultBundlePath /tmp/TMI-Full-Mac-Results.xcresult \
  -only-testing:TMITests
```

Result: `TEST SUCCEEDED`, 312 total, 308 passed, 4 skipped, 0 failed. The shared clear-all and delete-existing-key skips remain; passcode-protected Keychain retrieval and biometric SecureStorage retrieval are skipped on macOS because they require interactive Local Authentication prompts. No test was skipped because Firebase was unavailable.

Result bundle: `/tmp/TMI-Full-Mac-Results.xcresult`

### Swift 6 Release builds

```bash
xcodebuild build -project TMI.xcodeproj -scheme TMI -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/TMI-Release-DerivedData CODE_SIGNING_ALLOWED=NO

xcodebuild build -project TMI.xcodeproj -scheme TMI -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TMI-Release-DerivedData CODE_SIGNING_ALLOWED=NO
```

Result: both commands ended with `BUILD SUCCEEDED`. Swift 6 complete strict concurrency and approachable concurrency remain enabled for the application and test targets; no concurrency errors were emitted.

### Security rules and trusted functions

```bash
npm --prefix firebase test
```

Result: 5 test files passed, 32 tests passed, 0 failed. The Firestore, Storage, trusted-function, migration, and authorization tests ran against local Firebase emulators for `demo-tmi`.

### Migration dry-run and reconciliation

```bash
npm --prefix firebase run migrate:dry-run -- \
  --project demo-tmi --fixture firebase/fixtures/release.json

npm --prefix firebase run reconcile -- \
  --project demo-tmi --fixture firebase/fixtures/release.json
```

Results:

- Fixture SHA-256: `b0f43068e4e7179d51a915d6c9d2635249adbb25dbd4824788676911df1ea35a`
- Deterministic migration-plan checksum: `4a5decb7cb822fe560bbfe0f01291ba0bc44c5a9b3d0124ce00724f73c871aa6`
- Source records: 5
- Canonically mapped records: 4
- Quarantined unresolved record: 1
- Reconciliation: 5 expected, 5 found, zero mismatches, `isConsistent: true`

The unresolved synthetic record was quarantined rather than assigned to an unproven tenant. The plan contains only the fixture's declared canonical writes.

### UI and accessibility

```bash
xcodebuild test -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-Full-DerivedData \
  -resultBundlePath /tmp/TMI-Gate0-iPhone-Accessibility.xcresult \
  -only-testing:TMIUITests

xcodebuild test -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
  -derivedDataPath /tmp/TMI-Full-DerivedData \
  -resultBundlePath /tmp/TMI-Gate0-iPad-Accessibility.xcresult \
  -only-testing:TMIUITests

xcodebuild test -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TMI-Full-Mac-DerivedData \
  -resultBundlePath /tmp/TMI-Gate0-macOS-Accessibility.xcresult \
  -only-testing:TMIUITests
```

Result: 2 of 2 UI tests passed on each platform, with zero failures or skips. The deterministic signed-out fixture covered default text and accessibility size 5, verified that the keyboard does not obscure initial actions, measured heading enlargement, and confirmed both Log In and Create Account remain reachable. The macOS window met the 900 by 700 point minimum; interactive controls use at least a 44-point minimum height.

Default, largest-text top, and largest-text action screenshots were inspected for each platform under `/tmp/TMI-Gate0-Accessibility-Screenshots/`. Essential content was legible with no overlap, clipping, missing identifier, focus trap, or hidden primary action. The Aubergine + Teal semantic palette remained visibly distinct on the approved light surfaces.

Result bundles:

- `/tmp/TMI-Gate0-iPhone-Accessibility.xcresult`
- `/tmp/TMI-Gate0-iPad-Accessibility.xcresult`
- `/tmp/TMI-Gate0-macOS-Accessibility.xcresult`

### Data and logging boundaries

```bash
rg -n 'print\(|debugPrint\(|dump\(' TMI
rg -n 'Student\.sample|sampleStudent|SampleDataSeeder|fallback.*sample' TMI
rg -n '\.collection\("(users|students|plans|tmiPlans|formAssignments|resources)' TMI

git diff --unified=0 main -- TMI | \
  rg '^\+[^+].*(print\(|debugPrint\(|dump\()'
```

Review results:

- The repository-wide scans report 591 historical raw-logging matches, 24 sample-data matches, and 93 direct-collection matches.
- The Gate 0 delta introduces zero raw `print`, `debugPrint`, or `dump` calls.
- The only sample-data delta is the `SampleDataSeeder` declaration. It is enclosed in `#if DEBUG`, has no production caller, and cannot provide a production fallback.
- The 27 direct-collection delta lines were inspected. Personal `users/{uid}` profile/preference access is permitted. Tenant membership, audit, catalog, form, and legacy domain access is either canonical or recorded in `LegacyFirestorePaths.migrationManifest` for its owning release. The remaining student and plan legacy readers/writers are pre-existing paths wrapped by Gate 0 authorization and explicitly scheduled for Release 1 or Release 3 migration. Gate 0 adds no unapproved collection writer.

### Privacy manifest and archive inspection

A generic iOS archive completed with `ARCHIVE SUCCEEDED`. Twenty-six app, framework, and bundle privacy manifests were inspected. The aggregate required-reason declarations were File Timestamp `C617.1`, System Boot Time `35F9.1`, and User Defaults `1C8F.1`, `C56D.1`, and `CA92.1`.

The reviewed root manifest and both final Release products are byte-identical with SHA-256:

```text
377eac8ab57494fc8d218cd27e88d9bcaaf264a40998ddbb0053cbae25ab3ea8
```

This covers `TMI/PrivacyInfo.xcprivacy`, the iOS simulator app manifest, and the macOS app resources manifest. The application declares only accessed API categories and no collected data types.

## Known non-blocking warnings

- The local Java 25 Firebase emulator runtime warns about a terminally deprecated `sun.misc.Unsafe` method. CI pins Java 21; rule/function results are unaffected.
- Firebase Admin emits `MetadataLookupWarning` when its credential metadata probe has no endpoint. Tests use the explicit emulator project and complete successfully without live credentials.
- The iOS 26.5 simulator reports a duplicate WebCore/WebKit accessibility loader class. The platform UI tests complete without a crash or accessibility failure.
- Xcode reports that AppIntents metadata extraction is skipped because the app does not link AppIntents; the app has no AppIntents feature.
- Xcode reports multiple matching local macOS destinations and selects the first identical architecture/host match.
- The iPad UI test runner emits an Xcode-generated launch-screen warning; launch and all assertions succeed.
- An earlier macOS run completed its tests but could not finish a 662 MB post-test diagnostic bundle after the temporary volume filled. Disposable DerivedData was cleared and the identical accepted command was rerun to exit 0; only the successful rerun and its result bundle are acceptance evidence.

## Decision

All Gate 0 acceptance conditions are satisfied: the canonical authorization and data foundation is enforced, migration reconciliation is exact, retention-safe account deletion preserves institution-owned records, Aubergine + Teal tokens are installed, Swift 6 Release builds pass on both supported platforms, deterministic UI/accessibility fixtures pass on iPhone, iPad, and macOS, and the branch introduces no unapproved logging, sample fallback, or collection writer. Gate 0 may advance to Release 1.
