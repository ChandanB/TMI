# TMI Final Product Program Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the complete TMI product contract through dependency-ordered vertical releases that each end in secure, accessible, testable software.

**Architecture:** Migrate the existing application in place using a strangler pattern: establish trusted tenant authorization and one canonical data tree, then move one end-to-end workflow at a time behind typed repositories. Each release uses the Aubergine + Teal system, adds its own security and accessibility coverage, migrates its legacy data, and removes the superseded path before advancing.

**Tech Stack:** Swift 6.2, SwiftUI, Observation, Swift Testing, XCTest UI automation, Firebase Auth, Firestore, Storage, App Check, Cloud Functions with TypeScript, Firebase Emulator Suite, GitHub Actions, PDFKit, EventKit, LocalAuthentication

---

## Source of truth

Implement against `docs/superpowers/specs/2026-07-19-tmi-final-product-blueprint-design.md`. Earlier phase, MVP, teacher-only, warm-light, and completion documents are historical inputs only.

## Program file map

| Plan | Working product at exit |
|---|---|
| `2026-07-20-tmi-gate-0-canonical-foundation.md` | Green Swift 6 builds/tests, trusted authorization, canonical paths, safe deletion, CI, and design tokens |
| `2026-07-20-tmi-release-1-secure-roster.md` | Verified staff can authenticate and manage only their assigned roster |
| `2026-07-20-tmi-release-2-discovery-classroom-pilot.md` | Educator launches Student Mode; survey results persist interests and drive explainable career matches |
| `2026-07-20-tmi-release-3-core-intervention-mvp.md` | A student can move from discovery to an approved, active, measured intervention plan |
| `2026-07-20-tmi-release-4-school-collaboration.md` | Forms, resources, meetings, notes, tasks, notifications, and search work in student/plan context |
| `2026-07-20-tmi-release-5-district-pilot.md` | Least-privilege administration, reconciled metrics, retention, audit, and district reporting |
| `2026-07-20-tmi-release-6-optional-ai.md` | Feature-flagged AI suggestions with provenance and human confirmation; deterministic product unchanged |
| `2026-07-20-tmi-ga-hardening.md` | Cross-platform accessibility, offline/conflict, privacy, recovery, performance, migration, and release gates pass |

## Dependency graph

```text
Gate 0
  -> Release 1 secure roster
      -> Release 2 discovery
          -> Release 3 intervention core
              -> Release 4 school collaboration
                  -> Release 5 district pilot
                      -> GA hardening

Release 6 optional AI depends on Releases 2-5 domain contracts,
but it remains disabled and never blocks GA.
```

## Branch and checkpoint policy

- Create one `codex/` branch per plan from the accepted previous release tag.
- Do not begin the next plan until the current release acceptance suite is green and migration reconciliation is zero.
- Use test-first red/green/refactor cycles for every behavior change.
- Make a focused commit after every plan task; do not mix migration, UI, and rule changes in one commit.
- Run `git diff --check` before every commit.
- Use Firebase Emulator project ID `demo-tmi`; tests must never depend on production credentials.
- Use the literal per-plan DerivedData and result-bundle paths written in each plan so stale DerivedData cannot masquerade as a code failure.

## Universal release gate

Every release must prove all of the following before it can advance:

- [ ] **Step 1: Run the focused domain suite**

Run the exact `xcodebuild` and emulator commands in that release plan. Expected: all focused tests pass.

- [ ] **Step 2: Run the full iOS suite**

```bash
xcodebuild test -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/TMI-Full-DerivedData \
  -resultBundlePath /tmp/TMI-Full-Results.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **`, zero failures, and no tests skipped because Firebase was unavailable.

Run the macOS unit/integration suite:

```bash
xcodebuild test -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TMI-Full-Mac-DerivedData \
  -resultBundlePath /tmp/TMI-Full-Mac-Results.xcresult \
  -only-testing:TMITests CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **` with the same platform-independent domain fixtures passing.

- [ ] **Step 3: Build all supported platforms**

```bash
xcodebuild build -project TMI.xcodeproj -scheme TMI -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/TMI-Release-DerivedData CODE_SIGNING_ALLOWED=NO
xcodebuild build -project TMI.xcodeproj -scheme TMI -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TMI-Release-DerivedData CODE_SIGNING_ALLOWED=NO
```

