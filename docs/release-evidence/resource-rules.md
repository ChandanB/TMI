# Resource repository — Firestore rules coverage

The district-scoped `ResourceRepository` (Phase 3) writes to three paths. This
records how each is authorized by the existing `firestore.rules`, and the
manual checks to run once against the live project (rules cannot be verified
locally without the emulator).

## 1. District resource library — `districts/{districtID}/resources/{resourceID}`
- Rule: `firestore.rules` `match /districts/{districtID}/resources/{resourceID}` (~line 1058).
- `create`/`library` read are authorized for active members per that block.
- Written by `ResourceRepository.create`, which forces `districtId`/`ownerUid`
  to the member's values.

## 2. Student-assigned resources — `districts/{districtID}/students/{studentID}/resources/{resourceID}`
- Rule: `match /resources/{resourceID}` inside the students block (~line 741):
  - `allow read: canReadStudent(...) && (hasActiveMembership || studentVisible)`
  - `allow create, update: canCollaborateOnStudent(districtID, studentID)`
  - `allow delete: if false`
- Written by `ResourceRepository.assign`, which denormalizes the full library
  resource (so `studentResources()` decodes it back as a `Resource`). No field
  shape is required by the rule beyond collaboration rights.
- Manual check: as a member who can collaborate on the student, assign a
  resource → expect ALLOW; as a member without access → expect DENY; delete →
  expect DENY.

## 3. Plan-linked resources — `districts/{districtID}/plans/{planID}/resources/{resourceID}`
- Rule: the plans sub-collection catch-all `match /{collectionName}/{recordID}`
  (~line 892), which includes `'resources'`:
  - `allow read`: `canReadPlan(...)` (or a respondent who may read the plan record).
  - `allow create`: `canWritePlan(...)` AND the plan status is `draft` or
    `changesRequested` AND **`request.resource.data.planID == planID`**.
  - `allow update`: `canWritePlan(...)` AND `request.resource.data.planID == planID`
    AND (plan is `draft`/`changesRequested`, or the status-only active/paused
    exception which does not apply to `resources`).
  - `allow delete: if false`.
- Written by `ResourceRepository.linkToPlan`, which denormalizes the full
  resource AND stamps `planID = planID` to satisfy the create/update guard.
- CONSTRAINT surfaced by the rule: resources can only be linked while the plan
  is in `draft` or `changesRequested`. Linking on an `active`/`completed` plan
  is denied by design; the UI (`PlanResourceListSection`) should therefore be
  understood as an editing-phase affordance. No rules change was made.
- Manual check: as a plan writer with the plan in `draft`, link a resource →
  expect ALLOW; repeat with the plan `active` → expect DENY; omit `planID`
  from the payload → expect DENY (regression guard for the field requirement);
  delete → expect DENY.

Verified via unit tests that the written payloads carry `districtId`,
`ownerUid`, and (for plan links) `planID`; the allow/deny outcomes above still
require a one-time emulator or live-project check.
