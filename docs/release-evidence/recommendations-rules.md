# Recommendations — Firestore rules coverage

Task 6.1 moves `RecommendationsService` from `users/{uid}/recommendations` to
the district-scoped tree, mirroring the Task 4.1 `MeetingService` pattern.
This records how the new path is authorized by `firestore.rules`, and the
manual checks to run once against the live project (rules cannot be verified
locally without the emulator).

## Collection — `districts/{districtID}/recommendations/{recommendationID}`
- Rule: `firestore.rules` `match /districts/{districtID}` → `match
  /recommendations/{recommendationID}` (added just before the district block's
  `{unmatched=**}` deny, near the `complianceAudits` block, ~line 1120):
  ```
  match /recommendations/{recommendationID} {
    allow read: if hasActiveMembership(districtID);
    allow write: if hasActiveMembership(districtID);
  }
  ```
- `allow write` covers `create`, `update`, and `delete`, matching
  `RecommendationsService.saveRecommendation` / `updateRecommendation` /
  `deleteRecommendation`.
- `hasActiveMembership(districtID)` already requires the caller to hold an
  active staff membership in that district (see the function definition
  ~line 49), so this satisfies "staff can write" without widening to `if
  true`. It intentionally does not further restrict by role/capability
  beyond membership — recommendations are a district-shared advisory
  artifact, same trust level as `meetings`.
- Path is registered in `FirestorePaths.recommendations(districtID:)` /
  `productionCollectionTemplates` (`TMI/Services/FirestorePaths.swift`) and
  covered by `TMITests/Services/FirestorePathsTests.swift`.

## Manual checks (run once against the live project or emulator)
1. As an active staff member of district `d1`, `read` and `write` (create,
   update, delete) a document at `districts/d1/recommendations/{id}` → expect
   ALLOW for all four operations.
2. As a user with no active membership in `d1` (e.g. member of a different
   district, or a deactivated membership) → expect DENY on read and write.
3. As an unauthenticated request → expect DENY (covered generally by
   `hasActiveMembership` requiring `request.auth != null`).
4. Confirm no client can still reach the old `users/{uid}/recommendations`
   shape with district-scoped data — `RecommendationsService` no longer
   constructs that path at all, so there is nothing to deny; the legacy path
   is otherwise covered by the top-level `users/{uid}/{unmatched=**}` deny
   rule already in place.

Verified via `TMITests/StateModels/RecommendationsStateModelTests.swift`
(fake district-scoped store + fake trusted session) that
`RecommendationsService` reads/writes/deletes exclusively at
`districts/{districtID}/recommendations`, and that no `users/` path is used;
the emulator/live-project allow/deny checks above still need a one-time
manual run since rules cannot be exercised by the unit test suite.
