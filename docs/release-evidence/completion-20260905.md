# Product completion continuation

The approved July 19 blueprint remains the completion contract. This is an active work log, not GA acceptance.

## Workspace and baseline

- Base: `e44d193`, branch `codex/completion-20260905`.
- Worktree: `.worktrees/completion-20260905`.
- Additional uncommitted plan-editor, owner/approver, and list work appeared between the initial inspection and September 5 continuation. Preserve and review it separately from this task's career and Student Mode changes.
- macOS unit baseline compiled, but failed 8 assertions across 5 Swift tests in existing plan creation, decoding, owner/approver policy, and editor conflict handling. Log: `/tmp/TMI-Completion-September5-Baseline.log`. The Swift Testing runner executed 581 tests in 69 suites. XCTest executed 163 tests with 4 skips and 4 failures across two keychain tests; unsigned execution returned entitlement error `-34018`. This is not a passing baseline.

## Current implementation slices

1. Complete career-to-plan attachment through a trusted callable, a student-scoped plan picker, and reload after confirmed persistence. Keep approval-frozen plans immutable and reject cross-student links.
2. Scope Student Mode plan projections to the active student. Exclude other students' goals and progress, professional goal wording, and unrelated actions before creating display values.
3. Review both slices independently, run focused unit and emulator tests, then build and exercise supported UI destinations.

## Verified source gaps requiring subsequent work

| Area | Source evidence | Remaining behavior |
|---|---|---|
| Career attachment | `CanonicalCareerDetailView` has an empty, disabled attachment button; career rules prohibit changing `linkedPlanIDs` | Trusted, audited link mutation and reachable plan selection |
| Student Mode | Projection builder receives all plan children and filters visibility but not child student identity | Explicit target-student filtering before presentation |
| Collaboration | Student hub has Release 4 placeholders; canonical detail repository loads interests, careers, and plans only | Contextual forms, resources, meetings, notes, tasks, notifications, and search |
| Forms | Legacy version service uses top-level template paths while rules authorize district paths | Versioned templates, immutable submissions, review, and authorized export |
| Meetings | Legacy meeting service uses personal user paths and embedded action items | Shared district meetings with person-owned follow-up tasks |
| District metrics | Reachable analytics service queries `/analytics`, while rules expose `metricSnapshots`; fallback calculations throw | Versioned server calculations, canonical snapshot repository, real scoped filters |
| District exports | Exported URL is stored without presentation; legacy values lack canonical formula provenance | Audited report projection, reconciled metrics, retrievable PDF/CSV |
| Administrative access | Audit found broad district access inconsistent with aggregate-first blueprint | Verify newer accepted policy decisions before changing authorization |

## Release gates

Local verification does not establish deployment, production data migration, signed distribution, TestFlight acceptance, or institutional pilot acceptance. Keep these gates open until each has executable or observed evidence. Do not deploy or publish implicitly from a passing local test run.
