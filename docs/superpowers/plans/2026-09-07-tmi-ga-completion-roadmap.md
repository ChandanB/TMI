# TMI GA Completion Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans for implementation. Track verified outcomes with checkboxes. Delegated implementation uses only Sol, Terra, or Luna. This is the program-level sequencing and acceptance plan; use the linked subsystem plans for implementation detail, updating them against current code before each slice.

**Goal:** Complete the remaining institutional workflows and prove TMI ready for general availability while preserving the substantially implemented canonical intervention loop.

**Architecture:** One district-scoped institutional model, member-authorized repositories, trusted backend mutations for protected operations, and durable offline operations for permitted edits. SwiftUI presents explicit loading, error, permission, pending, and conflict states. Server-owned metrics, audit, migration, and release evidence establish institutional readiness.

**Tech Stack:** Swift 6, SwiftUI, Firebase Auth/Firestore/Functions, Swift Testing, XCTest, Firebase Emulator Suite, Xcode distribution tooling.

## Authority and starting evidence

- Product authority: [July 19 specification](../specs/2026-07-19-tmi-final-product-blueprint-design.md), including Aubergine + Teal and sections 16–18, 21, and 23–28.
- Preserve completed work from [September 4 completion plan](2026-09-04-product-completion.md) and [September 5 student-plan evidence](../../release-evidence/student-plan-hub.md). That evidence records 568 Swift Testing cases, 164 XCTest cases with three existing skips, four plan UI tests, 258 Firebase tests, and an unsigned macOS Release build. These are historical results for that increment, not current GA or distribution proof.
- Continue [Release 4 collaboration](2026-07-20-tmi-release-4-school-collaboration.md), [Release 5 district pilot](2026-07-20-tmi-release-5-district-pilot.md), and [GA hardening](2026-07-20-tmi-ga-hardening.md). Their unchecked tasks must be reconciled with implemented code rather than assumed missing.
- September 7 inspection: `main` has exactly two modified tracked files, the Debug invitation provisioner and its tests. The edit changes the school **identifier**, not just its display label, from `school-debug` to `Lincoln Elementary`.
- Current spot checks confirm legacy `FormAssignmentService` submission writes, unavailable private notes in `StudentDetailState`, and `serverMetricsUnavailable` in district analytics. `reviewSurveyResponse` already exists; assess and extend its actual contract before introducing any duplicate backend review operation.
- This planning pass does not rerun application tests, alter the Debug edits, deploy infrastructure, or establish a new verified baseline.

## Delivery order and dependencies

| Gate | Deliverable | Depends on |
|---|---|---|
| G0 | Clean, reproducible baseline and current coverage map | Existing core evidence |
| G1 | Canonical Forms from assignment through trusted review/export | G0; shared operation contract |
| G2 | Notes, person-owned tasks, notifications, authorized search | G1; shared operation contract |
| G3 | Server-owned district reporting and administration | G1; canonical collaboration events |
| G4 | Complete production legacy-path cutover and reconciliation | G1–G3 consumers migrated |
| G5 | Durable offline replay, conflict recovery, production UX hardening | Early sync foundation; all canonical repositories |
| G6 | Migration, security, privacy, restore, operational readiness | G4–G5 |
| G7 | Deployed release candidate, distribution tests, pilot, GA decision | G6 and all evidence gates |

Build stable operation IDs, version preconditions, and error contracts during G0/G1. Integrate offline behavior in every subsequent feature slice; G5 proves coverage and recovery across them. Port legacy callers alongside their replacement features, then use G4 as the final zero-legacy-production-I/O gate. Staging configuration and deployment rehearsals begin early; production deployment remains a separately recorded release action.

## G0 — Establish the next baseline

**Existing files:** `TMI/Features/Authentication/DebugStaffInvitationProvisioner.swift`, `TMITests/Features/Authentication/DebugStaffInvitationProvisionerTests.swift`, `SWIFT_CODING_STANDARDS.md`.

