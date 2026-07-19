# Account Deletion Review Remediation Design

**Date:** 2026-07-19
**Context:** App Store Review Guideline 5.1.1(v), submission `0aaf4efa-7ee2-4b0d-b1f6-1d9827072367`

## Goal

Make permanent account deletion easy to find and complete inside TMI while preserving institution-owned educational and compliance records.

## Current Gaps

The repository already contains `DeleteAccountView` and `AuthenticationService.deleteAccount(password:)`, but the entry point is in `SettingsView`. The shipped navigation opens `UserProfileView` and does not expose `SettingsView`, so a user or reviewer cannot reach account deletion.

The existing deletion service also deletes user-scoped `students` and `tmiPlans`, contrary to the approved retention policy, and omits several private user-scoped collections and profile-image locations.

## Reachable User Flow

1. The signed-in user opens the profile menu and selects Profile.
2. `UserProfileView` shows a destructive Delete Account action under Account Settings.
3. The action presents `DeleteAccountView`.
4. The warning step distinguishes deleted personal data from retained institutional data.
5. The confirmation step requires the current password.
6. The app reauthenticates, removes personal data and profile uploads, and deletes the Firebase Auth account.
7. The existing authentication-state listener returns the app to its signed-out state.

The complete App Review recording path is: Sign in -> Profile -> Delete Account -> Continue -> enter password -> Permanently Delete Account.

## Retention Policy

### Permanently deleted

- Firebase Authentication account
- `users/{uid}` profile document
- Private preferences, notifications, recommendations, saved career activity, survey responses, and other personal-only user-scoped data
- Personal interests and personal resources owned solely by the deleting user
- Profile photos at both storage paths currently used by the app
- Local authenticated session state and private caches

### Preserved

- Student records
- TMI plans
- Form assignments and submissions
- Meetings and action items that form part of an institutional record
- Consent records
- Audit and compliance records
- District and school records
- Shared or institution-owned templates and resources

Retained records may keep a stable opaque user identifier where required for audit integrity, but the deleted user profile will no longer provide a name, email address, or active login associated with that identifier.

## Architecture

### `AccountDeletionPolicy`

A small value type defines the personal subcollections that may be erased and the institutional subcollections that must be preserved. The deletion service consumes this policy instead of embedding an unsafe ad hoc list. Unit tests assert that protected collections never enter the deletion set.

### `AccountDeletionService`

The service owns the destructive sequence and exposes one async operation. Its collaborators are injected behind narrow protocols so ordering and failure behavior can be tested without a live Firebase project.

The sequence is:

1. Validate the current email/password user.
2. Reauthenticate with the supplied password.
3. Delete personal-only Firestore subcollections in bounded batches.
4. Delete known personal profile-photo objects. A missing object is treated as already deleted.
5. Delete `users/{uid}`.
6. Delete the Firebase Auth user last.

Any failure before step 6 leaves the Auth account active and returns a retryable error. The service is idempotent: missing personal documents or files do not prevent a later retry.

Institution-owned collections are never passed to the deletion primitive. They remain available under their existing storage model.

### SwiftUI integration

`UserProfileView` owns a Boolean sheet state and presents the existing deletion sheet. `DeleteAccountView` remains a focused two-step state machine, but its copy reflects the approved retention policy and its action calls the hardened deletion service.

The destructive action uses a text label, red styling, and a clear irreversible-action description. Loading disables repeated submission, errors remain visible inline, and Cancel and Go Back remain available before deletion begins.

## Error Handling

- Empty password: destructive button remains disabled.
- Incorrect password: show a specific reauthentication error without deleting data.
- Network or Firestore failure: keep the account active and show a retry message.
- Missing personal document or image: continue because the desired state is already satisfied.
- Firebase Auth deletion failure: report the failure while leaving the signed-in account available for retry.
- Success: clear local session state and allow the root authentication switch to show sign-in.

## Testing

- Unit-test the policy to prove student, plan, assignment, submission, consent, meeting, audit, and compliance collections are preserved.
- Unit-test destructive operation ordering: reauthentication first and Auth deletion last.
- Unit-test that a cleanup failure prevents Auth deletion.
- Unit-test idempotent handling for already-missing personal data.
- Verify the Profile source exposes and presents Delete Account.
- Verify the confirmation UI includes both deletion and retention disclosures.
- Build and run the focused tests, then run the full project test suite.

## Out of Scope

- A new Firebase Cloud Functions deployment
- Deleting institution-owned educational records
- Redesigning unrelated Profile or Settings controls
- Supporting federated authentication providers, because the app currently creates and signs in accounts with Firebase email/password only

## App Review Evidence

After installing the updated build on a physical Mac or supported iOS device, record the complete flow from account creation or demo sign-in through the final deletion confirmation. Attach the recording in App Review Information -> Notes and summarize that deletion is available at Profile -> Delete Account.
