# Registration Presentation Recovery Design

**Status:** Approved on August 31, 2026

## Goal

Keep staff registration visible until the application has either published a
fully trusted authenticated session or displayed the registration failure.
Firebase's intermediate authentication callbacks must not silently replace the
registration form with the sign-in screen.

This design complements the approved canonical Debug registration repair. It
does not weaken Firebase authorization, invitation validation, or rollback.

## Confirmed Failure

Creating a Firebase Auth identity immediately emits an authentication-state
callback. The app root then replaces `AuthenticationView`, which owns the
registration sheet, while invitation provisioning is still in progress. If
provisioning later fails and the repository deletes the new identity, the
listener transitions to `.unauthenticated`; the user sees the sign-in screen
instead of the registration error.

The currently running `main` build also lacks the approved Debug invitation
translator. That causes the memorable Debug alias to reach Firebase unchanged,
fail validation, and trigger this rollback path. The translator repair and a
seeded canonical Firebase invitation remain prerequisites for successful Debug
registration.

## Chosen Design

### Root-owned registration presentation

The app's standard composition root will own whether staff registration is
presented. `AuthenticationView` will request presentation through an explicit
action or binding rather than owning the sheet itself. Because the root remains
alive across authentication-state transitions, Firebase callbacks cannot
destroy the registration form while submission is in flight.

The root will continue presenting the form through intermediate states,
including loading, staff-access setup, authorization recovery, and rollback to
unauthenticated. The user may cancel before submitting. While submission is in
progress, the existing disabled/loading controls prevent duplicate requests.

### Success-gated dismissal

`SimplifiedRegistrationView` will no longer dismiss merely because the
repository call returned. The form will record the `identity.userID` returned
by the successful repository registration. After registration it will request
an authorization refresh and wait for `AuthStateModel` to publish a fully
trusted authenticated session whose profile, claim, and membership belong to
that exact user ID. `isLoggedIn` alone is not a sufficient dismissal condition.
Only the matching confirmed session closes the form.

If registration or authorization fails, the form remains visible and presents
a standard staff-mode error. Sensitive values such as the password and
invitation code remain cleared according to the existing behavior. After a
terminal rollback, the user can correct the input or retry without being
silently redirected.

### Ambiguous post-commit recovery

`StaffInvitationProvisioningError.claimRefreshPending` is recovery state, not a
fresh-registration failure. The repository deliberately preserves both the
Firebase identity and encrypted pending registration because the server may
already have committed canonical records.

When registration reports this condition, the form remains presented, enters
recovery, and calls the existing `AuthenticationProviding.refresh()` path to
continue the pending registration idempotently. It must not call `register()`
or create another Firebase identity. If the immediate recovery attempt remains
pending, the form exits its non-dismissible operation state, displays recovery
guidance, and offers a retry action that calls `refresh()` again. A retry never
submits the original Create Account request.

Recovery records the identity returned by `refresh()` and applies the same
identity-specific trusted-session dismissal gate. A missing or mismatched
identity fails closed and keeps the form visible.

### Dismissal control

Once submission or pending-registration recovery begins, registration is
non-dismissible until the active operation reaches a terminal failure or a
matching trusted-session success. The toolbar Cancel action is disabled during
that interval, and the root-owned sheet disables interactive dismissal. Cancel
remains available before submission and after a terminal failure.

### Security and rollback

The existing repository remains responsible for identity creation,
server-authoritative invitation provisioning, claim refresh, and rollback. A
known pre-commit provisioning failure still deletes the just-created Firebase
identity. An ambiguous post-commit failure still preserves the identity and
encrypted pending registration for idempotent recovery.

Presentation state never grants account access. The app routes to staff content
only from `AuthStateModel.isLoggedIn`, which requires a canonical profile,
trusted claim, and active matching membership.

## Data Flow

1. The user opens registration; the app root presents the form.
2. The form calls the canonical authentication repository.
3. Firebase may emit intermediate identity callbacks, but the root keeps the
   form presented.
4. On a terminal pre-commit failure, the repository rolls back the identity;
   the form remains visible with an actionable error and permits correction or
   retry.
5. On `claimRefreshPending`, the identity and pending record remain; the form
   invokes `refresh()` idempotently and never creates a second identity.
6. On canonical repository success, the form records the returned identity ID,
   clears secrets, and requests authorization refresh.
7. After `AuthStateModel` publishes `.authenticated` for that exact identity,
   the root dismisses the form and reveals the staff workspace.
8. An unrelated, stale, missing, or mismatched authenticated identity never
   dismisses registration.

## Verification

Automated coverage will prove:

- Registration presentation survives an intermediate authenticated callback.
- A terminal provisioning failure followed by identity deletion leaves the
  form visible and displays the error.
- An ambiguous post-commit result preserves the form and identity, invokes the
  existing pending-registration `refresh()` path, and never calls user creation
  or `register()` a second time.
- A successful repository result does not dismiss before a trusted session for
  the returned identity is published.
- An authenticated session for a different identity does not dismiss the form.
- Publishing the matching trusted authenticated session dismisses registration
  and routes to staff content.
- Cancel still dismisses registration when no submission is in progress.
- Cancel during submission or recovery does not dismiss registration.
- Interactive sheet dismissal is disabled during submission or recovery.
- Existing authentication, Debug invitation, and Release-isolation tests pass.

The focused suite will be followed by Debug and Release builds. Live acceptance
still requires an authorized operator to seed the canonical invitation in the
configured `tmi-education` Firebase project.

## Out of Scope

- Suppressing or buffering Firebase authentication callbacks.
- Keeping failed, unprovisioned Firebase identities.
- Client-synthesized memberships or claims.
- Changing invitation security, account roles, or production release behavior.
- Adding a general registration coordinator beyond this presentation boundary.