- [ ] Read coding standards and local instructions before implementation. Record starting SHA, tracked/untracked changes, toolchain, destinations, Firebase project configuration, and signing mode.
- [ ] Inspect every Debug school-ID consumer and fixture. Prefer a stable machine identifier with `Lincoln Elementary` as the display name unless an intentional fixture migration requires otherwise. Verify teacher and administrator registration, membership, roster access, and local plan access together. Do not discard the existing edits or simply update assertions to match an inconsistent identifier.
- [ ] Commit the verified Debug resolution separately; establish a clean implementation branch using the `codex/` prefix.
- [ ] Create `docs/release-evidence/ga-baseline.md` and `docs/release-evidence/ga-contract-matrix.md`. Map each required route to its repository, storage path, authorization rule, tests, evidence, and remaining defect. Mark implemented, verified, partial, missing, or externally blocked separately.
- [ ] Run the unit, focused canonical-loop UI, Firebase emulator, and macOS Release baseline. Record failures as current regressions; do not erase the September 5 evidence or treat old checklist state as fresh failure.
- [ ] Define the shared operation envelope: stable operation ID, actor/tenant scope, target, command kind, payload/schema version, expected record version, and creation time. Define duplicate-success, conflict, retryable failure, and revoked-access results. Backend deduplication binds actor, scope, and payload so reuse cannot mutate another target.

**Exit:** Debug identity is consistent; baseline SHA and actual results are recorded; remaining work has a traceable inventory.

## G1 — Finish Forms end-to-end

**Existing integration points:** `TMI/Services/FormAssignmentService.swift`, `TMI/Services/FormSubmissionService.swift`, `TMI/Services/FormService.swift`, `TMI/Models/FormModels/`, `TMI/Views/Forms/FormCompletionView.swift`, `TMI/Views/Forms/SubmissionReviewView.swift`, `firebase/src/index.ts`, `firestore.rules`.

**Implementation reference:** Release 4 Task 1. Reuse existing canonical form types/repositories found during G0 instead of creating a parallel model.

- [ ] Inventory all general-form draft, submission, review, and export readers/writers, including alternate form screens and respondent-session entry points.
- [ ] Persist respondent records under `districts/{district}/formAssignments/{assignment}/respondents/{respondent}`. Bind assignment, respondent identity/session, published template version, student/plan context, and scope server-side.
- [ ] Keep drafts editable/autosaved; trusted submission validates conditional required fields and template version and atomically freezes the answer payload. Submitted answers cannot be edited by clients or by review. Separate review metadata/history from frozen answer content.
- [ ] Extend the trusted review boundary to preserve the canonical score, maximum score, comments, reviewer attribution, version, and audit contract. Compute score from the explicit published scoring definition; reject client-supplied computed scores. Unscored forms remain unscored.
- [ ] Make submit/review retries idempotent and concurrent review conflicts explicit. Enforce district/school/capability/session/assignment boundaries in backend and rules; deny direct review or submitted-answer mutations.
- [ ] Wire assignment → completion → submitted receipt → staff review → authorized export. Cover staff, Student Mode, and guardian respondent routes allowed by the specification; preserve overdue and not-started/in-progress/submitted/reviewed states.
- [ ] Migrate legacy submissions with deterministic identity mapping, dry-run output, duplicate detection, and provenance. Quarantine unresolved ownership rather than guessing. Cut over all runtime writers and readers once reconciliation passes.
- [ ] Verify immutable answers, scoring tampering, malformed answers, expired sessions, cross-tenant access, concurrent submit/review, retry after server success, draft restart, and permission-safe exports with Swift, callable, rules, and UI tests.

**Exit:** A real assigned form can be completed, reviewed, reopened, and exported through canonical storage; the client cannot forge scores or change submitted answers. Record evidence in `docs/release-evidence/ga-forms.md`.

## G2 — Complete collaboration

**Existing integration points:** `TMI/Features/Students/StudentDetailState.swift`, `TMI/Services/NotificationService.swift`, `TMI/Views/Components/NotificationCenterView.swift`, `firebase/src/index.ts`, `firestore.rules`.

**Planned feature ownership:** `TMI/Features/Notes/`, `TMI/Features/Tasks/`, `TMI/Features/Notifications/`, `TMI/Features/Search/`; reuse existing canonical implementations if present. Execute as four separately reviewable slices using Release 4 Tasks 4 onward.

