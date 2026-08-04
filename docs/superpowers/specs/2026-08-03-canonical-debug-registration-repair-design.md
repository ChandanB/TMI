# Canonical Debug Registration Repair Design

**Status:** Approved for implementation on August 3, 2026

## Goal

Make ordinary Debug builds accept the memorable staff invitation code
`TMI-DEBUG-ACCESS-2026` for `tmi-debug@example.com`, complete canonical Firebase
staff provisioning, and enter the application without weakening Release builds.

The repair must also prevent a successfully provisioned account from losing its
recovery record before Firebase claims have refreshed.

## Confirmed Failure

The current `main` branch does not install the previously requested Debug
invitation decorator. Consequently, `TMI-DEBUG-ACCESS-2026` reaches the
production `provisionStaffMembership` callable as a malformed invitation. The
authentication repository then rolls back the newly created Firebase Auth user
and clears `authentication.pending-staff-registration`. This produces the
observed secure-storage save/delete sequence without authorizing the app.

The deferred client-only bypass is not suitable for integration. Returning a
synthetic `MembershipContext` cannot satisfy `AuthStateModel`, which separately
loads the canonical Firebase profile, tenant claim, and membership. It would
also leave Firestore requests without trusted staff claims.

## Architecture

### Canonical Debug invitation alias

Debug builds will decorate `FirebaseStaffInvitationProvisioner`. For the exact
normalized pair below, the decorator replaces the memorable alias with one
valid opaque invitation token and then delegates to the existing Firebase
callable:

- Email: `tmi-debug@example.com`
- Alias: `TMI-DEBUG-ACCESS-2026`

All other codes pass through unchanged. The decorator will be enclosed by
`#if DEBUG`; Release compilation and dependency composition will continue to
use `FirebaseStaffInvitationProvisioner` directly.

The corresponding invitation record will be created in the currently
configured Firebase project, `tmi-education`, using the existing trusted
invitation schema. The repository does not yet contain a separate development
Firebase configuration. The invitation will be bound to the normalized Debug
email, grant a teacher membership in the Debug district and school, expire
before GA, and contain only the capabilities required for the current
deterministic application workflows.

This preserves the existing source of authority: the callable validates the
authenticated identity and invitation, creates the canonical profile,
membership, policy acknowledgements, preferences, and audit event, and sets
the Firebase custom claims before returning.

### Post-provision authorization refresh

`AuthenticationRepository` will treat a successful provisioning response as a
committed server operation, not as final client authorization. It will:

1. Force-refresh the current Firebase identity and ID token.
2. Confirm the refreshed identity still matches the pending registration.
3. Return the trusted provisioned membership using the refreshed identity.
4. Clear the pending registration only after refresh succeeds.

If token refresh fails after provisioning, the repository will translate the
failure to the existing recoverable `claimRefreshPending` state. It will retain
both the Firebase Auth identity and the encrypted pending registration so that
sign-in or refresh can retry the idempotent provisioning flow. It must not
delete a user after the server may have committed canonical records.

Existing-account Staff Access Setup will use the same forced-refresh behavior
after its invitation is accepted and before `AuthStateModel` reloads canonical
authorization.

## Data Flow

1. The developer registers `tmi-debug@example.com` with a valid password and
   enters `TMI-DEBUG-ACCESS-2026` in an ordinary Debug build.
2. Firebase Auth creates the identity and the repository saves the encrypted
   pending registration.
3. The Debug decorator recognizes the exact email and alias, substitutes the
   opaque invitation, and delegates to `provisionStaffMembership`.
4. The callable creates or validates the canonical onboarding records, sets
   trusted claims, and returns the canonical membership.
5. The repository forces an ID-token refresh. On success it clears the pending
   registration.
6. `AuthStateModel.fetch()` loads the canonical profile, refreshed claim, and
   canonical membership, then publishes an authenticated session.
7. The app routes to the staff workspace.

Normal institutional invitations follow the same flow without alias
translation. Release builds never contain or recognize the Debug alias.

## Error Handling and Recovery

- The Debug alias with any other email fails locally without delegating or
  exposing whether another account exists.
- A missing or invalid institutional invitation retains the current generic
  registration failure presentation and rolls back a newly created Auth user
  only when the server operation is known not to have committed.
- Ambiguous callable failures preserve the identity and pending registration.
- Post-provision token-refresh failures preserve the identity and pending
  registration and surface a retryable authorization message.
- Reusing the Debug invitation for the same Firebase UID remains idempotent.
- Reusing a consumed invitation for a different UID fails closed. Creating a
  replacement invitation is an explicit development administration action.
- Secure logs may report pending-record storage and deletion, but must not log
  the opaque invitation token, password, or ID token.

## Security Boundaries

- No editable client field grants role, district, school, capability, or
  student scope.
- The memorable alias and opaque token are compiled only into Debug builds.
- The trusted callable remains the only component that provisions Firebase
  staff authority.
- The invitation is email-bound, single-recipient, expiring, and consumable.
- Release behavior, Firestore rules, account deletion, and institutional-data
  retention remain unchanged.
- The temporary Debug invitation in `tmi-education` must be revoked or allowed
  to expire, and its alias mapping removed, before GA. Public Release builds do
  not contain the alias or opaque token.

## Verification

Automated coverage will prove:

- The exact normalized Debug email and alias delegate with the expected opaque
  invitation while no other email can use the alias.
- Non-Debug invitation codes delegate unchanged.
- Release source composition does not install the Debug decorator.
- Registration force-refreshes identity after provisioning and clears pending
  state only afterward.
- A post-provision refresh failure preserves the identity and pending state.
- Staff Access Setup refreshes claims before canonical authorization reload.
- Focused authentication tests, Firebase invitation tests, and Debug and
  Release builds pass.

Live verification will create or confirm the temporary Debug invitation in
`tmi-education`, register the Debug account, and verify that the app reaches
the staff workspace with a canonical profile, claim, and membership.

## Out of Scope

- A general-purpose production invitation administration UI.
- Arbitrary-email or arbitrary-role Debug access.
- Synthetic client-only Firebase authority.
- Weakening App Check, Firestore rules, or callable authentication.
- Making the Debug invitation reusable across different Firebase UIDs.
