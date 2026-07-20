# TMI Release 3 Core Intervention MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn approved student discovery data into an authorized, approved, active, measurable TMI plan using all six brand-fixed intervention models.

**Architecture:** Model plans as versioned aggregate roots with a pure lifecycle state machine and append-only revisions/progress. Draft edits use optimistic concurrency; approval and lifecycle transitions run through idempotent trusted transactions; deterministic recommendations explain inputs but educators retain final choice.

**Tech Stack:** Swift 6.2, SwiftUI, Swift Testing, Firebase Firestore/Functions/Storage, PDFKit, XCTest UI automation

---

## File map

| Action | Path | Responsibility |
|---|---|---|
| Create | `TMI/Features/Plans/TMIModel.swift` | Six fixed model IDs/names and approved content |
| Create | `TMI/Features/Plans/PlanRecord.swift` | Canonical aggregate root |
| Create | `TMI/Features/Plans/PlanRevision.swift` | Frozen revision snapshot |
| Create | `TMI/Features/Plans/PlanLifecycle.swift` | Pure transition policy |
| Create | `TMI/Features/Plans/PlanRepository.swift` | Draft CRUD and trusted transitions |
| Create | `TMI/Features/Plans/PlanRecommendation.swift` | Deterministic rationale |
| Create | `TMI/Features/Plans/GoalRecord.swift` | Baseline/target/measure/due/status |
| Create | `TMI/Features/Plans/ActionRecord.swift` | Staff/student next actions |
| Create | `TMI/Features/Plans/ProgressEntry.swift` | Append-only measures/reflections |
| Replace | `TMI/Views/TMIPlans/TMIPlanListView.swift` | Canonical plan list |
| Replace | `TMI/Views/TMIPlans/TMIPlanEditorView.swift` | Twelve-step draft editor |
| Replace | `TMI/Views/TMIPlans/TMIPlanDetailView.swift` | Lifecycle, evidence, history |
| Replace | `TMI/Views/TMIPlan/PlanApprovalView.swift` | Approval queue |
| Replace | `TMI/Views/TMIPlan/PlanApprovalDetailView.swift` | Review/approve/request changes |
| Create | `TMI/Features/Plans/PlanExportRenderer.swift` | Permission-safe PDF projections |
| Modify | `TMI/Views/StudentMode/StudentModeView.swift` | Goals, actions, reflection, check-in |
| Create | `TMITests/Features/Plans/PlanLifecycleTests.swift` | Complete state graph |
| Create | `TMITests/Features/Plans/PlanRepositoryTests.swift` | Version/idempotency/authorization |
| Create | `TMITests/Features/Plans/PlanRecommendationTests.swift` | Deterministic rationale |
| Create | `TMITests/Features/Plans/PlanExportTests.swift` | Redaction and stable rendering |
| Create | `firebase/test/plans.test.ts` | Transaction/rules/audit behavior |
| Create | `firebase/fixtures/release3.json` | Plan migration/reconciliation |

## Task 1: Lock the six branded intervention models

**Files:**
- Create: `TMI/Features/Plans/TMIModel.swift`
- Create: `TMI/Resources/TMIModels.json`
- Create: `TMITests/Features/Plans/TMIModelTests.swift`

- [ ] **Step 1: Write failing identity tests**

```swift
@Test func modelNamesAreBrandFixed() {
    #expect(TMIModel.allCases.map(\.displayName) == [
        "Chase Your Space",
        "Acknowledge Your Interests and Hobbies",
        "Align Your Mind",
        "Direct & Correct Negative Behavior",
        "From Bully to Boss",
        "From Meek to Promising Protector"
    ])
}
```

- [ ] **Step 2: Implement stable identifiers**

```swift
enum TMIModel: String, Codable, CaseIterable, Sendable {
    case chaseYourSpace
    case acknowledgeInterestsAndHobbies
    case alignYourMind
    case directAndCorrectNegativeBehavior
    case fromBullyToBoss
    case fromMeekToPromisingProtector
}
```

Load product-owner-approved purpose, use cases, boundaries, activities, measures, cadence, student explanation, and staff guidance from versioned bundled/catalog content. Fail the release build when any model content is missing or still marked draft. Do not invent clinical claims.

- [ ] **Step 3: Run tests and commit**

```bash
git add TMI/Features/Plans/TMIModel.swift TMI/Resources/TMIModels.json TMITests/Features/Plans/TMIModelTests.swift
git commit -m "feat: lock approved TMI intervention models"
```

