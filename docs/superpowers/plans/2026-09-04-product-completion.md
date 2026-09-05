# TMI Product Completion Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development for independent implementation and review. Track verified outcomes here; do not infer completion from old status documents.

**Goal:** Finish TMI against the approved July 19 product contract, starting with verified defects in the canonical intervention loop.

**Architecture:** Continue the existing district-scoped repository migration. SwiftUI presents member-authorized actions; trusted Functions own audited lifecycle transitions; Firestore rules enforce the same boundaries. Preserve institutional records and the Aubergine + Teal design system.

**Tech Stack:** Swift 6, SwiftUI, Firebase Auth/Firestore/Functions, Swift Testing, XCTest, Firebase Emulator Suite.

## Authority

The user confirmed September 4 that the pasted blueprint is the oldest source. `docs/superpowers/specs/2026-07-19-tmi-final-product-blueprint-design.md` and subsequent accepted repository decisions govern. Keep iOS/iPadOS/macOS 26+ and Aubergine + Teal. The supplied historical blueprint is context, not an override.

## Baseline

- Starting commit: `b71f75f`; working tree clean; implementation branch `codex/product-completion`.
- [x] Read coding standards and existing program/release plans.
- [x] Run Firebase baseline: 225 tests passed across 13 files.
- [x] Run iOS unit baseline and record real failures. Latest student-hub regression: 568 Swift tests and 164 XCTest cases, with 3 existing skips and no unit failures.
- [ ] Inventory reachable core, supporting, and district workflows against current specification.

## 1. Repair canonical plan lifecycle

Files: `TMI/Features/Plans/PlanRecord.swift`, `CanonicalPlanRepository.swift`, `CanonicalPlanDetailState.swift`, `CanonicalPlanDetailView.swift`, `firebase/src/index.ts`, `firestore.rules`, associated Swift/emulator tests.

- [ ] Add regression coverage for approval bypass, inconsistent statuses, version conflicts, cross-scope access, and history creation.
- [ ] Align the lifecycle on draft, pending approval, changes requested, approved, active, paused, completed, archived.
- [ ] Route transitions through the trusted callable, with atomic attribution, version check, audit, and frozen revision.
- [ ] Prevent direct clients from bypassing approval or editing frozen plan content.
- [ ] Make create retries idempotent and draft edits transactional.
- [ ] Present recoverable errors rather than silently empty goals/progress/history.
- [ ] Verify focused Swift and emulator suites, review changes, then run full regression.

## 2. Complete remaining core and supporting gaps

- [ ] Verify plan editor captures required goals/actions, discovery context and review schedule.
- [ ] Verify progress, action completion, student projections and PDF sharing are reachable and persist.
- [ ] Repair canonical supporting workflows in dependency order from Release 4; do not reconnect denied legacy writers.
- [ ] Complete district workflows and reports from Release 5 with aggregate-first authorization.
- [ ] Verify migrations, offline/conflict behavior, deletion, accessibility, and cross-platform release builds.

## Release evidence

Only mark a gate complete with executable evidence. Production deployment, staging workflow, TestFlight and institutional pilot validation remain distinct gates; local passing tests are not a substitute.

## September 5 continuation

The latest workspace includes committed plan lifecycle and Debug teacher access repairs (`f206bda`, `5a88ba8`). This continuation connects the production student hub to canonical plan/discovery records and makes student-scoped plan navigation reachable. Detailed commands, test outcomes, and remaining release gates are tracked in `docs/release-evidence/student-plan-hub.md`. The remaining unchecked product gates above still apply.
