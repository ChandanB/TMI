# TMI Gate 0 Canonical Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a green Swift 6 baseline, trusted tenant authorization, canonical Firebase paths, safe account deletion, deterministic feature flags, Aubergine + Teal tokens, and enforceable CI.

**Architecture:** Introduce pure Swift domain contracts and inject Firebase adapters at the application boundary. Authorization derives from server-managed membership and claims, clients write only whitelisted personal fields, trusted functions own privileged mutations and audit events, and migration tools move one canonical collection at a time without restoring legacy writers.

**Tech Stack:** Swift 6.2, SwiftUI, Observation, Swift Testing, Firebase Auth/Firestore/Storage/App Check/Functions, TypeScript, Firebase Emulator Suite, GitHub Actions

---

## File map

| Action | Path | Responsibility |
|---|---|---|
| Modify | `TMITests/Core/AccessibilityManagerTests.swift` | Repair baseline test compilation |
| Modify | `TMI.xcodeproj/project.pbxproj` | Swift 6.2 and strict concurrency settings |
| Create | `TMI/Core/Configuration/FeatureFlags.swift` | Typed production feature gates |
| Create | `TMI/Core/Authorization/Capability.swift` | Canonical capability vocabulary |
| Create | `TMI/Core/Authorization/MembershipContext.swift` | Trusted tenant/school/role/permission snapshot |
| Create | `TMI/Core/Authorization/AuthorizationPolicy.swift` | Pure client-side policy mirror |
| Create | `TMI/Core/Data/CanonicalRecordMetadata.swift` | Schema and optimistic-concurrency metadata |
| Replace | `TMI/Services/FirestorePaths.swift` | Canonical district/catalog paths only |
| Create | `TMI/Migration/LegacyFirestorePaths.swift` | Read-only legacy paths isolated from production repositories |
| Create | `TMI/Core/Dependencies/AppDependencies.swift` | Injected repositories and adapters |
| Modify | `TMI/App/TMIApp.swift` | Composition root and App Check startup |
| Modify | `TMI/Models/TMIUser.swift` | Personal profile only; canonical role migration |
| Replace | `TMI/Services/RBACService.swift` | Compatibility adapter over pure policy, then removal |
| Create | `TMI/Core/DesignSystem/TMIColors.swift` | Approved Aubergine + Teal tokens |
| Modify | `TMI/Core/DesignSystem/TMIDesignTokens.swift` | Non-color tokens only |
| Create | `TMI/Services/AccountDeletionService.swift` | Retention-safe personal deletion |
| Modify | `TMI/Views/User/UserProfileView.swift` | Reachable deletion entry point |
| Modify | `TMI/Views/Settings/DeleteAccountView.swift` | Accurate delete/retain disclosure |
| Create | `firebase.json` | Emulator, rules, indexes, functions configuration |
| Create | `firestore.indexes.json` | Checked-in canonical query indexes |
| Replace | `firestore.rules` | Trusted membership and capability enforcement |
| Create | `storage.rules` | Tenant-scoped object authorization |
| Create | `firebase/package.json` | Emulator, test, migration, and reconciliation commands |
| Create | `firebase/package-lock.json` | Reproducible Node dependency graph |
| Create | `firebase/tsconfig.json` | Strict TypeScript settings |
| Create | `firebase/src/authz.ts` | Shared server authorization predicates |
| Create | `firebase/src/index.ts` | Callable privileged operations |
| Create | `firebase/src/migrate.ts` | Idempotent canonical migration CLI |
| Create | `firebase/src/reconcile.ts` | Count/reference/decode reconciliation CLI |
| Create | `firebase/test/firestore.rules.test.ts` | Rule denial and allow tests |
| Create | `firebase/test/storage.rules.test.ts` | Storage authorization tests |
| Create | `firebase/test/functions.test.ts` | Trusted mutation/audit tests |
| Replace | `.github/workflows/ci.yml` | Current Xcode/SPM build and test matrix |
| Create | `.github/workflows/firebase-ci.yml` | Emulator and TypeScript checks |
| Create | `TMI/PrivacyInfo.xcprivacy` | Accurate required-reason API declaration |
| Create | `TMIUITests/SmokeUITests.swift` | App-launch and authentication smoke test |
| Modify | `TMI.xcodeproj/project.pbxproj` | Add the UI automation target |

## Task 1: Repair the executable test baseline

**Files:**
- Modify: `TMITests/Core/AccessibilityManagerTests.swift:446`

- [ ] **Step 1: Preserve the failing evidence**

Run:

```bash
xcodebuild test -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-Gate0-DerivedData \
  -resultBundlePath /tmp/TMI-Gate0-Red.xcresult
```