- [ ] **Notes:** Implement author, category, visibility, linked records, timestamps, and revision history. Physically separate restricted records. Define author-private versus explicitly granted restricted access in the policy matrix; ordinary school/district administration must not implicitly grant access. Replace the student-detail unavailable state with reachable authorized list/create/edit/history flows. Verify another staff member cannot discover restricted content through queries, search, exports, notifications, or caches.
- [ ] **Tasks:** Connect person-owned tasks to canonical task paths with owner, source link, due date, status, and version. Support standalone creation, follow-up creation from meetings/notes, editing, completion, reopening, and overdue views. Validate owner/assignee changes and visibility on the server; plan actions remain distinct records. Test deterministic source-event deduplication and unauthorized reassignment.
- [ ] **Notifications:** Replace user-scoped institutional notification writes with the approved canonical repository and trusted event producers. Cover required event categories, event-key grouping, unread/read state, and preferences. Keep payload previews free of sensitive student content. Push/email remain disabled unless their separate configuration and consent gates are met.
- [ ] **Deep links:** Resolve exact targets after current membership/capability validation. Handle cold launch, sign-in, wrong active district, deleted record, revoked access, and stale student context. Show the selected context before any mutation; denied destinations expose no protected preview.
- [ ] **Search:** Implement bounded, paginated authorized search across students, plans, careers, and resources. Choose queries/projections from the actual Firestore authorization model; never fetch broad protected data and filter it only in the client. Test cross-tenant denial, stale requests, context changes, inaccessible hits, pagination, empty/error/offline states, and authorized result navigation.
- [ ] Regress ported resources, meetings, and recommendations, including calendar permission denial and safe calendar text. Confirm follow-ups and notifications work with their real canonical records.

**Exit:** Each collaboration capability is reachable, persistent, and authorization-safe from its intended student/plan or personal context. Record `docs/release-evidence/ga-collaboration.md`.

## G3 — District analytics, reporting, and administration

**Existing integration points:** `TMI/Services/DistrictAnalyticsService.swift`, `TMI/Models/DistrictAnalytics.swift`, `TMI/Views/District/DistrictDashboardView.swift`, `firebase/src/index.ts`.

**Planned responsibilities:** `firebase/src/metrics.ts` for canonical calculations; `TMI/Features/Analytics/` for snapshot DTOs/readers; administration, audit, retention, and reports under their corresponding feature directories. Reconcile with Release 5 before adding files.

- [ ] Implement one versioned metric dictionary defining numerator, denominator, time window/timezone, exclusions, freshness, and sample suppression. Cover schools, active staff, students served, surveys, interests, plan status/model distribution, timeliness, approval duration, and engagement/completion trends. Distinguish zero, unavailable, stale, and insufficient sample.
- [ ] Produce server-owned `metricSnapshots` from canonical data/events. Make event replay, late events, rebuild, and backfill deterministic and idempotent; deny client snapshot writes. Replace obsolete analytics and form-assignment reads.
- [ ] Support school, staff, grade-band, and date filters within authorized scope. Include staff attribution/deduplication rules in the metric dictionary. Dashboards read bounded snapshots rather than scanning institutional records on-device.
- [ ] Implement capability-checked, reasoned, audited student drill-down with expiring access where required by Release 5. Aggregate access does not imply detail access; revalidate scope when navigating and exporting.
- [ ] Generate redacted PDF/CSV evidence reports through trusted, audited operations. Report formulas, filter scope, snapshot version, and freshness consistently with dashboards. Verify temporary files and downloads obey access and retention policy.
- [ ] Complete schools, invitations, staff activation/deactivation, roles/capabilities, assignments, district templates/resources, retention/legal holds, and audit review. Prevent self-escalation and grants beyond the actor's authority.
- [ ] Test metrics against hand-calculated fixtures, including empty populations, timezone boundaries, duplicates, excluded/cancelled records, school/staff filters, suppression, revoked access, and dashboard/export reconciliation.

**Exit:** District staff can administer permitted scope and obtain reproducible, truthful reports without obsolete collections or placeholder metrics. Record `docs/release-evidence/ga-district-reporting.md`.

## G4 — Eliminate remaining production legacy architecture

**Existing targets:** `TMI/Services/TMIPlanService.swift`, `TMI/Services/ResourceAssignmentService.swift`, `TMI/Services/StudentInterestSynchronizer.swift`, plus approval, list, student-context, export, district analytics, and bootstrap callers discovered by symbol/path inventory.

