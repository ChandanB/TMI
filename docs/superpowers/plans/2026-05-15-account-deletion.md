# Account Deletion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a complete, Apple-compliant in-app account deletion flow so the app passes App Store Review Guideline 5.1.1(v).

**Architecture:** A `deleteAccount(password:)` method on `AuthenticationService` handles all Firebase cleanup (re-auth → subcollection purge → user doc delete → Auth account delete). A new `DeleteAccountView` sheet presents a 2-step confirmation flow (warning → password confirmation). `SettingsView` gains a "Delete Account" row that presents the sheet.

**Tech Stack:** SwiftUI, Firebase Auth (`FirebaseAuth`), Firestore (`FirebaseFirestore`), Swift Testing (`@Test`/`@Suite`/`#expect`)

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `TMI/Services/AuthenticationService.swift` | Add `deleteAccount(password:)` method |
| Create | `TMI/Views/Settings/DeleteAccountView.swift` | 2-step deletion sheet UI |
| Modify | `TMI/Views/Settings/SettingsView.swift` | Add row + sheet presentation |
| Create | `TMITests/Services/AccountDeletionTests.swift` | Tests for deletion logic + view structure |

---

## Task 1: Add `deleteAccount(password:)` to `AuthenticationService`

**Files:**
- Modify: `TMI/Services/AuthenticationService.swift`
- Create: `TMITests/Services/AccountDeletionTests.swift`

- [ ] **Step 1.1: Write the failing test**

Create `TMITests/Services/AccountDeletionTests.swift`:

```swift
import Foundation
import Testing

@Suite("Account Deletion")
struct AccountDeletionTests {

    // Verifies the method signature and subcollection list exist in the source.
    // Firebase integration is not unit-testable without a live backend, so we
    // validate structural correctness via source inspection — the same pattern
    // used elsewhere in this test suite.
    @Test("deleteAccount method exists in AuthenticationService source")
    func deleteAccountMethodExists() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TMI/Services/AuthenticationService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        #expect(source.contains("func deleteAccount(password: String) async throws"))
    }

    @Test("deleteAccount re-authenticates before deleting")
    func deleteAccountReauthenticatesFirst() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TMI/Services/AuthenticationService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        // reauthenticate must appear before delete() in the source
        let reauthRange = source.range(of: "reauthenticate(with: password)")
        let deleteRange = source.range(of: "user.delete()")
        #expect(reauthRange != nil)
        #expect(deleteRange != nil)
        if let r = reauthRange, let d = deleteRange {
            #expect(r.lowerBound < d.lowerBound, "reauthenticate must come before delete()")
        }
    }

    @Test("deleteAccount purges all required subcollections")
    func deleteAccountPurgesAllSubcollections() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TMI/Services/AuthenticationService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        #expect(source.contains("\"students\""))
        #expect(source.contains("\"tmiPlans\""))
        #expect(source.contains("\"interests\""))
        #expect(source.contains("\"resources\""))
    }
}
```

- [ ] **Step 1.2: Run tests to verify they fail**

```bash
cd /Users/chandanbrown/Development/TMI/.claude/worktrees/inspiring-shtern-362ae9
xcodebuild test -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing TMITests/AccountDeletionTests 2>&1 | grep -E "FAIL|PASS|error:|Build"
```

Expected: Build succeeds, all 3 tests FAIL (method not yet defined).

- [ ] **Step 1.3: Add `deleteAccount(password:)` to `AuthenticationService`**

Open `TMI/Services/AuthenticationService.swift`. Add a new `AuthError` case and the deletion method. Add the new error case to the existing `AuthError` enum:

```swift
case deletionFailed(String)
```

Add its `errorDescription`:

```swift
case .deletionFailed(let message):
    return "Failed to delete account: \(message)"
```

Add the following method after the existing `signOut()` method:

