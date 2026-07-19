# Account Deletion Review Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make permanent account deletion reachable from Profile and delete personal account data without deleting institution-owned educational records.

**Architecture:** Introduce a testable account-deletion policy and service whose Firebase adapter performs reauthentication, bounded Firestore cleanup, profile-photo cleanup, profile deletion, and Firebase Auth deletion in that order. Wire the existing two-step SwiftUI confirmation sheet directly into `UserProfileView` and revise its disclosures to match the approved retention policy.

**Tech Stack:** Swift 6, SwiftUI, Firebase Auth, Firebase Firestore, Firebase Storage, Swift Testing, Xcode

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Create | `TMI/Services/AccountDeletionService.swift` | Deletion policy, orchestration, Firebase adapter, and user-facing errors |
| Modify | `TMI/Services/AuthenticationService.swift` | Remove the unsafe legacy deletion implementation |
| Modify | `TMI/Views/Settings/DeleteAccountView.swift` | Accurate deletion/retention disclosure and hardened service call |
| Modify | `TMI/Views/User/UserProfileView.swift` | Reachable destructive entry point and sheet presentation |
| Replace | `TMITests/Services/AccountDeletionTests.swift` | Behavioral ordering, retention, failure, and UI wiring tests |

## Task 1: Define and test the deletion policy

**Files:**
- Create: `TMI/Services/AccountDeletionService.swift`
- Replace: `TMITests/Services/AccountDeletionTests.swift`

- [ ] **Step 1: Write failing policy tests**

Add tests asserting that the production policy deletes only personal collections and never contains `students`, `tmiPlans`, `formAssignments`, `formSubmissions`, `meetings`, `consents`, `auditLogs`, or `complianceAudits`.

```swift
@Test("Production policy preserves institutional collections")
func policyPreservesInstitutionalCollections() {
    let protected = Set([
        "students", "tmiPlans", "formAssignments", "formSubmissions",
        "meetings", "consents", "auditLogs", "complianceAudits"
    ])
    #expect(protected.isDisjoint(with: AccountDeletionPolicy.production.personalSubcollections))
}

@Test("Production policy includes known personal collections")
func policyDeletesPersonalCollections() {
    let expected = Set([
        "notifications", "recommendations", "savedCareers", "careerBookmarks",
        "careerExplorations", "careerState", "settings", "interests", "hobbies", "resources"
    ])
    #expect(expected.isSubset(of: AccountDeletionPolicy.production.personalSubcollections))
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
xcodebuild test -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TMIAccountDeletionDerivedData \
  -only-testing:TMITests/AccountDeletionPolicyTests
```

Expected: compilation fails because `AccountDeletionPolicy` does not exist.

- [ ] **Step 3: Implement the minimal policy**

Create a `Sendable` value type with `Set<String>` properties and a `production` constant. Keep protected names in a separate set so tests and runtime preconditions can prove they never overlap.

```swift
struct AccountDeletionPolicy: Sendable {
    let personalSubcollections: Set<String>
    let retainedSubcollections: Set<String>

    static let production = AccountDeletionPolicy(
        personalSubcollections: [
            "notifications", "recommendations", "savedCareers", "careerBookmarks",
            "careerExplorations", "careerState", "settings", "interests", "hobbies", "resources"
        ],
        retainedSubcollections: [
            "students", "tmiPlans", "formTemplates", "formAssignments", "formSubmissions",
            "meetings", "interestSurveys", "consents", "auditLogs", "complianceAudits"
        ]
    )
}
```

- [ ] **Step 4: Run the focused tests and verify GREEN**

Use the Step 2 command. Expected: the policy suite passes.

## Task 2: Implement testable deletion orchestration

**Files:**
- Modify: `TMI/Services/AccountDeletionService.swift`
- Modify: `TMITests/Services/AccountDeletionTests.swift`

- [ ] **Step 1: Write failing orchestration tests**

Create a `@MainActor` fake backend that records calls. Test all four behaviors independently:

```swift
@Test("Deletion reauthenticates first and deletes Auth last")
@MainActor
func deletionOrder() async throws {
    let backend = FakeAccountDeletionBackend()
    let service = AccountDeletionService(backend: backend, policy: .production)
    try await service.deleteAccount(password: "correct horse")
    #expect(backend.calls.first == .reauthenticate)
    #expect(backend.calls.last == .deleteAuthenticatedUser)
}

@Test("Cleanup failure keeps Auth account active")
@MainActor
func cleanupFailureKeepsAuthAccount() async {
    let backend = FakeAccountDeletionBackend(failingCall: .deleteUserDocument)
    let service = AccountDeletionService(backend: backend, policy: .production)
    await #expect(throws: AccountDeletionError.self) {
        try await service.deleteAccount(password: "correct horse")
    }
    #expect(!backend.calls.contains(.deleteAuthenticatedUser))
}
```

Also assert that every `.deleteSubcollection(name)` call belongs to `personalSubcollections`, and that missing storage objects do not prevent completion.

- [ ] **Step 2: Run the orchestration suite and verify RED**

Run the same test command with `-only-testing:TMITests/AccountDeletionServiceTests`.

