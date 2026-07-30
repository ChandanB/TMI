# TMI Release 1 Acceptance Evidence

Release 1 is accepted for the immutable application source identified below. Verification used deterministic local fixtures and the synthetic `demo-tmi` Firebase project; this record contains no credentials, production identifiers, or student PII.

## Acceptance identity

- Verification completed: July 30, 2026 (CDT)
- Verified implementation commit: `ebcec1ebc02e4f5678eeb4c736cf9bc9927815bb`
- Acceptance tag: `tmi-release-1-accepted` (annotated on this evidence commit)
- Xcode: 26.6, build 17F113
- Swift: 6.3.3 (`swiftlang-6.3.3.1.3`, `clang-2100.1.1.101`)
- Local Node/npm: 23.10.0 / 11.3.0
- Local Java: OpenJDK 25

## Release 1 roster journey

The deterministic acceptance provider uses the real authentication gate, adaptive application shell, `StudentRepository`, and `StudentListView`. The focused journey covers sign-in, invitation onboarding, create, accessible duplicate warning, edit, search/filter/pagination, archive, and reconstruction from the encrypted offline cache. The universal UI suite additionally covers the first-student action and assigned-scope authorization denial.

### iPhone

The complete iPhone suite includes the Release 1 journey and the universal UI checks.

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-Full-DerivedData \
  -resultBundlePath /tmp/TMI-Full-Results.xcresult
```

Result: `Passed`, 494 total, 491 passed, 3 expected hosted SecureStorage skips, 0 failed.

Result bundle: `/tmp/TMI-Full-Results.xcresult`

### iPad

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
  -derivedDataPath /tmp/TMI-DD-iPadAcceptance2 \
  -resultBundlePath /tmp/TMI-Release1-iPad-Acceptance-Final-2.xcresult \
  -only-testing:TMIUITests/Release1AcceptanceUITests
```

Result: `Passed`, 8 of 8 acceptance tests passed, 0 skipped, 0 failed.

### macOS

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TMI-DD-MacAcceptance2 \
  -resultBundlePath /tmp/TMI-Release1-Mac-Acceptance-Final-2.xcresult \
  -only-testing:TMIUITests/Release1AcceptanceUITests
```

Result: `Passed`, 8 of 8 acceptance tests passed, 0 skipped, 0 failed.

The earlier cross-platform visual and accessibility review found no blocker or high-severity issue. The final changes after that review were nonvisual cache and account-deletion safety hardening.

## Universal release gate

### Full macOS unit and integration suite

```bash
xcodebuild test -quiet -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TMI-Full-Mac-DerivedData \
  -resultBundlePath /tmp/TMI-Full-Mac-Results.xcresult \
  -only-testing:TMITests
```

Result: `Passed`, 468 total, 464 passed, 4 expected hosted Keychain or Local Authentication skips, 0 failed.

Result bundle: `/tmp/TMI-Full-Mac-Results.xcresult`

### Swift 6 Release builds

```bash
xcodebuild build -quiet -project TMI.xcodeproj -scheme TMI \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/TMI-Release-DerivedData \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build -quiet -project TMI.xcodeproj -scheme TMI \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TMI-Release-DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

Result: both commands exited 0. Swift 6 strict-concurrency settings produced no concurrency errors.

### Security rules and trusted functions

```bash
npm --prefix firebase test
```

Result: 8 test files passed, 89 tests passed, 0 failed.

### Migration dry-run and reconciliation

```bash
npm --prefix firebase run migrate:dry-run -- \
  --project demo-tmi --fixture firebase/fixtures/release.json

npm --prefix firebase run reconcile -- \
  --project demo-tmi --fixture firebase/fixtures/release.json
```

Results:

- Fixture SHA-256: `a6dee3d3e13f071b019c18d7797b3ae6eca418cc15e0715ae1eab850ac9c89c3`
- Deterministic migration-plan checksum: `78ff3b615eda9f2f80afb551b452fec5a9841d0044aaba902ba477251a3c026e`
- Source records: 5
- Canonically mapped records: 4
- Quarantined unresolved records: 1
- Reconciliation: 5 expected, 5 found, zero mismatches, `isConsistent: true`

The unresolved synthetic record was quarantined rather than assigned to an unproven tenant. The plan contains only the fixture's declared canonical writes.

## Offline and deletion safety

- The student page cache is encrypted, bounded to 16 pages, versioned, and scoped by tenant, user, and normalized query.
- Permission denial records a SHA-256 authority tombstone and invalidates all cached pages for that authority.
- If tombstone persistence fails, the repository fails closed by removing the entire roster archive; if removal also fails, it persists an empty archive.
- Trusted create, reconciliation, update, and archive operations invalidate affected cached pages immediately after backend success, before any downstream refresh can fail.
- Account deletion reauthenticates first, then removes the roster archive, all service-scoped denial tombstones, and the pending-create outbox before deleting the personal backend/Auth account.
- A failed local purge prevents backend deletion, and retry reuses the original operation ID.
- Institution-owned student and TMI-plan records remain outside personal-account deletion scope.
- Final P0/P1 review found no remaining issue in cache invalidation or account deletion.

## Data and logging boundaries

Repository-wide scans remain a legacy inventory, so Release 1 acceptance is based on the implementation delta:

- Zero added `print`, `debugPrint`, or `dump` calls when scanned with an identifier boundary.
- Zero added sample-data fallback.
- Zero added direct access to an unapproved collection.
- The broader literal `print\(` scan reports a false positive for the new `fingerprint(` helper; it is not a logging call.
- `git diff --check` completed with no whitespace errors.

## Expected non-blocking warnings

- The three iOS skips and four macOS skips require hosted Keychain or interactive Local Authentication behavior and are unchanged from Gate 0.
- The local Node 23 and Java 25 toolchains emit Firebase dependency/runtime support warnings; the deterministic tests and reconciliation complete successfully. CI uses the pinned supported toolchain.
- Xcode can emit an LLDB initialization warning and the iOS simulator can emit a duplicate WebKit accessibility-loader warning; accepted tests complete without a crash or accessibility failure.

## Decision

Release 1 satisfies the secure-roster contract: verified staff can enter the adaptive shell and manage only assigned students through canonical, idempotent persistence; the full roster journey passes on iPhone, iPad, and macOS; offline data fails closed; personal account deletion preserves institution-owned records; migrations reconcile exactly; backend tests pass; and Swift 6 Release builds succeed on both supported platforms. The program may advance to Release 2.