## Task 2: Define the canonical plan aggregate and lifecycle

**Files:**
- Create: `TMI/Features/Plans/PlanRecord.swift`
- Create: `TMI/Features/Plans/PlanRevision.swift`
- Create: `TMI/Features/Plans/PlanLifecycle.swift`
- Create: `TMITests/Features/Plans/PlanLifecycleTests.swift`

- [ ] **Step 1: Write one failing test per transition**

Test draft→pending, pending→changes requested, changes requested→draft, pending→approved, approved→active, active↔paused, active/paused→completed, completed→archived, and every forbidden edge. Test approver capability, owner activation, start-date validation, and terminal archive.

```swift
enum PlanStatus: String, Codable, Sendable {
    case draft, pendingApproval, changesRequested, approved, active, paused, completed, archived
}

enum PlanCommand: Sendable {
    case submit, requestChanges(reason: String), approve, activate, pause, resume, complete(outcome: String), archive
}
```

- [ ] **Step 2: Implement a pure state machine**

`PlanLifecycle.apply(command:to:actor:now:)` returns a new status plus an audit description or throws a typed error. It has no Firebase dependency. Approval and completion freeze the current revision; completed plans are duplicated into a new ID for a new cycle.

- [ ] **Step 3: Define focused child records**

Goals, actions, resources, schedule, forms, survey links, careers, interests, approvals, progress, and revisions live in their contract subcollections. The aggregate stores IDs/counts/current revision, not copied child arrays.

- [ ] **Step 4: Run tests and commit**

```bash
git add TMI/Features/Plans/PlanRecord.swift TMI/Features/Plans/PlanRevision.swift TMI/Features/Plans/PlanLifecycle.swift TMITests/Features/Plans/PlanLifecycleTests.swift
git commit -m "feat: define plan lifecycle state machine"
```

## Task 3: Implement deterministic plan recommendations

**Files:**
- Create: `TMI/Features/Plans/PlanRecommendation.swift`
- Create: `TMI/Features/Plans/PlanRecommendationEngine.swift`
- Create: `TMITests/Features/Plans/PlanRecommendationTests.swift`

- [ ] **Step 1: Write failing recommendation fixtures**

Each fixture supplies approved interests, survey clusters, saved careers, active/completed plan history, and explicit educator-selected need tags. Assert model ranking, named inputs, rationale, stable ties, and manual-choice availability. Assert no recommendation diagnoses or infers trauma.

- [ ] **Step 2: Implement versioned deterministic rules**

```swift
struct PlanRecommendation: Identifiable, Sendable, Equatable {
    let id: String
    let model: TMIModel
    let inputRecordIDs: [String]
    let reasons: [String]
    let rulesVersion: Int
}
```

Rules may use only canonical approved records. The UI labels results as suggestions; educator manual selection remains available and records rationale.

- [ ] **Step 3: Run tests and commit**

```bash
git add TMI/Features/Plans/PlanRecommendation.swift TMI/Features/Plans/PlanRecommendationEngine.swift TMITests/Features/Plans/PlanRecommendationTests.swift
git commit -m "feat: explain plan model recommendations"
```

## Task 4: Implement transactional plan persistence

**Files:**
- Create: `TMI/Features/Plans/PlanRepository.swift`
- Modify: `firebase/src/index.ts`
- Create: `TMITests/Features/Plans/PlanRepositoryTests.swift`
- Create: `firebase/test/plans.test.ts`

- [ ] **Step 1: Write failing repository tests**

Cover draft create/update, expected version, idempotent replay, child writes, submit, approval, requested changes, activation, pause/resume, append-only progress, completion, archive, new-cycle duplication, ownership/collaborator/approver boundaries, and offline rules.

```swift
protocol PlanRepository: Sendable {
    func plans(_ request: PlanPageRequest, member: MembershipContext) async throws -> PlanPage
    func plan(id: String, member: MembershipContext) async throws -> PlanRecord
    func saveDraft(_ draft: PlanDraft, expectedVersion: Int?, operationID: UUID, member: MembershipContext) async throws -> PlanRecord
    func transition(planID: String, command: PlanCommand, expectedVersion: Int, operationID: UUID, member: MembershipContext) async throws -> PlanRecord
    func appendProgress(_ entry: ProgressDraft, operationID: UUID, member: MembershipContext) async throws -> ProgressEntry
}
```