- [ ] Classify each reference as active production runtime, Debug fixture, migration input, or historical documentation. Personal account collections remain valid where the contract permits them; the gate concerns obsolete institutional storage, not every `users/` occurrence.
- [ ] Port remaining plan consumers to `TMI/Features/Plans/CanonicalPlanRepository.swift` and the trusted lifecycle operations. Port resource assignment consumers to canonical relationship documents.
- [ ] Remove production service registration, bootstrap reads/writes, and duplicate screens using legacy repositories only after replacement routes pass. Preserve referenced migration provenance and intentionally isolated Debug support.
- [ ] Add a scoped CI guard for forbidden institutional path construction and obsolete service imports. Pair static checks with repository/emulator tests; dynamic path construction must also be covered.
- [ ] Reconcile legacy/canonical counts, stable IDs, relationships, approvals/history, authorship, and restricted visibility. Prove repeated and interrupted migration converges without dual writers. Keep ambiguous ownership in an explicit repair report.
- [ ] Deny obsolete production writes in rules after compatible cutover. Define supported old-client behavior and forward repair; rollback must not reactivate legacy writes.

**Exit:** One production institutional data model; no active legacy plan/form/resource/notification I/O; migration inputs remain identifiable and reconciliation has no unexplained discrepancies. Record `docs/release-evidence/ga-data-cutover.md`.

## G5 — Complete offline synchronization and production hardening

**Planned sync files from GA hardening:** `TMI/Core/Sync/SyncOperation.swift`, `SyncCoordinator.swift`, `ConflictResolution.swift`, `SyncStatusView.swift`, `TMITests/Core/SyncCoordinatorTests.swift`.

- [ ] Persist the early operation contract in protected local storage, partitioned by account and district. Process in order per aggregate, permit independent work concurrently, and survive termination between enqueue, server commit, and acknowledgment. Persist deduplication on the trusted side, not only in app memory.
- [ ] Cover cached reads, draft survey/form answers, draft plan text, new notes/reflections/independent progress, and personal preferences. Keep approvals, membership/assignment changes, session issuance, deletion, sensitive export, and multi-record destructive actions online-only.
- [ ] Merge append-only operations by stable ID. Enforce expected versions on mutable roots; retain local and server drafts and offer explicit field-level resolution. Retrying a conflict cannot silently overwrite the server version.
- [ ] Revalidate authorization on replay. Block revoked writes, explain failure, isolate queued work on sign-out/account switch, and clear protected cached content according to policy without discarding unrelated authorized drafts.
- [ ] Present pending/syncing/succeeded/failed counts, durable errors, and safe retry/discard actions. Test restart, reconnect, partial success, duplicate delivery, stale versions, revocation, tenant changes, and denied online-only actions in UI as well as coordinator tests.
- [ ] Complete Aubergine + Teal consolidation and audit every reachable control. Cover loading, empty, error, permission denied, offline, conflict, and success states. Remove production sample fallbacks, fake metrics, dead controls, and raw logging; preserve explicit unavailable states for real failures.
- [ ] Verify iPhone/iPad/macOS layout, largest Dynamic Type, VoiceOver, keyboard access, contrast, Reduce Motion, and non-color state cues. Record design review for significant UI changes.
- [ ] Measure the existing contract budgets: cached shell p95 ≤2 seconds, cached detail ≤1 second, loading feedback ≤250 ms, first online page p95 ≤3 seconds, reconnect convergence p95 ≤60 seconds, and bounded 50-record pages. Record device, network, dataset size, sample count, and failures.

**Exit:** Permitted work survives offline/restart without duplication, unauthorized replay, or silent data loss; critical screens meet accessibility and measured performance gates. Use the GA hardening evidence files for sync, accessibility, logging/privacy, and performance.

## G6 — Prove migration, security, privacy, and recovery