Hosted Keychain/SecureStorage tests require normal local signing so runtime entitlements remain embedded; simulator “Sign to Run Locally” does not require distribution credentials.

Expected: build fails at line 446 with `ambiguous use of 'init(_:)'`; zero tests execute.

- [ ] **Step 2: Qualify the intended SwiftUI initializer**

Replace the ambiguous construction with:

```swift
let contentSizeCategory: SwiftUI.ContentSizeCategory = .init(uiCategory)
```

The nonoptional contextual result selects TMI's non-failable mapping initializer over SwiftUI's failable overload.

- [ ] **Step 3: Re-run the full test suite**

Run the Step 1 command with result bundle `/tmp/TMI-Gate0-Green.xcresult`. Expected: the test bundle compiles and tests execute; record any behavioral failures as separate red tests before fixing them.

- [ ] **Step 4: Commit the baseline repair**

```bash
git add TMITests/Core/AccessibilityManagerTests.swift
git commit -m "test: repair accessibility test compilation"
```

## Task 2: Establish typed feature flags

**Files:**
- Create: `TMI/Core/Configuration/FeatureFlags.swift`
- Create: `TMI/Core/Dependencies/AppDependencies.swift`
- Create: `TMITests/Core/FeatureFlagsTests.swift`
- Modify: `TMI/App/TMIApp.swift`
- Modify: `TMI/Views/Authentication/RoleSelectionView.swift`

- [ ] **Step 1: Write failing production-default tests**

```swift
import Testing
@testable import TMI

struct FeatureFlagsTests {
    @Test func productionDisablesUnsupportedAccountsAndAI() {
        let flags = FeatureFlags.production
        #expect(flags.independentStudentAccounts == false)
        #expect(flags.guardianAccounts == false)
        #expect(flags.aiSuggestions == false)
        #expect(flags.institutionalSSO == false)
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run the Gate 0 test command with `-only-testing:TMITests/FeatureFlagsTests`. Expected: compile failure because `FeatureFlags` is missing.

- [ ] **Step 3: Implement immutable production flags**

```swift
struct FeatureFlags: Sendable, Equatable {
    let independentStudentAccounts: Bool
    let guardianAccounts: Bool
    let aiSuggestions: Bool
    let institutionalSSO: Bool

    static let production = FeatureFlags(
        independentStudentAccounts: false,
        guardianAccounts: false,
        aiSuggestions: false,
        institutionalSSO: false
    )
}
```

Create the minimal `AppDependencies` composition value with an immutable `flags` property and inject it through SwiftUI Environment at `TMIApp`; Task 10 expands this same value with repositories and adapters. Remove role-selection and root-routing branches for student, parent, and legal-guardian accounts unless the corresponding flag is true. Do not destroy stored legacy users.

- [ ] **Step 4: Re-run focused and navigation tests**

Expected: `FeatureFlagsTests`, `SimplifiedRegistrationViewTests`, and `MainTabViewTests` pass and no production route exposes disabled roles.

- [ ] **Step 5: Commit**

```bash
git add TMI/Core/Configuration/FeatureFlags.swift TMI/Core/Dependencies/AppDependencies.swift TMITests/Core/FeatureFlagsTests.swift TMI/App/TMIApp.swift TMI/Views/Authentication/RoleSelectionView.swift
git commit -m "feat: gate unsupported accounts and optional AI"
```

## Task 3: Define canonical authorization contracts

**Files:**
- Create: `TMI/Core/Authorization/Capability.swift`
- Create: `TMI/Core/Authorization/MembershipContext.swift`
- Create: `TMI/Core/Authorization/AuthorizationPolicy.swift`
- Create: `TMITests/Core/AuthorizationPolicyTests.swift`

- [ ] **Step 1: Write failing least-privilege tests**

```swift
@Test func administratorDetailRequiresExplicitPermission() {
    let member = MembershipContext.fixture(role: .schoolAdministrator, capabilities: [])
    #expect(!AuthorizationPolicy.canReadStudentDetail(member, student: .fixture()))
}

@Test func assignmentDoesNotGrantRestrictedRecordAccess() {
    let member = MembershipContext.fixture(role: .counselor, assignedStudentIDs: ["student-1"])
    #expect(!AuthorizationPolicy.canReadRestrictedRecord(member, studentID: "student-1"))
}

@Test func districtScopeNeverCrossesTenant() {
    let member = MembershipContext.fixture(districtID: "district-a", role: .districtAdministrator)
    #expect(!AuthorizationPolicy.canViewAggregate(member, districtID: "district-b"))
}
```

- [ ] **Step 2: Run and verify RED**

Expected: types do not exist.

- [ ] **Step 3: Implement the capability vocabulary**

```swift
enum Capability: String, Codable, Sendable, CaseIterable {
    case studentReadDetail = "student.read.detail"
    case studentWriteDetail = "student.write.detail"
    case studentRestrictedRead = "student.restricted.read"
    case studentRestrictedWrite = "student.restricted.write"
    case planApprove = "plan.approve"
    case staffManage = "staff.manage"
    case reportExport = "report.export"
    case auditRead = "audit.read"
}

