# TMI Release 4 School Collaboration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete contextual school collaboration with forms, resources, meetings, notes, person-owned tasks, in-app notifications, and permission-safe global search.

**Architecture:** Each capability owns canonical records and a repository, but enters through student or plan context rather than a new top-level tab. Submitted responses and protected notes remain separate authorization domains; source events create deduplicated notifications and tasks; search indexes only authorized projections.

**Tech Stack:** Swift 6.2, SwiftUI, Firestore, Cloud Functions, EventKit, PDFKit, Swift Testing, XCTest UI automation

---

## File map

| Domain | Canonical implementation files |
|---|---|
| Forms | `TMI/Features/Forms/FormTemplate.swift`, `TMI/Features/Forms/FormAssignment.swift`, `TMI/Features/Forms/FormResponse.swift`, `TMI/Features/Forms/FormRepository.swift`; existing view paths named in Task 1 |
| Resources | `TMI/Features/Resources/ResourceRecord.swift`, `TMI/Features/Resources/ResourceRelationship.swift`, `TMI/Features/Resources/ResourceRepository.swift`; existing view paths named in Task 2 |
| Meetings | `TMI/Features/Meetings/MeetingRecord.swift`, `TMI/Features/Meetings/MeetingRepository.swift`, `TMI/Features/Meetings/CalendarAdapter.swift`; existing view paths named in Task 3 |
| Notes | `TMI/Features/Notes/StaffNote.swift`, `TMI/Features/Notes/StudentReflection.swift`, `TMI/Features/Notes/NoteRepository.swift`, `TMI/Features/Notes/Restricted/RestrictedRecord.swift`, `TMI/Features/Notes/Restricted/RestrictedRecordRepository.swift` |
| Tasks | `TMI/Features/Tasks/TaskRecord.swift`, `TMI/Features/Tasks/TaskRepository.swift`, `TMI/Features/Tasks/TaskListView.swift` |
| Notifications | `TMI/Features/Notifications/AppNotification.swift`, `TMI/Features/Notifications/NotificationRepository.swift`, `TMI/Views/Components/NotificationCenterView.swift` |
| Search | `TMI/Features/Search/SearchResult.swift`, `TMI/Features/Search/SearchRepository.swift`, `TMI/Features/Search/GlobalSearchView.swift` |
| Backend | `firebase/src/index.ts`, `firebase/test/collaboration.test.ts`, `firebase/fixtures/release4.json` |
| UI automation | `TMIUITests/SchoolCollaborationUITests.swift` |

## Task 1: Consolidate versioned forms and immutable responses

**Files:**
- Create: `TMI/Features/Forms/FormTemplate.swift`
- Create: `TMI/Features/Forms/FormAssignment.swift`
- Create: `TMI/Features/Forms/FormResponse.swift`
- Create: `TMI/Features/Forms/FormRepository.swift`
- Replace: `TMI/Views/Forms/FormBuilderView.swift`
- Replace: `TMI/Views/Forms/FormCompletionView.swift`
- Replace: `TMI/Views/Forms/SubmissionReviewView.swift`
- Create: `TMITests/Features/Forms/FormWorkflowTests.swift`

- [ ] **Step 1: Write failing form-domain tests**

Test draft/published/archived template states; short/long text, single/multiple choice, rating, yes/no, date, numeric, acknowledgment, conditional questions, and sections; explicit versioned scoring; respondent type; multi-student/plan assignment; autosave; immutable submit; review; overdue; and permission-safe export.

```swift
enum FormFieldKind: Codable, Sendable, Equatable {
    case shortText, longText, singleChoice, multipleChoice, rating, yesNo, date, number, acknowledgment
}

enum FormAssignmentStatus: String, Codable, Sendable {
    case notStarted, inProgress, submitted, reviewed, overdue
}
```

- [ ] **Step 2: Implement canonical repositories and trusted submit**

Published versions are immutable. Assignments link student/plan/due date/respondent type. Drafts can queue offline; submit validates visible required fields and version online, freezes response, creates an event, and never overwrites history. Scores exist only when a published scoring definition names every contributing field.

- [ ] **Step 3: Build contextual UI**

Staff builder/library/review lives in student/plan context and authorized admin tooling. Student Mode and guardian respondent sessions use the same completion renderer with scope-specific projections. Provide review comments and authorized export.

- [ ] **Step 4: Run form tests and commit**

```bash
git add TMI/Features/Forms TMI/Views/Forms TMITests/Features/Forms firebase/src/index.ts
git commit -m "feat: consolidate forms and responses"
```

## Task 2: Consolidate resources and relationship progress

