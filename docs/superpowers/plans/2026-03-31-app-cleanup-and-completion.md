# App Cleanup & Feature Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove AI from careers, fix survey data persistence, add sheet minimum sizes, clean up Settings, and make Edit Profile functional.

**Architecture:** Five independent changes applied sequentially. AI career services are replaced with the existing static `CareerMatchingService` database. Survey persistence is fixed by wiring the existing save pipeline correctly. Sheet sizing uses a shared ViewModifier. Settings cleanup and Edit Profile are straightforward view modifications.

**Tech Stack:** SwiftUI, Firebase Auth/Firestore/Storage, SDWebImageSwiftUI, PhotosUI

---

### Task 1: Delete AI Service Files

**Files:**
- Delete: `TMI/Services/AI/AICareerGenerator.swift`
- Delete: `TMI/Services/AI/FoundationModelsService.swift`
- Delete: `TMI/Services/AI/AIPromptBuilder.swift`
- Delete: `TMI/Services/AIInsightsService.swift`
- Delete: `TMI/Models/AIInsightsModel.swift`

- [ ] **Step 1: Delete the AI service files**

```bash
rm TMI/Services/AI/AICareerGenerator.swift
rm TMI/Services/AI/FoundationModelsService.swift
rm TMI/Services/AI/AIPromptBuilder.swift
rm TMI/Services/AIInsightsService.swift
rm TMI/Models/AIInsightsModel.swift
```

- [ ] **Step 2: Remove the AI directory if empty**

```bash
rmdir TMI/Services/AI/
```

- [ ] **Step 3: Verify the project builds**

Run: `xcodebuild build -scheme TMI -destination 'platform=macOS' 2>&1 | tail -20`

Expected: Build will FAIL with missing references — this is expected. The next tasks fix those references.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: delete AI career generation service files"
```

---

### Task 2: Rewrite CareerService Without AI Dependencies

**Files:**
- Modify: `TMI/Services/CareerService.swift`

The current `CareerService` delegates to `AIInsightsService` for search and recommendations. Rewrite it to use `CareerMatchingService` as the sole data source.

- [ ] **Step 1: Replace CareerService implementation**

Replace the entire `CareerService` class. The new version:
- Removes all `AIInsightsService` references
- Uses `CareerMatchingService.CareerDatabase.allCareerPaths` as the static career catalog
- Converts `CareerPath` to `Career` for the existing API surface
- Implements search as simple string filtering over the static catalog
- Implements recommendations as interest-cluster-to-career matching

```swift
import Foundation
import FirebaseAuth
import FirebaseFirestore
import Observation

@Observable
final class CareerService: @unchecked Sendable {
    static let shared = CareerService()
    private let firestore = FirebaseManager.shared.firestore

    private init() {}

    // MARK: - Search (static catalog filter)

    func searchCareers(query: String, student: Student? = nil) -> [Career] {
        let allCareers = CareerMatchingService.CareerDatabase.allCareerPaths.map { careerPathToCareer($0) }
        let lowercasedQuery = query.lowercased()

        let filtered = allCareers.filter { career in
            career.title.lowercased().contains(lowercasedQuery) ||
            career.field.lowercased().contains(lowercasedQuery) ||
            career.description.lowercased().contains(lowercasedQuery) ||
            career.skills.contains { $0.lowercased().contains(lowercasedQuery) } ||
            career.tags.contains { $0.lowercased().contains(lowercasedQuery) }
        }

        return filtered.isEmpty ? allCareers : filtered
    }

    // MARK: - Recommendations (deterministic matching)

    func getCareerRecommendations(for student: Student, clusters: [InterestCluster] = []) -> [Career] {
        let results = CareerMatchingService.shared.matchCareers(from: clusters)
        return results.prefix(10).map { careerPathToCareer($0.career) }
    }

    // MARK: - All Careers

    func fetchAllCareers() -> [Career] {
        CareerMatchingService.CareerDatabase.allCareerPaths.map { careerPathToCareer($0) }
    }

    // MARK: - Related Careers

