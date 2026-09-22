# Developer Mode, early childhood, and staff administration

Branch: `feat/developer-mode-early-childhood` (from `main` at `0f6f070`). Local
verification only — nothing in this document has been deployed.

## What shipped on the branch

| Area | Client | Server | Tests |
|---|---|---|---|
| Baseline repair | NSNumber claim versions; Swift 6 isolation fixes so the test target compiles; `[TMIDIAG]` logging removed | — | Existing suites green |
| App Check | `FirebaseBootstrap` installs App Check (debug provider in DEBUG, DeviceCheck in Release) before `FirebaseApp.configure()` | Every callable already enforces App Check | Build + launch |
| Developer Mode (DEBUG only) | Settings → Developer → Developer Mode: organizations & sites, invitation codes, staff access, local debug tenant, session diagnostics, live/emulator switch; `developer-mode` UI fixture | `dev*` callables gated by server-only `platformOperators/{uid}` + `TMI_DEVELOPER_CONSOLE` kill switch; `scripts/manage-operator.mjs` | `developer-console.test.ts` (11), `DeveloperModeStateTests` (9) |
| Program types | `ProgramContextStore`, `ProgramProfile`, `Terminology`, `AgeGroup`; site names instead of raw IDs | `programType` on districts/schools; `attachCareerToPlan` rejects early-childhood sites | `ProgramProfileTests`, `career-plan.test.ts` |
| Early-childhood flow | Children/Center/Age group vocabulary; age-group picker + required DOB; no Careers; plan wizard "Interests & play", observed preferences/family perspective, age-appropriate models, draft age-adapted guidance, ELOF developmental domains on goals, Family action audience | — | `ProgramProfileTests` |
| Early-childhood discovery | Picture tiles + read-aloud for image-choice questions; Picture Choice gated to age 3+; caregiver interest observations; family "All About My Child" input with locked device hand-off | `recordInterestObservation`, `recordFamilyInput` (audited, immutable, server-owned vocabulary); rules for `observations`/`familyInputs` | `observations.test.ts` (5), `family-input.test.ts` (4), `EarlyChildhoodContentTests` |
| Staff administration | Settings → Administration → Staff Management (staff directory, edit access, invitations) and Audit Log replace two dead rows; `staff-administration` UI fixture | `adminListStaff`, `adminListInvitations`, `adminCreateInvitation`, `adminRevokeInvitation`; `mutateMembership` now enforces a capability ceiling and keeps `userID` | `administration.test.ts` (8), `StaffAdministrationTests` |
| Demo data | — | `scripts/seed-early-childhood-demo.mjs` | Ran against the emulator |

## Verification (local)

- `npm --prefix functions run lint` / `run build`: exit 0.
- `npm --prefix functions test` (emulator `demo-tmi`): 20 files, 317 tests passed.
- `xcodebuild test -only-testing:TMITests` on iPhone 17 Pro (iOS 26.5): Swift Testing and XCTest suites passed (counts recorded in the commit log of this branch); XCTest has 3 pre-existing skips.
- macOS Debug build (unsigned): succeeded.
- Simulator checks via UI fixtures: Developer Mode (create invitation → one-time code → list), early-childhood roster and Add Child editor, Picture Choice tiles, Staff Management list and access editor.

## Required before any of this works live (user actions)

1. **Deploy** (not done — needs your approval): `firestore.rules` and the new/changed Functions to `tmi-education`.
   `cd functions && npx firebase deploy --only firestore:rules,functions --project tmi-education`
2. **App Check**: run a DEBUG build once, copy the App Check debug token from the Xcode console, and add it in Firebase console → App Check → Apps → Manage debug tokens. For Release/TestFlight, register the DeviceCheck key for `ZLHN.TMI`.
3. **Operator access**: `GOOGLE_APPLICATION_CREDENTIALS=… npm --prefix functions run operator:grant -- --email <you> --project tmi-education`.
4. **Content approval**: the early-childhood model guidance, Picture Choice questions, observation checklist, and family questions are drafts marked "pending product-owner approval".
5. **Legal review**: COPPA / state child-care record rules for early-childhood sites (FERPA may not apply to private child care).

## Known limits and follow-ups

- Family input is completed on a caregiver's device (locked hand-off). Remote family links need a hosted web respondent experience (roadmap G1).
- The synthetic Debug tenant never touches Firestore, so observations, family input, and staff administration need a real (or emulator) tenant; use Developer Mode → Local debug tenant → Program preview to see the early-childhood UI offline.
- Picture Choice uses SF Symbol pictures; licensed illustrations can replace them through asset or Storage references without schema changes.
- Remaining GA roadmap work (canonical Forms respondents, notes/tasks/notifications/search, metric snapshots and reports, legacy cutover, offline sync, release gates) is unchanged; see `docs/superpowers/plans/2026-09-07-tmi-ga-completion-roadmap.md`.