- [ ] **Step 2: Implement trusted transactions**

Functions load membership, plan, student, assignments, and expected version; validate the pure lifecycle; write revision/status/children/audit atomically; and return the authoritative record. Clients cannot author approvals or audit events.

- [ ] **Step 3: Implement conflict behavior**

Draft text may queue offline with stable IDs. Status transitions, approvals, completion, and archive require online revalidation. A draft version conflict preserves both local and server drafts for explicit field resolution.

- [ ] **Step 4: Run Swift/emulator tests and commit**

```bash
git add TMI/Features/Plans/PlanRepository.swift TMITests/Features/Plans/PlanRepositoryTests.swift firebase
git commit -m "feat: persist plans with trusted transitions"
```

## Task 5: Build goals, actions, and progress

**Files:**
- Create: `TMI/Features/Plans/GoalRecord.swift`
- Create: `TMI/Features/Plans/ActionRecord.swift`
- Create: `TMI/Features/Plans/ProgressEntry.swift`
- Replace: `TMI/Views/Goals/AddGoalView.swift`
- Replace: `TMI/Views/Goals/EditGoalView.swift`
- Create: `TMI/Features/Plans/ProgressEntryView.swift`
- Create: `TMITests/Features/Plans/GoalProgressTests.swift`

- [ ] **Step 1: Write failing goal/progress tests**

Test required baseline, target, measurement method, due date, responsible staff, student-facing wording, action ownership, cadence, append-only progress, source attribution, and completion percentage from due actions rather than hidden scores.

- [ ] **Step 2: Implement focused records and validation**

Goals store baseline/target/measure/due/status; actions store owner, audience, due/status; progress stores goal/action source, measured value, note/reflection visibility, author, and server time. Never overwrite progress history.

- [ ] **Step 3: Build accessible editors**

Use standard professional wording in staff editors and supportive wording for student-visible fields. Preserve drafts, show field errors, and announce saved progress only after repository confirmation.

- [ ] **Step 4: Run tests and commit**

```bash
git add TMI/Features/Plans TMI/Views/Goals TMITests/Features/Plans/GoalProgressTests.swift
git commit -m "feat: track plan goals actions and progress"
```

## Task 6: Build the plan editor and list

**Files:**
- Replace: `TMI/Views/TMIPlans/TMIPlanListView.swift`
- Replace: `TMI/Views/TMIPlans/TMIPlanEditorView.swift`
- Create: `TMI/Features/Plans/PlanEditorState.swift`
- Create: `TMITests/Features/Plans/PlanEditorStateTests.swift`
- Create: `TMIUITests/PlanCreationUITests.swift`

- [ ] **Step 1: Write failing editor-state tests**

Test all twelve contract steps, autosaved draft, recommendation/manual selection, at least one immediate action, date/cadence validation, assigned owner, student voice, family collaboration permission, review, save draft, submit, recoverable failure, and version conflict.

- [ ] **Step 2: Implement the editor as focused sections**

The sequence is student; signals; model recommendation/manual choice; professional need; interests/careers; immediate action; goals/measures; responsible staff; resources/forms/surveys; dates/cadence; student voice/authorized family collaboration; review/save/submit. Extract one view per section and keep `PlanEditorState` as the draft owner.

- [ ] **Step 3: Implement list/filter states**

List owned/collaborative/approval-assigned plans with student, model, owner, status, dates, progress, and next review. Search and filter status, model, student, owner, school, and attention reason.

- [ ] **Step 4: Run UI/state tests and commit**

```bash
git add TMI/Views/TMIPlans/TMIPlanListView.swift TMI/Views/TMIPlans/TMIPlanEditorView.swift TMI/Features/Plans/PlanEditorState.swift TMITests/Features/Plans/PlanEditorStateTests.swift TMIUITests/PlanCreationUITests.swift
git commit -m "feat: deliver intervention plan creation"
```

## Task 7: Build approval, detail, history, and Student Mode follow-through

**Files:**
- Replace: `TMI/Views/TMIPlans/TMIPlanDetailView.swift`
- Replace: `TMI/Views/TMIPlan/PlanApprovalView.swift`
- Replace: `TMI/Views/TMIPlan/PlanApprovalDetailView.swift`
- Modify: `TMI/Views/StudentMode/StudentModeView.swift`
- Create: `TMIUITests/PlanLifecycleUITests.swift`