    func getRelatedCareers(to career: Career, limit: Int = 5) -> [Career] {
        let allCareers = fetchAllCareers()
        return allCareers
            .filter { $0.field == career.field && $0.title != career.title }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Saved Careers (Firebase)

    func saveCareer(career: Career, for studentId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = firestore.collection("users").document(uid)
            .collection("students").document(studentId)
            .collection("savedCareers").document(career.id ?? UUID().uuidString)
        try ref.setData(from: career)
    }

    func fetchSavedCareers(for studentId: String) async throws -> [Career] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        let snapshot = try await firestore.collection("users").document(uid)
            .collection("students").document(studentId)
            .collection("savedCareers").getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Career.self) }
    }

    func removeSavedCareer(careerId: String, for studentId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await firestore.collection("users").document(uid)
            .collection("students").document(studentId)
            .collection("savedCareers").document(careerId).delete()
    }

    // MARK: - Conversion Helper

    func careerPathToCareer(_ path: CareerPath) -> Career {
        Career(
            id: path.id.uuidString,
            title: path.title,
            field: path.category,
            description: path.description,
            skills: path.requiredInterests,
            education: path.educationLevel.displayName,
            salaryRange: Double(path.estimatedSalary?.min ?? 30000)...Double(path.estimatedSalary?.max ?? 80000),
            jobOutlook: "Stable",
            growthRate: 0.05,
            aiGenerated: false,
            relatedInterests: path.requiredInterests,
            tags: [path.category],
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
```

- [ ] **Step 2: Remove the old CareerExplorationAction enum, CareerDiscoveryInsights struct, and CareerLibraryService references**

Check the bottom of `CareerService.swift` for `CareerDiscoveryInsights`, `CareerExplorationAction`, and any other types only used by the old AI flow. Remove them. Keep only the code from Step 1.

- [ ] **Step 3: Verify the file compiles**

Run: `xcodebuild build -scheme TMI -destination 'platform=macOS' 2>&1 | grep -E 'error:|Build Succeeded'`

Expected: May still have errors in `CareerExplorerStateModel` — that's fixed in Task 3.

- [ ] **Step 4: Commit**

```bash
git add TMI/Services/CareerService.swift
git commit -m "refactor: rewrite CareerService to use static career catalog"
```

---

### Task 3: Rewrite CareerExplorerStateModel Without AI

**Files:**
- Modify: `TMI/StateModels/CareerExplorerStateModel.swift`

- [ ] **Step 1: Replace the state model implementation**

The new version removes all AI service calls and uses `CareerService` for static data:

```swift
import Foundation
import Observation
import SwiftUI

struct CareerExplorerData: Equatable {
    var careers: [Career] = []
    var searchResults: [Career] = []
    var personalizedRecommendations: [Career] = []
}

@Observable
@MainActor
final class CareerExplorerStateModel {
    var data = CareerExplorerData()
    var isLoading = false
    var error: Error?

    // UI State
    var searchText = ""
    var isSearching = false
    var hasSearched = false
    var selectedStudent: Student?
    var selectedField: String?

    private let careerService = CareerService.shared

    // MARK: - Load initial data

    func fetch() {
        isLoading = true
        data.careers = careerService.fetchAllCareers()
        isLoading = false
    }

    // MARK: - Search (filter static catalog)

    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        data.searchResults = careerService.searchCareers(query: searchText, student: selectedStudent)
        hasSearched = true
        isSearching = false
    }

    func clearSearch() {
        searchText = ""
        hasSearched = false
        data.searchResults = []
    }

    // MARK: - Personalized recommendations

    func loadPersonalizedRecommendations(clusters: [InterestCluster] = []) {
        guard let student = selectedStudent else { return }
        data.personalizedRecommendations = careerService.getCareerRecommendations(for: student, clusters: clusters)
    }

    // MARK: - Computed properties

    var searchResults: [Career] { data.searchResults }
    var personalizedRecommendations: [Career] { data.personalizedRecommendations }
    var careers: [Career] { data.careers }

    var filteredCareers: [Career] {
        var result = hasSearched ? searchResults : careers
        if let field = selectedField {
            result = result.filter { $0.field == field }
        }
        return result
    }
}
```

- [ ] **Step 2: Verify the file compiles**

Run: `xcodebuild build -scheme TMI -destination 'platform=macOS' 2>&1 | grep -E 'error:|Build Succeeded'`

Expected: May still have errors in `CareerExplorerView` — fixed in Task 4.

- [ ] **Step 3: Commit**

```bash
git add TMI/StateModels/CareerExplorerStateModel.swift
git commit -m "refactor: rewrite CareerExplorerStateModel without AI dependencies"
```

---

### Task 4: Update CareerExplorerView

**Files:**
- Modify: `TMI/Views/Career Explorer/CareerExplorerView.swift`

- [ ] **Step 1: Remove AI-specific UI elements**

In `CareerExplorerView.swift`, make these changes:

1. Remove the `showingInsightsSheet` state variable and any sheet that presents AI insights.
2. Remove the `trendingCareersSection` computed property (or replace with a simple "Featured Careers" section that shows the first 6 careers from the static catalog).
3. Remove the `enhancedCareerStatsSummary` computed property if it references AI-generated data.
4. Remove any "AI-generated" badges or labels from career cards.
5. Update `performSearch()` to call the new synchronous `stateModel.performSearch()`.
6. Update `loadBasicCareerData()` to call `stateModel.fetch()`.
7. Remove the `personalizedRecommendationsSection` if it references AI insights, or update it to use the new deterministic `stateModel.loadPersonalizedRecommendations()`.

- [ ] **Step 2: Update search to be synchronous**

The old search was async (calling AI). The new search is synchronous (filtering a static list). Update any `Task { await stateModel.performSearch() }` to just `stateModel.performSearch()`. Same for `stateModel.fetch()`.

- [ ] **Step 3: Verify the project builds**

Run: `xcodebuild build -scheme TMI -destination 'platform=macOS' 2>&1 | grep -E 'error:|Build Succeeded'`

Expected: Build Succeeded (or errors in other files referencing removed AI types — fix those too).

- [ ] **Step 4: Fix any remaining compile errors across the project**

Search for any remaining references to removed types:
```bash
grep -rn "AIInsightsService\|AICareerGenerator\|FoundationModelsService\|AIPromptBuilder\|AICareerResponse\|CareerDiscoveryInsights\|FoundationModelsServiceAccessor\|FoundationModelType\|searchCareersWithAI\|getCareerDiscoveryInsights" TMI/ --include="*.swift"
```

Fix each reference. Common fixes:
- `CareerService.shared.searchCareersWithAI(query:student:)` → `CareerService.shared.searchCareers(query:student:)`
- `CareerService.shared.getCareerRecommendations(for:)` → same name but now synchronous
- Remove any `AICareerResponse` usage — methods now return `[Career]` directly
- Remove any `CareerDiscoveryInsights` usage

- [ ] **Step 5: Remove aiGenerated and generatedAt from Career model**

In `TMI/Models/Career/Career.swift`:
- Remove the `aiGenerated: Bool` property (line ~23)
- Remove the `generatedAt: Date?` property (line ~24)
- Update `CodingKeys`, `init(from decoder:)`, `encode(to:)`, and the memberwise init to remove these fields
- Update `sampleCareers` to remove `aiGenerated` and `generatedAt` parameters
- Update `CareerService.careerPathToCareer()` to remove the `aiGenerated: false` parameter from the `Career` initializer call

- [ ] **Step 6: Verify clean build**

Run: `xcodebuild build -scheme TMI -destination 'platform=macOS' 2>&1 | grep -E 'error:|Build Succeeded'`

Expected: Build Succeeded

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: update CareerExplorerView and Career model to remove AI references"
```

---

### Task 5: Fix Survey Interest Persistence

**Files:**
- Modify: `TMI/Views/Survey/SurveyResultsView.swift`
- Modify: `TMI/Services/SurveyService.swift`

The survey save pipeline has these breaks:
1. `SurveyService.saveStudentSurveyResponse()` calls `StudentInterestService.shared.saveSurveyResults()` but the interest IDs may not match predefined interest IDs
2. `SurveyResultsView.saveSurveyToFirebase()` creates a `[interestId: level]` map from `topInterests` (display names, not IDs) — this mismatch means interests don't resolve

- [ ] **Step 1: Fix interest ID mapping in SurveyService.saveStudentSurveyResponse()**

In `TMI/Services/SurveyService.swift`, find the `saveStudentSurveyResponse` method (~line 319). The `convertClustersToInterests()` method (~line 496) attempts to match cluster names to predefined interests. Verify it returns `Interest` objects with valid IDs that match what `StudentInterestService` expects.

The fix: In `convertClustersToInterests()`, ensure the returned `Interest` objects use the predefined interest's `id` field (not a generated UUID) when a match is found. If the current code generates new UUIDs for matched interests, change it to use `PredefinedInterestsData`'s actual IDs.

- [ ] **Step 2: Fix interest saving in SurveyResultsView.saveSurveyToFirebase()**

In `TMI/Views/Survey/SurveyResultsView.swift`, find `saveSurveyToFirebase()` (~line 396). The current code at ~line 411-416 creates:
```swift
let interestResults = Dictionary(uniqueKeysWithValues: topInterests.map { ($0, 3) })
```

This uses display names as keys. Fix it to use actual interest IDs:

```swift
// Convert analyzed clusters to Interest objects with proper IDs
let interests = SurveyService.shared.convertClustersToInterests(analyzedClusters)
let interestResults = Dictionary(uniqueKeysWithValues: interests.compactMap { interest -> (String, Int)? in
    guard let id = interest.id else { return nil }
    return (id, 3)
})
```

Make sure `convertClustersToInterests` is accessible (may need to change from private to internal in SurveyService).

- [ ] **Step 3: Verify interest data flows to StudentDetailView**

After saving, the `StudentDetailView.loadStudentInterests()` method fetches from `StudentInterestService.shared.getStudentInterests(studentId:)` and resolves them against the interest library. Verify this resolution works by checking that the interest IDs saved in Step 2 match IDs in `PredefinedInterestsData`.

If `loadStudentInterests()` doesn't exist or doesn't call `StudentInterestService`, add the call:

```swift
private func loadStudentInterests() async {
    isLoadingInterests = true
    defer { isLoadingInterests = false }
    do {
        let edges = try await StudentInterestService.shared.getStudentInterests(studentId: student.id ?? "")
        studentInterestEdges = edges
        // Resolve edge IDs to Interest objects
        resolvedInterests = edges.compactMap { edge in
            PredefinedInterestsData.allInterests.first { $0.id == edge.interestId }
        }
    } catch {
        print("Failed to load student interests: \(error)")
    }
}
```

- [ ] **Step 4: Verify build**

Run: `xcodebuild build -scheme TMI -destination 'platform=macOS' 2>&1 | grep -E 'error:|Build Succeeded'`

- [ ] **Step 5: Commit**

```bash
git add TMI/Views/Survey/SurveyResultsView.swift TMI/Services/SurveyService.swift TMI/Views/Students/StudentDetailView.swift
git commit -m "fix: wire survey interest selections to student profile persistence"
```

---

### Task 6: Fix Career Matching From Survey

**Files:**
- Modify: `TMI/Views/Survey/SurveyResultsView.swift`

- [ ] **Step 1: Update career matching to use actual survey clusters**

In `SurveyResultsView.saveSurveyToFirebase()`, find where `CareerMatchingService.shared.matchCareers()` is called (~line 429). Ensure it passes the actual `analyzedClusters` from the survey:

```swift
careerMatches = CareerMatchingService.shared.matchCareers(from: analyzedClusters, dreamJob: extractDreamJob())
```

Verify `analyzedClusters` is populated from `analyzeSurveyResponses()` before this call.

- [ ] **Step 2: Add career save action to SurveyResultsView**

In the career matches section of `SurveyResultsView`, there should be a way to save a career. Find the "Explore Career Matches" button or career list. Add a save button to each career match card:

```swift
Button("Save Career") {
    Task {
        try? await CareerService.shared.saveCareer(
            career: CareerService.shared.careerPathToCareer(match.career),
            for: studentId
        )
    }
}
```

- [ ] **Step 3: Verify build**

Run: `xcodebuild build -scheme TMI -destination 'platform=macOS' 2>&1 | grep -E 'error:|Build Succeeded'`

- [ ] **Step 4: Commit**

```bash
git add TMI/Views/Survey/SurveyResultsView.swift
git commit -m "fix: career matching uses actual survey selections, add save career action"
```

---

### Task 7: Display Saved Careers on Student Detail

**Files:**
- Modify: `TMI/Views/Students/StudentDetailView.swift`
- Modify: `TMI/Views/Students/Sections/StudentCareersSection.swift`

- [ ] **Step 1: Add saved careers state to StudentDetailView**

Add state variables to `StudentDetailView`:

```swift
@State private var savedCareers: [Career] = []
@State private var isLoadingSavedCareers = false
```

- [ ] **Step 2: Add career loading function**

```swift
private func loadSavedCareers() async {
    isLoadingSavedCareers = true
    defer { isLoadingSavedCareers = false }
    do {
        savedCareers = try await CareerService.shared.fetchSavedCareers(for: student.id ?? "")
    } catch {
        print("Failed to load saved careers: \(error)")
    }
}
```

Call this in the `.task` or `.onAppear` modifier alongside `loadStudentInterests()`.

- [ ] **Step 3: Display saved careers in the student detail view**

Add a saved careers section after the interests section. If `StudentCareersSection` already exists, update it to accept `savedCareers`. Otherwise, add inline:

```swift
if !savedCareers.isEmpty {
    TMIGlassCard(style: .standard) {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("Saved Careers")
                .font(.headline)
            ForEach(savedCareers) { career in
                HStack {
                    VStack(alignment: .leading) {
                        Text(career.title).font(.subheadline.bold())
                        Text(career.field).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(career.education).font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
    }
}
```

- [ ] **Step 4: Verify build**

Run: `xcodebuild build -scheme TMI -destination 'platform=macOS' 2>&1 | grep -E 'error:|Build Succeeded'`

- [ ] **Step 5: Commit**

```bash
git add TMI/Views/Students/StudentDetailView.swift TMI/Views/Students/Sections/StudentCareersSection.swift
git commit -m "feat: display saved careers on student detail view"
```

---

### Task 8: Remove Survey Delivery Service Placeholders

**Files:**
- Delete: `TMI/Services/SurveyDeliveryService.swift`

- [ ] **Step 1: Check for references to SurveyDeliveryService**

```bash
grep -rn "SurveyDeliveryService\|SurveyDelivery\b\|SurveyDeliveryMethod\|SurveyDeliveryResult\|SurveyDeliveryError\|SurveyDeliveryStatus" TMI/ --include="*.swift"
```

Fix any references found — remove the calls or replace with no-ops.

- [ ] **Step 2: Delete the file**

```bash
rm TMI/Services/SurveyDeliveryService.swift
```

- [ ] **Step 3: Verify build**

Run: `xcodebuild build -scheme TMI -destination 'platform=macOS' 2>&1 | grep -E 'error:|Build Succeeded'`

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove placeholder SurveyDeliveryService"
```

---

### Task 9: Add TMISheetStyle Modifier

**Files:**
- Modify: `TMI/Views/Components/TMIComponentLibrary.swift`

- [ ] **Step 1: Add the sheet style modifier**

At the end of `TMIComponentLibrary.swift` (before the preview section), add:

```swift
// MARK: - Sheet Style

struct TMISheetStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(minWidth: 500, minHeight: 400)
            .presentationDragIndicator(.visible)
    }
}