Expected: both commands end with `** BUILD SUCCEEDED **` under Swift 6 with no concurrency errors.

- [ ] **Step 4: Run security rules and trusted-function tests**

```bash
npm --prefix firebase test
```

Expected: Firestore, Storage, and function authorization tests all pass against `demo-tmi`.

- [ ] **Step 5: Validate migrations**

```bash
npm --prefix firebase run migrate:dry-run -- --project demo-tmi --fixture firebase/fixtures/release.json
npm --prefix firebase run reconcile -- --project demo-tmi --fixture firebase/fixtures/release.json
```

Expected: dry-run reports only the release's declared writes; reconciliation reports zero count, ownership, reference, and decode mismatches.

- [ ] **Step 6: Validate UI and accessibility**

Run the release UI tests on iPhone 17 Pro, iPad Pro 13-inch, and macOS. Inspect result-bundle screenshots for default and largest accessibility text sizes. Expected: no clipped essential content, missing accessibility identifiers, focus traps, or controls below 44 points.

- [ ] **Step 7: Review data and logging boundaries**

```bash
rg -n "print\(|debugPrint\(|dump\(" TMI
rg -n "Student\.sample|sampleStudent|SampleDataSeeder|fallback.*sample" TMI
rg -n '\.collection\("(users|students|plans|tmiPlans|formAssignments|resources)' TMI
```

Expected: no newly introduced raw logging, production sample fallback, or direct collection access outside the currently approved repository/migration allowlist.

- [ ] **Step 8: Tag the accepted release**

Run the literal annotated-tag command in the release plan's acceptance task. Expected: the release-specific tag points at the verified evidence commit.

## Specification coverage map

| Contract sections | Owning plan |
|---|---|
| 1-5 authority, product, users, architecture, delivery | Program plan and Gate 0 |
| 6-8 schema, authorization, Student Mode security | Gate 0, Releases 1-2 |
| 9-12 navigation, auth, dashboard, students | Releases 1 and 5 |
| 13-14 survey and careers | Release 2 |
| 15 plans and exports | Release 3 |
| 16-17 collaboration, notifications, search | Release 4 |
| 18 district administration | Release 5 |
| 19-20 visual system, accessibility, adaptation | Gate 0, every UI release, GA |
| 21 privacy/security/compliance | Gate 0, Releases 2 and 5, GA |
| 22 AI | Release 6 |
| 23 offline/conflict | Each repository release, GA validation |
| 24 reliability/performance/recovery | Every release and GA |
| 25 migration/deletion | Gate 0 and each domain release |
| 26 testing/CI | Gate 0 and universal gate |
| 27 cleanup | Every release and GA removal audit |
| 28 final definition of done | GA hardening |
| 29 verified baseline | Gate 0 |

## Program completion

- [ ] **Step 1: Confirm every release tag exists**

```bash
git tag --list 'tmi-*' --sort=creatordate
```

Expected: accepted tags for Gate 0 and Releases 1-5, `tmi-ga-1.0.0`, and the Release 6 tag only if AI shipped.

- [ ] **Step 2: Confirm the canonical loop with production-shaped data**

Create a fresh educator through the staging invitation flow, create a student, complete Student Mode discovery, save and compare a career, create and approve a plan, record progress, complete a meeting, export the plan, and verify district aggregates. Expected: every record is visible only within its authorized context and every dashboard/export metric reconciles to source events.

- [ ] **Step 3: Confirm no superseded implementation remains active**

```bash
rg -n "users/.*/(students|tmiPlans)|StudentMainView|signedInStudent|warm|glass|neon" TMI firestore.rules storage.rules
```

Expected: matches exist only in migration readers, historical comments scheduled for removal, or explicitly approved non-color prose; no production route or writer uses them.

- [ ] **Step 4: Commit the final release evidence**

```bash
git add docs/release-evidence
git commit -m "docs: record TMI GA acceptance evidence"
```

Expected: the commit contains result-bundle summaries, emulator results, migration reconciliation, accessibility review, security review, restore rehearsal, TestFlight smoke test, and district-pilot sign-off without student PII.
