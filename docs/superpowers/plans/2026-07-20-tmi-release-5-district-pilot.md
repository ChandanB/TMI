# TMI Release 5 District Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver least-privilege school/district administration, truthful aggregate analytics, audited drill-down, retention enforcement, and evidence reporting for a production-shaped district pilot.

**Architecture:** Privileged mutations remain server-only. Metric snapshots are produced from canonical events by one versioned calculation library and consumed by dashboards/exports. Administrators receive aggregates by default; student detail requires an explicit capability, reason code, online revalidation, and protected audit event.

**Tech Stack:** Swift 6.2, SwiftUI Charts, Firestore, Cloud Functions scheduled/callable triggers, Firebase Emulator Suite, PDF/CSV export, Swift Testing, XCTest UI automation

---

## File map

| Action | Path | Responsibility |
|---|---|---|
| Create | `TMI/Features/Administration/SchoolAdministrationRepository.swift` | Schools, invitations, staff, assignments |
| Create | `TMI/Features/Administration/StaffAdministrationView.swift` | Privileged management UI |
| Create | `TMI/Features/Analytics/MetricDefinition.swift` | Shared formula IDs/windows/exclusions |
| Create | `TMI/Features/Analytics/MetricSnapshot.swift` | Precomputed aggregate DTO |
| Create | `TMI/Features/Analytics/DashboardRepository.swift` | Aggregate snapshot reads |
| Replace | `TMI/Views/Dashboard/DashboardView.swift` | Deterministic staff/admin dashboard |
| Replace | `TMI/Views/District/DistrictDashboardView.swift` | District filters and reconciled evidence |
| Create | `TMI/Features/Administration/StudentDrillDownGrant.swift` | Reasoned, expiring access grant |
| Create | `TMI/Features/Retention/RetentionPolicy.swift` | District policy and legal holds |
| Create | `TMI/Features/Retention/RetentionRepository.swift` | Server policy management |
| Create | `TMI/Features/Compliance/ConsentRecord.swift` | Versioned consent/withdrawal history |
| Create | `TMI/Features/Compliance/ConsentRepository.swift` | Permission-safe consent management |
| Create | `TMI/Features/Audit/AuditEvent.swift` | Protected event projection |
| Create | `TMI/Features/Audit/AuditRepository.swift` | Privileged audit queries |
| Create | `TMI/Features/Reports/DistrictReportRenderer.swift` | Redacted PDF/CSV reports |
| Create | `firebase/src/metrics.ts` | Canonical metric calculations |
| Create | `firebase/src/retention.ts` | Scheduled retention enforcement |
| Create | `firebase/test/administration.test.ts` | Privileged authorization |
| Create | `firebase/test/metrics.test.ts` | Formula and reconciliation fixtures |
| Create | `firebase/test/retention.test.ts` | Policy/legal-hold behavior |
| Create | `firebase/fixtures/release5.json` | District migration/pilot fixture |

## Task 1: Implement trusted school/staff administration

**Files:**
- Create: `TMI/Features/Administration/SchoolAdministrationRepository.swift`
- Create: `TMI/Features/Administration/StaffAdministrationView.swift`
- Modify: `firebase/src/index.ts`
- Create: `firebase/test/administration.test.ts`
- Create: `TMITests/Features/Administration/AdministrationPolicyTests.swift`

- [ ] **Step 1: Write failing privilege tests**

Test school admin limited to own schools, district admin limited to own district, invitation role request versus granted role, activation/deactivation, capability grant/revoke/version, student assignment, explicit plan approval, restricted-record non-inheritance, and no client direct writes.

- [ ] **Step 2: Implement trusted repository calls**

```swift
protocol SchoolAdministrationRepository: Sendable {
    func schools(member: MembershipContext) async throws -> [SchoolRecord]
    func members(schoolID: String, member: MembershipContext) async throws -> [MembershipContext]
    func invite(_ request: InvitationRequest, operationID: UUID, member: MembershipContext) async throws -> InvitationRecord
    func updateMembership(_ command: MembershipCommand, expectedVersion: Int, operationID: UUID, member: MembershipContext) async throws -> MembershipContext
    func assignStudent(_ command: StudentAssignmentCommand, operationID: UUID, member: MembershipContext) async throws
}
```

Every function validates capability, tenant/school scope, target role ceiling, version, and operation ID and writes an audit event. No administrator can grant a capability they do not possess or change their own role.

- [ ] **Step 3: Build accessible administration UI**

