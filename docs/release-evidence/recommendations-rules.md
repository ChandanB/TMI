# Recommendations — Firestore rules coverage

Task 6.1 moves `RecommendationsService` from `users/{uid}/recommendations` to
the district-scoped tree, mirroring the Task 4.1 `MeetingService` pattern.
This records how the new path is authorized by `firestore.rules`, and the
manual checks to run once against the live project (rules cannot be verified
locally without the emulator).

## Collection — `districts/{districtID}/recommendations/{recommendationID}`
- Rule: `firestore.rules` `match /districts/{districtID}` → `match
  /recommendations/{recommendationID}` (added just before the district block's
  `{unmatched=**}` deny, near the `complianceAudits` block, ~line 1127):
  ```
  match /recommendations/{recommendationID} {
    allow read: if hasActiveMembership(districtID);
    allow create: if hasActiveMembership(districtID)
      && canCollaborateOnStudent(districtID, request.resource.data.studentId);
    allow update: if hasActiveMembership(districtID)
      && canCollaborateOnStudent(districtID, resource.data.studentId)
      && canCollaborateOnStudent(districtID, request.resource.data.studentId);
    allow delete: if hasActiveMembership(districtID)
      && canCollaborateOnStudent(districtID, resource.data.studentId);
  }
  ```
- `create`/`update`/`delete` are gated on `canCollaborateOnStudent(districtID,
  studentID)` (defined ~line 287), matching the pattern used by sibling
  student-scoped collections (e.g. `careerRelationships`, `progressEntries`).
  `update` checks collaboration against both the existing document's
  `studentId` and the incoming payload's `studentId`, so a write cannot be
  used to reassign a recommendation onto a student the caller can't
  collaborate on. `RecommendationsService.toFirestoreData()` always writes a
  `studentId` field, and `parseRecommendation` reads it back, so every
  document has the field the rule depends on.
- `hasActiveMembership(districtID)` still requires the caller to hold an
  active staff membership in that district (see the function definition
  ~line 49); read remains active-member-only per the original plan, but
  writes now also require collaboration on the referenced student, so a
  district member with no relationship to the student can no longer
  create, overwrite, or delete that student's recommendations.
- Path is registered in `FirestorePaths.recommendations(districtID:)` /
  `productionCollectionTemplates` (`TMI/Services/FirestorePaths.swift`) and
  covered by `TMITests/Services/FirestorePathsTests.swift`.

## Manual checks (run once against the live project or emulator)
1. As a staff member who can collaborate on student `s1` in district `d1`
   (assigned staff or otherwise satisfies `canWriteStudent`), `create`,
   `update`, and `delete` a document at
   `districts/d1/recommendations/{id}` with `studentId: "s1"` → expect ALLOW
   for all three writes, and ALLOW on read.
2. As an active member of `d1` who is NOT a collaborator on `s1` → expect
   DENY on create/update/delete of a recommendation with `studentId: "s1"`,
   while read still succeeds (read remains active-member-only).
3. As a collaborator on `s1`, attempt to `update` an existing `s1`
   recommendation by changing its payload `studentId` to `s2`, a student the
   caller does NOT collaborate on → expect DENY (the update rule requires
   collaboration on both the existing and incoming `studentId`).
4. As a user with no active membership in `d1` (e.g. member of a different
   district, or a deactivated membership) → expect DENY on read and write.
5. As an unauthenticated request → expect DENY (covered generally by
   `hasActiveMembership` requiring `request.auth != null`).
6. Confirm no client can still reach the old `users/{uid}/recommendations`
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
