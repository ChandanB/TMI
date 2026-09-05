# TMI Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the stranded-but-built subsystems (Compliance, Forms, Resources, Meetings, Recommendations) onto the canonical district-scoped architecture and into the navigation shell, prune the legacy dead code the `Canonical*` migration left behind, and fix the reachable dead controls — without introducing any Cloud Functions dependency.

**Architecture:** The shipping app is district-scoped (`districts/{districtID}/…`), dependency-injected via `AppDependencies`, and authorizes every read/write with a `MembershipContext` obtained from `@Environment(\.authStateModel).currentMembership`. The stranded subsystems predate this: they are `*.shared` singletons that read `Firestore.firestore()` directly, target the obsolete `users/{uid}/…` model, and use legacy value types (`Meeting`, `Resource`, `Student`). "Wiring" therefore means **porting** each to the canonical path helpers in `FirestorePaths` (which already exist for meetings/resources/forms), passing `MembershipContext`, adding any missing `firestore.rules` blocks, then attaching the entry view to the `Canonical*` shell. Work is sequenced lightest-first so each phase ships independently and green.

**Tech Stack:** Swift 6, SwiftUI (iOS/macOS), Firebase iOS SDK 11.15 (Auth/Firestore), Swift Testing + XCTest. No Cloud Functions (Spark plan).

**Test/build shorthand** (used throughout):
```bash
DEST='platform=iOS Simulator,name=iPhone 17 Pro'
DD=/private/tmp/tmi-dd   # any stable derived-data path
xcodebuild build -project TMI.xcodeproj -scheme TMI -configuration Debug -destination "$DEST" -derivedDataPath "$DD"
xcodebuild test  -project TMI.xcodeproj -scheme TMI -configuration Debug -destination "$DEST" -derivedDataPath "$DD" -only-testing:TMITests
```

**Baseline (verified 2026-09-05 before this plan):** app builds (exit 0); `TMITests` = 161 XCTest cases + Swift Testing suites, 0 failures, 3 skipped. Every phase must return to this-or-better before its final commit.

---

## Cross-cutting conventions (read once)

- **Membership in a view:** `@Environment(\.authStateModel) private var authStateModel` → `authStateModel.currentMembership` (a `MembershipContext?` with `.districtID`, `.role`, `.capabilities`, `.assignedStudentIDs`). Views must fail closed (`ContentUnavailableView`) when it is `nil`.
- **District path helpers (already defined in `TMI/Services/FirestorePaths.swift`):** `meetings(districtID:)`, `meeting(districtID:meetingID:)`, `resources(districtID:)`, `resource(districtID:resourceID:)`, `studentResources(districtID:studentID:)`, `planResources(districtID:planID:)`, `formTemplates(districtID:)`, `formTemplate(districtID:templateID:)`, `formAssignments(districtID:)`, `formAssignment(districtID:assignmentID:)`, `studentConsents(districtID:studentID:)`. **Missing (add when its phase runs):** `recommendations(districtID:…)`, `complianceSettings(districtID:)`, `complianceAudits(districtID:)`.
- **Service injection:** follow the existing `@Entry var notificationService: NotificationService? = nil` pattern in `EnvironmentValues` when a service needs test substitution; otherwise the established `Service.shared` singleton used directly by the view is acceptable for read-mostly admin screens (e.g. `ComplianceSettingsView` already does this).
- **Settings entries:** `SettingsView` exposes a private `settingsRow(icon:title:destination:)` → `NavigationLink`. Add rows there for admin/staff destinations; gate by `authStateModel.currentMembership?.role`.
- **Rules changes are unverifiable locally without the emulator.** Each rules edit must be paired with a note in `docs/release-evidence/` describing the collection, the allow-conditions, and a manual read/write check to run once against the live project. Never widen a rule to `if true`.
- **Commit style:** small, one logical change; Conventional Commits; end body with the required Co-Authored-By trailer.

---

## Phase 1 — Compliance settings reachable (lightest, mostly canonical)

Compliance UI (`ComplianceSettingsView`, `ConsentManagementView`) is district-scoped already but has no entry point, and its service writes to `districts/{id}/settings/compliance` + `districts/{id}/complianceAudits`, which `firestore.rules` does not yet cover (they fall through to `districts/{id}/{unmatched=**}` → deny).

### Task 1.1: Add `firestore.rules` coverage for compliance settings & audits