enum StaffRole: String, Codable, Sendable {
    case teacher, counselor, socialWorker, schoolAdministrator, districtAdministrator
}

struct MembershipContext: Codable, Sendable, Equatable {
    let userID: String
    let districtID: String
    let schoolIDs: Set<String>
    let role: StaffRole
    let capabilities: Set<Capability>
    let assignedStudentIDs: Set<String>
    let isActive: Bool
    let version: Int
}
```

Implement pure policy methods matching the contract matrix. A school/district administrator needs `.studentReadDetail`; restricted records always need their dedicated capability; all operations require active membership and matching district.

- [ ] **Step 4: Run tests and verify GREEN**

Expected: all policy fixtures pass without Firebase.

- [ ] **Step 5: Commit**

```bash
git add TMI/Core/Authorization TMITests/Core/AuthorizationPolicyTests.swift
git commit -m "feat: define canonical authorization policy"
```

## Task 4A: Establish trusted membership and authenticated-session boundaries

This slice makes a profile-only authenticated state impossible. It does not yet
remove legacy profile fields because Task 4B first migrates every caller.

**Files:**
- Create: `TMI/Core/Authorization/TrustedTenantClaim.swift`
- Create: `TMI/Services/MembershipRepository.swift`
- Modify: `TMI/StateModels/AuthStateModel.swift`
- Modify: `TMITests/StateModels/AuthStateModelSignOutTests.swift`
- Create: `TMITests/Services/MembershipRepositoryTests.swift`
- Create: `TMITests/StateModels/AuthStateModelMembershipTests.swift`

- [ ] **Step 1: Freeze the trusted claim wire contract**

The server-managed Firebase custom-claim keys are:

```text
tmiDistrictID
tmiAccessClass
tmiMembershipVersion
```

All three claims are required. `tmiAccessClass` uses an explicit stable enum;
persistent educator sessions accept only the staff access class. Student Mode
and guardian respondent sessions receive separate access classes in Release 2
and never become staff memberships. Never fall back to editable profile fields
when a claim is missing or malformed.

```swift
struct TrustedTenantClaim: Sendable, Equatable {
    let userID: String
    let districtID: String
    let accessClass: TrustedAccessClass
    let membershipVersion: Int
}

struct AuthenticatedSession: Equatable {
    let profile: TMIUser
    let claim: TrustedTenantClaim
    let membership: MembershipContext
}
```

- [ ] **Step 2: Write failing repository and session tests**

Use actor-backed fakes and Swift Testing. Prove all of the following before
writing production code:

- A malicious profile role or district never changes trusted membership access.
- Missing, inactive, malformed, cross-tenant, claim-version-mismatched, or stale
  membership fails closed with no authenticated session.
- The repository reads exactly
  `districts/{districtID}/members/{userID}` from the server and never falls back
  to a cached membership while offline.
- Membership version 1 followed by version 2 refreshes policy state; version 2
  followed by version 1 is rejected.
- Sign-out during a suspended membership load prevents the late result from
  restoring authentication.
- A late result for user A cannot overwrite a newer authorization attempt for
  user B.
- Repeated `fetch()` calls install one auth listener, not several.
- Failed sign-out preserves the complete prior session; successful sign-out
  clears profile, claim, membership, and session state.

Run the signed focused suite and verify RED:

```bash
xcodebuild test -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-Gate0-DerivedData \
  -resultBundlePath /tmp/TMI-Gate0-Membership-Red.xcresult \
  -only-testing:TMITests/MembershipRepositoryTests \
  -only-testing:TMITests/AuthStateModelMembershipTests
```

Expected: missing trusted-claim, repository, authenticated-session, and adapter
contracts.

- [ ] **Step 3: Implement the server-only repository boundary**

`MembershipStore` returns a typed `Sendable` record rather than
`DocumentSnapshot` or `[String: Any]`. `FirebaseMembershipStore` owns Firebase
types and uses `getDocument(source: .server)`. Derive `userID` and `districtID`
from the trusted path arguments instead of duplicate document fields.

```swift
protocol MembershipProviding: Sendable {
    func membership(for claim: TrustedTenantClaim) async throws -> MembershipContext
}

