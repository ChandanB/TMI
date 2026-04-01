# Sheet UX Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix four UX bugs: missing dismiss buttons on career sheet, career sheet not auto-dismissing, Enter key submitting forms instead of filtering, and duplicate sample resources.

**Architecture:** Direct bug fixes to existing views and models. No new files or architectural changes. Each task is independent.

**Design note on auto-dismiss (spec Fix 2):** The spec calls for auto-dismiss after career selection. However, `CareerExplorerView` navigates to `CareerDetailView` via `NavigationLink` — the bookmark/save action happens on the *pushed* detail page. Auto-dismissing the entire sheet from a pushed navigation destination would be jarring (the user just tapped into a detail view). The root problem is that the sheet had no dismiss mechanism at all. Task 1 fixes this by adding an always-visible close button, which the user can tap when they're done exploring. This addresses the user's actual pain point.

**Tech Stack:** SwiftUI, Firebase (`@DocumentID`)

**Spec:** `docs/superpowers/specs/2026-04-01-sheet-ux-fixes-design.md`

---

### Task 1: Add Dismiss Button and NavigationStack to CareerExplorerView Sheet

The `CareerExplorerView` is presented as a `.sheet` but (a) lacks `@Environment(\.dismiss)` and a close button, and (b) is not wrapped in a `NavigationStack` at the presentation sites, so its `.toolbar` items and `NavigationLink` destinations don't render.

**Files:**
- Modify: `TMI/Views/Career Explorer/CareerExplorerView.swift:4-8` (add dismiss environment) and `:206-221` (add close button to toolbar)
- Modify: `TMI/Views/Students/Sections/StudentCareersSection.swift:56-59` (wrap in NavigationStack)
- Modify: `TMI/Views/TMIPlans/Sections/PlanCareersSection.swift:62-65` (wrap in NavigationStack)

- [ ] **Step 1: Add `@Environment(\.dismiss)` to CareerExplorerView**

In `CareerExplorerView.swift`, add the dismiss environment property after the existing environment declarations (after line 7):

```swift
@Environment(\.dismiss) private var dismiss
```

- [ ] **Step 2: Add close button to CareerExplorerView toolbar**

In `CareerExplorerView.swift`, add a new `ToolbarItem` inside the existing `.toolbar { }` block (after the `studentPickerButton` item, around line 209). This button should always be visible (not gated by `hasSearched`):

```swift
ToolbarItem(placement: .navigationBarTrailing) {
    Button {
        dismiss()
    } label: {
        Image(systemName: "xmark.circle.fill")
            .font(.system(size: 20))
            .symbolRenderingMode(.hierarchical)
            .foregroundColor(.white.opacity(0.8))
    }
}
```

The existing "New Search" trailing toolbar item (lines 211-220) should remain as-is — SwiftUI supports multiple trailing toolbar items.

- [ ] **Step 3: Wrap CareerExplorerView in NavigationStack at StudentCareersSection presentation**

In `StudentCareersSection.swift`, change lines 56-59 from:

```swift
.sheet(isPresented: $showExploreSheet) {
    CareerExplorerView()
        .tmiSheetStyle()
}
```

to:

```swift
.sheet(isPresented: $showExploreSheet) {
    NavigationStack {
        CareerExplorerView()
    }
    .tmiSheetStyle()
}
```

- [ ] **Step 4: Wrap CareerExplorerView in NavigationStack at PlanCareersSection presentation**

In `PlanCareersSection.swift`, change lines 62-65 from:

```swift
.sheet(isPresented: $showExploreSheet) {
    CareerExplorerView()
        .tmiSheetStyle()
}
```

to:

```swift
.sheet(isPresented: $showExploreSheet) {
    NavigationStack {
        CareerExplorerView()
    }
    .tmiSheetStyle()
}
```

- [ ] **Step 5: Build and verify**

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add TMI/Views/Career\ Explorer/CareerExplorerView.swift TMI/Views/Students/Sections/StudentCareersSection.swift TMI/Views/TMIPlans/Sections/PlanCareersSection.swift
git commit -m "fix: add dismiss button and NavigationStack to CareerExplorerView sheet"
```

---

### Task 2: Add .onSubmit and .submitLabel(.search) to Interest Search Fields

Both `StudentInterestsSection` and `PlanInterestsSection` have search TextFields that lack `.onSubmit` handlers. When embedded in a Form/NavigationStack context (as in StudentProfileView), pressing Enter can trigger parent form submission. Adding `.onSubmit {}` intercepts the Enter key. Adding `.submitLabel(.search)` shows "Search" on the keyboard instead of "Return".

**Files:**
- Modify: `TMI/Views/Students/Sections/StudentInterestsSection.swift:56-58`
- Modify: `TMI/Views/TMIPlans/Sections/PlanInterestsSection.swift:57-59`

- [ ] **Step 1: Add .onSubmit and .submitLabel to StudentInterestsSection search field**

In `StudentInterestsSection.swift`, change lines 56-58 from:

```swift
TextField("Search interests…", text: $searchText)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
```

to:

```swift
TextField("Search interests…", text: $searchText)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
    .submitLabel(.search)
    .onSubmit {
        // Filtering is reactive via searchText binding — just dismiss keyboard
    }
