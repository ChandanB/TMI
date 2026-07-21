# TMI Release 1 Secure Roster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let verified staff authenticate, enter a canonical cross-platform shell, and manage only the students within their assigned scope.

**Architecture:** Build the first complete vertical slice on Gate 0 contracts. A `StudentRepository` owns canonical roster access; pure validation and duplicate-detection policies are shared by create/edit flows; a typed router owns navigation; every mutation carries tenant context, capability, record version, and idempotency key.

**Tech Stack:** Swift 6.2, SwiftUI, Observation, Swift Testing, Firebase Auth/Firestore/Functions, Firebase Emulator Suite, LocalAuthentication

---

## File map

| Action | Path | Responsibility |
|---|---|---|
| Create | `TMI/Features/Authentication/AuthSession.swift` | Identity, verified membership, and auth state |
| Create | `TMI/Features/Authentication/AuthenticationRepository.swift` | Email/password, reset, verification, refresh, reauth |
| Create | `TMI/Features/Authentication/MFARepository.swift` | TOTP enrollment and privileged-session challenge |
| Create | `TMI/Features/Authentication/InstitutionalSSOProvider.swift` | Disabled SSO integration boundary |
| Modify | `TMI/Views/Authentication/AuthenticationView.swift` | Canonical sign-in flow |
| Modify | `TMI/Views/Authentication/SimplifiedRegistrationView.swift` | Invitation-based staff registration |
| Create | `TMI/Features/Navigation/AppRoute.swift` | Typed tabs, destinations, sheets, and deep links |
| Create | `TMI/Features/Navigation/AppRouter.swift` | Paths and active-student context |
| Replace | `TMI/Views/MainTabView.swift` | Adaptive staff shell |
| Create | `TMI/Features/Students/StudentRecord.swift` | Canonical roster aggregate |
| Create | `TMI/Features/Students/StudentDraft.swift` | Normalized create/edit input |
| Create | `TMI/Features/Students/StudentRepository.swift` | Assigned roster CRUD/archive/pagination |
| Create | `TMI/Features/Students/StudentValidation.swift` | Required fields and normalization |
| Create | `TMI/Features/Students/StudentDuplicatePolicy.swift` | Deterministic duplicate candidates |
| Replace | `TMI/Views/Students/StudentListView.swift` | Search/filter/sort/pagination roster |
| Replace | `TMI/Views/Students/StudentDetailView.swift` | Operational student hub shell |
| Create | `TMI/Features/Students/StudentEditorView.swift` | Shared create/edit form |
| Modify | `TMI/Views/Dashboard/DashboardView.swift` | Purposeful first-student empty state |
| Create | `TMITests/Features/Authentication/AuthSessionTests.swift` | Verification and membership gating |
| Create | `TMITests/Features/Navigation/AppRouterTests.swift` | Typed navigation and stale-context denial |
| Create | `TMITests/Features/Students/StudentRepositoryTests.swift` | CRUD, scope, pagination, idempotency |
| Create | `TMITests/Features/Students/StudentValidationTests.swift` | Normalization and duplicates |
| Create | `TMITests/Features/Students/StudentListStateTests.swift` | Honest UI states and filtering |
| Create | `firebase/test/students.test.ts` | Server and rules enforcement |
| Create | `firebase/fixtures/release1.json` | Legacy roster migration fixture |

## Task 1: Implement verified staff authentication

**Files:**
- Create: `TMI/Features/Authentication/AuthSession.swift`
- Create: `TMI/Features/Authentication/AuthenticationRepository.swift`
- Modify: `TMI/Views/Authentication/AuthenticationView.swift`
- Modify: `TMI/Views/Authentication/SimplifiedRegistrationView.swift`
- Create: `TMITests/Features/Authentication/AuthSessionTests.swift`

- [x] **Step 1: Write failing access-state tests**

```swift
@Test func unverifiedEmailCannotEnterStudentRecords() {
    let session = AuthSession(identity: .fixture(emailVerified: false), membership: .fixture())
    #expect(session.access == .emailVerificationRequired)
}

@Test func activeVerifiedMemberCanEnter() {
    let session = AuthSession(identity: .fixture(emailVerified: true), membership: .fixture(isActive: true))
    #expect(session.access == .authorized)
}
```

Also test missing invitation, inactive membership, tenant mismatch, token refresh failure, and registration rollback after provisioning failure.

- [x] **Step 2: Run tests and verify RED**

Expected: `AuthSession` and repository contracts are missing.

- [x] **Step 3: Implement the auth contract**