```swift
// MARK: - Account Deletion

/// Permanently deletes the authenticated user's account and all associated data.
/// Re-authenticates first as required by Firebase before account deletion.
func deleteAccount(password: String) async throws {
    guard let user = Auth.auth().currentUser,
          let email = user.email else {
        throw AuthError.deletionFailed("No authenticated user found")
    }

    // Firebase requires re-authentication immediately before deletion
    let credential = EmailAuthProvider.credential(withEmail: email, password: password)
    try await user.reauthenticate(with: credential)

    let uid = user.uid

    // Purge all user-scoped subcollections
    let subcollections = ["students", "tmiPlans", "interests", "resources"]
    for name in subcollections {
        let ref = db.collection("users").document(uid).collection(name)
        let snapshot = try await ref.getDocuments()
        for document in snapshot.documents {
            try await document.reference.delete()
        }
    }

    // Delete the top-level user document
    try await db.collection("users").document(uid).delete()

    // Delete the Firebase Auth account (must be last)
    try await user.delete()
}
```

- [ ] **Step 1.4: Run tests to verify they pass**

```bash
xcodebuild test -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing TMITests/AccountDeletionTests 2>&1 | grep -E "FAIL|PASS|error:|Build"
```

Expected: All 3 tests PASS.

- [ ] **Step 1.5: Commit**

```bash
git add TMI/Services/AuthenticationService.swift TMITests/Services/AccountDeletionTests.swift
git commit -m "feat: add deleteAccount method to AuthenticationService"
```

---

## Task 2: Create `DeleteAccountView`

**Files:**
- Create: `TMI/Views/Settings/DeleteAccountView.swift`
- Modify: `TMITests/Services/AccountDeletionTests.swift`

- [ ] **Step 2.1: Write failing structural tests for `DeleteAccountView`**

Add the following `@Suite` to `TMITests/Services/AccountDeletionTests.swift` (append after the existing suite):

```swift
@Suite("DeleteAccountView structure")
struct DeleteAccountViewStructureTests {

    private func source() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TMI/Views/Settings/DeleteAccountView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("View defines a two-step DeletionStep enum")
    func definesDeletionStepEnum() throws {
        let src = try source()
        #expect(src.contains("enum DeletionStep"))
        #expect(src.contains("case warning"))
        #expect(src.contains("case confirm"))
    }

    @Test("View uses SecureField for password entry")
    func usesSecureField() throws {
        #expect(try source().contains("SecureField"))
    }

    @Test("View shows inline error message state")
    func showsErrorMessage() throws {
        #expect(try source().contains("errorMessage"))
    }

    @Test("Delete button is disabled when password is empty")
    func deleteButtonDisabledWhenPasswordEmpty() throws {
        #expect(try source().contains(".disabled(password.isEmpty"))
    }

    @Test("View calls deleteAccount on AuthenticationService")
    func callsDeleteAccount() throws {
        #expect(try source().contains("deleteAccount(password: password)"))
    }

    @Test("View calls authStateModel.signOut() on success")
    func callsSignOutOnSuccess() throws {
        #expect(try source().contains("authStateModel.signOut()"))
    }
}
```

- [ ] **Step 2.2: Run tests to verify they fail**

```bash
xcodebuild test -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing TMITests/AccountDeletionTests 2>&1 | grep -E "FAIL|PASS|error:|Build"
```