**Files:**
- Create: `TMI/Features/Resources/ResourceRecord.swift`
- Create: `TMI/Features/Resources/ResourceRelationship.swift`
- Create: `TMI/Features/Resources/ResourceRepository.swift`
- Replace: `TMI/Views/Resources/ResourcesView.swift`
- Replace: `TMI/Views/Resources/ResourceDetailView.swift`
- Replace: `TMI/Views/Resources/AssignedResourcesView.swift`
- Create: `TMITests/Features/Resources/ResourceWorkflowTests.swift`

- [ ] **Step 1: Write failing resource tests**

Test global/district-school/personal scope, moderation, broken-link report, search, type/interest/career/grade/model/subject/accessibility/language/cost/delivery filters, assignment relationship, completion, reflection, and student-safe projection.

- [ ] **Step 2: Implement one catalog and relationship model**

Resource content is stored once under canonical scope. Student and plan documents contain relationship records with source, assignment, status, progress, reflection visibility, and timestamps; never copy the full resource into a student/plan.

- [ ] **Step 3: Build contextual views and run tests**

Resource search opens from student or plan, retains context, and confirms the target before assignment. Assigned views show real relationships only. Expected: unit/UI/accessibility tests pass.

- [ ] **Step 4: Commit**

```bash
git add TMI/Features/Resources TMI/Views/Resources TMITests/Features/Resources
git commit -m "feat: deliver contextual resource workflow"
```

## Task 3: Implement meetings with safe calendar integration

**Files:**
- Create: `TMI/Features/Meetings/MeetingRecord.swift`
- Create: `TMI/Features/Meetings/MeetingRepository.swift`
- Create: `TMI/Features/Meetings/CalendarAdapter.swift`
- Replace: `TMI/Views/Meetings/CreateEditMeetingView.swift`
- Replace: `TMI/Views/Meetings/MeetingDetailView.swift`
- Replace: `TMI/Views/Meetings/MeetingListView.swift`
- Create: `TMITests/Features/Meetings/MeetingWorkflowTests.swift`

- [ ] **Step 1: Write failing meeting tests**

Test student/team/plan-review/family/progress types, participants, schedule, location/link, agenda, linked records, decisions, follow-ups, next meeting, overdue-note event, version conflict, and EventKit denial/safe event text.

```swift
protocol CalendarWriting: Sendable {
    func authorizationStatus() async -> CalendarAuthorization
    func requestAccess() async throws -> Bool
    func save(_ event: CalendarEventDraft) async throws -> String
}
```

- [ ] **Step 2: Implement canonical meeting persistence**

Meetings are district records linked to students/plans. Completion requires notes/decisions/follow-ups or an explicit `none` acknowledgement. Calendar writes occur only after user permission and use generic text such as `TMI plan review`; student names, needs, and notes never enter shared event text.

- [ ] **Step 3: Build list/calendar/detail/editor and run tests**

Use adaptive views, date filters, accessible status labels, and person-owned follow-up creation. Expected: tests pass with fake calendar adapter and real EventKit boundary isolated.

- [ ] **Step 4: Commit**

```bash
git add TMI/Features/Meetings TMI/Views/Meetings TMITests/Features/Meetings
git commit -m "feat: deliver meetings and safe calendar sync"
```

## Task 4: Separate ordinary notes, restricted records, and student reflections

**Files:**
- Create: `TMI/Features/Notes/StaffNote.swift`
- Create: `TMI/Features/Notes/StudentReflection.swift`
- Create: `TMI/Features/Notes/Restricted/RestrictedRecord.swift`
- Create: `TMI/Features/Notes/NoteRepository.swift`
- Create: `TMI/Features/Notes/Restricted/RestrictedRecordRepository.swift`
- Create: `TMITests/Features/Notes/NoteAuthorizationTests.swift`
- Modify: `firebase/test/collaboration.test.ts`

- [ ] **Step 1: Write failing authorization tests**

Test physical path separation, explicit restricted read/write capability, assignment not implying restricted access, admin no-default access, revision history, student reflection visibility, and sensitive-read audit event.

- [ ] **Step 2: Implement separate contracts and queries**

`notes` and `restrictedRecords` use different repositories, rule matches, DTOs, screens, and export policies. Staff notes store author/category/visibility/revisions/links. Student reflections are a distinct student-safe type. Never fetch restricted records as part of ordinary student detail.

- [ ] **Step 3: Run Swift/rules tests and commit**

```bash
git add TMI/Features/Notes TMITests/Features/Notes firebase/test/collaboration.test.ts
git commit -m "feat: isolate restricted student records"
```

## Task 5: Add person-owned follow-up tasks

**Files:**
- Create: `TMI/Features/Tasks/TaskRecord.swift`
- Create: `TMI/Features/Tasks/TaskRepository.swift`
- Create: `TMI/Features/Tasks/TaskListView.swift`
- Create: `TMITests/Features/Tasks/TaskWorkflowTests.swift`

- [ ] **Step 1: Write failing task tests**