actor MembershipRepository: MembershipProviding {
    private let store: any MembershipStore
    private var latestVersionByMember: [MemberKey: Int]
}
```

Require active membership, canonical role and capabilities, well-formed IDs,
positive version, exact claim/membership-version equality, and monotonic version
observation. Missing documents, offline server reads, cancellation, and decoding
failures deny access.

- [ ] **Step 4: Make trusted session publication atomic**

Change `AuthenticationState.authenticated` to carry `AuthenticatedSession`.
Expose compatibility profile access as `currentUser` and trusted access as
`currentMembership`; protected routing must key off the session/membership.

Load identity, claim, profile, and membership without publishing a partial
authenticated state. Publish them together only after all checks pass. Retain
and remove the Firebase auth-listener handle idempotently. Use a cancelable task
or monotonically increasing authorization generation so sign-out, account
switches, and repeated callbacks invalidate older work. Remove same-user
deduplication based only on profile ID because it suppresses membership-version
refreshes.

Use the same standard error for missing, inactive, malformed, stale, offline,
or mismatched access: “We couldn’t verify your organization access. Check your
connection and try again.” Do not disclose membership status.

- [ ] **Step 5: Verify, scan, and commit Task 4A**

Re-run the focused suite to
`/tmp/TMI-Gate0-Membership-Green.xcresult`, then run the full signed suite to
`/tmp/TMI-Gate0-Membership-Full.xcresult`. Expected: zero failures; only the five
documented environment skips may remain.

```bash
git diff --check
git add TMI/Core/Authorization/TrustedTenantClaim.swift TMI/Services/MembershipRepository.swift TMI/StateModels/AuthStateModel.swift TMITests/StateModels/AuthStateModelSignOutTests.swift TMITests/Services/MembershipRepositoryTests.swift TMITests/StateModels/AuthStateModelMembershipTests.swift
git commit -m "feat: derive sessions from trusted memberships"
```

Expected: the authenticated-session boundary is green. The legacy RBAC surface
remains only until its callers are migrated atomically in Task 4B; Task 4A is
not a releasable checkpoint.

## Task 4B: Purge editable profile authorization from callers and writes

Task 4 is not complete until no UI, service, bootstrap, or registration path
authorizes from the editable `users/{uid}` profile.

**Primary files:**
- Modify: `TMI/Models/TMIUser.swift`
- Modify: `TMI/App/TMIApp.swift`
- Modify: `TMI/Core/AppBootstrapService.swift`
- Modify: `TMI/Core/Security/SecurityConfig.swift`
- Replace: `TMI/Services/RBACService.swift`
- Modify: `TMI/Services/AuthenticationService.swift`
- Modify: `TMI/Services/FirebaseManager.swift`
- Modify: `TMI/Services/StudentService.swift`
- Modify: `TMI/Services/TMIPlanService.swift`
- Modify: `TMI/Services/FormAssignmentService.swift`
- Modify: `TMI/Views/MainTabView.swift`
- Modify: `TMI/Views/Dashboard/DashboardView.swift`
- Modify: `TMI/Views/District/DistrictDashboardView.swift`
- Modify: `TMI/Views/Settings/SettingsView.swift`
- Modify: `TMI/Views/Students/StudentListView.swift`
- Modify: `TMI/Views/TMIPlans/PlanTemplateLibraryView.swift`
- Modify: `TMI/Views/Forms/Templates/FormTemplateLibraryView.swift`
- Modify: `TMI/Views/Forms/FormAssignmentCreateView.swift`
- Modify: `TMI/Views/Forms/Assignments/AssignmentCreationView.swift`
- Replace: `TMITests/Services/RBACServiceTests.swift`
- Modify or create focused tests beside each changed authority boundary

- [ ] **Step 1: Write failing authority-source and regression tests**

Prove routing, tabs, district bootstrap, dashboard visibility, mutation
authorization, plan approval, form assignment, template scope, and student
archive/delete decisions consume `MembershipContext` and typed target scopes.
Include a malicious administrator profile paired with a teacher membership; it
must receive only teacher access. Student deletion remains denied until the
retention-safe archive/delete contract exists.

- [ ] **Step 2: Migrate every authority reader**

Use `currentMembership.role`, capabilities, schools, assigned students, and
`AuthorizationPolicy`; never translate membership back into `UserRole`. Services
receive trusted membership/typed scope through initializer or method arguments
and never fetch `users/{uid}` to authorize. Bind target district/school/student
scope from canonical records or repository paths, never from caller-created
labels.

Replace `RBACService` in the same commit as its callers. Keep it only as a
temporary stateless adapter over `AuthorizationPolicy`, accepting
`MembershipContext` plus typed target scope. Remove its singleton, nested broad
permission enum, `TMIUser`/`UserRole` overloads, and every `UserRole.can...`
extension. Unsupported legacy operations deny until a typed target contract
exists.

- [ ] **Step 3: Remove authorization writes from personal profiles**

Registration and profile updates must not persist `role`, `permissions`,
`dataClassificationAccess`, `districtId`, `schoolId`, institution authority, or
activation state. A non-authoritative `requestedRole` may remain solely for the
trusted provisioning workflow. Server functions own claim and membership
mutations.

After callers migrate, reduce `TMIUser` to personal profile/preferences. Decode
old authorization keys only in a migration-only `LegacyUserAuthorizationRecord`;
do not re-encode them. Remove `TMIUser.hasPermission`,
`canAccessSensitiveData`, `canManageUserData`, `UserRole.defaultPermissions`,
and `UserRole.defaultDataAccess`.

- [ ] **Step 4: Prove the purge is complete**

```bash
rg -n 'authStateModel\.currentUser\?\.(role|districtId|schoolId)|authStateModel\.currentUser\.(role|districtId|schoolId)' TMI
rg -n 'RBACService\.shared|requirePermission\([^,]+, user:|hasPermission\([^,]+, (user|role):' TMI
rg -n 'role\.defaultPermissions|role\.defaultDataAccess|defaultPermissions|defaultDataAccess|canAccessSensitiveData|canManageUserData' TMI
rg -n '"(role|permissions|dataClassificationAccess|districtId|schoolId|institutionID|isActive)"' TMI/Services/AuthenticationService.swift TMI/Services/FirebaseManager.swift
```

Expected: zero authorizing profile reads, zero permissive legacy RBAC calls, zero
default role-derived permissions, and zero registration/profile writes of
authority fields. Migration-only decoder matches must live under
`TMI/Migration/` and be explicitly allowlisted.

- [ ] **Step 5: Verify and commit Task 4B**

Run affected focused suites to
`/tmp/TMI-Gate0-Authority-Purge-Green.xcresult`, then the full signed suite to
`/tmp/TMI-Gate0-Authority-Purge-Full.xcresult`. Expected: zero failures; only the
five documented environment skips may remain.

```bash
git diff --check
git add TMI TMITests
git commit -m "refactor: purge editable profile authorization"
```

## Task 5: Lock the canonical schema and path builder

**Files:**
- Create: `TMI/Core/Data/CanonicalRecordMetadata.swift`
- Replace: `TMI/Services/FirestorePaths.swift`
- Create: `TMI/Migration/LegacyFirestorePaths.swift`
- Replace: `TMITests/Services/FirestorePathsTests.swift`

- [ ] **Step 1: Write exact path tests**

```swift
@Test func canonicalStudentPathsAreTenantScoped() {
    #expect(FirestorePaths.students(districtID: "d1") == "districts/d1/students")
    #expect(FirestorePaths.student(districtID: "d1", studentID: "s1") == "districts/d1/students/s1")
    #expect(FirestorePaths.studentInterests(districtID: "d1", studentID: "s1") == "districts/d1/students/s1/interests")
}

