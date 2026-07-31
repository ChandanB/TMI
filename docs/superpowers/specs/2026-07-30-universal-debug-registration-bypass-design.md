# Universal Debug Registration Bypass Design

> **Status: deferred after integration review.** The proposed client-only
> provisioner does not create the canonical Firebase profile, tenant claim, and
> membership reloaded by `AuthStateModel`, so its implementation was not merged
> to `main`. A future bypass must provision canonical backend authority or
> provide a complete Debug authorization stack; this document is not approved
> for implementation as written.

## Goal

Allow developers to register and recover a staff account in an ordinary Debug build without first creating a Firebase staff invitation.

The universal Debug invitation code is:

`TMI-DEBUG-ACCESS-2026`

## Scope and boundaries

- The bypass is compiled only when `DEBUG` is defined.
- It requires no launch argument or environment variable in a Debug build.
- Release builds retain the existing trusted Firebase invitation flow and do not contain the bypass code or provider.
- The bypass grants only the synthetic `teacher` authority for `district-debug` and `school-debug`.
- The bypass is accepted only for the exact normalized email `tmi-debug@example.com`.
- Any other invitation code or email continues through the existing Firebase callable.
- Existing account deletion and institution-owned data-retention behavior is unchanged.

## Architecture

A Debug-only invitation provisioner decorates the existing
`StaffInvitationProvisioning` boundary. For the exact bypass-code and email
pair, it returns a canonical synthetic staff membership result. Otherwise, it
delegates unchanged to `FirebaseStaffInvitationProvisioner`.

`AppDependencies.live` installs the decorator only in Debug compilation. The
authentication repository and views continue to use the same protocol and
registration flow, so no UI-specific backdoor or Firebase schema mutation is
required.

## Data flow

1. The developer registers `tmi-debug@example.com` with any valid password and
   enters `TMI-DEBUG-ACCESS-2026`.
2. Firebase Authentication creates or authenticates the identity normally.
3. The Debug provisioner recognizes the exact normalized email and code.
4. It returns the synthetic teacher membership for `district-debug` and
   `school-debug`.
5. The authentication repository publishes the authenticated staff session.
6. Existing users missing canonical onboarding can use the same code through
   Staff Access Setup.

The bypass does not accept arbitrary email addresses and does not change the
email-verification feature flag.

## Error handling

- The universal code with a non-debug email fails as an unusable invitation.
- Empty or malformed input keeps the existing validation behavior.
- All non-bypass codes delegate to Firebase and retain existing retry,
  rollback, identity-binding, and partial-state handling.

## Verification

- Unit tests cover successful registration and Staff Access Setup with the
  exact Debug email and code.
- Unit tests verify case-insensitive email normalization.
- Unit tests verify rejection for a different email.
- Unit tests verify non-bypass codes delegate to Firebase.
- A source-contract test verifies the implementation is enclosed by
  `#if DEBUG`.
- Release builds for iOS Simulator and macOS must succeed.
- Existing authentication and Firebase test suites must remain green.

## Out of scope

- Creating or deploying a live Firebase invitation.
- Allowing arbitrary emails to use the universal code.
- Adding the bypass to TestFlight, App Store, or other Release builds.
- Changing staff roles, institutional identifiers, or production authorization
  rules.