- [ ] **Step 1: Write the failing lifecycle journey**

Automate create, submit, approve/request changes, activate, append progress, pause/resume, complete, inspect frozen history, archive, duplicate new cycle, student goal/action view, reflection, and check-in. Assert permissions at each step.

- [ ] **Step 2: Build approval/detail views**

Approval shows immutable proposed revision, source records, rationale, goals/actions, schedule, and changes reason. Detail shows current lifecycle, next action, goals, progress, resources, meetings, revision timeline, and permission-backed controls.

- [ ] **Step 3: Add Student Mode projections**

Show only approved student-facing explanation, goals, due actions, resources, reflections, and progress check-ins. Hide professional need text, staff notes, approval discussion, and restricted records.

- [ ] **Step 4: Split the 3,312-line legacy detail file**

Extract header, lifecycle controls, goals, progress, resources, schedule, approvals, revisions, export, and student card to focused files. Delete superseded nested types.

- [ ] **Step 5: Run UI/accessibility tests and commit**

```bash
git add TMI/Views/TMIPlans TMI/Views/TMIPlan TMI/Views/StudentMode TMIUITests/PlanLifecycleUITests.swift
git commit -m "feat: complete plan lifecycle experience"
```

## Task 8: Implement permission-safe plan exports

**Files:**
- Create: `TMI/Features/Plans/PlanExportProjection.swift`
- Create: `TMI/Features/Plans/PlanExportRenderer.swift`
- Create: `TMITests/Features/Plans/PlanExportTests.swift`
- Modify: `firebase/src/index.ts`

- [ ] **Step 1: Write failing projection tests**

Test professional plan PDF, MTSS summary, progress report, meeting summary seam, aggregate-safe report seam, role-based field inclusion, restricted-note exclusion, Student Mode wording exclusion, online permission revalidation, and audit creation.

- [ ] **Step 2: Implement authorized projection before rendering**

The trusted function returns only authorized export DTO fields and audit ID. `PlanExportRenderer` receives that DTO and creates stable PDF pages with title, student context, model, rationale, goals/actions, schedule, progress, and footer classification. UI hiding is never the redaction mechanism.

- [ ] **Step 3: Run PDF snapshot/content tests and commit**

```bash
git add TMI/Features/Plans/PlanExportProjection.swift TMI/Features/Plans/PlanExportRenderer.swift TMITests/Features/Plans/PlanExportTests.swift firebase/src/index.ts
git commit -m "feat: export authorized plan reports"
```

## Task 9: Migrate plans and retire legacy implementations

**Files:**
- Modify: `firebase/src/migrationManifest.ts`
- Create: `firebase/fixtures/release3.json`
- Remove after migration: `TMI/Services/TMIPlanService.swift`
- Remove after migration: `TMI/Data/PlanRepository.swift`
- Remove after migration: `TMI/Services/PlanApprovalService.swift`
- Remove after migration: superseded plan models/state models/views with no callers

- [ ] **Step 1: Add migration fixtures**

Cover user-scoped/top-level plans, embedded goals/resources, every legacy status, missing owner, duplicate revisions, completed history, and already-canonical records.

- [ ] **Step 2: Apply twice and reconcile**

Expected: state/history/child counts and IDs reconcile; invalid states quarantine with reason; second apply writes zero.

- [ ] **Step 3: Remove all legacy writers and duplicate plan representations**

```bash
rg -n 'TMIPlanService|PlanRepository|PlanApprovalService|users/.*/tmiPlans|collection\("plans"\)' TMI
```

Expected: only canonical repository or migration adapter matches remain.

- [ ] **Step 4: Commit**

```bash
git add -A TMI firebase
git commit -m "refactor: retire legacy plan persistence"
```

## Task 10: Release 3 acceptance

**Files:**
- Create: `docs/release-evidence/release-3.md`

- [ ] **Step 1: Run universal gate and canonical-loop journey**

Use real Emulator and staging data to create a student, complete discovery, choose a career, create/submit/approve/activate a plan, record student/staff progress, complete/archive, inspect history, and export. Attempt forbidden transitions and cross-scope reads.

- [ ] **Step 2: Record evidence, commit, and tag**

```bash
git add docs/release-evidence/release-3.md
git commit -m "docs: record Release 3 acceptance"
git tag -a tmi-release-3-accepted -m "TMI Release 3 accepted"
```
