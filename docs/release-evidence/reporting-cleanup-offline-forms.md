# District reporting, legacy cleanup, offline sync, and forms completion

Date: 2026-09-22 · Branch: `feat/reporting` · Project: `tmi-education`

## Crash fix: Firestore cache lock

A second copy of the Mac app sharing the container aborted in LevelDB
(`LOCK: Resource temporarily unavailable`). `FirestoreCacheLock` probes the lock
with `F_GETLK` before Firestore starts; if another process holds it, the app
uses a memory cache instead of crashing. `enableOfflineMode` now keeps existing
settings (it previously overwrote the DEBUG emulator host).

## District reporting (G3)

- `functions/src/metrics.ts`: versioned metric dictionary (v1, 18 metrics with
  numerator/denominator/window), time-zone-aware windows, weekly trend,
  per-site breakdown, suppression below 5, cached server-owned `metricSnapshots`
  (10-minute freshness, `refresh` to recompute).
- Access: district administrators (any scope) and school administrators (own
  sites). Teachers, counselors, and social workers are denied. Aggregate access
  never implies detail access.
- `exportDistrictReport`: requires `report.export`, audited
  (`report.district.export`), CSV built on the server with formula-injection
  protection; PDF rendered on-device from the same report (3+ US Letter pages).
- `listStudentsNeedingAttention`: only students the caller can already open;
  audited (`report.student.drilldown`).
- `transitionPlan` now stamps `submittedForApprovalAt` and `completedAt`.
- App: the Reports tab (district and school administrators) replaces the stubbed
  dashboard.

Limits: 1,500 students, 2,000 plans/tasks, 300 form assignments per report;
beyond that the report is marked partial.

## Legacy cleanup (G4)

- Removed about 118 files: unreachable code (reachability analysis from `TMIApp`, confirmed by
  the compiler) and the legacy data services: `TMIPlanService`,
  `FormSubmissionService`, `ResourceAssignmentService`, `PlanApprovalService`,
  `InterestLibraryService`, `ResourceLibraryService`, `AuditLogService`,
  `DistrictAnalyticsService`, `DistrictExportService`, `DistrictStateModel`,
  `GoalsRepository`, `PlanRepository`, `FormService`.
- Removed the legacy personal Data Import/Export screens (they read and wrote
  `users/{uid}/…` subcollections the rules already deny).
- The signed-in-student destination (never routed) now shows an unavailable
  screen instead of the legacy student app.
- The context header's plan count now reads canonical plans.
- `LegacyPathGuardTests` fails CI if production code touches retired
  collections or reintroduces a retired service. `TMI/Migration` is exempt.
- Kept on purpose: `MFARepository`, `InstitutionalSSOProvider`,
  `StudentDuplicatePolicy` (tested building blocks), `LegacyFirestorePaths`
  (migration input).

## Offline sync (G5)

- `TMI/Core/Sync`: durable per-account outbox (`FileSyncOutboxStore`, hashed
  file names, complete file protection) and `SyncCoordinator`.
- Queued offline: team notes, new follow-up tasks, task updates, form draft
  answers (coalesced). Online-only: submissions, reviews, approvals,
  restricted records, access changes, exports.
- Replays in order per record; a conflicting record waits while others continue.
  Network failures stay queued; conflicts, rejections, and revoked access become
  visible failures with Retry/Discard (Settings → Sync, and a toolbar indicator).
- The operation ID is the server idempotency key, so replays never double-apply.
  A form-draft replay whose earlier response was lost is recognised by comparing answers.
- Queues are isolated per account. Signing out hides them; work queued under
  another organization is marked and never sent.
- Replays on reconnect (`NWPathMonitor`), app foreground, and sign-in.

Known gap: forms need a connection to open (fields come from the server).

## Forms completion

- Scored forms: templates opt in with `isScored`; choice options carry
  `optionPoints`, checkboxes and ratings carry `points`; optional `scoreBands`.
  The server computes and freezes `scoring` at submission. Clients can't send
  a score, and reviews and later template edits never change it.
- `listAssignmentResponses` (per-assignment progress, scores, bands) replaces
  the legacy `StaffAnalyticsView`; `exportAssignmentResponses` is an audited,
  formula-safe CSV that requires `report.export`.
- Template editor: choice options, per-option points, checkbox/rating points,
  scored toggle, score bands.
- Legacy migration: `npm --prefix functions run migrate:form-submissions -- --project tmi-education`
  (dry run; add `--apply`). Forward-only, idempotent, never overwrites; maps
  answers by key then label, keeps unmatched answers and legacy scores as
  provenance, and lists conflicts and unresolved records.

## Verification

- Firebase emulator suite: 26 files, 349 tests passing (metrics, form scoring,
  migration, and all earlier suites).
- Swift: 686 Swift Testing tests plus 164 XCTest passing (3 pre-existing skips);
  iOS Simulator and macOS builds succeed.
- Deployed to `tmi-education` on 2026-09-23 (59 functions live) and pushed as 44c6cf7: the new callables (`getMetricDictionary`, `getDistrictReport`,
  `exportDistrictReport`, `listStudentsNeedingAttention`,
  `listAssignmentResponses`, `exportAssignmentResponses`) and the updated
  `transitionPlan` and form callables.
- Screens checked in the Simulator: `-uiTesting -fixture district-report`,
  `-fixture assignment-responses`.
