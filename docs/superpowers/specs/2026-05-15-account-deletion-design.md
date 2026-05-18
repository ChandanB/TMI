# Account Deletion — Design Spec

**Date:** 2026-05-15  
**Context:** Apple App Store Review rejection (Guideline 5.1.1(v)) — app supports account creation but lacks account deletion.

---

## Background

The app received an App Store Review rejection requiring a complete, in-app account deletion flow. The rejection explicitly prohibits deactivation-only solutions and requires deletion to be completable without leaving the app.

---

## Data Deletion Scope

When a user confirms account deletion, the following is purged in order:

1. Firestore subcollections under `users/{uid}/`: `students`, `tmiPlans`, `interests`, `resources`
2. Firestore user document at `users/{uid}`
3. Firebase Auth account via `Auth.auth().currentUser?.delete()`
4. Local app state — `AuthStateModel` clears `currentUser` and transitions to `.unauthenticated`

Post-deletion navigation back to the login screen is handled automatically by the existing auth state listener in `AuthStateModel`. No additional routing code is required.

---

## UI & Flow

### Entry Point

A new "Delete Account" `SettingsRow` is added to `dangerousActionsSection` in `SettingsView`, styled with a red title color. Tapping it presents `DeleteAccountView` as a `.tmiSheetStyle()` sheet.

### `DeleteAccountView` — 2-step state machine

State is driven by a private enum:

```swift
enum DeletionStep {
    case warning
    case confirm
}
```

**`.warning` (initial)**
- Red `exclamationmark.triangle.fill` icon + "Delete Account" title
- Consequence card: permanently deletes your account, all students, all TMI plans, interests, and resources
- "Continue" → advances to `.confirm`
- "Cancel" → dismisses sheet

**`.confirm`**
- Brief recap: "This action cannot be undone."
- `SecureField` for password entry
- Inline error message if re-auth or deletion fails
- "Permanently Delete Account" red button — disabled while password field is empty; shows `ProgressView` while async operation is running
- "Go Back" → returns to `.warning`

---

## Architecture

### New method: `AuthenticationService.deleteAccount(password:)`

```swift
func deleteAccount(password: String) async throws
```

Sequence:
1. Call `FirebaseManager.shared.reauthenticate(with: password)` (already implemented)
2. For each subcollection in `["students", "tmiPlans", "interests", "resources"]`: fetch all documents, delete each
3. Delete `users/{uid}` Firestore document
4. Call `Auth.auth().currentUser?.delete()`

### New file: `TMI/Views/Settings/DeleteAccountView.swift`

- Self-contained SwiftUI view, presented as a sheet
- Reads `authStateModel` via `@Environment(\.authStateModel)`
- Calls `AuthenticationService.shared.deleteAccount(password:)` in an async context
- On success, calls `authStateModel.signOut()` to clear local state and trigger navigation

### `SettingsView` changes

- Add `@State private var showingDeleteAccountSheet = false`
- Add "Delete Account" `SettingsRow` to `dangerousActionsSection` with `.red` title color
- Add `.sheet(isPresented: $showingDeleteAccountSheet) { DeleteAccountView().tmiSheetStyle() }`

### No changes required to

- `AuthStateModel` — existing `.unauthenticated` transition handles post-deletion routing
- `FirebaseManager` — `reauthenticate(with:)` already exists
- Any navigation/routing code

---

## Error Handling

| Error | User-facing message |
|-------|---------------------|
| Wrong password (re-auth fails) | "Incorrect password. Please try again." |
| Network error during deletion | "Deletion failed. Check your connection and try again." |
| Partial Firestore deletion failure | Log error, attempt to continue; surface generic error if Auth deletion also fails |

Partial Firestore failures (e.g. one subcollection fails to delete) should not block the Auth account deletion — user data orphans are acceptable over leaving an un-deletable account.

---

## Apple Review Compliance Checklist

- [x] Full deletion, not deactivation
- [x] Completable entirely in-app (no external website required)
- [x] Confirmation step present (2-step flow)
- [x] Re-authentication required before deletion (password)
- [x] No customer service contact required