@Test func legacyWriterPathsAreAbsent() {
    let names = FirestorePaths.productionCollectionTemplates
    #expect(!names.contains("users/{uid}/students"))
    #expect(!names.contains("students/{studentId}/studentInterests"))
    #expect(!names.contains("plans/{planId}"))
}
```

- [ ] **Step 2: Implement canonical metadata and paths**

```swift
struct CanonicalRecordMetadata: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let recordVersion: Int
    let createdAt: Date
    let createdBy: String
    let updatedAt: Date
    let updatedBy: String
}
```

Expose only the district tree and five catalog names from the contract. Put legacy read paths in a separate `LegacyFirestorePaths` file under `TMI/Migration/`; production repositories must not import it.

- [ ] **Step 3: Run path tests and search for direct legacy access**

```bash
rg -n 'users/.*/(students|tmiPlans)|collection\("students"\)|collection\("plans"\)' TMI
```

Expected: every match is recorded in the migration manifest for its owning release; no new writer uses it.

- [ ] **Step 4: Commit**

```bash
git add TMI/Core/Data TMI/Services/FirestorePaths.swift TMI/Migration TMITests/Services/FirestorePathsTests.swift
git commit -m "feat: lock canonical data paths"
```

## Task 6: Add Firebase Emulator infrastructure and deny-by-default rules

**Files:**
- Create: `firebase.json`
- Create: `firestore.indexes.json`
- Replace: `firestore.rules`
- Create: `storage.rules`
- Create: `firebase/package.json`
- Create: `firebase/tsconfig.json`
- Create: `firebase/src/authz.ts`
- Create: `firebase/src/index.ts`
- Create: `firebase/test/firestore.rules.test.ts`
- Create: `firebase/test/storage.rules.test.ts`
- Create: `firebase/test/functions.test.ts`

- [ ] **Step 1: Initialize a reproducible test package**

Use Node 22 and pin `firebase-tools`, `@firebase/rules-unit-testing`, `firebase-admin`, `firebase-functions`, `typescript`, and `vitest`. Define scripts `build`, `lint`, `test`, `emulators`, `migrate:dry-run`, and `reconcile`; every script uses project `demo-tmi` for tests.

- [ ] **Step 2: Write failing self-promotion and cross-tenant rule tests**

```typescript
it("denies changing protected profile fields", async () => {
  const db = testEnv.authenticatedContext("teacher-1", { districtId: "d1" }).firestore();
  await assertFails(setDoc(doc(db, "users/teacher-1"), { role: "districtAdministrator" }, { merge: true }));
});

