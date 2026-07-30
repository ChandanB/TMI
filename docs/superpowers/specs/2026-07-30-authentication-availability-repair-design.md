# TMI Authentication Availability Repair Design

**Date:** July 30, 2026
**Status:** Approved for implementation
**Scope:** Staff authentication, onboarding recovery, and startup availability

## Goal

Make every supported build leave the intro loading screen deterministically and provide a usable path for staff to sign in or register while email verification is temporarily disabled.

This repair does not weaken tenant, invitation, membership, role, or assigned-student authorization. It bypasses only the email-verification prerequisite.

## Confirmed failure modes

1. A persisted Firebase identity starts authorization during launch. Profile, token-claim, and membership requests are currently unbounded, so a stalled request can leave `AuthStateModel` in `.loading` forever.
2. Email verification is enforced independently by the app session policy, authentication repository, state model, and staff-invitation callable. Removing only the visible prompt cannot make registration work.
3. Older Firebase identities may not have the canonical private profile, trusted tenant claims, or active district membership introduced by the canonical authorization foundation.
4. The acceptance fixture invitation `DISTRICT-INVITE-2026` is not a live Firebase invitation and must not be presented as one.

## Chosen approach

### Temporary email-verification flag

Add an explicit `staffEmailVerificationRequired` flag to the application feature flags and the staff-invitation backend configuration. It is disabled for current builds.

When disabled:

- registration does not send a verification email;
- an unverified Firebase identity may proceed to invitation provisioning;
- the client does not present the email-verification gate;
- the callable accepts an authenticated user whose email is present even when Firebase reports it as unverified;
- the canonical profile records the actual Firebase verification value rather than falsely claiming verification.

When re-enabled, the existing verified-email behavior and tests remain available without redesigning authentication.

### Bounded startup authorization

Initial authorization receives a finite deadline around each remote boundary: private-profile read, forced token refresh, and membership read. A timeout or connectivity failure exits `.loading` and presents a recoverable organization-access state.

That state provides:

- **Retry**, which starts one fresh authorization attempt for the current identity;
- **Sign Out**, which clears the persisted Firebase session and returns to the login screen.

The application never treats a timeout as authorization and never falls back to cached membership for privileged access.

### Existing-account recovery

An authenticated identity without canonical onboarding artifacts enters an **Access Setup Required** flow instead of a generic error or incomplete registration state.

The user supplies a valid staff invitation. The trusted callable then creates the canonical profile, policy acknowledgements, membership, audit record, and claims using the same transaction as new registration. No role, district, or school authority is inferred from an editable legacy profile.

If the identity already has compatible canonical records, provisioning remains idempotent. If the invitation is missing, expired, email-mismatched, or already consumed by someone else, the flow returns the same non-enumerating invitation error used by registration.

### Registration and login behavior

New registration:

1. Validate the form and invitation presence.
2. Create the Firebase identity.
3. Save pending onboarding state.
4. Skip verification email while the flag is disabled.
5. Provision the invitation immediately.
6. Refresh claims and publish the trusted staff session.

Existing login:

1. Authenticate with Firebase email/password.
2. Bound the canonical authorization attempt.
3. Publish the trusted session when profile, claims, and membership match.
4. Present Access Setup Required when canonical onboarding is absent.
5. Present recoverable Retry/Sign Out when authorization is unavailable.

## Security boundaries

- A password-authenticated Firebase identity alone never grants application access.
- Staff access still requires a server-owned invitation or an existing valid trusted membership.
- All staff routing remains derived from trusted claims and canonical membership.
- Student and guardian accounts remain feature flagged.
- Errors do not reveal whether another email or invitation exists.
- Institution-owned student and plan records remain outside personal-account deletion.
- The email-verification bypass must be called out in release evidence and restored before a production security sign-off.

## Testing

### Client unit tests

- An unverified identity can proceed when the flag is disabled.
- The same identity is held at verification when the flag is enabled.
- Registration skips `sendVerification` and provisions immediately when disabled.
- Registration preserves the existing pending-verification behavior when enabled.
- Startup timeout exits loading.
- Retry starts a fresh bounded authorization attempt.
- Sign Out from recovery returns to unauthenticated state.
- Missing canonical artifacts produce Access Setup Required without authorizing.
- Existing-account invitation repair publishes only a matching trusted session.

### Backend tests

- An unverified authenticated user can consume a valid invitation when the backend flag is disabled.
- Verification remains mandatory when enabled.
- Invitation email binding, expiry, consumption, idempotency, claims, membership, and audit behavior remain enforced in both modes.

### UI acceptance

- Cold launch with no user reaches login.
- Cold launch with a stalled persisted session reaches recovery within the deadline.
- Existing-user login reaches the staff shell or Access Setup Required.
- New registration with a real invitation reaches the staff shell without an email-verification screen.
- Retry and Sign Out are reachable on iPhone, iPad, and macOS.

## Deployment note

The client and Firebase Functions changes must be released together. Shipping only the client bypass would leave server-side invitation provisioning blocked. Function deployment and creation of real staff invitations remain explicit operational actions and are not performed merely by compiling the application.