extension View {
    func tmiSheetStyle() -> some View {
        modifier(TMISheetStyle())
    }
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild build -scheme TMI -destination 'platform=macOS' 2>&1 | grep -E 'error:|Build Succeeded'`

- [ ] **Step 3: Commit**

```bash
git add TMI/Views/Components/TMIComponentLibrary.swift
git commit -m "feat: add TMISheetStyle shared modifier for consistent sheet sizing"
```

---

### Task 10: Apply TMISheetStyle to All Sheets

**Files:**
- Modify: All 56 Swift files containing `.sheet(` (excluding docs/markdown)

This is a mechanical change. For every `.sheet(isPresented:) { ... }` or `.sheet(item:) { ... }` in the codebase, add `.tmiSheetStyle()` to the sheet content view.

- [ ] **Step 1: Apply tmiSheetStyle to all sheet content views**

For each file with a `.sheet()` modifier, add `.tmiSheetStyle()` to the root view inside the sheet closure. Pattern:

**Before:**
```swift
.sheet(isPresented: $showingSomething) {
    SomeView()
}
```

**After:**
```swift
.sheet(isPresented: $showingSomething) {
    SomeView()
        .tmiSheetStyle()
}
```

For sheets that already have custom `presentationDetents` or `frame` modifiers, replace them with `.tmiSheetStyle()` unless the custom sizing is specifically needed (e.g., a small picker).

Files to update (56 Swift files):
- `TMI/Views/Dashboard/DashboardView.swift`
- `TMI/Views/Students/StudentListView.swift`
- `TMI/Views/MainTabView.swift`
- `TMI/Views/Authentication/AuthenticationView.swift`
- `TMI/Views/Career Explorer/CareerDetailView.swift`
- `TMI/Views/TMIPlans/TMIPlanDetailView.swift`
- `TMI/Views/Authentication/RoleSelectionView.swift`
- `TMI/Views/TMIPlans/Sections/PlanFormsSection.swift`
- `TMI/Views/Students/Sections/StudentCareersSection.swift`
- `TMI/Views/Students/Sections/StudentInterestsSection.swift`
- `TMI/Views/TMIPlans/TMIPlanEditorView.swift`
- `TMI/Views/Dashboard/Components/QuickActionCards.swift`
- `TMI/Views/Students/StudentDetailView.swift`
- `TMI/Views/TMIPlans/Sections/PlanCareersSection.swift`
- `TMI/Views/TMIPlans/Sections/PlanInterestsSection.swift`
- `TMI/Views/Dashboard/DashboardInsightsView.swift`
- `TMI/Views/Forms/FormView.swift`
- `TMI/Views/Forms/Assignments/StaffAssignmentListView.swift`
- `TMI/Views/TMIPlan/PlanApprovalDetailView.swift`
- `TMI/Views/Resources/ResourceDetailView.swift`
- `TMI/Views/TMIPlans/PlanTemplateLibraryView.swift`
- `TMI/Views/Components/NotificationCenterView.swift`
- `TMI/Views/Resources/AssignedResourcesView.swift`
- `TMI/Views/Forms/FormsAndSurveysView.swift`
- `TMI/Views/Career Explorer/CareerExplorerView.swift`
- `TMI/Views/Forms/Templates/FormTemplateLibraryView.swift`
- `TMI/Views/Survey/SurveyResultsView.swift`
- `TMI/Views/InterestsAndHobbies/InterestDetailView.swift`
- `TMI/Views/TMIPlans/TMIPlanListView.swift`
- `TMI/Views/District/DistrictDashboardView.swift`
- `TMI/Views/StudentMode/StudentModeView.swift`
- `TMI/Views/Survey/CareerExplorationView.swift`
- `TMI/Views/Meetings/MeetingListView.swift`
- `TMI/Views/Meetings/MeetingCalendarView.swift`
- `TMI/Views/Meetings/MeetingDetailView.swift`
- `TMI/Views/Meetings/CreateEditMeetingView.swift`
- `TMI/Views/TMIPlan/PlanApprovalView.swift`
- `TMI/Views/Compliance/AuditLogListView.swift`
- `TMI/Views/Compliance/ConsentManagementView.swift`
- `TMI/Views/User/UserProfileView.swift`
- `TMI/Views/Resources/ResourcesView.swift`
- `TMI/Views/Scheduling/ScheduleMeetingView.swift`
- `TMI/Views/InterestsAndHobbies/InterestsAndHobbiesView.swift`
- `TMI/Views/InterestsAndHobbies/StudentInterestProfileView.swift`
- `TMI/Views/Forms/Templates/FormTemplateEditorView.swift`
- `TMI/Views/Forms/FormSectionCard.swift`
- `TMI/Views/Forms/FormAssignmentDetailView.swift`
- `TMI/Views/Forms/FormAssignmentListView.swift`
- `TMI/Views/Forms/FormAssignmentCreateView.swift`
- `TMI/Views/Forms/MyFormsView.swift`
- `TMI/Views/Forms/FormTemplateDetailView.swift`
- `TMI/Views/Forms/StudentFormListView.swift`
- `TMI/Views/Forms/FormSubmissionsView.swift`
- `TMI/Views/Settings/SettingsView.swift`

- [ ] **Step 2: Verify build**

Run: `xcodebuild build -scheme TMI -destination 'platform=macOS' 2>&1 | grep -E 'error:|Build Succeeded'`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: apply tmiSheetStyle to all sheet presentations for consistent sizing"
```

---

### Task 11: Settings Cleanup

**Files:**
- Modify: `TMI/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Remove Staff Settings section**

In `SettingsView.swift`, find the `staffSettingsSection` computed property (~lines 136-156) and delete it. Also remove the conditional rendering in the body that checks `isStaff` to show this section (~line 73 area).

- [ ] **Step 2: Remove Support & Legal section**

Find `supportLegalSection` (~lines 462-519) and delete it. Also remove the reference in the body.

- [ ] **Step 3: Remove associated state variables if unused**

Check if any `@AppStorage` or `@State` variables were only used by the removed sections. Remove them. Likely candidates:
- `notificationsEnabled` (if only used in Staff Settings)

- [ ] **Step 4: Verify build**

Run: `xcodebuild build -scheme TMI -destination 'platform=macOS' 2>&1 | grep -E 'error:|Build Succeeded'`

- [ ] **Step 5: Commit**

```bash
git add TMI/Views/Settings/SettingsView.swift
git commit -m "chore: remove Staff Settings and Support & Legal sections from Settings"
```

---

### Task 12: Wire Edit Profile Navigation

**Files:**
- Modify: `TMI/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Add navigation state**

Add a state variable to `SettingsView`:

```swift
@State private var showingEditProfile = false
```

- [ ] **Step 2: Wire the Edit Profile button**

Find the `accountSection` computed property (~line 356). The "Edit Profile" row has an empty action handler (~line 362). Change it to:

```swift
Button {
    showingEditProfile = true
} label: {
    // existing label
}
```

Then add a `.sheet` or `NavigationLink` presentation. Since `UserProfileView` exists and works as a standalone view, use a sheet:

```swift
.sheet(isPresented: $showingEditProfile) {
    NavigationStack {
        UserProfileView()
    }
    .tmiSheetStyle()
}
```

- [ ] **Step 3: Verify build**

Run: `xcodebuild build -scheme TMI -destination 'platform=macOS' 2>&1 | grep -E 'error:|Build Succeeded'`

- [ ] **Step 4: Commit**

```bash
git add TMI/Views/Settings/SettingsView.swift
git commit -m "feat: wire Edit Profile button in Settings to UserProfileView"
```

---

### Task 13: Add Model Fields for Profile

**Files:**
- Modify: `TMI/Models/TMIUser.swift`

- [ ] **Step 1: Check if photoURL and organization fields exist**

Search `TMIUser.swift` for `photoURL` and `organization`:

```bash
grep -n "photoURL\|organization" TMI/Models/TMIUser.swift
```

- [ ] **Step 2: Add missing fields to TMIUser**

If not present, add to the `TMIUser` struct properties (after `email`):

```swift
var photoURL: String?
var organization: String?
```

Add to `CodingKeys` if TMIUser uses custom coding keys. Add to any memberwise initializer with defaults of `nil`.

- [ ] **Step 3: Add fields to UserProfileData**

In the `UserProfileData` struct (~line 831), add:

```swift
var photoURL: String?
var organization: String?
```

- [ ] **Step 4: Verify build**

Run: `xcodebuild build -scheme TMI -destination 'platform=macOS' 2>&1 | grep -E 'error:|Build Succeeded'`

- [ ] **Step 5: Commit**

```bash
git add TMI/Models/TMIUser.swift
git commit -m "feat: add photoURL and organization fields to TMIUser model"
```

---

### Task 14: Expand Edit Profile View

**Files:**
- Modify: `TMI/Views/User/UserProfileView.swift`

- [ ] **Step 1: Add PhotosUI import and state variables**

At the top of the file, add:

```swift
import PhotosUI
import SDWebImageSwiftUI
```

In `UserProfileStateModel`, add properties:

```swift
var organization: String = ""
var photoURL: String?
var selectedPhotoItem: PhotosPickerItem?
var selectedPhotoData: Data?
var isUploadingPhoto = false
```

- [ ] **Step 2: Load organization and photoURL in fetch()**

In `UserProfileStateModel.fetch()`, after loading the TMIUser from Firestore, populate:

```swift
organization = tmiUser.organization ?? ""
photoURL = tmiUser.photoURL
```

- [ ] **Step 3: Add profile photo upload logic**

Add a method to `UserProfileStateModel`:

```swift
func uploadProfilePhoto() async {
    guard let photoData = selectedPhotoData else { return }
    guard let uid = Auth.auth().currentUser?.uid else { return }
    isUploadingPhoto = true
    defer { isUploadingPhoto = false }

    do {
        let storageRef = FirebaseManager.shared.storage.reference().child("users/\(uid)/profile.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await storageRef.putDataAsync(photoData, metadata: metadata)
        let url = try await storageRef.downloadURL()
        photoURL = url.absoluteString

        // Save URL to Firestore
        let userRef = FirebaseManager.shared.firestore.collection("users").document(uid)
        try await userRef.updateData(["photoURL": url.absoluteString])
    } catch {
        self.error = IdentifiableError(error: error)
    }
}
```

- [ ] **Step 4: Add organization save to updateProfile()**

In the existing `updateProfile()` method, after saving the display name, also save the organization:

```swift
try await userRef.updateData([
    "displayName": data.displayName,
    "organization": organization
])
```

- [ ] **Step 5: Add UI fields to userProfileForm**

In the `userProfileForm` computed property, add after the Display Name field:

**Profile Photo:**
```swift
Section("Profile Photo") {
    HStack {
        if let photoURL, let url = URL(string: photoURL) {
            WebImage(url: url)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
        } else if let photoData = stateModel.selectedPhotoData,
                  let nsImage = NSImage(data: photoData) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundStyle(.secondary)
        }

        PhotosPicker(selection: $stateModel.selectedPhotoItem, matching: .images) {
            Text("Change Photo")
        }
    }
}
```

Add an `.onChange` for the photo picker:
```swift
.onChange(of: stateModel.selectedPhotoItem) { _, newItem in
    Task {
        if let data = try? await newItem?.loadTransferable(type: Data.self) {
            stateModel.selectedPhotoData = data
            await stateModel.uploadProfilePhoto()
        }
    }
}
```

**Role (read-only):**
```swift
Section("Role") {
    Text(stateModel.data.role.isEmpty ? "Unknown" : stateModel.data.role)
        .foregroundStyle(.secondary)
}
```

**Organization:**
```swift
Section("School / Organization") {
    TMITextField(
        placeholder: "Enter your school or organization",
        text: $stateModel.organization,
        icon: "building.2"
    )
}
```

- [ ] **Step 6: Verify build**

Run: `xcodebuild build -scheme TMI -destination 'platform=macOS' 2>&1 | grep -E 'error:|Build Succeeded'`

- [ ] **Step 7: Commit**

```bash
git add TMI/Views/User/UserProfileView.swift
git commit -m "feat: expand Edit Profile with photo, role display, and organization fields"
```

---

### Task 15: Final Build Verification and Cleanup

**Files:**
- Any remaining files with compile errors

- [ ] **Step 1: Full clean build**

```bash
xcodebuild clean build -scheme TMI -destination 'platform=macOS' 2>&1 | grep -E 'error:|warning:|Build Succeeded|Build Failed'
```

- [ ] **Step 2: Fix any remaining compile errors**

Address each error. Common issues:
- Missing type references to deleted AI types
- Method signature mismatches from CareerService rewrite
- Missing imports

- [ ] **Step 3: Search for dead code references**

```bash
grep -rn "AIInsightsService\|AICareerGenerator\|FoundationModelsService\|AIPromptBuilder\|SurveyDeliveryService\|aiGenerated\|generatedAt" TMI/ --include="*.swift"
```

Remove any remaining references.

- [ ] **Step 4: Final clean build**

```bash
xcodebuild clean build -scheme TMI -destination 'platform=macOS' 2>&1 | tail -5
```

Expected: Build Succeeded

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: fix remaining compile errors after cleanup"
```