it("denies cross-district student reads", async () => {
  const db = testEnv.authenticatedContext("teacher-1", { districtId: "d1" }).firestore();
  await assertFails(getDoc(doc(db, "districts/d2/students/student-2")));
});
```

Also cover inactive membership, unassigned student, restricted record, admin aggregate access, explicit admin drill-down, client audit writes, catalog reads, Storage cross-tenant reads, and unauthorized exports.

- [ ] **Step 3: Replace rules with trusted membership checks**

Rules read membership from `districts/{districtId}/members/{uid}` and compare its active state, school IDs, assignments, and capabilities. User writes allow only `displayName`, personal preferences, and profile-photo metadata. Deny all unmatched documents. Client writes to `auditEvents`, `metricSnapshots`, membership, role, permission, retention, approval, and export records are false.

- [ ] **Step 4: Implement privileged callable functions**

Expose typed callables for membership mutation, audited student-detail access grants, plan transitions, Student Mode session issuance, deletion cleanup, sensitive exports, and audit events. Each callable validates Auth, App Check, district, membership version, capability, record version, and idempotency key before a transaction.

- [ ] **Step 5: Run emulator tests**

```bash
npm --prefix firebase ci
npm --prefix firebase test
```

Expected: TypeScript compiles strictly and all allow/deny tests pass.

- [ ] **Step 6: Commit**

```bash
git add firebase.json firestore.rules firestore.indexes.json storage.rules firebase
git commit -m "feat: enforce trusted Firebase authorization"
```

## Task 7: Add idempotent migration and reconciliation tools

**Files:**
- Create: `firebase/src/migrate.ts`
- Create: `firebase/src/reconcile.ts`
- Create: `firebase/src/migrationManifest.ts`
- Create: `firebase/test/migration.test.ts`
- Create: `firebase/fixtures/gate0.json`

- [ ] **Step 1: Write failing dry-run/idempotency tests**

Test legacy user-scoped students/plans, top-level students/plans, unresolved tenant ownership, stable IDs, second-run no-op, and forward-only rollback behavior.

- [ ] **Step 2: Define manifest contracts**

```typescript
export type MigrationManifest = {
  id: string;
  sourcePath: string;
  destinationPath: string;
  schemaVersion: number;
  ownerResolution: "mapped" | "quarantine";
  checksum: string;
};
```

Every migrated document records `migrationId`, `legacyPath`, `legacyId`, and checksum. Ownership that cannot be proven writes to `migrationQuarantine` and never enters a tenant collection.

- [ ] **Step 3: Implement dry-run, apply, and reconcile modes**

Dry-run emits a JSON write plan without mutations. Apply uses stable IDs and preconditions. Reconcile verifies counts, IDs, tenant ownership, references, required fields, and decoded equality. Re-running apply produces zero writes.

- [ ] **Step 4: Run migration tests**

```bash
npm --prefix firebase run test -- migration.test.ts
npm --prefix firebase run migrate:dry-run -- --project demo-tmi --fixture firebase/fixtures/gate0.json
npm --prefix firebase run reconcile -- --project demo-tmi --fixture firebase/fixtures/gate0.json
```

Expected: tests pass; reconciliation reports zero mismatches.

- [ ] **Step 5: Commit**

```bash
git add firebase/src/migrate.ts firebase/src/reconcile.ts firebase/src/migrationManifest.ts firebase/test/migration.test.ts firebase/fixtures/gate0.json
git commit -m "feat: add canonical migration tooling"
```

## Task 8: Implement retention-safe reachable account deletion

**Files:**
- Create: `TMI/Services/AccountDeletionService.swift`
- Modify: `TMI/Services/AuthenticationService.swift`
- Modify: `TMI/Views/User/UserProfileView.swift`
- Modify: `TMI/Views/Settings/DeleteAccountView.swift`
- Replace: `TMITests/Services/AccountDeletionTests.swift`

- [ ] **Step 1: Execute the approved deletion plan exactly**

Complete every red/green/refactor task in `docs/superpowers/plans/2026-07-19-account-deletion-review-remediation.md`. The policy must preserve institutional students, plans, forms, meetings, consents, and audit data; delete personal profile/preferences/activity; reauthenticate first; delete Firebase Auth last; and expose `Profile -> Delete Account`.

- [ ] **Step 2: Add a trusted cleanup function test**

Prove the callable is idempotent, refuses a mismatched UID, records a deidentified former-user attribution, and never deletes canonical institution-owned paths.

- [ ] **Step 3: Run the complete deletion suite**

Expected: Swift orchestration/UI tests and Firebase function tests pass.

- [ ] **Step 4: Commit**

```bash
git add TMI/Services/AccountDeletionService.swift TMI/Services/AuthenticationService.swift TMI/Views/User/UserProfileView.swift TMI/Views/Settings/DeleteAccountView.swift TMITests/Services/AccountDeletionTests.swift firebase
git commit -m "feat: make account deletion retention safe"
```

## Task 9: Install Aubergine + Teal foundation tokens

**Files:**
- Create: `TMI/Core/DesignSystem/TMIColors.swift`
- Modify: `TMI/Core/DesignSystem/TMIDesignTokens.swift`
- Create: `TMITests/Core/TMIColorsTests.swift`
- Modify: `TMI/App/TMIApp.swift`

- [ ] **Step 1: Write failing exact-token tests**

Assert the sRGB values for background `F7F6FA`, surface `FFFFFF`, text `1F1A24`, secondary `514A57`, border `C7C0CF`, aubergine `5B2A5B`, teal `0F766E`, and semantic pairs. Assert white/aubergine and white/teal contrast meet WCAG AA.

- [ ] **Step 2: Implement semantic tokens**

```swift
enum TMIColors {
    static let background = Color(hex: "#F7F6FA")
    static let surface = Color(hex: "#FFFFFF")
    static let textPrimary = Color(hex: "#1F1A24")
    static let textSecondary = Color(hex: "#514A57")
    static let border = Color(hex: "#C7C0CF")
    static let aubergine = Color(hex: "#5B2A5B")
    static let teal = Color(hex: "#0F766E")
    static let aubergineSoft = Color(hex: "#EDE1ED")
}
```

Add semantic success/warning/error/info surface and text pairs. Keep `.preferredColorScheme(.light)` and remove the user-facing dark-mode setting. New UI may use only semantic tokens.

- [ ] **Step 3: Run token and WCAG tests**

Expected: exact-value and contrast tests pass.

- [ ] **Step 4: Commit**

```bash
git add TMI/Core/DesignSystem/TMIColors.swift TMI/Core/DesignSystem/TMIDesignTokens.swift TMI/App/TMIApp.swift TMITests/Core/TMIColorsTests.swift
git commit -m "feat: establish Aubergine and Teal tokens"
```

## Task 10: Create the injected composition root and eliminate production fabrication

**Files:**
- Modify: `TMI/Core/Dependencies/AppDependencies.swift`
- Modify: `TMI/App/TMIApp.swift`
- Modify: `TMI/Services/FirebaseManager.swift`
- Modify: `TMI/Utilities/SampleDataSeeder.swift`
- Modify: `TMI/Core/Logging/TMILogger.swift`
- Create: `TMITests/Core/AppDependenciesTests.swift`

- [ ] **Step 1: Write failing dependency tests**

Verify production dependencies use Firebase adapters, preview dependencies use in-memory fixtures, and a repository failure returns an honest error/empty state rather than sample records.

- [ ] **Step 2: Implement the composition root**

```swift
@MainActor
struct AppDependencies {
    let flags: FeatureFlags
    let membership: any MembershipProviding
    let logger: TMILogger