Expected: The 6 new `DeleteAccountViewStructureTests` tests FAIL (file doesn't exist yet). The 3 `AccountDeletionTests` tests still PASS.

- [ ] **Step 2.3: Create `TMI/Views/Settings/DeleteAccountView.swift`**

Create the file with this content:

```swift
//
//  DeleteAccountView.swift
//  TMI
//

import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.authStateModel) private var authStateModel
    @Environment(\.dismiss) private var dismiss

    enum DeletionStep {
        case warning
        case confirm
    }

    @State private var step: DeletionStep = .warning
    @State private var password: String = ""
    @State private var isDeleting: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .base)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16))
                        .foregroundColor(.tmiTextSecondary)
                        .padding()
                }

                ScrollView {
                    VStack(spacing: 24) {
                        // Icon + title
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.red)

                            Text("Delete Account")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.tmiTextPrimary)
                        }
                        .padding(.top, 8)

                        if step == .warning {
                            warningContent
                        } else {
                            confirmContent
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Warning Step

    private var warningContent: some View {
        VStack(spacing: 20) {
            TMICard(style: .default) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("This will permanently delete:")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.tmiTextPrimary)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    VStack(alignment: .leading, spacing: 8) {
                        consequenceRow(icon: "person.fill", text: "Your account and profile")
                        consequenceRow(icon: "person.2.fill", text: "All student records")
                        consequenceRow(icon: "doc.text.fill", text: "All TMI plans")
                        consequenceRow(icon: "heart.fill", text: "All interests and resources")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }

            Text("This action cannot be undone.")
                .font(.system(size: 14))
                .foregroundColor(.tmiTextSecondary)
                .multilineTextAlignment(.center)

            TMIButton(text: "Continue", style: .primary) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    step = .confirm
                }
            }

            Button("Cancel") { dismiss() }
                .font(.system(size: 16))
                .foregroundColor(.tmiTextSecondary)
        }
    }

    private func consequenceRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.red.opacity(0.8))
                .frame(width: 20)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.tmiTextPrimary)
        }
    }

    // MARK: - Confirm Step

    private var confirmContent: some View {
        VStack(spacing: 20) {
            Text("Enter your password to confirm deletion.")
                .font(.system(size: 15))
                .foregroundColor(.tmiTextSecondary)
                .multilineTextAlignment(.center)

            TMICard(style: .default) {
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .font(.system(size: 16))
                    .foregroundColor(.tmiTextPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            TMIButton(
                text: isDeleting ? "" : "Permanently Delete Account",
                style: .primary
            ) {
                Task { await deleteAccount() }
            }
            .disabled(password.isEmpty || isDeleting)
            .overlay {
                if isDeleting {
                    ProgressView()
                        .tint(.white)
                }
            }
            .tint(.red)

            Button("Go Back") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    errorMessage = nil
                    step = .warning
                }
            }
            .font(.system(size: 16))
            .foregroundColor(.tmiTextSecondary)
        }
    }

    // MARK: - Deletion Logic

    @MainActor
    private func deleteAccount() async {
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        do {
            try await AuthenticationService.shared.deleteAccount(password: password)
            authStateModel.signOut()
        } catch let error as AuthenticationService.AuthError {
            withAnimation { errorMessage = error.errorDescription ?? "Deletion failed. Please try again." }
        } catch {
            withAnimation { errorMessage = "Deletion failed. Check your connection and try again." }
        }
    }
}

#Preview {
    DeleteAccountView()
}
```

- [ ] **Step 2.4: Run tests to verify they pass**

```bash
xcodebuild test -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing TMITests/AccountDeletionTests 2>&1 | grep -E "FAIL|PASS|error:|Build"
```

Expected: All 9 tests (3 + 6) PASS.

- [ ] **Step 2.5: Commit**

```bash
git add TMI/Views/Settings/DeleteAccountView.swift TMITests/Services/AccountDeletionTests.swift
git commit -m "feat: add DeleteAccountView with 2-step confirmation flow"
```

---

## Task 3: Wire `SettingsView`

**Files:**
- Modify: `TMI/Views/Settings/SettingsView.swift`
- Modify: `TMITests/Services/AccountDeletionTests.swift`

- [ ] **Step 3.1: Write failing structural test for `SettingsView`**

Append to `TMITests/Services/AccountDeletionTests.swift`:

```swift
@Suite("SettingsView account deletion wiring")
struct SettingsViewDeletionTests {

    private func source() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TMI/Views/Settings/SettingsView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("SettingsView declares showingDeleteAccountSheet state")
    func declaresDeleteAccountSheetState() throws {
        #expect(try source().contains("showingDeleteAccountSheet"))
    }

    @Test("SettingsView presents DeleteAccountView as a sheet")
    func presentsDeleteAccountViewSheet() throws {
        #expect(try source().contains("DeleteAccountView()"))
    }

    @Test("SettingsView has Delete Account row in dangerous actions section")
    func hasDeleteAccountRow() throws {
        #expect(try source().contains("Delete Account"))
    }
}
```

- [ ] **Step 3.2: Run tests to verify they fail**

```bash
xcodebuild test -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing TMITests/AccountDeletionTests 2>&1 | grep -E "FAIL|PASS|error:|Build"
```

Expected: 3 new `SettingsViewDeletionTests` FAIL. All 9 prior tests still PASS.

- [ ] **Step 3.3: Add `showingDeleteAccountSheet` state to `SettingsView`**

In `TMI/Views/Settings/SettingsView.swift`, add this line after the existing `@State private var showingLogoutAlert = false`:

```swift
@State private var showingDeleteAccountSheet = false
```

- [ ] **Step 3.4: Add "Delete Account" row to `dangerousActionsSection`**

In `SettingsView.swift`, replace the existing `dangerousActionsSection`:

```swift
private var dangerousActionsSection: some View {
    SettingsSection(title: "Account Actions", icon: "exclamationmark.triangle.fill") {
        SettingsRow(
            title: "Log Out",
            subtitle: "Sign out of your account",
            icon: "rectangle.portrait.and.arrow.right",
            titleColor: .orange,
            action: {
                showingLogoutAlert = true
            }
        )

        Divider()
            .background(Color.white.opacity(0.1))
            .padding(.horizontal, 16)

        SettingsRow(
            title: "Delete Account",
            subtitle: "Permanently delete your account and all data",
            icon: "person.crop.circle.badge.minus",
            titleColor: .red,
            action: {
                showingDeleteAccountSheet = true
            }
        )
    }
}
```

- [ ] **Step 3.5: Add the sheet modifier to `SettingsView.body`**

In `SettingsView.swift`, find the `.navigationBarTitleDisplayMode(.inline)` modifier and add the sheet below it:

```swift
.navigationTitle("Settings")
.navigationBarTitleDisplayMode(.inline)
.sheet(isPresented: $showingDeleteAccountSheet) {
    DeleteAccountView()
        .tmiSheetStyle()
}
.onAppear {
    withAnimation(.easeInOut(duration: 0.5).delay(0.1)) {
        isLoaded = true
    }
}
```

- [ ] **Step 3.6: Run all account deletion tests**

```bash
xcodebuild test -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing TMITests/AccountDeletionTests 2>&1 | grep -E "FAIL|PASS|error:|Build"
```

Expected: All 12 tests PASS.

- [ ] **Step 3.7: Run the full test suite**

```bash
xcodebuild test -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20
```

Expected: All tests pass with no regressions.

- [ ] **Step 3.8: Commit**

```bash
git add TMI/Views/Settings/SettingsView.swift TMITests/Services/AccountDeletionTests.swift
git commit -m "feat: wire account deletion entry point in SettingsView"
```

---

## Task 4: Verify the full flow manually

- [ ] **Step 4.1: Build and run on simulator**

```bash
xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4.2: Smoke-test the flow**

1. Launch the app in the simulator and sign in (or create an account)
2. Navigate to **Settings** tab
3. Scroll to **Account Actions** — verify "Delete Account" row appears in red below "Log Out"
4. Tap "Delete Account" — verify the warning sheet appears listing all data that will be deleted
5. Tap "Continue" — verify the password field appears and the delete button is disabled with an empty field
6. Tap "Go Back" — verify you return to the warning step
7. Enter a wrong password and tap delete — verify an inline error appears without dismissing the sheet
8. Enter the correct password — verify the button enables and tapping it triggers deletion and navigates back to the login screen

- [ ] **Step 4.3: Final commit if any minor tweaks were made during smoke test**

```bash
git add -p
git commit -m "fix: account deletion smoke test adjustments"
```

---

## Apple Review Checklist

Before submitting to App Store Review, record a screen capture on a physical device demonstrating:
- [ ] Creating a new account or signing in with the demo account
- [ ] Navigating to Settings → Account Actions → Delete Account
- [ ] The complete 2-step deletion flow through to confirmation
- [ ] Being returned to the login screen after deletion