```swift
enum AppAccessState: Sendable, Equatable {
    case signedOut
    case emailVerificationRequired
    case membershipRequired
    case membershipInactive
    case authorized
}

struct AuthSession: Sendable, Equatable {
    let identity: AuthIdentity?
    let membership: MembershipContext?
    var access: AppAccessState {
        guard let identity else { return .signedOut }
        guard identity.isEmailVerified else { return .emailVerificationRequired }
        guard let membership else { return .membershipRequired }
        guard membership.isActive else { return .membershipInactive }
        return .authorized
    }
}

protocol AuthenticationProviding: Sendable {
    func signIn(email: String, password: String) async throws -> AuthSession
    func register(_ request: StaffRegistrationRequest) async throws -> AuthSession
    func sendPasswordReset(email: String) async throws
    func sendVerification() async throws
    func refresh() async throws -> AuthSession
    func reauthenticate(password: String) async throws
    func signOut() async throws
}
```

The Firebase adapter provisions membership only through the invitation callable. If profile or membership creation fails irrecoverably, delete the new Auth account before reporting failure.

- [x] **Step 4: Implement administrator TOTP MFA**

Create `MFARepository` methods `enrollTOTP()`, `confirmEnrollment(code:)`, `challenge(code:)`, and `unenroll(factorID:)`. School and district administrators must enroll before privileged access and complete a current challenge before staff management, retention, audit, drill-down, or sensitive export. Write tests for invalid/expired/replayed codes, recovery after sign-out, role promotion requiring enrollment, role demotion retaining but not requiring the factor, and recent-auth failure.

- [x] **Step 5: Add the disabled institutional SSO seam**

```swift
protocol InstitutionalSSOProvider: Sendable {
    func beginSignIn(configurationID: String) async throws -> AuthSession
}
```

Inject no production implementation and expose no SSO control while `FeatureFlags.production.institutionalSSO` is false. A missing provider must resolve to `.unavailable`, never a partial web flow.

- [x] **Step 6: Replace the visible flows**

Registration collects professional role request and invitation code, verifies email, records privacy/acceptable-use document versions, then creates preferences. Hide student/guardian roles and SSO. Error messages preserve entered non-secret fields and never reveal whether another user's email exists.

- [x] **Step 7: Run focused tests and commit**

```bash
git add TMI/Features/Authentication TMI/Views/Authentication TMITests/Features/Authentication
git commit -m "feat: require verified staff membership"
```

Expected: focused tests pass.

## Task 2: Implement the typed adaptive router

**Files:**
- Create: `TMI/Features/Navigation/AppRoute.swift`
- Create: `TMI/Features/Navigation/AppRouter.swift`
- Replace: `TMI/Views/MainTabView.swift`
- Modify: `TMI/Core/DeepLinkRouter.swift`
- Create: `TMITests/Features/Navigation/AppRouterTests.swift`

- [ ] **Step 1: Write failing route tests**

```swift
@Test func districtTabRequiresDistrictRole() {
    let router = AppRouter(policy: .fixture(role: .teacher))
    #expect(router.availableTabs == [.dashboard, .students, .plans])
}

@Test func staleStudentContextBlocksMutationRoute() {
    var router = AppRouter(policy: .fixture(role: .teacher))
    router.activeStudentID = "student-a"
    #expect(throws: NavigationError.staleStudentContext) {
        try router.open(.editStudent("student-b"))
    }
}
```

- [ ] **Step 2: Implement route values**

```swift
enum AppTab: Hashable, Sendable { case dashboard, students, plans, district }
enum AppRoute: Hashable, Sendable {
    case student(String)
    case editStudent(String)
    case plan(String)
    case profile
    case settings
}

@MainActor @Observable
final class AppRouter {
    var selectedTab: AppTab = .dashboard
    var path: [AppRoute] = []
    var activeStudentID: String?
    // policy-backed open and deep-link validation
}
```

Use `TabView(.sidebarAdaptable)` on iPhone/iPad and `NavigationSplitView` with commands/keyboard shortcuts on macOS. The account menu owns Profile and Settings. Student/plan mutations show the active student's name.

- [ ] **Step 3: Remove competing navigation state**

Migrate supported routes from `DeepLinkRouter`, `NavigationManager`, per-tab `NavigationPath` values, and student context caches into `AppRouter`. Delete an obsolete coordinator only after `rg` proves no production caller remains.

- [ ] **Step 4: Run navigation tests and commit**

```bash
git add TMI/Features/Navigation TMI/Views/MainTabView.swift TMI/Core/DeepLinkRouter.swift TMITests/Features/Navigation
git commit -m "refactor: centralize typed app navigation"
```

## Task 3: Define the canonical student aggregate