    static func production() -> AppDependencies {
        AppDependencies(
            flags: .production,
            membership: MembershipRepository(store: FirebaseMembershipStore()),
            logger: TMILogger.production
        )
    }
}
```

Extend this value as each release adds repositories. Inject through Environment at `TMIApp`; do not add new globals or singletons. Move sample seeding behind `#if DEBUG` and an explicit preview/developer action unavailable in production.

- [ ] **Step 3: Replace raw logging in Gate 0 paths**

Use `Logger` privacy interpolation and stable non-PII IDs. Delete prints in `TMIApp`, `MainTabView`, authentication, Firebase configuration, and account deletion. Never log student names, survey text, notes, or plan content.

- [ ] **Step 4: Run tests and production-string scans**

Expected: dependency tests pass; a Release build contains no sample students and no raw Gate 0 prints.

- [ ] **Step 5: Commit**

```bash
git add TMI/Core/Dependencies TMI/App/TMIApp.swift TMI/Services/FirebaseManager.swift TMI/Utilities/SampleDataSeeder.swift TMI/Core/Logging/TMILogger.swift TMITests/Core/AppDependenciesTests.swift
git commit -m "refactor: inject production dependencies"
```

## Task 11: Migrate to Swift 6.2 strict concurrency

**Files:**
- Modify: `TMI.xcodeproj/project.pbxproj`
- Modify: compiler-reported Swift files only
- Modify: affected tests alongside each production fix