```

- [ ] **Step 2: Add .onSubmit and .submitLabel to PlanInterestsSection search field**

In `PlanInterestsSection.swift`, change lines 57-59 from:

```swift
TextField("Search interests…", text: $searchText)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
```

to:

```swift
TextField("Search interests…", text: $searchText)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
    .submitLabel(.search)
    .onSubmit {
        // Filtering is reactive via searchText binding — just dismiss keyboard
    }
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add TMI/Views/Students/Sections/StudentInterestsSection.swift TMI/Views/TMIPlans/Sections/PlanInterestsSection.swift
git commit -m "fix: add .onSubmit to interest search fields to prevent form submission on Enter"
```

---

### Task 3: Add .onSubmit and .submitLabel(.search) to Career Search Fields

Both `StudentCareersSection` and `PlanCareersSection` have search TextFields (filtering selected/linked careers) that also lack `.onSubmit` handlers. Same fix as Task 2.

**Files:**
- Modify: `TMI/Views/Students/Sections/StudentCareersSection.swift:81-83`
- Modify: `TMI/Views/TMIPlans/Sections/PlanCareersSection.swift:87-89`

- [ ] **Step 1: Add .onSubmit and .submitLabel to StudentCareersSection search field**

In `StudentCareersSection.swift`, change lines 81-83 from:

```swift
TextField("Search selected careers", text: $searchText)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
```

to:

```swift
TextField("Search selected careers", text: $searchText)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
    .submitLabel(.search)
    .onSubmit {
        // Filtering is reactive via searchText binding — just dismiss keyboard
    }
```

- [ ] **Step 2: Add .onSubmit and .submitLabel to PlanCareersSection search field**

In `PlanCareersSection.swift`, change lines 87-89 from:

```swift
TextField("Search linked careers", text: $searchText)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
```

to:

```swift
TextField("Search linked careers", text: $searchText)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
    .submitLabel(.search)
    .onSubmit {
        // Filtering is reactive via searchText binding — just dismiss keyboard
    }
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add TMI/Views/Students/Sections/StudentCareersSection.swift TMI/Views/TMIPlans/Sections/PlanCareersSection.swift
git commit -m "fix: add .onSubmit to career search fields to prevent form submission on Enter"
```

---

### Task 4: Assign Stable UUIDs to Sample Resources

`Resource.sampleResources` creates 3 resources without explicit IDs. Since `@DocumentID var id: String?` defaults to `nil`, all three share `id == nil`, which breaks `Equatable` (they all compare as equal) and causes duplicates in the UI. Fix by assigning stable UUID strings.

**Files:**
- Modify: `TMI/Models/Resource.swift:70-116`

- [ ] **Step 1: Add stable IDs to sample resources**

In `Resource.swift`, change the `sampleResources` computed property (lines 70-116). Add an `id` parameter to each `Resource(...)` initializer call. Use stable string literals (not `UUID().uuidString` which would generate new IDs on every access since `sampleResources` is a computed property):

```swift
static var sampleResources: [Resource] {
    [
        // Featured Resources
        Resource(
            id: "sample-resource-student-engagement",
            title: "Understanding Student Engagement",
            description: "A comprehensive guide to measuring and improving student engagement in educational settings.",
            category: .article,
            url: "https://www.edutopia.org/article/understanding-student-engagement",
            createdAt: Date().addingTimeInterval(-86400 * 7),
            updatedAt: Date().addingTimeInterval(-86400 * 7),
            tags: ["engagement", "research", "metrics", "classroom-management"],
            recommendedFor: ["Teachers", "Counselors", "Administrators"],
            isFeatured: true,
            scope: .global,
            districtId: nil,
            ownerUid: nil
        ),
        Resource(
            id: "sample-resource-tmi-implementation",
            title: "TMI Implementation Course",
            description: "Step-by-step course on implementing Tangible Modification Intervention in your school or district.",
            category: .course,
            url: "https://www.coursera.org/learn/trauma-informed-education",
            createdAt: Date().addingTimeInterval(-86400 * 30),
            updatedAt: Date().addingTimeInterval(-86400 * 30),
            tags: ["implementation", "training", "certification", "trauma-informed"],
            recommendedFor: ["Administrators", "Program Coordinators", "Counselors"],
            isFeatured: true,
            scope: .global,
            districtId: nil,
            ownerUid: nil
        ),
        Resource(
            id: "sample-resource-interest-assessment",
            title: "Student Interest Assessment Toolkit",
            description: "Comprehensive toolkit with validated instruments for assessing student interests across age groups.",
            category: .tool,
            url: "https://www.assessmenttools.edu/interest-inventory",
            createdAt: Date().addingTimeInterval(-86400 * 15),
            updatedAt: Date().addingTimeInterval(-86400 * 15),
            tags: ["assessment", "interests", "toolkit", "validated-instruments"],
            recommendedFor: ["Counselors", "Teachers", "Researchers"],
            isFeatured: true,
            scope: .global,
            districtId: nil,
            ownerUid: nil
        )
    ]
}
```

Note: `@DocumentID` properties can be set via the memberwise initializer. When Firestore decodes a document, it overwrites `id` with the document ID regardless of the default. Using `id:` in the initializer is safe for sample data.

- [ ] **Step 2: Verify @DocumentID accepts explicit id in initializer**

Check that `Resource`'s synthesized memberwise initializer includes `id` as the first parameter. Since `@DocumentID var id: String?` is the first stored property and has a default of `nil`, Swift's memberwise init will include it as an optional parameter. The `id: "sample-..."` syntax will work.

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TMI/Models/Resource.swift
git commit -m "fix: assign stable IDs to sample resources to prevent duplicate display"
```

---

### Task 5: Final Verification

- [ ] **Step 1: Full build**

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | tail -10`

Expected: BUILD SUCCEEDED with no warnings related to our changes.

- [ ] **Step 2: Verify all changes are committed**

Run: `git status`

Expected: clean working tree (all changes committed in Tasks 1-4).
