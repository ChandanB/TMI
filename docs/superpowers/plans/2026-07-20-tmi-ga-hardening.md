# TMI GA Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove the complete deterministic TMI product is accessible, privacy-accurate, resilient, performant, migration-safe, recoverable, and ready for App Store/TestFlight and district production use.

**Architecture:** GA hardening closes cross-cutting gaps accumulated through vertical releases without introducing new product scope. Automated matrices enforce offline/conflict, accessibility, privacy, performance, security, migration, backup/restore, and full-loop behavior; legacy implementation and misleading documentation are removed or archived before the release candidate is signed.

**Tech Stack:** Swift 6.2, SwiftUI, XCTest/Swift Testing, Xcode result bundles, Firebase Emulator/staging, App Check, MetricKit, OSLog, VoiceOver/Accessibility Inspector, TestFlight

---

## File map

| Action | Path | Responsibility |
|---|---|---|
| Create | `TMI/Core/Sync/SyncOperation.swift` | Stable queued-operation contract |
| Create | `TMI/Core/Sync/SyncCoordinator.swift` | Pending/sync/success/failure state |
| Create | `TMI/Core/Sync/ConflictResolution.swift` | Version conflict preservation |
| Create | `TMITests/Core/SyncCoordinatorTests.swift` | Offline convergence/idempotency |
| Create | `TMI/Core/Performance/PerformanceBudget.swift` | Named p95 thresholds |
| Replace | `TMI/Core/Performance/PerformanceMonitor.swift` | Privacy-safe measurements |
| Create | `TMITests/Core/PerformanceBudgetTests.swift` | Budget evaluation |
| Create | `TMIUITests/AccessibilityMatrixTests.swift` | Identifiers and state matrix |
| Create | `TMIUITests/CanonicalLoopUITests.swift` | Full product loop |
| Modify | `TMI/PrivacyInfo.xcprivacy` | Final archive-verified manifest |
| Create | `TMI/Features/Privacy/PersonalDataExportService.swift` | Authenticated personal-only export |
| Create | `TMITests/Features/Privacy/PersonalDataExportTests.swift` | Export scope and redaction |
| Create | `docs/release-evidence/privacy-disclosures.md` | Store disclosure verification |
| Create | `docs/release-evidence/restore-rehearsal.md` | RPO/RTO evidence |
| Create | `docs/release-evidence/ga-migration.md` | Clean/existing-user rehearsals |
| Create | `docs/release-evidence/ga-accessibility.md` | Platform/assistive-tech review |
| Create | `docs/release-evidence/ga-performance.md` | p95 measurements |
| Create | `docs/release-evidence/ga-security.md` | Final security disposition |
| Create | `docs/release-evidence/ga-release-checklist.md` | Archive/TestFlight/pilot evidence |

## Task 1: Complete offline queue and conflict resolution

**Files:**
- Create: `TMI/Core/Sync/SyncOperation.swift`
- Create: `TMI/Core/Sync/SyncCoordinator.swift`
- Create: `TMI/Core/Sync/ConflictResolution.swift`
- Create: `TMI/Core/Sync/SyncStatusView.swift`
- Create: `TMITests/Core/SyncCoordinatorTests.swift`

- [ ] **Step 1: Write failing sync tests**

Test cached reads; survey/form/plan draft; new note/reflection/progress; preferences; stable operation IDs; app restart; reconnection; idempotent replay; permission revocation; append-only merge; aggregate version conflict; both-draft preservation; and pending/syncing/succeeded/failed counts.

```swift
struct SyncOperation: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let domain: SyncDomain
    let targetID: String
    let expectedVersion: Int?
    let payload: Data
    let createdAt: Date
}
```

- [ ] **Step 2: Implement actor-confined queue**

`SyncCoordinator` persists non-sensitive queued operations in an encrypted/protected local store, processes in creation order per aggregate, permits independent aggregates concurrently, and keeps rejected operations with typed explanation. It never queues role/permission, approval/lifecycle transition, Student Mode issuance, account deletion, sensitive export, or multi-record destructive operations.

- [ ] **Step 3: Implement explicit conflict UI**

Append-only records merge by stable ID. Mutable roots send expected version; a conflict retains server and local drafts and presents field-by-field choices. Permission revocation prevents sync and explains that the user's access changed.

- [ ] **Step 4: Run offline integration/UI tests and commit**

```bash
git add TMI/Core/Sync TMITests/Core/SyncCoordinatorTests.swift
git commit -m "feat: harden offline sync and conflicts"
```

## Task 2: Complete Aubergine + Teal visual consolidation