**Files:**
- Create: `TMI/Features/Students/StudentRecord.swift`
- Create: `TMI/Features/Students/StudentDraft.swift`
- Create: `TMI/Features/Students/StudentValidation.swift`
- Create: `TMI/Features/Students/StudentDuplicatePolicy.swift`
- Create: `TMITests/Features/Students/StudentValidationTests.swift`

- [ ] **Step 1: Write failing validation tests**

Test trimmed/collapsed names, normalized institutional IDs, required district/school/grade, future birth date, allowed pronoun length, and duplicate matching within the same school.

```swift
@Test func duplicateUsesSchoolNameGradeAndIdentifier() {
    let draft = StudentDraft.fixture(displayName: "  Ava  Stone ", grade: "7", studentIdentifier: " 0012 ")
    let existing = StudentRecord.fixture(displayName: "Ava Stone", grade: "7", studentIdentifier: "0012")
    #expect(StudentDuplicatePolicy.candidates(for: draft, in: [existing]) == [existing.id])
}
```

- [ ] **Step 2: Implement focused values**

```swift
struct StudentRecord: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let districtID: String
    let schoolID: String
    var displayName: String
    var grade: String
    var studentIdentifier: String?
    var assignedMemberIDs: Set<String>
    var isArchived: Bool
    var metadata: CanonicalRecordMetadata
}

struct StudentDraft: Sendable, Equatable {
    var displayName: String
    var schoolID: String
    var grade: String
    var studentIdentifier: String?
    var dateOfBirth: Date?
    var pronouns: String?
    var assignedMemberIDs: Set<String>
}
```

Keep photo, guardian references, cohort tags, and support-note references in focused relationship/metadata files rather than expanding this aggregate with embedded records.

- [ ] **Step 3: Run validation tests and commit**

```bash
git add TMI/Features/Students/StudentRecord.swift TMI/Features/Students/StudentDraft.swift TMI/Features/Students/StudentValidation.swift TMI/Features/Students/StudentDuplicatePolicy.swift TMITests/Features/Students/StudentValidationTests.swift
git commit -m "feat: define canonical student records"
```

## Task 4: Implement assigned-scope roster persistence

**Files:**
- Create: `TMI/Features/Students/StudentRepository.swift`
- Modify: `firebase/src/index.ts`
- Create: `TMITests/Features/Students/StudentRepositoryTests.swift`
- Create: `firebase/test/students.test.ts`

- [ ] **Step 1: Write failing repository tests**

Cover first page/next page of 50, search by normalized name/identifier, school/grade/member/status filters, create idempotency, version-conflict edit, archive, duplicate result, assignment scope, permission revocation, offline queued draft, and online-required archive.

```swift
protocol StudentRepository: Sendable {
    func page(_ request: StudentPageRequest, member: MembershipContext) async throws -> StudentPage
    func student(id: String, member: MembershipContext) async throws -> StudentRecord
    func create(_ draft: StudentDraft, operationID: UUID, member: MembershipContext) async throws -> StudentRecord
    func update(id: String, draft: StudentDraft, expectedVersion: Int, operationID: UUID, member: MembershipContext) async throws -> StudentRecord
    func archive(id: String, expectedVersion: Int, operationID: UUID, member: MembershipContext) async throws
}
```

- [ ] **Step 2: Implement Firestore reads and trusted writes**

Reads query `districts/{districtId}/students`, constrained by membership assignments and approved filters. Create/update/archive call trusted functions; functions revalidate capability, duplicate candidates, version, assignment, and operation ID in a transaction and write an authoritative audit event.

- [ ] **Step 3: Run Swift and emulator tests**

Expected: cross-tenant, unassigned, self-promoted, duplicate, stale-version, and replayed operations behave exactly as tests specify.

- [ ] **Step 4: Commit**

```bash
git add TMI/Features/Students/StudentRepository.swift TMITests/Features/Students/StudentRepositoryTests.swift firebase/src/index.ts firebase/test/students.test.ts
git commit -m "feat: add assigned-scope student repository"
```

## Task 5: Build the roster and shared editor

**Files:**
- Replace: `TMI/Views/Students/StudentListView.swift`
- Create: `TMI/Features/Students/StudentListState.swift`
- Create: `TMI/Features/Students/StudentEditorView.swift`
- Create: `TMITests/Features/Students/StudentListStateTests.swift`
- Create: `TMIUITests/StudentRosterUITests.swift`

- [ ] **Step 1: Write failing state tests**

Test loading, empty, populated, refreshing, offline-cache, permission-denied, recoverable error, search debounce, filters, sort, next-page loading, disabled double-submit, preserved draft after failure, and success only after repository confirmation.

- [ ] **Step 2: Implement observable state**