Provide schools, pending invitations, active/inactive staff, role, explicit permissions, assignments, revocation confirmation, and audit link. Use standard professional language and show scope before mutation.

- [ ] **Step 4: Run Swift/emulator tests and commit**

```bash
git add TMI/Features/Administration TMITests/Features/Administration firebase
git commit -m "feat: add trusted school administration"
```

## Task 2: Implement the canonical metric dictionary

**Files:**
- Create: `TMI/Features/Analytics/MetricDefinition.swift`
- Create: `TMI/Features/Analytics/MetricSnapshot.swift`
- Create: `firebase/src/metrics.ts`
- Create: `firebase/test/metrics.test.ts`
- Create: `TMITests/Features/Analytics/MetricDefinitionTests.swift`

- [ ] **Step 1: Write one exact fixture per formula**

Test assigned students; active plans; staff adoption trailing 30 days; survey completion excluding cancelled; follow-up timeliness; student action completion; 28-day engagement comparison requiring four due actions in both windows; school/grade/date filters; timezone boundaries; and minimum sample suppression.

```swift
enum MetricID: String, Codable, Sendable {
    case assignedStudents, staffAdoption, surveyCompletion, activePlans
    case followUpTimeliness, studentActionCompletion, engagementTrend
}

struct MetricSnapshot: Codable, Sendable, Equatable {
    let metricID: MetricID
    let formulaVersion: Int
    let scope: MetricScope
    let window: DateInterval
    let numerator: Double
    let denominator: Double?
    let value: Double?
    let suppressedReason: String?
}
```

- [ ] **Step 2: Implement one server calculation library**

Scheduled/event-driven functions update district/school/staff snapshots from canonical events. Dashboard and export DTOs read these snapshots; no client recomputes definitions or scans student records.

- [ ] **Step 3: Reconcile fixture source events to snapshots**

Expected: every snapshot numerator/denominator/value equals the hand-calculated fixture and rerunning aggregation is idempotent.

- [ ] **Step 4: Run tests and commit**

```bash
git add TMI/Features/Analytics firebase/src/metrics.ts firebase/test/metrics.test.ts TMITests/Features/Analytics
git commit -m "feat: define canonical district metrics"
```

## Task 3: Rebuild staff and administrative dashboards

**Files:**
- Create: `TMI/Features/Analytics/DashboardRepository.swift`
- Create: `TMI/Features/Analytics/NextBestAction.swift`
- Replace: `TMI/Views/Dashboard/DashboardView.swift`
- Replace: `TMI/Views/District/DistrictDashboardView.swift`
- Create: `TMITests/Features/Analytics/NextBestActionTests.swift`
- Create: `TMIUITests/DashboardUITests.swift`

- [ ] **Step 1: Write failing Next Best Action tests**

Assert exact priority: help request; requested plan changes; current-user approval; overdue meeting notes; overdue progress/review; submitted survey review; interests/no plan; no interests; first student. Assert destination route and authorization.

- [ ] **Step 2: Implement attention reasons and ordered action policy**

Reasons remain visible labels: open help request, review over seven days late, progress late beyond cadence plus seven days, or eligible completion decline at least 20 percentage points. Do not collapse them into a hidden score.

- [ ] **Step 3: Build role-specific dashboards**

Header shows greeting, name/role, context, profile, notification, sign-out, sync/offline. Staff dashboard shows assigned students, students without interests or active plans, active plans, stale progress, pending forms/surveys, upcoming meetings, labeled attention reasons, recent activity, engagement/completion trends, and contextual quick actions. Admin dashboard shows students served, staff adoption, survey completion, plan lifecycle counts, approval queue, missing follow-up, model distribution, and school/grade/date filters. Charts include accessible text summaries and non-color encoding.

- [ ] **Step 4: Run tests and commit**

```bash
git add TMI/Features/Analytics TMI/Views/Dashboard TMI/Views/District/DistrictDashboardView.swift TMITests/Features/Analytics TMIUITests/DashboardUITests.swift
git commit -m "feat: deliver truthful role dashboards"
```

## Task 4: Add explicit audited student drill-down

**Files:**
- Create: `TMI/Features/Administration/StudentDrillDownGrant.swift`
- Create: `TMI/Features/Administration/StudentDrillDownView.swift`
- Modify: `firebase/src/index.ts`
- Modify: `firebase/test/administration.test.ts`

- [ ] **Step 1: Write failing drill-down tests**

