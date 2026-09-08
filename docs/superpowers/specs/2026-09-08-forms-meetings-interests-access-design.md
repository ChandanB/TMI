# Forms, Meetings, and Interests Access Repair

**Date:** 2026-09-08
**Status:** Approved design, pending implementation plan
**Authority:** Extends `2026-07-19-tmi-final-product-blueprint-design.md`

## Objective

Restore reliable access to interests, form templates, form assignments, and meetings without weakening tenant security. Remove operational Forms and Meetings destinations from Settings and make them reachable from the educator workflows defined by the product contract.

## Confirmed Causes

1. `InterestLibraryService` reads and writes the obsolete top-level `interests` collection. The canonical interest catalog is `catalogs/interests/items`, and client catalog mutation is not authorized.
2. Meetings, form templates, and form assignments use canonical district paths, but their concrete services instantiate Firestore transports directly. The Debug staff session synthesizes a local membership that is intentionally unavailable to Firestore security rules, so those direct requests are denied.
3. Settings currently exposes Form Templates, Form Assignments, and Meetings as operational destinations. The navigation contract reserves Settings for account and configuration concerns and embeds these workflows in student, plan, and dashboard context.

## Navigation Design

The permanent staff navigation remains:

- Dashboard
- Students
- TMI Plans
- District, for authorized administrators

Forms and Meetings will be removed from Settings. They will be reachable through:

- Student detail: Forms and Meetings sections scoped to the active student.
- Plan detail: attached forms and plan-review meetings scoped to the active plan.
- Dashboard: contextual quick actions and pending/upcoming summaries that route into the relevant student or plan context.

No standalone Forms or Meetings main tab will be added. Routes must retain and validate active student or plan context before presenting mutable records.

## Data and Dependency Design

### Interests

The interest library will read from `FirestorePaths.catalogItems(.interests)`. Catalog writes and seeding remain server-owned. Client UI that currently offers direct catalog creation, editing, or deletion will show an explicit unavailable state or use an authorized student-interest workflow; it will not write around the rules.

Debug builds will use deterministic local catalog fixtures so the Interests experience remains testable without trusted Firebase claims.

### Meetings

Meeting operations will depend on an injected meeting repository/store selected by `AppDependencies`:

- Production: district-scoped Firestore implementation at `districts/{districtID}/meetings`.
- Debug synthetic tenant: deterministic local implementation with the same authorization-facing contract.

Participant-scoped reads remain mandatory in production. Existing Firestore rules will not be broadened.

### Forms

Form template and assignment operations will depend on injected repositories selected by `AppDependencies`:

- Production: canonical district-scoped Firestore implementations.
- Debug synthetic tenant: deterministic local implementations that preserve template and assignment relationships.

Authorization decisions continue to use `MembershipContext`, school boundaries, assigned-student scope, and capabilities. Submitted-response mutation and trusted review remain outside this repair unless required to compile or preserve an existing contract.

## Error Handling

- Permission failures must identify the unavailable feature without exposing raw Firebase internals to users.
- Empty data is distinct from failed loading.
- Debug fixtures must not silently replace failed production requests.
- Production authentication or membership failures remain explicit and fail closed.

## Testing and Verification

Implementation will begin with failing tests covering:

1. Interest catalog reads use `catalogs/interests/items` and no active top-level `interests` access remains.
2. Debug staff sessions route Meetings and Forms through local repositories rather than Firestore.
3. Production Meetings and Forms retain canonical district paths and authorization constraints.
4. Settings no longer contains operational Forms and Meetings destinations.
5. Student/plan/dashboard navigation exposes the contextual routes required by the product contract.

Verification will include focused Swift tests, Firestore rules tests, a full relevant test pass, and a runtime smoke test using the Debug staff account. Runtime evidence must show that Interests, Meetings, Form Templates, and Form Assignments load without permission-denied errors.

## Non-Goals

- Adding Forms or Meetings as permanent main tabs.
- Broadening Firestore rules to trust editable profile data or Debug-only claims.
- Treating Blaze billing as an authorization mechanism.
- Completing the separate trusted form-review backend or all GA Forms work.
- Refactoring unrelated legacy Firestore paths.
