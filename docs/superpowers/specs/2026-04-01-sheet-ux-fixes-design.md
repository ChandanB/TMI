# Sheet UX Fixes: Dismiss, Search, and Resource Deduplication

**Date:** 2026-04-01
**Scope:** Bug fixes across student/plan creation and editing flows

## Problem Summary

Four UX issues affecting the add/edit flows for students and TMI plans:

1. Several sheets lack cancel/dismiss buttons, trapping users
2. Career selection sheet never dismisses, even after selection
3. Pressing Enter in search fields submits the parent form instead of searching
4. Same resource appears multiple times in "Available Resources" lists

## Fix 1: Add Dismiss Buttons to Sheets Missing Them

### Current State
`CareerExplorerView` is presented as a `.sheet` from `StudentCareersSection` (line 56) and `PlanCareersSection` (line 62). It has no `@Environment(\.dismiss)` and no close button in its toolbar. The only way out is the swipe-down gesture, which is not discoverable.

### Changes
- **CareerExplorerView.swift**: Add `@Environment(\.dismiss) private var dismiss` and a close button (`xmark.circle.fill`) to the toolbar's trailing position. The close button should always be visible, not just when `hasSearched` is true.

### Files
- `TMI/Views/Career Explorer/CareerExplorerView.swift`

---

## Fix 2: Auto-Dismiss Career Sheet After Selection

### Current State
When a user selects/bookmarks a career in `CareerExplorerView`, nothing happens to dismiss the sheet. The career is saved but the user is left staring at the explorer.

### Changes
- After a career is successfully bookmarked/saved in `CareerExplorerView`, call `dismiss()` to close the sheet automatically.
- Identify the bookmark/save action handler and add `dismiss()` after the save completes.

### Files
- `TMI/Views/Career Explorer/CareerExplorerView.swift`

---

## Fix 3: Enter Key Triggers Search, Not Form Submission

### Current State
The search `TextField` in `StudentInterestsSection` (line 56) has no `.onSubmit` handler:
```swift
TextField("Search interests...", text: $searchText)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
```

When this view is embedded inside a `Form` or `NavigationStack` context (as it is in `StudentProfileView`), pressing Enter triggers form-level submission, which can create the student/plan prematurely. The same pattern exists in career search fields within section views.

### Changes
- **StudentInterestsSection.swift**: Add `.onSubmit {}` to the search TextField. Since the list already filters reactively via the `filteredAvailable` computed property based on `searchText`, the `.onSubmit` handler just needs to be a no-op to block form submission. However, to provide feedback, dismiss the keyboard on submit.
- **StudentCareersSection.swift**: Same fix for the career search TextField if present.
- **PlanInterestsSection.swift**: Same fix if this file has a search field.
- **PlanCareersSection.swift**: Same fix if this file has a search field.
- Add `.submitLabel(.search)` to all search TextFields so the keyboard shows "Search" instead of "Return".

### Files
- `TMI/Views/Students/Sections/StudentInterestsSection.swift`
- `TMI/Views/Students/Sections/StudentCareersSection.swift`
- `TMI/Views/TMIPlans/Sections/PlanInterestsSection.swift` (if search field exists)
- `TMI/Views/TMIPlans/Sections/PlanCareersSection.swift` (if search field exists)

---

## Fix 4: Deduplicate Available Resources

### Current State
`Resource.sampleResources` creates 3 resources without explicit IDs. Since `@DocumentID var id: String?` defaults to `nil`, all three have `id = nil`. The `Equatable` conformance compares only by `id`:

```swift
public static func == (lhs: Resource, rhs: Resource) -> Bool {
    lhs.id == rhs.id  // nil == nil is true
}
```

This means all sample resources are considered equal, causing filtering and display bugs.

### Changes
- **Resource.swift**: Assign a unique UUID string to each sample resource at creation time. Use `UUID().uuidString` as the `id` parameter for each sample resource in `sampleResources`.

Since `@DocumentID` is `String?`, we can set it explicitly for sample data. When fetched from Firestore, the real document ID will be used instead.

### Files
- `TMI/Models/Resource.swift`

---

## Out of Scope

- Redesigning the career exploration flow
- Adding new features to resource management
- Refactoring sheet presentation patterns app-wide
- Changes to the TMIPlanEditorView's inline goal form (it already has Cancel/Add buttons)

## Testing

- Verify each sheet can be dismissed via the new close button
- Verify career selection auto-dismisses the sheet
- Verify pressing Enter in interest/career search fields does not submit the parent form
- Verify no duplicate resources appear in Available Resources lists
- Verify existing functionality (adding students, creating plans, bookmarking careers) still works