```swift
@MainActor @Observable
final class StudentListState {
    enum Phase: Equatable { case idle, loading, loaded, empty, offline, permissionDenied, failed(String) }
    var phase: Phase = .idle
    var students: [StudentRecord] = []
    var query = StudentPageRequest.first
    var isSubmitting = false
    // repository-backed load, refresh, paginate, create, update, archive
}
```

- [ ] **Step 3: Build adaptive roster UI**

Use `List` at compact widths and an adaptive `LazyVGrid` where it materially improves scanning. Add `.searchable`, filter sheet, sort menu, accessible bulk assignment for authorized users, pull-to-refresh, honest states, and 44-point controls. Use Aubergine + Teal semantic components only.

- [ ] **Step 4: Build shared create/edit form**

Normalize before validation, show field-level errors, surface duplicate candidates before creation, preserve state on recoverable failure, disable duplicate submission, and announce confirmed success to VoiceOver.

- [ ] **Step 5: Run state/UI tests and commit**

```bash
git add TMI/Views/Students/StudentListView.swift TMI/Features/Students/StudentListState.swift TMI/Features/Students/StudentEditorView.swift TMITests/Features/Students/StudentListStateTests.swift TMIUITests/StudentRosterUITests.swift
git commit -m "feat: deliver secure student roster"
```

## Task 6: Build the student operational hub shell

**Files:**
- Replace: `TMI/Views/Students/StudentDetailView.swift`
- Create: `TMI/Features/Students/StudentDetailState.swift`
- Create: `TMI/Features/Students/StudentHeaderView.swift`
- Create: `TMI/Features/Students/StudentTimelineView.swift`
- Create: `TMITests/Features/Students/StudentDetailStateTests.swift`

- [ ] **Step 1: Write failing projection tests**

Test header projection, permission-backed menu actions, separate private notes/student reflections queries, purposeful current/history empty sections derived from empty canonical collections, and active-student router context.

- [ ] **Step 2: Implement the focused hub**

Create tabs/sections for overview, interests, surveys/forms, careers, resources, plans, meetings/notes, and progress. In Release 1, unbuilt domains show purposeful empty states describing the next available release action, not dead buttons or fabricated records. Header shows identity, grade, school, assigned team, active-plan status, last interaction, Student Mode availability (disabled until Release 2), edit, archive, and delete when permitted.

- [ ] **Step 3: Split the legacy file**

Move header, timeline, and each domain section to its own file as the section becomes active. Remove superseded nested types from the 1,257-line legacy view and keep no duplicate route.

- [ ] **Step 4: Run detail/accessibility tests and commit**

```bash
git add TMI/Views/Students/StudentDetailView.swift TMI/Features/Students TMITests/Features/Students/StudentDetailStateTests.swift
git commit -m "feat: establish student operational hub"
```

## Task 7: Migrate roster data and remove legacy writers

**Files:**
- Modify: `firebase/src/migrationManifest.ts`
- Create: `firebase/fixtures/release1.json`
- Remove after migration: `TMI/Services/StudentService.swift`
- Remove after migration: `TMI/StateModels/StudentListStateModel.swift`
- Remove after migration: `TMI/StateModels/AddStudentStateModel.swift`
- Modify: all remaining student callers found by `rg`

- [ ] **Step 1: Add roster migration fixtures**

Include user-scoped, top-level, already-canonical, duplicate-ID, missing-district, archived, and cross-reference cases. Expected canonical destination is always `districts/{districtId}/students/{studentId}`.

- [ ] **Step 2: Run dry-run, apply twice, and reconcile**

Expected: first apply writes declared records; second apply writes zero; unresolved owners quarantine; reconciliation is zero.

- [ ] **Step 3: Freeze and remove legacy writers**

```bash
rg -n 'StudentService|users/.*/students|collection\("students"\)' TMI
```

Migrate every production caller to `StudentRepository`; then remove old service/state files. Keep the migration reader only in `TMI/Migration`.

- [ ] **Step 4: Commit**

```bash
git add -A TMI firebase
git commit -m "refactor: retire legacy student persistence"
```

## Task 8: Release 1 acceptance

**Files:**
- Create: `docs/release-evidence/release-1.md`

- [ ] **Step 1: Run the universal gate and roster journey**

Automate sign-in, invitation onboarding, first-student empty action, create, duplicate warning, edit, page/filter/search, unauthorized denial, archive, and restoration from cached offline read. Expected: all pass on iPhone, iPad, and macOS.

- [ ] **Step 2: Record evidence, commit, and tag**

```bash
git add docs/release-evidence/release-1.md
git commit -m "docs: record Release 1 acceptance"
git tag -a tmi-release-1-accepted -m "TMI Release 1 accepted"
```