Test default aggregate-only admin, required `.studentReadDetail`, non-empty approved reason code, online revalidation, bounded expiration, target student/district, protected audit event, revoked permission, and restricted-record denial.

- [ ] **Step 2: Implement expiring grants**

```swift
struct StudentDrillDownGrant: Codable, Sendable, Equatable {
    let grantID: String
    let administratorID: String
    let studentID: String
    let districtID: String
    let reason: DrillDownReason
    let expiresAt: Date
}
```

The function validates explicit permission and reason, caps grant at 15 minutes, audits issuance and each sensitive read, and returns a student-safe administrative projection excluding restricted records.

- [ ] **Step 3: Build confirmation UI, run tests, and commit**

```bash
git add TMI/Features/Administration firebase/src/index.ts firebase/test/administration.test.ts
git commit -m "feat: audit administrative student drill-down"
```

## Task 5: Implement retention policies, legal holds, and student archive/delete

**Files:**
- Create: `TMI/Features/Retention/RetentionPolicy.swift`
- Create: `TMI/Features/Retention/RetentionRepository.swift`
- Create: `TMI/Features/Retention/RetentionSettingsView.swift`
- Create: `firebase/src/retention.ts`
- Create: `firebase/test/retention.test.ts`
- Create: `TMITests/Features/Retention/RetentionPolicyTests.swift`

- [ ] **Step 1: Write failing retention tests**

Test district-selected supported policy, active versus archived record, legal hold override, immutable audit/history preservation, dry-run count, idempotent job, failure retry, and authorized student archive/deletion projection.

- [ ] **Step 2: Implement policy without pretending law is universal**

Store the district's approved policy version, effective date, record-class durations within supported product bounds, legal holds, approver, and audit ID. The UI requires institutional confirmation; the system does not label a configurable duration as universal FERPA compliance.

- [ ] **Step 3: Implement scheduled enforcement**

The server job computes eligible records, writes a protected dry-run report, requires policy activation, skips legal holds, deletes/anonymizes by record class, preserves immutable required history, and records counts/checksums. Replays are idempotent.

- [ ] **Step 4: Run tests and commit**

```bash
git add TMI/Features/Retention TMITests/Features/Retention firebase/src/retention.ts firebase/test/retention.test.ts
git commit -m "feat: enforce district retention policies"
```

## Task 6: Consolidate consent and policy acknowledgments

**Files:**
- Create: `TMI/Features/Compliance/ConsentRecord.swift`
- Create: `TMI/Features/Compliance/ConsentRepository.swift`
- Replace: `TMI/Views/Compliance/ConsentManagementView.swift`
- Create: `TMITests/Features/Compliance/ConsentRepositoryTests.swift`
- Modify: `firebase/test/administration.test.ts`

- [ ] **Step 1: Write failing consent tests**

Test student/district scope, consent type, policy/document version, consenting party reference, granted/declined/withdrawn state, effective/server timestamp, append-only history, current projection, role/capability boundary, respondent-session submission, and audit event without copying signature/content into telemetry.

- [ ] **Step 2: Implement append-only consent records**

```swift
struct ConsentRecord: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let districtID: String
    let studentID: String
    let documentID: String
    let documentVersion: Int
    let respondentReference: String
    let state: ConsentState
    let effectiveAt: Date
    let recordedBy: String
}
```

New consent, refusal, renewal, and withdrawal append records; no client edits prior history. The current state is a server-derived projection. Staff policy acknowledgments use the same document/version/timestamp principle under the member path.

- [ ] **Step 3: Build permission-safe management UI**

Show required/received/declined/withdrawn/expired states, document version, effective time, and authorized actions. Never expose one student's consent to unrelated staff or another respondent session.

- [ ] **Step 4: Run Swift/rules tests and commit**

```bash
git add TMI/Features/Compliance TMI/Views/Compliance/ConsentManagementView.swift TMITests/Features/Compliance firebase/test/administration.test.ts
git commit -m "feat: preserve consent and acknowledgment history"
```

## Task 7: Consolidate protected audit views

**Files:**
- Create: `TMI/Features/Audit/AuditEvent.swift`
- Create: `TMI/Features/Audit/AuditRepository.swift`
- Replace: `TMI/Views/Compliance/AuditLogListView.swift`
- Create: `TMITests/Features/Audit/AuditRepositoryTests.swift`

- [ ] **Step 1: Write failing audit tests**

Test authoritative server source, privileged event categories, tenant/school scope, own-action view, administrator audit permission, sensitive-read details, export, pagination, immutable event, and client-write denial.