**Files:**
- Modify: every production SwiftUI view returned by `rg` scans below
- Remove: superseded color/component helpers with no callers
- Modify: `TMITests/Modern/ModernComponentTests.swift`

- [ ] **Step 1: Inventory legacy styling**

```bash
rg -n 'foregroundColor|Color\.(blue|yellow|orange|purple)|Color\(hex:|LinearGradient|RadialGradient|glass|neon|darkMode|preferredColorScheme' TMI
rg -n 'ZLHN|RedesignBridge|RedesignComponents|UIComponents|TMIComponentLibrary' TMI
```

Classify every match as semantic-token migration, approved content visualization, or removal. The only color scheme is light.

- [ ] **Step 2: Consolidate canonical components**

Keep one implementation each for background, card, button, field, search, picker, badge, avatar, progress, empty/loading/error/offline states, section header, accordion, dialog, sheet, banner, student row, plan row, stat card, and timeline item. All use semantic tokens, visible borders, solid surfaces, sentence case, Dynamic Type, and system font fallback.

- [ ] **Step 3: Remove legacy visual systems**

Delete warm cream, blue/gold, dark, glass, neon, arbitrary colors, decorative blobs/particles, and unnecessary gradients. Remove component files only after callers migrate and `rg` confirms zero references.

- [ ] **Step 4: Run component/contrast/snapshot tests and commit**

```bash
git add -A TMI TMITests/Modern/ModernComponentTests.swift
git commit -m "refactor: complete Aubergine and Teal migration"
```

## Task 3: Pass the accessibility and platform matrix

**Files:**
- Create: `TMIUITests/AccessibilityMatrixTests.swift`
- Modify: affected feature views
- Create: `docs/release-evidence/ga-accessibility.md`

- [ ] **Step 1: Automate structural accessibility checks**

Test every critical screen/state for labels, hints/values where needed, logical focus order, 44-point targets, keyboard actions, no color-only state, accessible chart summaries, Reduce Motion, and essential-content visibility at the largest accessibility text size.

- [ ] **Step 2: Run the visual matrix**

Validate iPhone portrait and supported landscape; iPad compact/regular/split; macOS minimum/default/expanded; default and largest text; light appearance; loading/empty/error/offline/permission/success states.

- [ ] **Step 3: Complete manual assistive-technology review**

Use VoiceOver on iPhone/iPad/macOS, Full Keyboard Access, Switch Control sampling, Reduce Motion, Increase Contrast, and Differentiate Without Color. A design review must cover every significant UI slice and record defects/evidence.

- [ ] **Step 4: Fix each defect test-first and commit**

```bash
git add TMI TMIUITests/AccessibilityMatrixTests.swift docs/release-evidence/ga-accessibility.md
git commit -m "fix: pass GA accessibility matrix"
```

## Task 4: Enforce logging, privacy, and legal-release accuracy

**Files:**
- Replace: `TMI/Core/Logging/TMILogger.swift`
- Modify: every raw logging caller
- Modify: `TMI/PrivacyInfo.xcprivacy`
- Create: `TMITests/Core/LoggingPrivacyTests.swift`
- Create: `docs/release-evidence/privacy-disclosures.md`

- [ ] **Step 1: Write failing privacy-log tests**

Inject synthetic names, emails, student IDs, survey text, notes, and plan content into each logged error/event path. Assert structured output contains only privacy-redacted values, stable correlation IDs, domain/error codes, and no raw input.

- [ ] **Step 2: Remove raw console output**

```bash
rg -n 'print\(|debugPrint\(|dump\(' TMI
```

Replace operational diagnostics with `Logger` and `.private(mask: .hash)` or omit the field. Keep protected audit events separate from telemetry and never send protected data to Crashlytics/Analytics.

- [ ] **Step 3: Verify archive privacy artifacts**

Archive the app, inspect the generated privacy report, compare SDK declarations, update `PrivacyInfo.xcprivacy`, and make App Store privacy answers match actual collection/use/retention. Verify hosted Privacy Policy and Terms URLs return 200 over HTTPS and the support contact is monitored.

- [ ] **Step 4: Verify personal export and account deletion**

Create `PersonalDataExportService` that reauthenticates, requests a trusted personal-only export, downloads the encrypted short-lived archive, and deletes the local temporary file after share/dismiss. Test that the archive contains profile, preferences, personal notification/recommendation/activity/resource data and excludes institutional students, plans, forms, meetings, consents, restricted records, and other users. Then test accurate delete/retain disclosure, idempotent cleanup, retained institutional attribution, Auth deletion last, and post-deletion signed-out state.

