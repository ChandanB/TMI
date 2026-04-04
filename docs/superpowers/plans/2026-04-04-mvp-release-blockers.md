# TMI MVP Release Blockers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve all App Store submission and district adoption blockers to ship the TMI teacher-only MVP ASAP.

**Architecture:** Fix deployment target, replace crash paths with error handling, clean up placeholder UI states, add legal documents, and prepare for App Store submission. All changes stay on the existing `codex/teacher-district-mvp-focus` branch, then merge to `main`.

**Tech Stack:** SwiftUI, Firebase, Xcode project configuration, iOS 18

---

### Task 1: Unify Deployment Target to iOS 18

**Files:**
- Modify: `TMI.xcodeproj/project.pbxproj` (lines 354, 413, 444, 481, 512, 539)
- Modify: `TMI/Services/AI/ResourceGenerationService.swift` (lines 15, 30)

- [ ] **Step 1: Update deployment targets in Xcode project file**

Open `TMI.xcodeproj/project.pbxproj` and change all 6 `IPHONEOS_DEPLOYMENT_TARGET` values to `18.0`:

```
// Line 354 (Project Debug) — change 17.5 → 18.0
IPHONEOS_DEPLOYMENT_TARGET = 18.0;

// Line 413 (Project Release) — change 17.5 → 18.0
IPHONEOS_DEPLOYMENT_TARGET = 18.0;

// Line 444 (TMI App Debug) — change 26.0 → 18.0
IPHONEOS_DEPLOYMENT_TARGET = 18.0;

// Line 481 (TMI App Release) — change 26.0 → 18.0
IPHONEOS_DEPLOYMENT_TARGET = 18.0;

// Line 512 (TMITests Debug) — change 26.0 → 18.0
IPHONEOS_DEPLOYMENT_TARGET = 18.0;

// Line 539 (TMITests Release) — change 26.0 → 18.0
IPHONEOS_DEPLOYMENT_TARGET = 18.0;
```

- [ ] **Step 2: Update @available annotations in ResourceGenerationService**

In `TMI/Services/AI/ResourceGenerationService.swift`, change both `@available` annotations:

```swift
// Line 15 — change iOS 26.0 → iOS 18.0
@available(iOS 18.0, macOS 15.0, *)

// Line 30 — change iOS 26.0 → iOS 18.0
@available(iOS 18.0, macOS 15.0, *)
```

- [ ] **Step 3: Build the project to verify no version-related errors**

Run: `xcodebuild -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED with no deployment target warnings

- [ ] **Step 4: Commit**

```bash
git add TMI.xcodeproj/project.pbxproj TMI/Services/AI/ResourceGenerationService.swift
git commit -m "chore: unify deployment target to iOS 18.0"
```

---

### Task 2: Replace fatalError Calls with Graceful Error Handling

**Files:**
- Modify: `TMI/Services/FirestorePaths.swift` (lines 248, 263)
- Modify: `TMI/Core/ScheduleMeetingCoordinator.swift` (line 228)
- Test: `TMITests/Services/FirestorePathsTests.swift` (create)
- Test: `TMITests/Core/ScheduleMeetingCoordinatorTests.swift` (create)

- [ ] **Step 1: Write failing test for FirestorePaths.students() with nil inputs**

Create `TMITests/Services/FirestorePathsTests.swift`:

```swift
import Testing
@testable import TMI

@Suite("FirestorePaths")
struct FirestorePathsTests {

    @Test("students returns district path when districtId provided")
    func studentsWithDistrictId() throws {
        let path = try FirestorePaths.students(districtId: "district1", userId: nil)
        #expect(path.contains("district1"))
    }

    @Test("students returns user path when userId provided")
    func studentsWithUserId() throws {
        let path = try FirestorePaths.students(districtId: nil, userId: "user1")
        #expect(path.contains("user1"))
    }