- [ ] **Step 2: Implement safe projections**

Audit events contain actor opaque ID, tenant/school, action, target type/opaque ID, reason code, result, server time, correlation ID, and redacted metadata. They never copy student names, note text, survey answers, or plan content.

- [ ] **Step 3: Build filterable audit UI, run tests, and commit**

```bash
git add TMI/Features/Audit TMI/Views/Compliance/AuditLogListView.swift TMITests/Features/Audit
git commit -m "feat: expose protected audit evidence"
```

## Task 8: Implement district-safe reports and exports

**Files:**
- Create: `TMI/Features/Reports/DistrictReportProjection.swift`
- Create: `TMI/Features/Reports/DistrictReportRenderer.swift`
- Replace: `TMI/Services/DistrictExportService.swift`
- Create: `TMITests/Features/Reports/DistrictReportTests.swift`
- Modify: `firebase/src/index.ts`

- [ ] **Step 1: Write failing report tests**

Test school/grade/date filters, formula version, aggregate suppression, redaction, explicit student-detail permission when applicable, PDF/CSV values, online revalidation, and export audit event.

- [ ] **Step 2: Implement server-authorized report DTOs**

Reports use the same metric snapshots as dashboards and include scope/window/formula version/generated time. Default district evidence has no student names/IDs. Sensitive exports require explicit capability and purpose and are not cached unencrypted.

- [ ] **Step 3: Run content/render tests and commit**

```bash
git add TMI/Features/Reports TMI/Services/DistrictExportService.swift TMITests/Features/Reports firebase/src/index.ts
git commit -m "feat: export reconciled district evidence"
```

## Task 9: Run production-shaped district simulation and security review

**Files:**
- Create: `firebase/fixtures/release5.json`
- Create: `docs/release-evidence/release-5-security-review.md`
- Create: `docs/release-evidence/release-5-simulation.md`

- [ ] **Step 1: Seed the simulation fixture**

Include two districts, three schools per district, all five staff roles, active/inactive memberships, explicit permissions, assigned/unassigned students, restricted records, full plan lifecycles, forms, meetings, tasks, and metrics around timezone/minimum-sample boundaries.

- [ ] **Step 2: Run adversarial authorization tests**

Attempt self-promotion, cross-user/school/district reads, guessed IDs, client audit/metric writes, revoked session, export redaction bypass, drill-down without reason, and Storage traversal. Expected: every attempt is denied and audited where appropriate.

- [ ] **Step 3: Complete an independent security review**

Provide schema, rules, function authorization, respondent sessions, retention, deletion, exports, and threat model to the reviewer. Resolve every critical/high finding and record disposition for lower severities.

- [ ] **Step 4: Commit evidence**

```bash
git add firebase/fixtures/release5.json docs/release-evidence/release-5-security-review.md docs/release-evidence/release-5-simulation.md
git commit -m "docs: record district security simulation"
```

## Task 10: Migrate district data and retire duplicate analytics

**Files:**
- Modify: `firebase/src/migrationManifest.ts`
- Remove after migration: `TMI/Services/DistrictAnalyticsService.swift`
- Remove after migration: `TMI/ViewModels/DistrictDashboardViewModel.swift`
- Remove after migration: duplicate district metric/analytics models and dashboard components with no callers

- [ ] **Step 1: Transform legacy schools/staff/analytics/settings**

Preserve original role values in migration audit, map canonical roles, quarantine unresolved scope, and regenerate metrics from canonical events rather than copying unverified totals.

- [ ] **Step 2: Apply twice and reconcile**

Expected: membership/school/assignment counts reconcile; generated metrics equal source-event fixtures; second apply is zero-write.

- [ ] **Step 3: Remove legacy readers/writers and commit**

```bash
git add -A TMI firebase
git commit -m "refactor: retire legacy district analytics"
```

## Task 11: Release 5 acceptance

**Files:**
- Create: `docs/release-evidence/release-5.md`

- [ ] **Step 1: Run the universal gate and district pilot journey**

Manage a school/member/assignment, inspect school/district aggregates, request audited student drill-down, approve a plan, configure/test retention, inspect audit evidence, and export a redacted report. Verify dashboard/export reconciliation and cross-district denial.

- [ ] **Step 2: Record evidence, commit, and tag**

```bash
git add docs/release-evidence/release-5.md
git commit -m "docs: record Release 5 acceptance"
git tag -a tmi-release-5-accepted -m "TMI Release 5 accepted"
```