- [ ] **Step 5: Run tests and commit**

```bash
git add TMI TMITests/Core/LoggingPrivacyTests.swift docs/release-evidence/privacy-disclosures.md
git commit -m "fix: align privacy behavior and disclosures"
```

## Task 5: Meet reliability and performance budgets

**Files:**
- Create: `TMI/Core/Performance/PerformanceBudget.swift`
- Replace: `TMI/Core/Performance/PerformanceMonitor.swift`
- Create: `TMITests/Core/PerformanceBudgetTests.swift`
- Create: `docs/release-evidence/ga-performance.md`

- [ ] **Step 1: Encode exact budgets**

```swift
enum PerformanceBudget {
    static let cachedShellP95: Duration = .seconds(2)
    static let cachedDetailP95: Duration = .seconds(1)
    static let loadingFeedback: Duration = .milliseconds(250)
    static let firstOnlinePageP95: Duration = .seconds(3)
    static let offlineConvergenceP95: Duration = .seconds(60)
    static let pageSize = 50
}
```

- [ ] **Step 2: Write budget evaluation tests**

Use deterministic samples to validate p95 calculation and pass/fail boundary. Measure shell, student/plan detail, loading feedback, first page, pagination size, district snapshot reads, and reconnection convergence.

- [ ] **Step 3: Run production-shaped measurements**

Measure a current base-model iPhone and Apple-silicon Mac under the documented staging network profile using signposts/MetricKit. No PII enters metric names or payloads. District dashboards must read snapshots, not scan students on-device.

- [ ] **Step 4: Fix regressions and commit evidence**

```bash
git add TMI/Core/Performance TMITests/Core/PerformanceBudgetTests.swift docs/release-evidence/ga-performance.md
git commit -m "perf: meet GA response budgets"
```

## Task 6: Prove backup, restore, and incident recovery

**Files:**
- Create: `firebase/src/backup.ts`
- Create: `firebase/test/backup.test.ts`
- Create: `docs/runbooks/restore.md`
- Create: `docs/runbooks/incident-response.md`
- Create: `docs/release-evidence/restore-rehearsal.md`

- [ ] **Step 1: Configure encrypted scheduled backups**

Back up canonical Firestore and Storage at least daily to a separately administered encrypted destination with least-privilege access and retention. Backup jobs emit operational success/failure without record content.

- [ ] **Step 2: Write backup metadata/idempotency tests**

Test schedule state, failed-job alert, manifest checksum, expected collection prefixes, restricted-data inclusion without exposure, and no production app credential access to backup administration.

- [ ] **Step 3: Rehearse staging restore**

Restore a production-shaped encrypted backup into an isolated staging project. Verify counts, referential integrity, restricted-record isolation, Storage links, representative decoded equality, Auth/member recovery procedure, and audit continuity.

- [ ] **Step 4: Measure objectives and complete incident runbook**

Expected: recovery point is at most 24 hours and recovery time at most eight hours. Runbook covers evidence preservation, institution notification channel, containment, credential rotation, restore, validation, and post-incident review without student PII in operational tools.

- [ ] **Step 5: Commit evidence**

```bash
git add firebase/src/backup.ts firebase/test/backup.test.ts docs/runbooks docs/release-evidence/restore-rehearsal.md
git commit -m "docs: prove backup and recovery readiness"
```

## Task 7: Rehearse clean install and existing-user migration

**Files:**
- Create: `docs/release-evidence/ga-migration.md`
- Modify: migration tools/fixtures only when a failing reconciliation test proves a defect

- [ ] **Step 1: Run clean-install matrix**

Install the Release candidate with no local data on iPhone/iPad/macOS, register/sign in, complete the canonical loop, sign out/in, and delete the account. Expected: no seed/demo records and no credential/configuration leakage.

- [ ] **Step 2: Run existing-user fixtures**

Exercise each supported legacy schema/role/path, mixed canonical+legacy state, interrupted migration, unresolved ownership, duplicate IDs, completed history, offline pending writes, and deleted educator attribution.

- [ ] **Step 3: Prove forward-only rollback**

After canonical writes begin, roll the UI feature flag back while leaving canonical writer active; verify no new legacy writes and successful forward repair. Expected: apply twice is idempotent and final reconciliation is zero.

- [ ] **Step 4: Commit evidence**

```bash
git add firebase TMI/Migration docs/release-evidence/ga-migration.md
git commit -m "test: rehearse GA data migration"
```

## Task 8: Remove repository contradictions and misleading documentation

**Files:**
- Remove: unused legacy code/assets/routes discovered by the scans
- Modify or move: superseded planning/status Markdown
- Create: `docs/archive/README.md`