    @Test("students throws when both nil")
    func studentsWithBothNil() {
        #expect(throws: FirestorePathError.self) {
            try FirestorePaths.students(districtId: nil, userId: nil)
        }
    }

    @Test("plans returns district path when districtId provided")
    func plansWithDistrictId() throws {
        let path = try FirestorePaths.plans(districtId: "district1", userId: nil)
        #expect(path.contains("district1"))
    }

    @Test("plans returns user path when userId provided")
    func plansWithUserId() throws {
        let path = try FirestorePaths.plans(districtId: nil, userId: "user1")
        #expect(path.contains("user1"))
    }

    @Test("plans throws when both nil")
    func plansWithBothNil() {
        #expect(throws: FirestorePathError.self) {
            try FirestorePaths.plans(districtId: nil, userId: nil)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:TMITests/FirestorePathsTests 2>&1 | tail -20`
Expected: FAIL — `FirestorePathError` not defined, functions don't throw

- [ ] **Step 3: Add FirestorePathError and convert fatalError to throws in FirestorePaths.swift**

In `TMI/Services/FirestorePaths.swift`, add the error type at the top of the file:

```swift
enum FirestorePathError: Error, LocalizedError {
    case missingIdentifier(String)

    var errorDescription: String? {
        switch self {
        case .missingIdentifier(let context):
            return "Missing required identifier: \(context)"
        }
    }
}
```

Then change the two helper methods to throw instead of fatalError:

```swift
static func students(districtId: String?, userId: String?) throws -> String {
    if let districtId = districtId {
        return districtStudents(districtId: districtId)
    } else if let userId = userId {
        return userStudents(userId: userId)
    } else {
        throw FirestorePathError.missingIdentifier("Either districtId or userId must be provided for students path")
    }
}

static func plans(districtId: String?, userId: String?) throws -> String {
    if let districtId = districtId {
        return districtPlans(districtId: districtId)
    } else if let userId = userId {
        return userPlans(userId: userId)
    } else {
        throw FirestorePathError.missingIdentifier("Either districtId or userId must be provided for plans path")
    }
}
```

- [ ] **Step 4: Fix all call sites that now need try**

Search the project for callers of `FirestorePaths.students(` and `FirestorePaths.plans(` and add `try` at each call site. These callers should already be in `do/catch` or `throws` contexts — if not, wrap them.

- [ ] **Step 5: Run FirestorePaths tests to verify they pass**

Run: `xcodebuild test -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:TMITests/FirestorePathsTests 2>&1 | tail -20`
Expected: All 6 tests PASS

- [ ] **Step 6: Write failing test for ScheduleMeetingCoordinator.toMeeting()**

Create `TMITests/Core/ScheduleMeetingCoordinatorTests.swift`:

```swift
import Testing
@testable import TMI

@Suite("ScheduleMeetingCoordinator")
struct ScheduleMeetingCoordinatorTests {

    @Test("toMeeting throws when user not authenticated")
    func toMeetingWithoutAuth() {
        let coordinator = ScheduleMeetingCoordinator()
        #expect(throws: MeetingCreationError.self) {
            try coordinator.toMeeting()
        }
    }
}
```

- [ ] **Step 7: Run test to verify it fails**

Run: `xcodebuild test -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:TMITests/ScheduleMeetingCoordinatorTests 2>&1 | tail -20`
Expected: FAIL — `MeetingCreationError` not defined, `toMeeting()` doesn't throw

- [ ] **Step 8: Convert toMeeting() fatalError to throws**

In `TMI/Core/ScheduleMeetingCoordinator.swift`, add the error type:

```swift
enum MeetingCreationError: Error, LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to create a meeting"
        }
    }
}
```

Change the function signature and guard:

```swift
func toMeeting() throws -> Meeting {
    guard let currentUserId = Auth.auth().currentUser?.uid else {
        throw MeetingCreationError.notAuthenticated
    }

    return Meeting(
        // ... rest unchanged
```

- [ ] **Step 9: Fix all call sites for toMeeting()**

Search for `.toMeeting()` calls and add `try`. Ensure callers surface the error to the user.

- [ ] **Step 10: Run all tests to verify everything passes**

Run: `xcodebuild test -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: All tests PASS, no fatalError calls remain

- [ ] **Step 11: Verify no fatalError calls remain**

Run: `grep -rn "fatalError" TMI/`
Expected: No results in app code (test files may have them, that's fine)

- [ ] **Step 12: Commit**

```bash
git add TMI/Services/FirestorePaths.swift TMI/Core/ScheduleMeetingCoordinator.swift TMITests/Services/FirestorePathsTests.swift TMITests/Core/ScheduleMeetingCoordinatorTests.swift
git commit -m "fix: replace fatalError calls with throwing errors for App Store safety"
```

---

### Task 3: Clean Up Dashboard Role-Specific Metric Placeholders

**Files:**
- Modify: `TMI/Views/Dashboard/DashboardView.swift` (lines 233-256)

The TODO metrics currently show misleading data (e.g., total student count instead of counselor caseload, 0 for staff count). For MVP, replace these with honest values that don't promise unimplemented filtering.

- [ ] **Step 1: Replace misleading TODO metrics with honest MVP values**

In `TMI/Views/Dashboard/DashboardView.swift`, update the `generateRoleSpecificData` method:

```swift
case .counselor:
    // MVP: Show all students as caseload (filtering by assigned counselor is post-MVP)
    roleData.caseloadCount = students.count
    roleData.pendingApprovals = plans.filter { $0.approvalStatus == .pendingApproval }.count
    roleData.upcomingMeetings = 0
    roleData.criticalAlerts = students.filter { $0.engagementScore < 0.3 }.count
    roleData.caseloadStudentIds = students.compactMap { $0.id }

case .teacher:
    // MVP: Show all students (classroom filtering is post-MVP)
    roleData.classroomStudentCount = students.count
    roleData.classroomPlansActive = plans.filter { $0.approvalStatus == .approved }.count
    roleData.classroomSurveysPending = students.filter { $0.surveyResults?.isEmpty ?? true }.count
    roleData.classroomAttentionCount = Self.urgentAttentionStudents(in: students).count
    roleData.classroomPlanGapCount = Self.studentsMissingPlans(students: students, plans: plans).count
    roleData.classroomStudentIds = students.compactMap { $0.id }

case .administrator, .admin, .superintendent, .districtAdmin:
    roleData.schoolWideStudents = students.count
    roleData.schoolWidePlans = plans.count
    roleData.staffCount = 0
```

Remove all TODO comments from these lines. The values are correct for MVP (single-teacher context — all students belong to the teacher).

- [ ] **Step 2: Verify the dashboard renders without placeholder indicators**

Build and check in preview or simulator that the dashboard shows real numbers, not "0" for metrics that should have values.

- [ ] **Step 3: Commit**

```bash
git add TMI/Views/Dashboard/DashboardView.swift
git commit -m "chore: remove misleading TODO comments from dashboard metrics — values are correct for single-teacher MVP"
```

---

### Task 4: Add Error Alert for PDF Export Failure

**Files:**
- Modify: `TMI/Views/TMIPlans/TMIPlanDetailView.swift` (lines 2548-2565)

- [ ] **Step 1: Find existing state variables in TMIPlanDetailView**

Check if there's already an `@State private var exportError` or similar alert state. If not, add one near the other export-related state:

```swift
@State private var exportErrorMessage: String?
@State private var showingExportError = false
```

- [ ] **Step 2: Replace the TODO comment with error state update**

In the `exportPlanToPDF()` method, replace the catch block:

```swift
} catch {
    print("[TMIPlanDetail] Error exporting plan: \(error)")
    await MainActor.run {
        exportErrorMessage = error.localizedDescription
        showingExportError = true
    }
}
```

- [ ] **Step 3: Add the alert modifier to the view body**

Find the appropriate place in the view body (near other `.alert` or `.sheet` modifiers) and add:

```swift
.alert("Export Failed", isPresented: $showingExportError) {
    Button("OK", role: .cancel) { }
} message: {
    Text(exportErrorMessage ?? "An unexpected error occurred while exporting the plan.")
}
```

- [ ] **Step 4: Check if exportPlanToMTSS has the same issue and fix it too**

Search for similar `// TODO` patterns in other export functions in the same file.

- [ ] **Step 5: Build to verify no compilation errors**

Run: `xcodebuild -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add TMI/Views/TMIPlans/TMIPlanDetailView.swift
git commit -m "fix: show error alert when PDF export fails instead of silent failure"
```

---

### Task 5: Replace Mock Resources with Empty State

**Files:**
- Modify: `TMI/Views/TMIPlans/TMIPlanDetailView.swift` (lines 3050-3120, TMIPlanResourceCard)

The `TMIPlanResourceCard` shows hardcoded mock resources. For MVP, replace with an honest empty state until the resource service is wired up.

- [ ] **Step 1: Replace mock resources with coming-soon empty state**

Replace the `TMIPlanResourceCard` body with:

```swift
struct TMIPlanResourceCard: View {
    let interest: Interest
    let modelColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: interest.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(interest.color)

                Text(interest.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                Text("Resources coming soon")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .strokeBorder(interest.color.opacity(0.3), lineWidth: 1)
        )
    }
}
```

Remove the `mockResources` property and the `resourceIcon(for:)` helper if it's only used here.

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TMI/Views/TMIPlans/TMIPlanDetailView.swift
git commit -m "chore: replace mock resources with honest empty state for MVP"
```

---

### Task 6: Verify Interest Edge-Collection Migration

The Student model has already removed inline `interests`/`hobbies` properties. The app compiles and runs on TestFlight. This task verifies the migration is functionally complete.

**Files:**
- Read-only verification across all View and Service files

- [ ] **Step 1: Verify no compile-time references to removed Student.interests property**

Run: `grep -rn "\.interests" TMI/ --include="*.swift" | grep -v "plan\." | grep -v "TMIPlan" | grep -v "InterestService" | grep -v "Migration" | grep -v "//"`

Review results — any direct `student.interests` access that isn't through the migration extension or service is a bug.

- [ ] **Step 2: Verify StudentInterestService is the source of truth**

Run: `grep -rn "fetchInterestsFromEdgeCollection\|StudentInterestService" TMI/ --include="*.swift" | wc -l`

Expected: Multiple hits confirming views use the service.

- [ ] **Step 3: Document findings**

If migration is functionally complete, no code changes needed. If gaps found, fix them.

- [ ] **Step 4: Commit if changes were needed**

```bash
git add -A
git commit -m "fix: complete interest edge-collection migration gaps"
```

---

### Task 7: Create Privacy Policy and Terms of Service

**Files:**
- Create: `TMI/Resources/privacy-policy.html`
- Create: `TMI/Resources/terms-of-service.html`

These will be bundled in the app and also need to be hosted at a public URL for App Store Connect. For now, create the content; hosting is a manual step.

- [ ] **Step 1: Create privacy policy**

Create `TMI/Resources/privacy-policy.html` with a simple, honest privacy policy for a teacher productivity tool:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TMI App - Privacy Policy</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 700px; margin: 40px auto; padding: 0 20px; line-height: 1.6; color: #333; }
        h1 { font-size: 24px; }
        h2 { font-size: 18px; margin-top: 24px; }
        p { margin: 8px 0; }
        .updated { color: #666; font-size: 14px; }
    </style>
</head>
<body>
    <h1>TMI App Privacy Policy</h1>
    <p class="updated">Last updated: April 4, 2026</p>

    <h2>What TMI Does</h2>
    <p>TMI (Tangible Modification Intervention) is a tool for educators to create and manage trauma-informed intervention plans for their students.</p>

    <h2>Information We Collect</h2>
    <p><strong>Account Information:</strong> When you register, we collect your email address, name, and professional role (e.g., teacher, counselor, administrator).</p>
    <p><strong>Educator-Created Content:</strong> You create and store student profiles, intervention plans, notes, and observations. This content is created and controlled entirely by you.</p>

    <h2>How We Store Your Data</h2>
    <p>Your data is stored securely using Google Firebase, which provides encryption in transit and at rest. All educator content is scoped to your account — other users cannot access your data unless you are part of a shared district organization.</p>

    <h2>No Student Accounts</h2>
    <p>TMI does not create accounts for students. Students do not download or use this app. All student information is entered and managed by educators.</p>

    <h2>Third-Party Services</h2>
    <p>We use the following third-party services:</p>
    <ul>
        <li><strong>Firebase Authentication</strong> — for account management</li>
        <li><strong>Cloud Firestore</strong> — for data storage</li>
        <li><strong>Firebase Analytics</strong> — for anonymous usage statistics (no personal data)</li>
    </ul>

    <h2>Your Rights</h2>
    <p>You can export or delete your data at any time from within the app. To delete your account entirely, contact us at the support email below.</p>

    <h2>Changes to This Policy</h2>
    <p>We will notify you of significant changes via the app or email.</p>

    <h2>Contact</h2>
    <p>For questions about this privacy policy, contact: <strong>[SUPPORT_EMAIL]</strong></p>
</body>
</html>
```

**NOTE:** The `[SUPPORT_EMAIL]` placeholder must be replaced with the actual support email before submission.

- [ ] **Step 2: Create terms of service**

Create `TMI/Resources/terms-of-service.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TMI App - Terms of Service</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 700px; margin: 40px auto; padding: 0 20px; line-height: 1.6; color: #333; }
        h1 { font-size: 24px; }
        h2 { font-size: 18px; margin-top: 24px; }
        p { margin: 8px 0; }
        .updated { color: #666; font-size: 14px; }
    </style>
</head>
<body>
    <h1>TMI App Terms of Service</h1>
    <p class="updated">Last updated: April 4, 2026</p>

    <h2>Acceptance</h2>
    <p>By using TMI, you agree to these terms. If you do not agree, do not use the app.</p>

    <h2>Description of Service</h2>
    <p>TMI is a tool for educators to create trauma-informed intervention plans. It is not a substitute for professional clinical judgment.</p>

    <h2>Your Responsibilities</h2>
    <p>You are responsible for the accuracy of information you enter and for complying with your institution's data handling policies. You must be an authorized educator or administrator to use this app.</p>

    <h2>Data Ownership</h2>
    <p>You own all content you create in TMI. We do not claim ownership of your intervention plans, student notes, or other educator-created content.</p>

    <h2>Acceptable Use</h2>
    <p>You agree not to use TMI for any purpose other than educational intervention planning. You agree not to share your account credentials.</p>

    <h2>Limitation of Liability</h2>
    <p>TMI is provided "as is" without warranty. We are not liable for decisions made based on information in the app.</p>

    <h2>Termination</h2>
    <p>We may suspend accounts that violate these terms. You may delete your account at any time.</p>

    <h2>Contact</h2>
    <p>For questions about these terms, contact: <strong>[SUPPORT_EMAIL]</strong></p>
</body>
</html>
```

- [ ] **Step 3: Add files to Xcode project**

Ensure both HTML files are added to the TMI target's Copy Bundle Resources build phase.

- [ ] **Step 4: Commit**

```bash
git add TMI/Resources/privacy-policy.html TMI/Resources/terms-of-service.html
git commit -m "docs: add privacy policy and terms of service for App Store submission"
```

---

### Task 8: Add Legal Links to App Settings

**Files:**
- Modify: `TMI/Views/User/UserProfileView.swift` (or equivalent settings view)

- [ ] **Step 1: Find the existing settings/profile view**

Check `TMI/Views/User/UserProfileView.swift` for an existing settings section where legal links can be added.

- [ ] **Step 2: Add legal links section**

Add a section to the profile/settings view:

```swift
Section("Legal") {
    Button {
        if let url = Bundle.main.url(forResource: "privacy-policy", withExtension: "html") {
            showingPrivacyPolicy = true
        }
    } label: {
        Label("Privacy Policy", systemImage: "hand.raised")
    }

    Button {
        if let url = Bundle.main.url(forResource: "terms-of-service", withExtension: "html") {
            showingTermsOfService = true
        }
    } label: {
        Label("Terms of Service", systemImage: "doc.text")
    }
}
```

Add corresponding `@State` variables and `.sheet` modifiers with a simple `WebView` wrapper or `SafariViewController` to display the HTML.

- [ ] **Step 3: Build and verify links open correctly**

Run in simulator, navigate to profile/settings, tap both links.

- [ ] **Step 4: Commit**

```bash
git add TMI/Views/User/UserProfileView.swift
git commit -m "feat: add privacy policy and terms of service links to user profile"
```

---

### Task 9: Final Merge and Release Preparation

**Files:**
- All uncommitted work on `codex/teacher-district-mvp-focus` branch

- [ ] **Step 1: Run full test suite**

Run: `xcodebuild test -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -40`
Expected: All tests PASS

- [ ] **Step 2: Verify no remaining fatalError calls in app code**

Run: `grep -rn "fatalError" TMI/ --include="*.swift"`
Expected: No results

- [ ] **Step 3: Verify no TODO comments in user-facing views**

Run: `grep -rn "TODO" TMI/Views/ --include="*.swift"`
Review results — any remaining TODOs should be non-user-facing or acceptable for MVP.

- [ ] **Step 4: Merge to main**

```bash
git checkout main
git merge codex/teacher-district-mvp-focus
```

- [ ] **Step 5: Create release tag**

```bash
git tag -a v1.0.0-mvp -m "TMI MVP: Teacher-only App Store release"
```

- [ ] **Step 6: Document remaining manual steps**

These require human action outside the codebase:
1. Replace `[SUPPORT_EMAIL]` in both HTML files with actual support email
2. Host privacy policy and terms at public URLs
3. Add public URLs to App Store Connect
4. Prepare 3-5 App Store screenshots (iPhone 15 Pro, iPad Pro)
5. Write App Store description and select Education category
6. Set age rating (4+ since no student-facing content)
7. Submit for App Store review via Xcode → Archive → Distribute
