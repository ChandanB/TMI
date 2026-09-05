# Meetings — Firestore rules coverage (`participantUserIDs`)

## The bug

`firestore.rules` `match /districts/{districtID}/meetings/{meetingID}` (~line
926) gates every operation on a field the client never wrote:

```
allow read:   if hasActiveMembership(districtID) && request.auth.uid in resource.data.get('participantUserIDs', []);
allow create: if hasActiveMembership(districtID) && request.auth.uid in request.resource.data.get('participantUserIDs', []);
allow update: if hasActiveMembership(districtID) && request.auth.uid in resource.data.get('participantUserIDs', []) && request.auth.uid in request.resource.data.get('participantUserIDs', []);
allow delete: if false;
```

`Meeting` only ever carried `organizer: String` and `participants:
[MeetingParticipant]`; nothing in `MeetingService` stamped
`participantUserIDs`, so `.get('participantUserIDs', [])` always evaluated to
an empty array and `request.auth.uid in []` was always `false`. Every create,
read, and update was denied in production. The rule's design (visibility
scoped to named participants) is intentional and was NOT changed — the fix is
entirely client-side, in `TMI/Services/MeetingService.swift` and
`TMI/Services/MeetingStore.swift`.

## Participant-visibility model

`participantUserIDs` is a flat array of user ids computed as:

```
Set([meeting.organizer, actingUser.uid] + meeting.participants.map { $0.userId })
```

- `MeetingParticipant.userId` is the field carrying a participant's user id
  (see `TMI/Models/Meeting.swift`).
- The acting user (`session.membership.userID`, from the trusted
  authorization session) is always included, even when they aren't yet listed
  as a `MeetingParticipant`, so whoever creates or edits a meeting can always
  read/update what they just wrote.
- The organizer is always included, even on an edit made by a different
  collaborator, so the organizer never loses access.

## Where it's stamped (writes)

Every write path that persists a meeting document recomputes and writes
`participantUserIDs`, in `MeetingService`:

- `scheduleMeeting` — sets it alongside `organizer` before `addDocument`.
- `updateMeeting` — recomputes it from the updated meeting's `organizer` +
  `participants` + acting user before the full-document `setDocument`
  (`merge: false`), so the **new** document still satisfies the update rule's
  `request.resource.data` check.
- `updateActionItem`, `toggleActionItemCompletion`, `deleteActionItem` — these
  also do a full-document `setDocument(merge: false)` built from
  `toFirestoreData()`, which does not itself include `participantUserIDs`.
  Without re-stamping here, the field would have been silently dropped by the
  very next action-item edit after creation, re-breaking read/update access.
  Fixed the same way as `updateMeeting`.
- `updateMeetingStatus`, `completeMeeting`, `addActionItem` use a partial
  `updateDocument` (Firestore field-level merge) and do not touch
  `participantUserIDs`, so the existing value written at create time survives
  untouched — no change needed there.

Representative snippet (`scheduleMeeting`):

```swift
var data = try encode(newMeeting)
data["organizer"] = session.membership.userID
data["participantUserIDs"] = Self.participantUserIDs(
    organizerID: session.membership.userID,
    actingUserID: session.membership.userID,
    participants: meeting.participants
)
```

## Where reads are scoped (queries)

Firestore rejects an unconstrained `list` query against a collection whose
read rule depends on `resource.data` unless the query is provably limited to
documents the rule would allow. `MeetingStore` gained an `arrayContains`
query method:

```swift
func documents(
    atCollectionPath path: String,
    whereField field: String,
    arrayContains value: String
) async throws -> [(id: String, data: [String: Any])]
```

`MeetingService` methods now use it instead of an unfiltered `documents(atCollectionPath:)`:

- `fetchMeetings()` — `whereField: "participantUserIDs", arrayContains: session.membership.userID`.
- `fetchMeetings(for planId:)` — same `arrayContains` base query, then filters
  `relatedPlanId == planId` **client-side** rather than adding a second
  `whereField` clause. An `arrayContains` + equality compound query would
  require a composite Firestore index; filtering client-side avoids that
  entirely, at the cost of fetching slightly more documents than a compound
  query would (bounded by how many meetings the caller participates in).
- `fetchUpcomingMeetings()` — calls `fetchMeetings()` and filters
  `isUpcoming` client-side (unchanged; already correct).
- `fetchAllActionItems`, `fetchActionItems(assignedTo:)`,
  `fetchOverdueActionItems()` — all derive from `fetchMeetings()`, so they
  inherit the fix automatically.
- `MeetingsStateModel.fetchMeetings(forStudentId:)` (`TMI/StateModels/MeetingsStateModel.swift`)
  already calls `meetingService.fetchMeetings()` and filters by student id
  client-side — verified, not duplicated; it is fixed automatically by the
  `fetchMeetings()` change.

No composite index is required by any of the above.

## Manual verification (run once against the live project / emulator)

- As a participant (organizer or listed in `participants`): create a
  meeting → expect ALLOW; read it back via `fetchMeetings()` → expect the
  document to appear; update it (e.g. `completeMeeting`) → expect ALLOW.
- As a district member who is NOT a participant on that meeting: attempt to
  read the specific document by id → expect DENY; confirm `fetchMeetings()`
  does not return it (the `arrayContains` query naturally excludes it, so
  this should not even reach a permission error).
- Attempt `deleteMeeting` (bypassing `cancelMeeting`) as any user, including
  the organizer → expect DENY (`allow delete: if false` is unconditional and
  intentionally unchanged; `MeetingService.deleteMeeting` is documented as
  the unsupported path — use `cancelMeeting` instead).

## Test coverage

`TMITests/Services/MeetingServiceTests.swift`:
- `scheduleMeeting` writes a `participantUserIDs` array containing both the
  organizer (`session.membership.userID`) and every participant's `userId`.
- `fetchMeetings()` issues an `arrayContains` query on `participantUserIDs`
  scoped to the session user (asserts `store.arrayContainsCalls`, and that
  `store.listCalls` — the old unconstrained path — stays empty).
- `fetchMeetings(for:)` issues the same `arrayContains` base query and
  filters `relatedPlanId` client-side (asserts `store.queryCalls` — a
  compound Firestore query — stays empty).
- `FakeMeetingStore` gained a matching `arrayContains` fake implementation.
