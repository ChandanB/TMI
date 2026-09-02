# Debug Synthetic Staff Membership Design

**Date:** 2026-09-01
**Status:** Approved

## Purpose

Provide one reliable staff account path for local Debug builds without requiring Cloud Functions, Firestore invitation seeding, or custom Firebase Auth claims. Firebase Authentication remains responsible for creating, signing in, and restoring the identity. Only the staff membership needed to enter the app is synthesized locally.

Release builds retain the existing server-authoritative invitation and membership flow without fallback behavior.

## Fixed Debug Identity and Scope

The bypass recognizes only this exact fixture after normalizing the identity email by trimming whitespace and lowercasing it:

- Firebase project: `tmi-education`
- Email: `tmi-debug@example.com`
- Invitation alias: `TMI-DEBUG-ACCESS-2026`
- District ID: `district-debug`
- School IDs: `school-debug`
- Role: `teacher`
- Capabilities: `student.read.detail`, `student.write.detail`
- Assigned student IDs: empty
- Active: `true`
- Membership version: `1`

This scope matches `firebase/src/debugInvitation.ts`. The client must not add administrative, restricted-record, reporting, audit, or plan-approval capabilities.

The invitation alias comparison is exact after the registration request's existing surrounding-whitespace trimming. An eligible alias presented by any other email is rejected. Any other invitation code uses the normal Firebase provisioner.

## Architecture

### Canonical Debug Fixture

`DebugStaffInvitationProvisioner` remains compiled only under `#if DEBUG` and becomes the single owner of the fixed identity constants and canonical membership construction. The membership factory accepts the authenticated Firebase user ID so the resulting `MembershipContext.userID` always binds to the actual identity.

The factory returns an `AuthIdentity` whose district ID is `district-debug` alongside the canonical active membership when a complete authorized session is needed. It never fabricates or replaces the Firebase user ID.

### Provisioning Decorator

For the exact alias and allowed email, `DebugStaffInvitationProvisioner` returns the canonical membership locally and does not call its Firebase Cloud Functions delegate. For all other invitation codes, it delegates unchanged. For the alias with a nonmatching or missing identity email, it fails with the existing Debug email-not-allowed error and does not call the delegate.

`StaffInvitationProvisioning` gains a post-provision claim-refresh policy whose default is to require the existing trusted Firebase claim refresh. This preserves current behavior for the production provisioner and test doubles. The Debug provisioner waives that refresh only for the exact eligible alias and identity.

### Registration Completion

Registration still calls Firebase Authentication to create the user and still persists the pending registration before provisioning. Once the eligible Debug membership is synthesized, `AuthenticationRepository`:

1. does not call the backend claim refresh;
2. constructs the authorized session from the authenticated Firebase identity, adding only the canonical Debug district ID;
3. clears the pending registration; and
4. returns the authorized session so the registration sheet can dismiss for that exact identity.

If pending-store cleanup fails, registration still returns the authorized session and restores the pending record for the existing safe retry behavior. The identity is never rolled back after successful Debug membership synthesis.

Normal registrations continue to provision through Cloud Functions, force-refresh Firebase claims, validate identity and district agreement, and use the existing rollback and recovery rules.

### Sign-In and Restored Sessions

A `DebugAuthenticationSessionLoader` decorates the existing Firebase session loader under `#if DEBUG`.

For `tmi-debug@example.com`, it returns the canonical authorized session bound to the supplied Firebase identity without requesting custom claims or reading a Firestore membership document. This covers:

- a later email-and-password sign-in;
- repository refresh after the app observes an existing Firebase identity; and
- current-session restoration on a subsequent app launch.

The decorator accepts only an identity already obtained from Firebase Authentication. It does not bypass password validation, create an offline identity, or authorize a different email. Every other identity delegates to `FirebaseAuthenticationSessionLoader` unchanged.

## Build Isolation

All synthetic membership types, fixture constants, and dependency wiring are enclosed in `#if DEBUG`. `AppDependencies.production(firestore:)` wraps the Firebase provisioner and session loader only in Debug compilation. Release compilation directly constructs the existing Firebase provisioner and Firebase session loader.

The opaque server invitation code is not required by this path and must not be embedded in the app. Release products must contain neither the friendly Debug alias nor the fixed Debug email or membership identifiers.

## Error and Security Boundaries

- Firebase Authentication errors are surfaced normally; the bypass cannot register or sign in without a real Firebase Auth identity.
- The fixed invitation alias cannot authorize any email other than `tmi-debug@example.com`.
- Non-Debug invitations and identities never receive synthetic membership.
- The synthesized membership grants only the two capabilities present in the canonical Firebase Debug invitation fixture.
- Release builds remain fail-closed and server-authoritative.
- No Cloud Functions call or Firestore membership read is required for the eligible Debug identity.

## Tests

Implementation begins with failing tests covering:

1. eligible Debug provisioning returns the exact canonical teacher membership and never calls the delegate;
2. the Debug alias with another or missing email is rejected without delegation;
3. a non-Debug invitation delegates unchanged;
4. eligible registration creates the Firebase Auth identity, saves pending state, skips verification when the feature flag disables it, skips claim refresh and Cloud Functions, clears pending state, and returns authorized access;
5. eligible sign-in and repository refresh/restoration return the canonical authorized session without invoking the production session loader;
6. non-Debug sign-in and refresh delegate unchanged;
7. pending-store cleanup failure preserves the existing retry-safe behavior;
8. dependency assembly selects both decorators only in Debug source regions; and
9. Release builds and product-string scans verify that Debug fixture strings are excluded.

Focused authentication tests must pass before running Debug iOS, Release iOS, and Release macOS builds. The existing live Firebase Auth registration/sign-in acceptance remains the final integration gate before merging to `main`.
