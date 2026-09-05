# District compliance settings & audits rule coverage

Date: September 5, 2026
Base: `main` (post `e44d193`)

## Problem

`ComplianceService` writes district compliance data to `districts/{districtID}/settings/compliance`
and `districts/{districtID}/complianceAudits/{auditID}`. `firestore.rules` had no `match` blocks for
either collection inside `match /districts/{districtID} { ... }`, so both paths fell through to the
block's catch-all `match /{unmatched=**} { allow read, write: if false; }` and were denied
unconditionally — including for district administrators who should be able to manage them.

## Change

Added two `match` blocks inside `match /districts/{districtID}`, placed after the existing
`metricSnapshots` block and before the `{unmatched=**}` catch-all:

```
match /settings/{settingID} {
  allow read: if hasActiveMembership(districtID);
  allow write: if hasActiveMembership(districtID)
    && role(districtID) == 'districtAdministrator';
}

match /complianceAudits/{auditID} {
  allow read: if hasActiveMembership(districtID);
  allow create, update: if hasActiveMembership(districtID)
    && role(districtID) == 'districtAdministrator';
  allow delete: if false;
}
```

Conditions:

- **`settings/{settingID}`** (covers `settings/compliance`): any active district member (teacher,
  counselor, socialWorker, schoolAdministrator, districtAdministrator — per `hasActiveMembership`)
  may read; only a district administrator may write (create/update/delete all fall under `write`).
- **`complianceAudits/{auditID}`**: any active district member may read; only a district
  administrator may create or update an audit record; delete is unconditionally denied for all
  roles, including district administrators, so audit history cannot be erased through the client.

This mirrors the existing `hasActiveMembership(districtID) && role(districtID) ==
'districtAdministrator'` idiom already used elsewhere in the districts block (e.g. the existing
district-administrator gates at the time of writing). No new helper function was introduced, and no
existing rule (including `auditEvents`, which is a distinct, separately billing-gated audit trail)
was modified or widened.

## Manual verification checklist (run once against a live/emulated Firebase project)

Rules changes are not exercised by the Swift test suite and cannot be verified purely by reading the
file — they must be checked against the actual Firestore rules engine (emulator or a live project
with a disposable district). The following checks should be run before this change is relied upon in
production:

1. As a user with an active `districtAdministrator` membership on district `<id>`:
   - Write `districts/<id>/settings/compliance` → expect **ALLOW**.
   - Create a document under `districts/<id>/complianceAudits/<auditId>` → expect **ALLOW**.
   - Update that same `complianceAudits/<auditId>` document → expect **ALLOW**.
   - Delete `districts/<id>/complianceAudits/<auditId>` → expect **DENY**.
   - Read `districts/<id>/settings/compliance` → expect **ALLOW**.
2. As a user with an active `teacher` (or `counselor`/`socialWorker`/`schoolAdministrator`)
   membership on district `<id>`:
   - Read `districts/<id>/settings/compliance` → expect **ALLOW**.
   - Write `districts/<id>/settings/compliance` → expect **DENY**.
   - Read `districts/<id>/complianceAudits/<auditId>` → expect **ALLOW**.
   - Create/update `districts/<id>/complianceAudits/<auditId>` → expect **DENY**.
   - Delete `districts/<id>/complianceAudits/<auditId>` → expect **DENY**.
3. As a user with no membership (or an inactive/wrong-version membership) on district `<id>`:
   - Any read or write under `districts/<id>/settings/**` or `districts/<id>/complianceAudits/**` →
     expect **DENY**.
4. Confirm `districts/<id>/auditEvents/**` behavior is unchanged (read gated by
   `hasCapability(districtID, 'audit.read')` or actor match; write always denied) — this collection
   was not touched by this change.

These checks were **not** run as part of this commit — they require the Firebase emulator (or a
disposable live project) and authenticated test users for each role, which were not exercised in
this session. This document records the expected behavior so the checklist can be executed in a
follow-up verification pass (e.g. via `firebase emulators:exec` with the project's existing rules
test harness under `firebase/`) before this is treated as production-verified.