- [ ] **Step 1: Run the final dead/duplicate implementation audit**

Search duplicate auth, career, survey, interest, resource, plan, form, navigation, Firebase paths, components, sample data, fake metrics, broken controls, missing assets, bundled internal docs, and naming-only ViewModel/StateModel distinctions. Confirm each removal with compiler/tests.

- [ ] **Step 2: Remove giant-view remnants**

Ensure files touched by releases contain focused types with clear interfaces. No legacy 1,000-3,000-line operational view remains solely as a wrapper around duplicate nested components.

- [ ] **Step 3: Archive superseded documents**

Move historical phase/completion/teacher-only/warm-light documents under `docs/archive/` or add an unmistakable superseded banner linking to the master contract. Remove internal planning Markdown and development artifacts from app target membership/bundle resources.

- [ ] **Step 4: Run full builds/tests and commit**

```bash
git add -A
git commit -m "refactor: remove superseded TMI implementations"
```

## Task 9: Automate and pass the final canonical-loop suite

**Files:**
- Create: `TMIUITests/CanonicalLoopUITests.swift`
- Create: `TMIUITests/RoleBoundaryUITests.swift`
- Create: `TMIUITests/OfflineConflictUITests.swift`

- [ ] **Step 1: Automate the educator/student loop**

Register/sign in; create student; launch Student Mode; complete survey; approve interests; save/compare career; create goals/actions/plan; submit/approve/activate; progress/reflection; pause/resume/complete/archive/new cycle; meeting/form/resource/task/notification/search; export; district aggregate; account deletion.

- [ ] **Step 2: Automate every role and respondent boundary**

Exercise teacher, counselor, social worker, school administrator, district administrator, Student Mode, and guardian respondent session. Assert allowed and denied routes/data, including restricted records and audited drill-down.

- [ ] **Step 3: Automate all data states**

For critical screens, cover loading, refreshing, empty, populated, recoverable error, permission denied, offline, successful save, disabled submit, retry, conflict, and revoked access.

- [ ] **Step 4: Run on iPhone, iPad, and macOS and commit**

```bash
git add TMIUITests
git commit -m "test: cover the final TMI product loop"
```

## Task 10: Complete archive, TestFlight, and district-pilot validation

**Files:**
- Create: `docs/release-evidence/ga-security.md`
- Create: `docs/release-evidence/ga-release-checklist.md`

- [ ] **Step 1: Run final independent security review**

Re-review Auth/MFA, claims/membership, rules, Storage, App Check, functions, respondent sessions, export, deletion, retention, backup, audit, local storage, logging, and dependency vulnerabilities. Zero critical/high findings may remain.

- [ ] **Step 2: Produce an App Store archive**

Validate signing, entitlements, privacy manifest/report, app icon, screenshots, metadata, support/privacy/terms URLs, account-deletion reviewer path, and absence of debug/developer assets. Expected: Xcode validation succeeds.

- [ ] **Step 3: Run TestFlight smoke tests**

Install via TestFlight on representative iPhone/iPad and validate sign-in, roster, Student Mode, survey, plan, collaboration, district aggregate, export, offline/reconnect, notification deep link, and deletion.

- [ ] **Step 4: Run district-pilot simulation/sign-off**

Use production-shaped synthetic data and approved pilot staff to complete the canonical loop and administrative evidence workflow. Capture usability, support, accessibility, privacy, and data reconciliation sign-off.

- [ ] **Step 5: Commit evidence**

```bash
git add docs/release-evidence/ga-security.md docs/release-evidence/ga-release-checklist.md
git commit -m "docs: record GA release validation"
```

## Task 11: GA acceptance and tag

**Files:**
- All application, backend, test, migration, and release-evidence files

- [ ] **Step 1: Run the universal release gate from a clean clone**

Expected: iOS/iPadOS/macOS Release builds and all Swift/Emulator/UI/accessibility/performance/migration tests pass; zero critical/high defects; no production mock data, dead route, contradictory implementation, or deprecated Firebase path remains.

- [ ] **Step 2: Verify the contract definition of done line by line**

Use Section 28 of `docs/superpowers/specs/2026-07-19-tmi-final-product-blueprint-design.md`. Link every assertion to executable evidence; an unchecked or evidence-free line blocks the tag.

- [ ] **Step 3: Tag deterministic GA**

```bash
git tag -a tmi-ga-1.0.0 -m "TMI deterministic GA 1.0.0"
```

Expected: tag points at the verified evidence commit. Optional AI may be absent or disabled.