**Files:** Modify `firestore.rules` (inside `match /districts/{districtID}` block, near the existing `settings`-adjacent matches).

- [ ] **Step 1:** Add the two matches. District-admin write, active-member read:
```
match /settings/{settingID} {
  allow read:  if hasActiveMembership(districtID);
  allow write: if isDistrictAdministrator(districtID);   // reuse existing helper
}
match /complianceAudits/{auditID} {
  allow read:  if hasActiveMembership(districtID);
  allow create, update: if isDistrictAdministrator(districtID);
  allow delete: if false;
}
```
(Confirm the exact admin-check helper name in `firestore.rules`; the students block already uses role helpers — reuse the same one, do not invent a new predicate.)
- [ ] **Step 2:** Record the change + manual verification steps in `docs/release-evidence/compliance-rules.md`.
- [ ] **Step 3:** Commit: `feat(rules): authorize district compliance settings and audits`

### Task 1.2: Add `FirestorePaths` helpers for compliance

**Files:** Modify `TMI/Services/FirestorePaths.swift`; Test `TMITests/Services/FirestorePathsTests.swift` (create if absent).

- [ ] **Step 1 (test-first):** Add `func testComplianceSettingsPath()` asserting `FirestorePaths.complianceSettings(districtID: "d1") == "districts/d1/settings/compliance"` and `complianceAudits(districtID:"d1") == "districts/d1/complianceAudits"`.
- [ ] **Step 2:** Run the test, expect FAIL (no such members).
- [ ] **Step 3:** Add both `static func`s mirroring the existing helpers' style.
- [ ] **Step 4:** Run the test, expect PASS. Point `ComplianceService` at these helpers (replace its inline `db.collection("districts").document(districtId)...` strings).
- [ ] **Step 5:** Full `xcodebuild test`, expect baseline-green. Commit: `refactor(compliance): route ComplianceService through FirestorePaths`

### Task 1.3: Surface Compliance in Settings (admin-gated)

**Files:** Modify `TMI/Views/Settings/SettingsView.swift`.

- [ ] **Step 1:** In the settings body, add a section visible only when `authStateModel.currentMembership?.role == .districtAdministrator` (and `.schoolAdministrator` if desired), with two `settingsRow`s: "Compliance" → `ComplianceSettingsView()`, "Consent Management" → `ConsentManagementView()`.
- [ ] **Step 2:** Verify each destination reads `districtID` from `currentMembership` (not a hardcoded/legacy source); fix `ComplianceSettingsView`'s `districtId` acquisition if it uses anything other than `currentMembership`.
- [ ] **Step 3:** Build + launch (Debug, district-admin debug account) and confirm the rows appear and open. Full test run green.
- [ ] **Step 4:** Commit: `feat(compliance): reach compliance & consent settings from Settings`

---

## Phase 2 — Forms templates & assignments reachable + persistence fix

`FormTemplateService`/`FormAssignmentService` are already district-scoped via `FirestorePaths.formTemplates/formAssignments`. The admin surface (`FormsAndSurveysView` → `FormStoreViewModel`) is orphaned, and `FormStoreViewModel.createTemplate` has a `// TODO: Save to Firestore` that drops the write.

### Task 2.1: Make `FormStoreViewModel` persist templates

**Files:** Modify `TMI/Views/Forms/FormStoreViewModel.swift`; Test `TMITests/Views/Forms/FormStoreViewModelTests.swift` (create).

- [ ] **Step 1 (test-first):** Inject a `FormTemplatePersisting` seam (protocol with `func createTemplate(_:) async throws -> FormTemplate`; make `FormTemplateService` conform). Test: a fake persister records the call and the view model appends only on success.
- [ ] **Step 2:** Run, expect FAIL.
- [ ] **Step 3:** Change `createTemplate` to `async`, call the injected persister with the district from `currentMembership`, append on success, surface an error state on throw. Delete the `// TODO`.
- [ ] **Step 4:** Run test, expect PASS; full suite green. Commit: `fix(forms): persist created templates to Firestore`

### Task 2.2: Attach the Forms admin to the shell

**Files:** Modify `TMI/Views/Settings/SettingsView.swift` (staff-visible row) and/or `TMI/Views/MainTabView.swift`.