Expected: compilation fails because the service and backend protocol do not exist.

- [ ] **Step 3: Implement the orchestration API**

Define `AccountDeletionIdentity`, `AccountDeletionError`, and a narrow `@MainActor AccountDeletionBackend` protocol. Implement `AccountDeletionService.deleteAccount(password:)` with this exact order:

```swift
let identity = try backend.currentIdentity()
try await backend.reauthenticate(email: identity.email, password: password)
for name in policy.personalSubcollections.sorted() {
    try await backend.deleteUserSubcollection(name, userID: identity.userID)
}
try await backend.deleteProfilePhoto(userID: identity.userID)
try await backend.deleteProfilePhotoDirectory(userID: identity.userID)
try await backend.deleteUserDocument(userID: identity.userID)
try await backend.deleteAuthenticatedUser()
```

Validate that the personal and retained sets are disjoint during initialization. Do not catch cleanup failures in the orchestrator; propagating them is what prevents premature Auth deletion.

- [ ] **Step 4: Implement the Firebase adapter**

Use email/password reauthentication. Delete Firestore documents in repeated batches of at most 200 until the query is empty. Delete `users/{uid}/profile.jpg`, then list and delete all items under `profile_images/{uid}`. Treat Firebase Storage `objectNotFound` as success. Delete `users/{uid}`, then call `Auth.auth().currentUser?.delete()`.

- [ ] **Step 5: Remove the unsafe legacy method**

Remove `AuthenticationService.AuthError.deletionFailed` and `AuthenticationService.deleteAccount(password:)`. No production caller should retain the old list containing `students` and `tmiPlans`.

- [ ] **Step 6: Run the service tests and verify GREEN**

Expected: all policy and orchestration tests pass.

## Task 3: Make deletion reachable from Profile

**Files:**
- Modify: `TMI/Views/User/UserProfileView.swift`
- Modify: `TMITests/Services/AccountDeletionTests.swift`

- [ ] **Step 1: Write failing Profile wiring tests**

Add source-wiring tests that require `UserProfileView` to own deletion sheet state, show a visible Delete Account control, and present `DeleteAccountView`.

```swift
#expect(source.contains("showingDeleteAccount"))
#expect(source.contains("Delete Account"))
#expect(source.contains("DeleteAccountView()"))
```

- [ ] **Step 2: Run the Profile tests and verify RED**

Expected: all three expectations fail against the current unreachable flow.

- [ ] **Step 3: Add the Profile entry point**

Add `@State private var showingDeleteAccount = false` to `UserProfileView`, present the sheet beside the existing legal sheets, and pass a binding into `userProfileForm`. Under Account Settings, add an accessible destructive button with label `Delete Account`, symbol `person.crop.circle.badge.minus`, and supporting text `Permanently delete your account and personal data`.

- [ ] **Step 4: Run the Profile tests and verify GREEN**

Expected: the Profile wiring suite passes.

## Task 4: Correct the confirmation disclosure and service call

**Files:**
- Modify: `TMI/Views/Settings/DeleteAccountView.swift`
- Modify: `TMITests/Services/AccountDeletionTests.swift`

- [ ] **Step 1: Write failing disclosure tests**

Require the warning source to include `Personal profile and preferences`, `Institutional records retained`, and `Student records and TMI plans`, and require the action to call `AccountDeletionService.shared.deleteAccount(password:)`.

- [ ] **Step 2: Run the view tests and verify RED**

Expected: disclosure and service-call expectations fail.

- [ ] **Step 3: Update the confirmation UI**

Replace claims that all student records and plans will be deleted. Show separate Deleted and Retained cards, keep the irreversible-action warning, use `foregroundStyle`, preserve the two-step flow, and call the new service. Map `AccountDeletionError.incorrectPassword` to `Incorrect password. Please try again.` and other failures to a retryable generic message.

- [ ] **Step 4: Run the view tests and verify GREEN**

Expected: all account-deletion view suites pass.

## Task 5: Verify the complete remediation

**Files:**
- All files listed above

- [ ] **Step 1: Run formatting and diff checks**

```bash
git diff --check
```

Expected: no output.

- [ ] **Step 2: Run focused account-deletion tests**

Use a fresh derived-data directory so stale package artifacts cannot influence the result.

```bash
xcodebuild test -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TMIAccountDeletionDerivedData \
  -only-testing:TMITests/AccountDeletionPolicyTests \
  -only-testing:TMITests/AccountDeletionServiceTests \
  -only-testing:TMITests/AccountDeletionUIWiringTests
```

Expected: all focused tests pass.

- [ ] **Step 3: Build the app**

```bash
xcodebuild build -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TMIAccountDeletionDerivedData
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run the full test suite**

```bash
xcodebuild test -project TMI.xcodeproj -scheme TMI \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TMIAccountDeletionDerivedData
```

Expected: `** TEST SUCCEEDED **` with no new failures.

- [ ] **Step 5: Review the final diff against the spec**

Confirm the reviewer path is reachable, the disclosure is accurate, protected collection names never appear in the deletion set, Auth deletion is last, and no unrelated files changed.