- [ ] Rehearse clean install and legacy upgrade for every supported schema/role, mixed data, interrupted migration, duplicate identity, unresolved ownership, historical plans, and queued offline writes. Validate institutional retention after educator deletion.
- [ ] Validate the visible Profile → Delete Account reviewer path, reauthentication, personal-data cleanup/export, retained institutional attribution, idempotent retry, and final signed-out state. Match privacy disclosures to actual behavior and archive contents.
- [ ] Run allow/deny rules and callable matrices for teacher, counselor, social worker, school admin, district admin, Student Mode, guardian respondent, unauthenticated/expired sessions, and revoked memberships. Include query/list access, field tampering, restricted records, Storage, exports, task ownership, notifications, search, and aggregate/detail boundaries.
- [ ] Configure backups and alerts; restore into an isolated environment and verify content, referential integrity, Storage links, audit continuity, restricted permissions, and identity/membership recovery. Prove RPO ≤24 hours and RTO ≤8 hours.
- [ ] Complete incident, deployment/rollback, migration-repair, retention/legal-hold, and operational ownership runbooks. Rehearse alert delivery without exposing student content.
- [ ] Obtain an independent security review covering authorization, Functions/rules/Storage, sessions, local persistence, dependencies, logging, retention, exports, deletion, and backup. Resolve all critical/high findings; record disposition and owner for any accepted lower-severity finding.

**Exit:** Rehearsals are repeatable and evidenced; no critical/high security findings remain; recovery and privacy behavior match the contract. External review and credentials are explicit dependencies, never inferred successes.

## G7 — Release-test and make the GA decision

- [ ] Deploy the candidate Functions, rules, indexes, and required configuration to staging; record project ID, source SHA, deployment outcome, index readiness, App Check/session configuration, and live smoke results. Run the full canonical loop against deployed staging, not only emulators.
- [ ] From a clean checkout, run unit, emulator, UI, accessibility, performance, migration, and Release build gates. Investigate existing skips; explain any remaining skip and provide alternative coverage for a required behavior.
- [ ] Produce and validate the signed App Store archive. Verify bundle/version, entitlements, signing, privacy manifests/report, icons, reviewer account/path, support/privacy/terms metadata, and absence of Debug/sample assets.
- [ ] Install through TestFlight on representative physical iPhone and iPad devices. Exercise core loop, Forms/review, notes/tasks, notification cold-launch links, search, district reports, offline recovery, export, and account deletion.
- [ ] Verify the selected macOS distribution channel: signed distribution validation and notarization where applicable, installation/update, permissions, keyboard/navigation, and canonical workflows. An unsigned Release build does not satisfy this gate.
- [ ] Run the district-pilot simulation across every role with production-shaped synthetic data. Capture workflow, reconciliation, accessibility, privacy, support, and district acceptance evidence.
- [ ] Deploy the approved production backend/configuration with recorded rollback/forward-repair readiness; run a scoped production smoke test. Record external access or approval blocks separately from application defects.
- [ ] Audit specification Section 28 line by line against evidence at the exact candidate SHA. Tag/release only after all mandatory gates pass and the release decision is recorded. Optional AI remains disabled or absent unless independently accepted.

**Exit:** `docs/release-evidence/ga-release-checklist.md` identifies the exact source SHA, deployed backend, signed build, device results, security disposition, pilot sign-off, and release decision.

## Verification and execution discipline

Each slice follows: reproduce a specific missing behavior with a focused test; implement the smallest complete vertical flow; verify rules/callables and reachable UI; review; commit the slice and its evidence. Run broader regression at integration boundaries. Do not rewrite working core features or duplicate canonical repositories based on stale file maps.

Verified backend script entry points from the current package:

```bash
npm --prefix firebase run lint
npm --prefix firebase run build
npm --prefix firebase test
```

Expected: exit zero and actual suite/build success. Use a test Firebase project; record the invoked project and configuration. Resolve Xcode scheme and available destinations during G0 and store the exact commands in the baseline evidence instead of inventing device IDs here. Save exit status, logs, and result bundles for each release gate; absent or transient `/tmp` artifacts are not durable release evidence.

Every evidence entry includes candidate SHA, tool versions, environment/project, command, expected/actual result, durable artifact location, uncovered cases, and reviewer. Track separate states for local verification, staging verification, distribution verification, and pilot acceptance.

Parallel work may cover independent feature slices after shared authorization/operation contracts are fixed. Keep shared `firebase/src/index.ts`, rules, dependency wiring, and navigation integration under one owner. Security and migration checks accompany feature work; final review does not replace them.

## Completion rule

Product construction is complete when G1–G5 pass. Institutional operational readiness requires G6. TMI is GA-ready only when G7 and every mandatory Section 28 criterion have evidence. A passing local suite, completed plan, successful deployment, or signed archive alone is insufficient.