- [ ] **Step 1:** Add a staff-visible `settingsRow` "Forms & Surveys" → `FormsAndSurveysView()`. (Templates/assignments are staff-wide; a Settings entry avoids adding a 5th tab.)
- [ ] **Step 2:** Verify `FormsAndSurveysView`, `FormTemplateLibraryView`, `StaffAssignmentListView`, `FormSubmissionsView` obtain `districtID`/`userID` from `currentMembership`; repair any legacy `Firestore` singleton reads inside them to go through the (already district-scoped) services.
- [ ] **Step 3:** Build + launch; create a template, confirm it round-trips. Full suite green. Commit: `feat(forms): reach forms & surveys admin from Settings`

> **Deferred to Phase 5:** per-plan form assignment surfaced inside `CanonicalPlanDetailView` (depends on the submission-path port).

---

## Phase 3 — Resources port + attach

`ResourceService.shared` writes to `users/{uid}/resources` (legacy). Canonical targets already exist: `FirestorePaths.resources(districtID:)` (library), `studentResources(districtID:studentID:)`, `planResources(districtID:planID:)`. Rules already define `districts/{id}/resources` and `districts/{id}/students/{id}/resources`.

### Task 3.1: Canonical resource repository

**Files:** Create `TMI/Features/Resources/ResourceRepository.swift` (protocol + Firebase impl following `CanonicalPlanRepository`'s shape); Test `TMITests/Features/Resources/ResourceRepositoryTests.swift`.

- [ ] **Step 1 (test-first):** Protocol `ResourceRepository` with `library(member:)`, `studentResources(studentID:member:)`, `create(_:member:)`, `assign(resourceID:toStudent:member:)`, `linkToPlan(resourceID:planID:member:)`. Test a fake conforms and a `MembershipContext` with the wrong district is rejected (mirror `CanonicalPlanRepository`'s authorization tests).
- [ ] **Step 2:** Run, expect FAIL.
- [ ] **Step 3:** Implement the Firebase repository using the `FirestorePaths.resources/studentResources/planResources` helpers and `member.districtID`; reuse `Resource` (Codable) but write through the district paths.
- [ ] **Step 4:** Run tests, expect PASS. Commit: `feat(resources): district-scoped resource repository`

### Task 3.2: Inject the repository

**Files:** Modify `TMI/Core/Dependencies/AppDependencies.swift` (add `resourceRepository: (any ResourceRepository)?`, wire in `production(firestore:)`, default `nil` in `preview`/`unconfigured`).

- [ ] **Step 1:** Add the property + init param (default nil) + production construction, following `planRepository`'s exact pattern (including any `#if DEBUG` wrapper if a debug variant is warranted — otherwise omit).
- [ ] **Step 2:** Build; full suite green. Commit: `feat(resources): inject resource repository`

### Task 3.3: Attach Resources to Student & Plan detail

**Files:** Modify `TMI/Views/Students/StudentDetailView.swift` (add a "Resources" case to `destinationPicker` sections, rendering a resources section backed by `resourceRepository.studentResources`); Modify `TMI/Features/Plans/CanonicalPlanDetailView.swift` (add a resources section + "Link resource" sheet). Reuse/port `ResourceCard`, `ResourceDetailView`, `AddResourceView` (repoint their writes at the repository, drop `ResourceService.shared`).

- [ ] **Step 1:** Add the student-detail Resources section (follow the existing `StudentInterestsSection` attach pattern at `StudentDetailView.swift:411`). Test: a section projection test with a fake repository.
- [ ] **Step 2:** Add the plan-detail resources section + link sheet.
- [ ] **Step 3:** Build + launch; add a resource, assign to a student, link to a plan; confirm round-trip. Full suite green.
- [ ] **Step 4:** Commit in two: `feat(resources): resources on student detail` / `feat(resources): resources on plan detail`

---

## Phase 4 — Meetings port + attach

`MeetingService.shared` writes to `users/{uid}/meetings`. Canonical `FirestorePaths.meetings(districtID:)`/`meeting(...)` exist; rules allow active-member create/update, `delete:false`. `MeetingsStateModel` is already built and injected app-wide but consumed by nothing.

### Task 4.1: Port `MeetingService` to district scope

**Files:** Modify `TMI/Services/MeetingService.swift` (accept `MembershipContext`, use `FirestorePaths.meetings/meeting`); Modify `TMI/StateModels/MeetingsStateModel.swift` (call the ported API); Test `TMITests/StateModels/MeetingsStateModelTests.swift`.

- [ ] **Step 1 (test-first):** Test that `MeetingsStateModel.fetchMeetings(member:)` reads via a fake meeting store keyed by `districtID`, and that `scheduleMeeting` writes there. Assert nothing touches a `users/…` path (inject the store; the test's fake asserts the path helper used).
- [ ] **Step 2:** Run, expect FAIL.
- [ ] **Step 3:** Replace `db.collection("users").document(userId).collection("meetings")` with `db.collection(FirestorePaths.meetings(districtID: member.districtID))`. Thread `member` through `scheduleMeeting`/`fetchMeetings`/`fetchMeetings(for:)`. Keep the `Meeting` model; set `organizer = member.userID`.
- [ ] **Step 4:** Run tests, expect PASS; full suite green. Commit: `refactor(meetings): district-scope MeetingService`

### Task 4.2: Fix `CreateEditMeetingView` error handling & attach

**Files:** Modify `TMI/Views/Meetings/CreateEditMeetingView.swift` (surface save errors in the UI instead of `print`), `TMI/Views/Students/StudentDetailView.swift` (a "Meetings" section filtered by `relatedStudentIds`), and add an "All Meetings" entry (Settings row or plan-detail link).

- [ ] **Step 1:** Replace the `print("[CreateEditMeetingView] Failed…")` catch with an `errorMessage` state rendered inline; block dismissal on failure.
- [ ] **Step 2:** Attach `AllMeetingsView`/`MeetingCalendarView` via a Settings row "Meetings"; add a student-scoped meetings section on student detail.
- [ ] **Step 3:** Build + launch; schedule a meeting for a student, confirm it appears. Full suite green. Commit: `feat(meetings): reach meetings and fix save error handling`

---

## Phase 5 — Forms submissions port + per-plan assignment

`FormSubmissionService`/`FormAssignmentService` write submissions to `users/{uid}/formSubmissions`. Rules define `districts/{id}/formAssignments/{id}/respondents`. Port submissions there and surface assignment/submission where students act.

### Task 5.1: Port submission writes to `formAssignments/{id}/respondents`

**Files:** Modify `TMI/Services/FormSubmissionService.swift`, `TMI/Services/FormAssignmentService.swift` (the `users/…` submission path at ~line 249); Test `TMITests/Services/FormSubmissionServiceTests.swift`.

- [ ] **Step 1 (test-first):** Test that creating a submission writes under the respondents subcollection of its assignment, scoped by district.
- [ ] **Step 2–4:** Run→FAIL; repoint the collection to `FirestorePaths.formAssignment(districtID:assignmentID:) + "/respondents"`; run→PASS; suite green. Commit: `refactor(forms): district-scope form submissions`

### Task 5.2: Surface forms where they're used

**Files:** Modify `TMI/Features/Plans/CanonicalPlanDetailView.swift` (a "Forms" section: assign a template to this plan's student, list submissions) and the student side (`StudentFormListView` in Student Mode or student detail).

- [ ] **Step 1:** Add the plan-detail Forms section + assign sheet (staff), backed by `FormAssignmentService`.
- [ ] **Step 2:** Wire `StudentFormListView` into the reachable student surface for respondents.
- [ ] **Step 3:** Build + launch; assign a form, complete it as a respondent, see it listed. Suite green. Commit: `feat(forms): assign and complete forms from a plan`

> Staff survey/form **review & scoring** that requires server-side aggregation stays in the billing-blocked backlog.

---

## Phase 6 — Recommendations port (heaviest; may defer)

`RecommendationsService` uses `users/{uid}/recommendations`, the legacy `Student` model, and has **no** rules. Lowest ROI; sequenced last.

### Task 6.1: Rules + paths + port

**Files:** `firestore.rules` (add `districts/{id}/recommendations/{id}` read active-member / write staff), `TMI/Services/FirestorePaths.swift` (`recommendations(districtID:)`), `TMI/Services/RecommendationsService.swift` (district scope + accept `StudentRecord`/`MembershipContext` instead of legacy `Student`), `TMI/StateModels/RecommendationsStateModel.swift`.

- [ ] **Step 1 (test-first):** State-model test reading via a fake district-scoped store.
- [ ] **Steps 2–4:** Run→FAIL; add rules + path + repoint service + adapt to canonical models; run→PASS; suite green. Commit: `feat(recommendations): district-scope recommendations`

### Task 6.2: Surface recommendations

**Files:** `TMI/Views/Dashboard/DashboardView.swift` or `CanonicalPlanDetailView.swift` — a recommendations strip driven by the already-injected `RecommendationsStateModel`.

- [ ] Attach, build + launch, suite green. Commit: `feat(recommendations): surface recommendations`

---

## Phase 7 — Prune legacy dead code (interleave: prune each area right after its port lands)

For every candidate: (1) grep the reachable graph for the canonical replacement to confirm it's truly superseded, (2) delete the file, (3) build + full test green, (4) commit in small batches. **Never delete a file whose port phase above still needs it.**

**Confirmed-superseded (delete after confirming the named replacement is reachable):**
- `TMI/Views/Goals/AddGoalView.swift`, `EditGoalView.swift` → replaced by `TMI/Features/Plans/GoalEditorView.swift`.
- `TMI/Views/Dashboard/DashboardInsightsView.swift` + `Dashboard/Components/{DashboardHeaderView,DashboardStatsView,StudentStatusWidget,ActionableCards,AlignmentChartView(LegacyAlignmentChartView),QuickActionCards}.swift` → replaced by the current `DashboardView` composition. (Confirm each component isn't referenced by the live `DashboardView` first.)
- `TMI/Views/StudentMode/StudentTMIPlanDetailView.swift`, `StudentInterestDetailView.swift` → replaced by `StudentPlanProjectionView`.
- `TMI/Views/Authentication/RoleSelectionView.swift` → in-app role provisioning is disabled (no-Blaze); confirm no reachable registration path uses it.

**Evaluate during the relevant port (reuse or delete — do NOT blind-delete):**
- `TMI/Views/TMIPlans/Sections/PlanResourcesSection.swift`, `PlanInterestsSection.swift`, `PlanFormsSection.swift` — old plan sections; Phases 3 & 5 add canonical equivalents. Reuse the UI if convenient, else delete once the canonical section lands.
- `TMI/Views/Students/{StudentProgressView,StudentCard,BulkActionsView,StudentListFilterView,AddInterestToStudentView}.swift`, `Students/Sections/StudentResourcesSection.swift` — confirm the canonical Student list/detail already covers each before deleting.

- [ ] Each deletion is its own step: delete → `xcodebuild test` green → commit `chore: remove superseded <name>`.

---

## Phase 8 — Reachable dead-control fixes

### Task 8.1: `WorkspacePanelView` "Create New Plan" dead button

**Files:** Modify `TMI/Views/MainTabView.swift:696-714`.

- [ ] **Step 1:** Replace the empty-action button (`// Would navigate to plan creation`) with either navigation to the plan editor for `router.activeStudent`, or remove the button if the workspace isn't the right surface. Decide with the reachable plan-creation entry (student detail already presents the plan editor at `StudentDetailView.swift:205`).
- [ ] **Step 2:** Build + launch, confirm the control works or is gone. Commit: `fix(workspace): wire or remove the dead Create New Plan button`

### Task 8.2 (optional/cosmetic): Dashboard help tooltips
- [ ] Address `DashboardView.swift:648` `// TODO` only if in scope; otherwise delete the stale comment. Commit: `chore(dashboard): resolve stale tooltip TODO`

---

## Billing-blocked backlog (documented, NOT built here)

These cannot be completed without the Blaze plan / Cloud Functions and are out of scope for this plan:
- **Server-written audit trail** — `firestore.rules` sets `auditEvents` `write: if false` by design; `AuditLogService` client writes cannot be authorized. Compliance's audit *display* works; audit *writes* need a callable.
- **Staff survey/form review & scoring aggregation**, **trusted-mutation callables** (`FeatureFlags.usesTrustedMutationCallables` stays `false`), **SSO / LMS / SIS** integrations (`SSOService`, `LMSIntegrationService`, `SISIntegrationService` throw `notImplemented`), and **bulk plan export** (`PlanExportService` — single export works).
- Real staff provisioning remains the `firebase/scripts/provision-staff.mjs` operator path.

---

## Self-review notes
- **Spec coverage:** Compliance (P1), Forms admin+persistence (P2), Resources (P3), Meetings (P4), Forms submissions (P5), Recommendations (P6), prune (P7), dead controls (P8), billing-blocked documented. All four requested subsystems + prune + fixes covered.
- **Type consistency:** all writes route through the existing `FirestorePaths` helpers named above; new helpers (`complianceSettings`, `complianceAudits`, `recommendations`) are introduced in the phase that first uses them.
- **Ordering:** each phase is independently shippable and returns to baseline-green before its final commit; prune interleaves so no file is deleted while a later phase still needs it.