Test source link, owner, due date, status, reassignment permission, overdue state, completion attribution, notification event, and no cross-member reads outside collaboration scope.

- [ ] **Step 2: Implement task contracts**

```swift
struct TaskRecord: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let districtID: String
    let ownerID: String
    let source: RecordLink
    var title: String
    var dueAt: Date?
    var status: TaskStatus
    var metadata: CanonicalRecordMetadata
}
```

Meeting decisions, plan actions, form reviews, and broken resources may create a task through a trusted idempotent function; the task links back to its source.

- [ ] **Step 3: Build contextual task lists, test, and commit**

```bash
git add TMI/Features/Tasks TMITests/Features/Tasks
git commit -m "feat: add owned follow-up tasks"
```

## Task 6: Build event-derived in-app notifications

**Files:**
- Create: `TMI/Features/Notifications/AppNotification.swift`
- Create: `TMI/Features/Notifications/NotificationRepository.swift`
- Replace: `TMI/Views/Components/NotificationCenterView.swift`
- Create: `TMITests/Features/Notifications/NotificationTests.swift`
- Modify: `firebase/src/index.ts`

- [ ] **Step 1: Write failing notification tests**

Cover help request, survey completion, overdue form, upcoming meeting, missing notes, approval, requested changes, stale progress, explainable decline, completed resource, security event, event-key deduplication, category preference, authorized deep link, and redacted lock-screen copy.

- [ ] **Step 2: Implement event-keyed records**

Server event handlers create/update `notifications/{notificationId}` with recipient, category, event key, safe title/body, target route, read state, and server time. Push/email adapters remain disabled. Clients may update only read/dismiss state and personal preferences.

- [ ] **Step 3: Build notification center and test**

Group duplicate events, show category/status, support mark read/all read, and validate route authorization before navigation. Expected: tests pass.

- [ ] **Step 4: Commit**

```bash
git add TMI/Features/Notifications TMI/Views/Components/NotificationCenterView.swift TMITests/Features/Notifications firebase/src/index.ts
git commit -m "feat: add contextual in-app notifications"
```

## Task 7: Add permission-safe global search

**Files:**
- Create: `TMI/Features/Search/SearchResult.swift`
- Create: `TMI/Features/Search/SearchRepository.swift`
- Create: `TMI/Features/Search/GlobalSearchView.swift`
- Create: `TMITests/Features/Search/SearchAuthorizationTests.swift`

- [ ] **Step 1: Write failing search tests**

Test authorized students/plans/careers/resources, no restricted note indexing, assignment changes, district boundaries, active-student context, stale result denial, and deterministic ranking.

- [ ] **Step 2: Implement scoped search projections**

Search executes bounded queries per authorized domain and merges results by exact prefix, token match, then recency. Results carry safe subtitle and typed route; opening revalidates current permission and tenant.

- [ ] **Step 3: Build UI, run tests, and commit**

```bash
git add TMI/Features/Search TMITests/Features/Search
git commit -m "feat: add authorized global search"
```

## Task 8: Migrate collaboration data and remove duplicate services

**Files:**
- Modify: `firebase/src/migrationManifest.ts`
- Create: `firebase/fixtures/release4.json`
- Remove after migration: superseded form/resource/meeting/notification services, state models, and duplicate views with no callers

- [ ] **Step 1: Add fixtures for every collaboration domain**

Include user/top-level forms, submissions, resources, assignments, meetings, notes, notifications, malformed links, restricted content, and already-canonical records.

- [ ] **Step 2: Apply twice and reconcile**

Expected: immutable submissions and revisions remain intact, restricted data lands only in restricted paths, relationships resolve, second apply is zero-write, and reconciliation is zero.

- [ ] **Step 3: Remove legacy writers and dead top-level routes**

Search direct collection calls and old service names. Every production mutation must go through the domain repository/trusted function; forms/resources/meetings remain contextual rather than top-level tabs.

- [ ] **Step 4: Commit**

```bash
git add -A TMI firebase
git commit -m "refactor: retire legacy collaboration paths"
```

## Task 9: Release 4 acceptance

**Files:**
- Create: `docs/release-evidence/release-4.md`
- Create: `TMIUITests/SchoolCollaborationUITests.swift`

- [ ] **Step 1: Run universal gate and school collaboration journey**

Create/publish/assign/complete/review a form; assign/complete/reflect on a resource; schedule/complete a meeting and task; write ordinary/restricted/student-visible records; receive and open notifications; search each authorized domain; attempt restricted/cross-tenant access.

- [ ] **Step 2: Record evidence, commit, and tag**

```bash
git add TMIUITests/SchoolCollaborationUITests.swift docs/release-evidence/release-4.md
git commit -m "docs: record Release 4 acceptance"
git tag -a tmi-release-4-accepted -m "TMI Release 4 accepted"
```