- [ ] **Step 1: Capture the Swift 6 error inventory**

Set `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, and `SWIFT_APPROACHABLE_CONCURRENCY = YES` for app and tests, then build iOS and macOS. Save compiler diagnostics to `docs/release-evidence/gate-0-swift6-errors.txt`.

- [ ] **Step 2: Fix global actor defaults**

Replace global service constants and `.shared` environment defaults with injected dependencies. UI-facing observable types become `@MainActor`; background mutable services become actors. Do not silence errors with `@unchecked Sendable`, `nonisolated(unsafe)`, or `@preconcurrency` unless a test demonstrates the external framework boundary and the reason is documented inline.

- [ ] **Step 3: Fix Firestore model sendability**

Keep Firestore DTOs actor-confined or map them to Sendable domain values before crossing isolation. Remove unjustified `@unchecked Sendable` from `Student`, `TMIPlan`, `TMIUser`, notifications, and plan evidence/input models.

- [ ] **Step 4: Run builds until clean**

Run the two platform build commands from the program gate. Expected: both succeed with no diagnostics described as Swift 6 errors.

- [ ] **Step 5: Run the full suite**

Expected: all tests pass under the Swift 6 setting.

- [ ] **Step 6: Commit**

```bash
git add TMI.xcodeproj TMI TMITests docs/release-evidence/gate-0-swift6-errors.txt
git commit -m "build: enable Swift 6 strict concurrency"
```

## Task 12: Replace stale CI and add privacy configuration

**Files:**
- Replace: `.github/workflows/ci.yml`
- Create: `.github/workflows/firebase-ci.yml`
- Create: `TMI/PrivacyInfo.xcprivacy`
- Create: `TMIUITests/SmokeUITests.swift`
- Modify: `TMI.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create a real UI automation target**

Add `TMIUITests` as a multiplatform UI Testing Bundle for iOS/iPadOS/macOS that depends on `TMI`, uses Swift 6, and is included in the shared `TMI` scheme test action. Add a smoke test that launches with `-uiTesting -fixture signed-out` and asserts the sign-in screen appears. The app maps those arguments to in-memory test dependencies only in debug/UI-testing builds.

- [ ] **Step 2: Replace obsolete workspace/CocoaPods jobs**

Use the checked-in project, Swift Package Manager, current Xcode, iPhone 17 Pro/iPad Pro 13-inch simulators, macOS, cached SourcePackages, and result bundles. Do not reference a nonexistent workspace, UI target, or test plan.

- [ ] **Step 3: Add Firebase CI**

Install Java and Node 22, run `npm ci`, strict TypeScript build, and Emulator tests using `demo-tmi`.

- [ ] **Step 4: Add and audit the privacy manifest**

Declare only APIs actually used by the compiled app. Compare the generated archive privacy report with `PrivacyInfo.xcprivacy`; remove unused declarations and add missing required reasons before commit.

- [ ] **Step 5: Run workflow-equivalent commands locally**

Expected: iOS/macOS builds, Swift tests, TypeScript build, and Emulator tests pass.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows TMI/PrivacyInfo.xcprivacy TMIUITests/SmokeUITests.swift TMI.xcodeproj/project.pbxproj
git commit -m "ci: enforce canonical release checks"
```

## Task 13: Gate 0 acceptance

**Files:**
- Create: `docs/release-evidence/gate-0.md`

- [ ] **Step 1: Run the universal release gate**

Use `docs/superpowers/plans/2026-07-20-tmi-final-product-program-implementation.md`. Expected: all checks pass, including iOS/macOS builds, full Swift tests, emulator tests, migration reconciliation, and logging/sample scans.

- [ ] **Step 2: Record the evidence**

Document exact commands, commit SHA, Xcode/Swift versions, test counts, rule-test counts, migration fixture checksum, zero-mismatch reconciliation, known non-blocking warnings, and links to result bundles. Do not include credentials or student PII.

- [ ] **Step 3: Commit and tag**

```bash
git add docs/release-evidence/gate-0.md
git commit -m "docs: record Gate 0 acceptance"
git tag -a tmi-gate-0-accepted -m "TMI Gate 0 accepted"
```

Expected: the branch is clean and the annotated tag points at the evidence commit.
