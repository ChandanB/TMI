# UI Consolidation Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse 9 role-filtered tabs down to 4 (Dashboard, Students, TMI Plans, Settings) by embedding Career Explorer, Interests & Hobbies, Resources, and Forms into the Student and TMI Plan flows using accordion sections.

**Architecture:** In-place refactor. A shared `AccordionSection` component provides the expandable section pattern. `AddStudentView` + `EditStudentView` merge into `StudentProfileView` with 6 accordion sections. `NewTMIPlanView` + `EditTMIPlanView` merge into `TMIPlanEditorView` with 8 accordion sections. `DashboardView` absorbs district content behind a role check. `MainTabView` drops from 9 tab entries to 4.

**Tech Stack:** SwiftUI, Swift Concurrency (async/await), @Observable, Firebase/Firestore, SF Symbols

**Spec:** `docs/superpowers/specs/2026-03-31-ui-consolidation-refactor-design.md`

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `TMI/Views/Components/AccordionSection.swift` | Reusable expandable section component with icon, title, badge, required tag, chevron |
| `TMI/Views/Students/StudentProfileView.swift` | Unified create/edit student view with 6 accordion sections |
| `TMI/Views/Students/Sections/StudentInterestsSection.swift` | Inline interest management (search, chips, CRUD) |
| `TMI/Views/Students/Sections/StudentCareersSection.swift` | Simplified career picker + "Explore" sheet trigger |
| `TMI/Views/Students/Sections/StudentResourcesSection.swift` | Inline resource management |
| `TMI/Views/TMIPlans/TMIPlanEditorView.swift` | Unified create/edit plan view with 8 accordion sections |
| `TMI/Views/TMIPlans/Sections/PlanInterestsSection.swift` | Interest management linked to plan |
| `TMI/Views/TMIPlans/Sections/PlanCareersSection.swift` | Career pathway management linked to plan |
| `TMI/Views/TMIPlans/Sections/PlanResourcesSection.swift` | Resource management linked to plan |
| `TMI/Views/TMIPlans/Sections/PlanFormsSection.swift` | Forms & surveys management (absorbs Forms tab) |

### Modified Files
| File | Changes |
|------|---------|
| `TMI/Views/MainTabView.swift` | Remove 5 tab entries, keep Dashboard/Students/TMIPlans/Settings |
| `TMI/Views/Dashboard/DashboardView.swift` | Add district content sections for admin roles |
| `TMI/Views/Students/StudentListView.swift` | Update navigation to use `StudentProfileView` instead of separate Add/Edit views |
| `TMI/Views/TMIPlans/TMIPlanListView.swift` | Update navigation to use `TMIPlanEditorView` instead of separate New/Edit views |

### Files to Delete (after all tasks verified)
| File | Reason |
|------|--------|
| `TMI/Views/Students/AddStudentView.swift` | Replaced by `StudentProfileView` |
| `TMI/Views/Students/EditStudentView.swift` | Replaced by `StudentProfileView` |
| `TMI/Views/TMIPlans/NewTMIPlanView.swift` | Replaced by `TMIPlanEditorView` |
| `TMI/Views/TMIPlan/EditTMIPlanView.swift` | Replaced by `TMIPlanEditorView` |
| `TMI/Views/TMIPlans/CreateTMIPlanView.swift` | Replaced by `TMIPlanEditorView` |

---

## Task 1: Create Shared AccordionSection Component

**Files:**
- Create: `TMI/Views/Components/AccordionSection.swift`

- [ ] **Step 1: Create `AccordionSection.swift`**

```swift
import SwiftUI

struct AccordionSection<Content: View>: View {
    let icon: String
    let title: String
    var badge: String? = nil
    var badgeColor: Color = .blue
    var isRequired: Bool = false
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if isRequired {
                        Text("REQUIRED")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red, in: RoundedRectangle(cornerRadius: 4))
                    }

                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(badgeColor, in: Capsule())
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                content()
                    .padding(16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED (or pre-existing errors unrelated to AccordionSection)

- [ ] **Step 3: Commit**

```bash
git add TMI/Views/Components/AccordionSection.swift
git commit -m "feat: add reusable AccordionSection component for expandable form sections"
```

---

## Task 2: Create StudentInterestsSection

**Files:**
- Create: `TMI/Views/Students/Sections/StudentInterestsSection.swift`

- [ ] **Step 1: Create the Sections directory**

```bash
mkdir -p TMI/Views/Students/Sections
```

- [ ] **Step 2: Create `StudentInterestsSection.swift`**

```swift
import SwiftUI

struct StudentInterestsSection: View {
    @Binding var selectedInterests: [Interest]
    @State private var searchText = ""
    @State private var availableInterests: [Interest] = []
    @State private var isLoadingInterests = false
    @State private var showingCreateInterest = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Search bar + New button
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search interests...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                Button {
                    showingCreateInterest = true
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            // Selected interests as chips
            if !selectedInterests.isEmpty {
                Text("SELECTED")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(selectedInterests) { interest in
                        InterestChip(interest: interest) {
                            withAnimation {
                                selectedInterests.removeAll { $0.id == interest.id }
                            }
                        }
                    }
                }
            }

            // Filtered available interests
            let filtered = filteredAvailableInterests
            if !filtered.isEmpty {
                Text(searchText.isEmpty ? "SUGGESTED" : "RESULTS")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(filtered.prefix(8)) { interest in
                        Button {
                            withAnimation {
                                selectedInterests.append(interest)
                            }
                        } label: {
                            Label(interest.name, systemImage: "plus")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.quaternary, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if isLoadingInterests {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .task {
            await loadAvailableInterests()
        }
    }

    private var filteredAvailableInterests: [Interest] {
        let unselectedIds = Set(selectedInterests.compactMap(\.id))
        let unselected = availableInterests.filter { interest in
            guard let id = interest.id else { return true }
            return !unselectedIds.contains(id)
        }
        if searchText.isEmpty { return unselected }
        return unselected.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func loadAvailableInterests() async {
        isLoadingInterests = true
        defer { isLoadingInterests = false }
        do {
            guard let uid = FirebaseManager.shared.currentUserUID else { return }
            let db = FirebaseManager.shared.firestore
            let snapshot = try await db.collection("users").document(uid).collection("interests").getDocuments()
            availableInterests = snapshot.documents.compactMap { try? $0.data(as: Interest.self) }
        } catch {
            // Silently fail — user can still create new interests
        }
    }
}

private struct InterestChip: View {
    let interest: Interest
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(interest.name)
                .font(.subheadline)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.pink.opacity(0.15), in: Capsule())
        .overlay(Capsule().stroke(.pink.opacity(0.4), lineWidth: 1))
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}
```

- [ ] **Step 3: Verify it builds**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`

- [ ] **Step 4: Commit**

```bash
git add TMI/Views/Students/Sections/StudentInterestsSection.swift
git commit -m "feat: add StudentInterestsSection with search, chips, and CRUD"
```

---

## Task 3: Create StudentCareersSection

**Files:**
- Create: `TMI/Views/Students/Sections/StudentCareersSection.swift`

- [ ] **Step 1: Create `StudentCareersSection.swift`**

```swift
import SwiftUI

struct StudentCareersSection: View {
    @Binding var selectedCareers: [Career]
    var studentInterests: [Interest]
    @State private var searchText = ""
    @State private var recommendations: [Career] = []
    @State private var isLoadingRecommendations = false
    @State private var showingCareerExplorer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Search bar + Explore button
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search careers...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                Button {
                    showingCareerExplorer = true
                } label: {
                    Label("Explore", systemImage: "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }

            // Selected careers
            if !selectedCareers.isEmpty {
                Text("SELECTED")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(selectedCareers) { career in
                    CareerCard(career: career, studentInterests: studentInterests) {
                        withAnimation {
                            selectedCareers.removeAll { $0.id == career.id }
                        }
                    }
                }
            }

            // AI Recommendations
            if !recommendations.isEmpty {
                Text("AI RECOMMENDATIONS")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(recommendations.prefix(4)) { career in
                    CareerRecommendationRow(career: career) {
                        withAnimation {
                            selectedCareers.append(career)
                            recommendations.removeAll { $0.id == career.id }
                        }
                    }
                }
            }

            if isLoadingRecommendations {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showingCareerExplorer) {
            NavigationStack {
                CareerExplorerView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingCareerExplorer = false }
                        }
                    }
            }
        }
        .task {
            await loadRecommendations()
        }
    }

    private func loadRecommendations() async {
        guard !studentInterests.isEmpty else { return }
        isLoadingRecommendations = true
        defer { isLoadingRecommendations = false }
        do {
            let interestNames = studentInterests.map(\.name)
            recommendations = try await CareerService.shared.fetchRecommendedCareers(forInterests: interestNames)
            // Remove already-selected
            let selectedIds = Set(selectedCareers.compactMap(\.id))
            recommendations.removeAll { career in
                guard let id = career.id else { return false }
                return selectedIds.contains(id)
            }
        } catch {
            // Silently fail — recommendations are supplementary
        }
    }
}

private struct CareerCard: View {
    let career: Career
    var studentInterests: [Interest]
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(career.title)
                    .font(.subheadline.weight(.semibold))
                Text(career.field)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                let matchingInterests = studentInterests.filter { interest in
                    career.relatedInterests.contains(interest.name)
                }
                if !matchingInterests.isEmpty {
                    Text("Matches: \(matchingInterests.map(\.name).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                }
            }
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.cyan.opacity(0.3), lineWidth: 1))
    }
}

private struct CareerRecommendationRow: View {
    let career: Career
    let onAdd: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(career.title)
                    .font(.subheadline.weight(.medium))
                if let outlook = career.jobOutlook {
                    Text(outlook)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("+ Add", action: onAdd)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.green)
                .buttonStyle(.plain)
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`

Note: The `CareerExplorerView` is embedded as a sheet. If `CareerService.shared.fetchRecommendedCareers(forInterests:)` doesn't exist yet, create a stub that returns an empty array and add a `// TODO: wire to CareerMatchingService` comment. Check existing `CareerService.swift` and `CareerMatchingService.swift` for the actual method names.

- [ ] **Step 3: Commit**

```bash
git add TMI/Views/Students/Sections/StudentCareersSection.swift
git commit -m "feat: add StudentCareersSection with picker, AI recommendations, and explore sheet"
```

---

## Task 4: Create StudentResourcesSection

**Files:**
- Create: `TMI/Views/Students/Sections/StudentResourcesSection.swift`

- [ ] **Step 1: Create `StudentResourcesSection.swift`**

```swift
import SwiftUI

struct StudentResourcesSection: View {
    @Binding var selectedResources: [Resource]
    @State private var searchText = ""
    @State private var availableResources: [Resource] = []
    @State private var isLoadingResources = false
    @State private var showingCreateResource = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Search bar + New button
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search resources...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                Button {
                    showingCreateResource = true
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            // Selected resources
            if !selectedResources.isEmpty {
                Text("SELECTED")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(selectedResources) { resource in
                    ResourceRow(resource: resource) {
                        withAnimation {
                            selectedResources.removeAll { $0.id == resource.id }
                        }
                    }
                }
            }

            // Available resources
            let filtered = filteredAvailableResources
            if !filtered.isEmpty {
                Text(searchText.isEmpty ? "AVAILABLE" : "RESULTS")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(filtered.prefix(6)) { resource in
                    Button {
                        withAnimation {
                            selectedResources.append(resource)
                        }
                    } label: {
                        HStack {
                            Image(systemName: resource.category.iconName)
                                .foregroundStyle(resource.category.color)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(resource.title)
                                    .font(.subheadline)
                                Text(resource.category.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("+ Add")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.green)
                        }
                        .padding(10)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            if isLoadingResources {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .task {
            await loadAvailableResources()
        }
    }

    private var filteredAvailableResources: [Resource] {
        let selectedIds = Set(selectedResources.compactMap(\.id))
        let unselected = availableResources.filter { resource in
            guard let id = resource.id else { return true }
            return !selectedIds.contains(id)
        }
        if searchText.isEmpty { return unselected }
        return unselected.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private func loadAvailableResources() async {
        isLoadingResources = true
        defer { isLoadingResources = false }
        do {
            guard let uid = FirebaseManager.shared.currentUserUID else { return }
            let db = FirebaseManager.shared.firestore
            let snapshot = try await db.collection("users").document(uid).collection("resources").getDocuments()
            availableResources = snapshot.documents.compactMap { try? $0.data(as: Resource.self) }
        } catch {
            // Silently fail
        }
    }
}

private struct ResourceRow: View {
    let resource: Resource
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Image(systemName: resource.category.iconName)
                .foregroundStyle(resource.category.color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(resource.title)
                    .font(.subheadline.weight(.medium))
                Text(resource.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.indigo.opacity(0.3), lineWidth: 1))
    }
}
```

Note: Check `Resource.swift` for the actual property names on `ResourceCategory` — the model may use `systemImage` instead of `iconName`, and the color accessor may differ. Adapt as needed.

- [ ] **Step 2: Verify it builds**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add TMI/Views/Students/Sections/StudentResourcesSection.swift
git commit -m "feat: add StudentResourcesSection with search and CRUD"
```

---

## Task 5: Build StudentProfileView (Unified Create/Edit)

**Files:**
- Create: `TMI/Views/Students/StudentProfileView.swift`
- Reference: `TMI/Views/Students/AddStudentView.swift` (585 lines), `TMI/Views/Students/EditStudentView.swift` (663 lines)

- [ ] **Step 1: Create `StudentProfileView.swift`**

This view replaces both AddStudentView and EditStudentView. It uses `AccordionSection` for each form section. When `existingStudent` is nil, it's a creation flow; when provided, it's an edit flow.

```swift
import SwiftUI
import FirebaseFirestore

struct StudentProfileView: View {
    /// Pass nil for creation, or an existing Student for editing
    var existingStudent: Student?
    @Environment(\.dismiss) private var dismiss

    // MARK: - Section expansion state
    @State private var studentInfoExpanded = true
    @State private var guardianExpanded = false
    @State private var interestsExpanded = false
    @State private var careersExpanded = false
    @State private var resourcesExpanded = false
    @State private var notesExpanded = false

    // MARK: - Student Info fields
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var grade = ""
    @State private var school = ""
    @State private var dateOfBirth = Date()
    @State private var studentID = ""

    // MARK: - Guardian fields
    @State private var guardianName = ""
    @State private var guardianRelationship = ""
    @State private var guardianPhone = ""
    @State private var guardianEmail = ""
    @State private var emergencyContact = ""
    @State private var emergencyPhone = ""

    // MARK: - Interests, Careers, Resources
    @State private var selectedInterests: [Interest] = []
    @State private var selectedCareers: [Career] = []
    @State private var selectedResources: [Resource] = []

    // MARK: - Notes
    @State private var behavioralNotes = ""

    // MARK: - UI State
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private var isEditing: Bool { existingStudent != nil }

    private let grades = ["Pre-K", "K"] + Array(1...12).map { String($0) }
    private let relationshipOptions = ["Parent", "Legal Guardian", "Foster Parent", "Relative", "Other"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 1) {
                    // Section 1: Student Information
                    AccordionSection(
                        icon: "person.fill",
                        title: "Student Information",
                        isRequired: true,
                        isExpanded: $studentInfoExpanded
                    ) {
                        studentInfoContent
                    }

                    Divider()

                    // Section 2: Guardian Information
                    AccordionSection(
                        icon: "house.fill",
                        title: "Guardian Information",
                        isExpanded: $guardianExpanded
                    ) {
                        guardianInfoContent
                    }

                    Divider()

                    // Section 3: Interests & Hobbies
                    AccordionSection(
                        icon: "paintpalette.fill",
                        title: "Interests & Hobbies",
                        badge: selectedInterests.isEmpty ? nil : "\(selectedInterests.count) added",
                        badgeColor: .pink,
                        isExpanded: $interestsExpanded
                    ) {
                        StudentInterestsSection(selectedInterests: $selectedInterests)
                    }

                    Divider()

                    // Section 4: Career Exploration
                    AccordionSection(
                        icon: "briefcase.fill",
                        title: "Career Exploration",
                        badge: selectedCareers.isEmpty ? nil : "\(selectedCareers.count) added",
                        badgeColor: .cyan,
                        isExpanded: $careersExpanded
                    ) {
                        StudentCareersSection(
                            selectedCareers: $selectedCareers,
                            studentInterests: selectedInterests
                        )
                    }

                    Divider()

                    // Section 5: Resources
                    AccordionSection(
                        icon: "book.fill",
                        title: "Resources",
                        badge: selectedResources.isEmpty ? nil : "\(selectedResources.count) added",
                        badgeColor: .indigo,
                        isExpanded: $resourcesExpanded
                    ) {
                        StudentResourcesSection(selectedResources: $selectedResources)
                    }

                    Divider()

                    // Section 6: Notes & Additional Info
                    AccordionSection(
                        icon: "note.text",
                        title: "Notes & Additional Info",
                        isExpanded: $notesExpanded
                    ) {
                        notesContent
                    }
                }
                .background(.background)
            }
            .navigationTitle(isEditing ? "Edit Student" : "New Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        Task { await saveStudent() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving || firstName.isEmpty || lastName.isEmpty || school.isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .onAppear { populateFromExistingStudent() }
        }
    }

    // MARK: - Student Info Content

    @ViewBuilder
    private var studentInfoContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                LabeledField(label: "First Name", text: $firstName, placeholder: "Enter first name")
                LabeledField(label: "Last Name", text: $lastName, placeholder: "Enter last name")
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Grade").font(.caption).foregroundStyle(.secondary)
                    Picker("Grade", selection: $grade) {
                        Text("Select grade").tag("")
                        ForEach(grades, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }
                LabeledField(label: "School", text: $school, placeholder: "Enter school")
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date of Birth").font(.caption).foregroundStyle(.secondary)
                    DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                        .labelsHidden()
                }
                LabeledField(label: "Student ID", text: $studentID, placeholder: "Optional")
            }
        }
    }

    // MARK: - Guardian Info Content

    @ViewBuilder
    private var guardianInfoContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                LabeledField(label: "Guardian Name", text: $guardianName, placeholder: "Full name")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Relationship").font(.caption).foregroundStyle(.secondary)
                    Picker("Relationship", selection: $guardianRelationship) {
                        Text("Select").tag("")
                        ForEach(relationshipOptions, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }
            }
            HStack(spacing: 12) {
                LabeledField(label: "Phone", text: $guardianPhone, placeholder: "(555) 555-5555")
                LabeledField(label: "Email", text: $guardianEmail, placeholder: "email@example.com")
            }
            HStack(spacing: 12) {
                LabeledField(label: "Emergency Contact", text: $emergencyContact, placeholder: "Name")
                LabeledField(label: "Emergency Phone", text: $emergencyPhone, placeholder: "(555) 555-5555")
            }
        }
    }

    // MARK: - Notes Content

    @ViewBuilder
    private var notesContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Behavioral Notes").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $behavioralNotes)
                .frame(minHeight: 100)
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Data Operations

    private func populateFromExistingStudent() {
        guard let student = existingStudent else { return }
        // Split name into first/last
        let nameParts = student.name.components(separatedBy: " ")
        firstName = nameParts.first ?? ""
        lastName = nameParts.dropFirst().joined(separator: " ")
        grade = student.grade
        school = student.school
        dateOfBirth = student.dateOfBirth
        studentID = student.studentID ?? ""
        behavioralNotes = student.notes?.last?.content ?? ""
        // Interests, careers, resources loaded async by their sections
    }

    private func saveStudent() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
            if isEditing, var student = existingStudent {
                // Update existing
                student = Student(
                    id: student.id,
                    name: fullName,
                    grade: grade,
                    school: school,
                    dateOfBirth: dateOfBirth,
                    studentID: studentID.isEmpty ? nil : studentID
                )
                try await StudentService().updateStudent(student)
            } else {
                // Create new
                let newStudent = Student(
                    name: fullName,
                    grade: grade,
                    school: school,
                    dateOfBirth: dateOfBirth,
                    studentID: studentID.isEmpty ? nil : studentID
                )
                let saved = try await StudentService().addStudent(newStudent)
                // Save interests to edge collection
                if !selectedInterests.isEmpty, let studentId = saved.id {
                    try await StudentInterestService.shared.syncInterests(
                        selectedInterests,
                        forStudentId: studentId
                    )
                }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Labeled Text Field Helper

private struct LabeledField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}
```

**Important implementation notes for the executing agent:**
- Check `Student.swift` for the exact initializer signature — the model may require additional parameters like `createdBy`, `districtId`, etc. Adapt the `saveStudent()` method accordingly.
- Check `StudentService().addStudent()` — it may return `Student` or `String` (ID). Adapt the return handling.
- Check `StudentInterestService.shared.syncInterests()` — the method name and signature may differ. Look at existing usage in `AddStudentStateModel.swift`.
- The `LabeledField` helper may conflict with existing components in `TMIComponentLibrary.swift`. If so, rename it to `StudentLabeledField` or use the existing component.

- [ ] **Step 2: Verify it builds**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`

Fix any compilation errors related to model API mismatches.

- [ ] **Step 3: Commit**

```bash
git add TMI/Views/Students/StudentProfileView.swift
git commit -m "feat: add unified StudentProfileView with accordion sections for create/edit"
```

---

## Task 6: Create Plan Section Components

**Files:**
- Create: `TMI/Views/TMIPlans/Sections/PlanInterestsSection.swift`
- Create: `TMI/Views/TMIPlans/Sections/PlanCareersSection.swift`
- Create: `TMI/Views/TMIPlans/Sections/PlanResourcesSection.swift`
- Create: `TMI/Views/TMIPlans/Sections/PlanFormsSection.swift`

- [ ] **Step 1: Create the Sections directory**

```bash
mkdir -p TMI/Views/TMIPlans/Sections
```

- [ ] **Step 2: Create `PlanInterestsSection.swift`**

This is similar to `StudentInterestsSection` but pulls from selected students' existing interests as suggestions.

```swift
import SwiftUI

struct PlanInterestsSection: View {
    @Binding var linkedInterests: [Interest]
    var students: [Student]
    @State private var searchText = ""
    @State private var studentInterests: [Interest] = []
    @State private var isLoading = false
    @State private var showingCreateInterest = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Search bar + New button
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search interests...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                Button {
                    showingCreateInterest = true
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            // Linked interests as chips
            if !linkedInterests.isEmpty {
                Text("LINKED TO PLAN")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(linkedInterests) { interest in
                        InterestChip(interest: interest) {
                            withAnimation {
                                linkedInterests.removeAll { $0.id == interest.id }
                            }
                        }
                    }
                }
            }

            // From students' profiles
            let available = availableFromStudents
            if !available.isEmpty {
                Text("FROM STUDENTS' PROFILES")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(available.prefix(8)) { interest in
                        Button {
                            withAnimation { linkedInterests.append(interest) }
                        } label: {
                            Label(interest.name, systemImage: "plus")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.quaternary, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .task {
            await loadStudentInterests()
        }
    }

    private var availableFromStudents: [Interest] {
        let linkedIds = Set(linkedInterests.compactMap(\.id))
        let unlinked = studentInterests.filter { interest in
            guard let id = interest.id else { return true }
            return !linkedIds.contains(id)
        }
        if searchText.isEmpty { return unlinked }
        return unlinked.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func loadStudentInterests() async {
        isLoading = true
        defer { isLoading = false }
        var allInterests: [Interest] = []
        for student in students {
            do {
                let interests = try await student.fetchInterestsFromEdgeCollection()
                allInterests.append(contentsOf: interests)
            } catch {
                continue
            }
        }
        // Deduplicate by ID
        var seen = Set<String>()
        studentInterests = allInterests.filter { interest in
            guard let id = interest.id else { return true }
            return seen.insert(id).inserted
        }
    }
}
```

Note: Reuse `FlowLayout` and `InterestChip` from `StudentInterestsSection.swift`. If they're declared as `private`, move them to a shared file or make them `internal`. The executing agent should check and refactor as needed.

- [ ] **Step 3: Create `PlanCareersSection.swift`**

```swift
import SwiftUI

struct PlanCareersSection: View {
    @Binding var linkedCareers: [Career]
    var students: [Student]
    var linkedInterests: [Interest]
    @State private var searchText = ""
    @State private var recommendations: [Career] = []
    @State private var isLoading = false
    @State private var showingCareerExplorer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search careers...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                Button {
                    showingCareerExplorer = true
                } label: {
                    Label("Explore", systemImage: "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }

            if !linkedCareers.isEmpty {
                Text("LINKED TO PLAN")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(linkedCareers) { career in
                    CareerCard(career: career, studentInterests: linkedInterests) {
                        withAnimation { linkedCareers.removeAll { $0.id == career.id } }
                    }
                }
            }

            if !recommendations.isEmpty {
                Text("RECOMMENDATIONS")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(recommendations.prefix(4)) { career in
                    CareerRecommendationRow(career: career) {
                        withAnimation {
                            linkedCareers.append(career)
                            recommendations.removeAll { $0.id == career.id }
                        }
                    }
                }
            }

            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showingCareerExplorer) {
            NavigationStack {
                CareerExplorerView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingCareerExplorer = false }
                        }
                    }
            }
        }
        .task {
            await loadRecommendations()
        }
    }

    private func loadRecommendations() async {
        guard !linkedInterests.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let interestNames = linkedInterests.map(\.name)
            recommendations = try await CareerService.shared.fetchRecommendedCareers(forInterests: interestNames)
            let linkedIds = Set(linkedCareers.compactMap(\.id))
            recommendations.removeAll { career in
                guard let id = career.id else { return false }
                return linkedIds.contains(id)
            }
        } catch {}
    }
}
```

Note: `CareerCard` and `CareerRecommendationRow` are reused from `StudentCareersSection.swift`. Same guidance as above — make them `internal` or extract to a shared file.

- [ ] **Step 4: Create `PlanResourcesSection.swift`**

```swift
import SwiftUI

struct PlanResourcesSection: View {
    @Binding var linkedResources: [Resource]
    var students: [Student]
    @State private var searchText = ""
    @State private var availableResources: [Resource] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search resources...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                Button {} label: {
                    Label("New", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            if !linkedResources.isEmpty {
                Text("ATTACHED TO PLAN")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(linkedResources) { resource in
                    ResourceRow(resource: resource) {
                        withAnimation { linkedResources.removeAll { $0.id == resource.id } }
                    }
                }
            }

            let filtered = filteredAvailableResources
            if !filtered.isEmpty {
                Text(searchText.isEmpty ? "AVAILABLE" : "RESULTS")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(filtered.prefix(6)) { resource in
                    Button {
                        withAnimation { linkedResources.append(resource) }
                    } label: {
                        HStack {
                            Image(systemName: resource.category.iconName)
                                .foregroundStyle(resource.category.color)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(resource.title).font(.subheadline)
                                Text(resource.category.rawValue).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("+ Add").font(.subheadline.weight(.medium)).foregroundStyle(.green)
                        }
                        .padding(10)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .task {
            await loadAvailableResources()
        }
    }

    private var filteredAvailableResources: [Resource] {
        let linkedIds = Set(linkedResources.compactMap(\.id))
        let unlinked = availableResources.filter { r in
            guard let id = r.id else { return true }
            return !linkedIds.contains(id)
        }
        if searchText.isEmpty { return unlinked }
        return unlinked.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private func loadAvailableResources() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let uid = FirebaseManager.shared.currentUserUID else { return }
            let db = FirebaseManager.shared.firestore
            let snapshot = try await db.collection("users").document(uid).collection("resources").getDocuments()
            availableResources = snapshot.documents.compactMap { try? $0.data(as: Resource.self) }
        } catch {}
    }
}
```

Note: `ResourceRow` is reused from `StudentResourcesSection.swift`. Same guidance — extract to shared if private.

- [ ] **Step 5: Create `PlanFormsSection.swift`**

```swift
import SwiftUI

struct PlanFormsSection: View {
    var planId: String?
    @State private var assignments: [FormAssignment] = []
    @State private var isLoading = false
    @State private var showingAssignForm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !assignments.isEmpty {
                Text("ASSIGNED")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(assignments) { assignment in
                    FormAssignmentRow(assignment: assignment)
                }
            }

            Button {
                showingAssignForm = true
            } label: {
                HStack {
                    Spacer()
                    Label("Assign Form or Survey", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.blue)
                    Spacer()
                }
                .padding(14)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .foregroundStyle(.tertiary)
                )
            }
            .buttonStyle(.plain)

            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .task {
            if let planId { await loadAssignments(planId: planId) }
        }
    }

    private func loadAssignments(planId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            assignments = try await FormAssignmentService.shared.fetchAssignments(forPlanId: planId)
        } catch {}
    }
}

private struct FormAssignmentRow: View {
    let assignment: FormAssignment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.formTitle)
                    .font(.subheadline.weight(.semibold))
                Text(assignment.statusDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(assignment.status.rawValue.capitalized)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(assignment.statusColor, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
```

**Important:** Check `FormAssignment` model and `FormAssignmentService` for the actual property and method names. The model may use different field names like `title` instead of `formTitle`, or `completionStatus` instead of `status`. The service method for fetching plan-specific assignments may not exist yet — if so, create a stub.

- [ ] **Step 6: Verify all four files build**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`

- [ ] **Step 7: Commit**

```bash
git add TMI/Views/TMIPlans/Sections/
git commit -m "feat: add plan section components (interests, careers, resources, forms)"
```

---

## Task 7: Build TMIPlanEditorView (Unified Create/Edit)

**Files:**
- Create: `TMI/Views/TMIPlans/TMIPlanEditorView.swift`
- Reference: `TMI/Views/TMIPlans/NewTMIPlanView.swift` (498 lines), `TMI/Views/TMIPlan/EditTMIPlanView.swift` (343 lines)

- [ ] **Step 1: Create `TMIPlanEditorView.swift`**

```swift
import SwiftUI
import FirebaseFirestore

struct TMIPlanEditorView: View {
    /// Pass nil for creation, or an existing TMIPlan for editing
    var existingPlan: TMIPlan?
    /// Pre-selected student (when creating from student context)
    var preselectedStudent: Student?

    @Environment(\.dismiss) private var dismiss

    // MARK: - Section expansion state
    @State private var planDetailsExpanded = true
    @State private var studentsExpanded = false
    @State private var interestsExpanded = false
    @State private var careersExpanded = false
    @State private var resourcesExpanded = false
    @State private var formsExpanded = false
    @State private var goalsExpanded = false
    @State private var approvalExpanded = false

    // MARK: - Plan Details
    @State private var title = ""
    @State private var description = ""
    @State private var selectedModel: TMIPlanModel = .chaseYourSpace
    @State private var startDate = Date()
    @State private var endDate: Date?

    // MARK: - Students
    @State private var selectedStudents: [Student] = []
    @State private var showingStudentPicker = false

    // MARK: - Linked data
    @State private var linkedInterests: [Interest] = []
    @State private var linkedCareers: [Career] = []
    @State private var linkedResources: [Resource] = []

    // MARK: - Goals
    @State private var goals: [Goal] = []
    @State private var notes = ""

    // MARK: - UI State
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private var isEditing: Bool { existingPlan != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 1) {
                    // Section 1: Plan Details
                    AccordionSection(
                        icon: "doc.text.fill",
                        title: "Plan Details",
                        isRequired: true,
                        isExpanded: $planDetailsExpanded
                    ) {
                        planDetailsContent
                    }

                    Divider()

                    // Section 2: Students
                    AccordionSection(
                        icon: "person.fill",
                        title: "Students",
                        badge: selectedStudents.isEmpty ? nil : "\(selectedStudents.count) selected",
                        badgeColor: .green,
                        isRequired: true,
                        isExpanded: $studentsExpanded
                    ) {
                        studentsContent
                    }

                    Divider()

                    // Section 3: Interests
                    AccordionSection(
                        icon: "paintpalette.fill",
                        title: "Interests & Hobbies",
                        badge: linkedInterests.isEmpty ? nil : "\(linkedInterests.count) linked",
                        badgeColor: .pink,
                        isExpanded: $interestsExpanded
                    ) {
                        PlanInterestsSection(
                            linkedInterests: $linkedInterests,
                            students: selectedStudents
                        )
                    }

                    Divider()

                    // Section 4: Career Pathways
                    AccordionSection(
                        icon: "briefcase.fill",
                        title: "Career Pathways",
                        badge: linkedCareers.isEmpty ? nil : "\(linkedCareers.count) linked",
                        badgeColor: .cyan,
                        isExpanded: $careersExpanded
                    ) {
                        PlanCareersSection(
                            linkedCareers: $linkedCareers,
                            students: selectedStudents,
                            linkedInterests: linkedInterests
                        )
                    }

                    Divider()

                    // Section 5: Resources
                    AccordionSection(
                        icon: "book.fill",
                        title: "Resources",
                        badge: linkedResources.isEmpty ? nil : "\(linkedResources.count) attached",
                        badgeColor: .indigo,
                        isExpanded: $resourcesExpanded
                    ) {
                        PlanResourcesSection(
                            linkedResources: $linkedResources,
                            students: selectedStudents
                        )
                    }

                    Divider()

                    // Section 6: Forms & Surveys
                    AccordionSection(
                        icon: "doc.on.clipboard",
                        title: "Forms & Surveys",
                        badge: nil, // PlanFormsSection manages its own badge state
                        badgeColor: .orange,
                        isExpanded: $formsExpanded
                    ) {
                        PlanFormsSection(planId: existingPlan?.id)
                    }

                    Divider()

                    // Section 7: Goals & Progress
                    AccordionSection(
                        icon: "target",
                        title: "Goals & Progress",
                        badge: goals.isEmpty ? nil : "\(goals.count) goals",
                        badgeColor: .green,
                        isExpanded: $goalsExpanded
                    ) {
                        goalsContent
                    }

                    Divider()

                    // Section 8: Approval
                    AccordionSection(
                        icon: "checkmark.seal.fill",
                        title: "Approval",
                        badge: existingPlan?.approvalStatus.rawValue.capitalized ?? "Draft",
                        badgeColor: approvalBadgeColor,
                        isExpanded: $approvalExpanded
                    ) {
                        approvalContent
                    }
                }
                .background(.background)
            }
            .navigationTitle(isEditing ? "Edit Plan" : "New TMI Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        Task { await savePlan() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving || title.isEmpty || selectedStudents.isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .onAppear { populateFromExistingPlan() }
        }
    }

    // MARK: - Plan Details Content

    @ViewBuilder
    private var planDetailsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Plan Title").font(.caption).foregroundStyle(.secondary)
                TextField("Enter plan title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("TMI Model").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(TMIPlanModel.allCases, id: \.self) { model in
                        Button {
                            selectedModel = model
                            if title.isEmpty || title.contains(" - ") {
                                let studentName = selectedStudents.first?.firstName ?? ""
                                title = "\(model.rawValue)\(studentName.isEmpty ? "" : " - \(studentName)")"
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: model.iconName)
                                    .font(.title2)
                                Text(model.shortName)
                                    .font(.caption2)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(
                                selectedModel == model ? model.color.opacity(0.2) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedModel == model ? model.color : .secondary.opacity(0.3), lineWidth: selectedModel == model ? 2 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Description").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $description)
                    .frame(minHeight: 60)
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Students Content

    @ViewBuilder
    private var studentsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(selectedStudents) { student in
                HStack {
                    Circle()
                        .fill(student.avatarColor)
                        .frame(width: 32, height: 32)
                        .overlay(Text(student.initials).font(.caption.weight(.bold)).foregroundStyle(.white))
                    VStack(alignment: .leading) {
                        Text(student.name).font(.subheadline.weight(.medium))
                        Text("Grade \(student.grade)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        withAnimation { selectedStudents.removeAll { $0.id == student.id } }
                    } label: {
                        Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            Button {
                showingStudentPicker = true
            } label: {
                HStack {
                    Spacer()
                    Label("Add Student", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.blue)
                    Spacer()
                }
                .padding(14)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .foregroundStyle(.tertiary)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Goals Content

    @ViewBuilder
    private var goalsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach($goals) { $goal in
                HStack {
                    Image(systemName: goal.status == .completed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(goal.status == .completed ? .green : .secondary)
                    VStack(alignment: .leading) {
                        Text(goal.description).font(.subheadline)
                        if let dueDate = goal.dueDate {
                            Text("Due: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Notes").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $notes)
                    .frame(minHeight: 60)
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Approval Content

    @ViewBuilder
    private var approvalContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            let status = existingPlan?.approvalStatus ?? .draft
            HStack {
                Text("Status:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(status.rawValue.capitalized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(approvalBadgeColor)
            }

            if let history = existingPlan?.approvalHistory, !history.isEmpty {
                Text("HISTORY")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                ForEach(Array(history.enumerated()), id: \.offset) { _, entry in
                    HStack {
                        Text(entry.action.rawValue.capitalized)
                            .font(.caption.weight(.medium))
                        Spacer()
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }

            if status == .draft, isEditing {
                Button {
                    // Submit for approval
                } label: {
                    Text("Submit for Approval")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var approvalBadgeColor: Color {
        switch existingPlan?.approvalStatus ?? .draft {
        case .draft: .gray
        case .pendingApproval: .orange
        case .approved: .green
        case .rejected: .red
        case .changesRequested: .yellow
        }
    }

    // MARK: - Data Operations

    private func populateFromExistingPlan() {
        if let student = preselectedStudent {
            selectedStudents = [student]
            studentsExpanded = false
        }
        guard let plan = existingPlan else { return }
        title = plan.title
        description = plan.description ?? ""
        selectedModel = plan.model
        startDate = plan.startDate
        endDate = plan.endDate
        selectedStudents = plan.students
        linkedInterests = plan.interests
        linkedResources = plan.resources
        goals = plan.goals
        notes = plan.notes
    }

    private func savePlan() async {
        isSaving = true
        defer { isSaving = false }

        do {
            guard let uid = FirebaseManager.shared.currentUserUID else {
                throw NSError(domain: "TMI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
            }

            if isEditing, var plan = existingPlan {
                plan.title = title
                plan.description = description
                plan.model = selectedModel
                plan.students = selectedStudents
                plan.interests = linkedInterests
                plan.resources = linkedResources
                plan.goals = goals
                plan.notes = notes
                plan.lastUpdated = Date()
                try await TMIPlanService.shared.updatePlan(plan)
            } else {
                let plan = TMIPlan(
                    title: title,
                    description: description,
                    students: selectedStudents,
                    model: selectedModel,
                    interests: linkedInterests,
                    startDate: startDate,
                    endDate: endDate,
                    creationDate: Date(),
                    lastUpdated: Date(),
                    goals: goals,
                    progress: 0.0,
                    notes: notes,
                    createdBy: uid,
                    resources: linkedResources
                )
                try await TMIPlanService.shared.createPlan(plan)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
```

**Important implementation notes for the executing agent:**
- Check `TMIPlanModel` for `iconName`, `shortName`, and `color` computed properties — these may not exist yet. If not, add them as an extension on `TMIPlanModel`. Reference the existing color mapping in `NewTMIPlanView.swift`.
- Check `TMIPlan` initializer signature — it may require additional fields like `approvalStatus`, `approvalHistory`, `createdBy`, etc.
- Check `TMIPlanService.shared.createPlan()` and `updatePlan()` method signatures.
- The student picker sheet (`showingStudentPicker`) needs implementation. Use the existing `StudentListView` as a selection sheet, or create a simple picker. This is deferred to a follow-up step.

- [ ] **Step 2: Verify it builds**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`

Fix compilation errors from model API mismatches.

- [ ] **Step 3: Commit**

```bash
git add TMI/Views/TMIPlans/TMIPlanEditorView.swift
git commit -m "feat: add unified TMIPlanEditorView with 8 accordion sections for create/edit"
```

---

## Task 8: Modify DashboardView to Absorb District Content

**Files:**
- Modify: `TMI/Views/Dashboard/DashboardView.swift`
- Reference: `TMI/Views/District/DistrictDashboardView.swift`

- [ ] **Step 1: Read current DashboardView and DistrictDashboardView**

Read both files to understand current structure. The goal is to add district sections at the bottom of DashboardView, gated by a role check for `superintendent` and `districtAdmin`.

- [ ] **Step 2: Add district sections to DashboardView**

At the bottom of the existing DashboardView body, add:

```swift
// Inside DashboardView body, after existing content:

// District sections (admin/superintendent only)
if let role = authStateModel.currentUser?.role,
   role == .superintendent || role == .districtAdmin || role == .administrator || role == .admin {
    Divider()
        .padding(.vertical, 16)

    // Reuse existing district components
    DistrictKPICardsView(stateModel: districtStateModel)
    StudentsNeedingAttentionList(stateModel: districtStateModel)
    DistrictInsightsSummary(stateModel: districtStateModel)
}
```

**Important:** The exact component names and props must match the existing district components. Read `DistrictDashboardView.swift` to identify the child components it uses, then embed those same components in DashboardView. You may need to add `@Environment(\.districtStateModel)` or instantiate it locally.

- [ ] **Step 3: Verify it builds**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`

- [ ] **Step 4: Commit**

```bash
git add TMI/Views/Dashboard/DashboardView.swift
git commit -m "feat: absorb district dashboard content into main Dashboard for admin roles"
```

---

## Task 9: Update Navigation — StudentListView

**Files:**
- Modify: `TMI/Views/Students/StudentListView.swift`

- [ ] **Step 1: Read current StudentListView**

Identify where it navigates to `AddStudentView` (sheet for creation) and `EditStudentView` / `StudentDetailView` (navigation for editing).

- [ ] **Step 2: Replace AddStudentView sheet with StudentProfileView**

Find the `.sheet` presentation for adding students and replace:

```swift
// Before:
.sheet(isPresented: $showingAddStudent) {
    AddStudentView(...)
}

// After:
.sheet(isPresented: $showingAddStudent) {
    StudentProfileView()
}
```

- [ ] **Step 3: Replace edit navigation with StudentProfileView**

Find NavigationLink or sheet presentations for editing and replace:

```swift
// Before:
EditStudentView(student: student)

// After:
StudentProfileView(existingStudent: student)
```

- [ ] **Step 4: Verify it builds**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`

- [ ] **Step 5: Commit**

```bash
git add TMI/Views/Students/StudentListView.swift
git commit -m "refactor: wire StudentListView to unified StudentProfileView"
```

---

## Task 10: Update Navigation — TMIPlanListView

**Files:**
- Modify: `TMI/Views/TMIPlans/TMIPlanListView.swift`

- [ ] **Step 1: Read current TMIPlanListView**

Identify where it navigates to `NewTMIPlanView` (creation) and `EditTMIPlanView` / `TMIPlanDetailView` (editing).

- [ ] **Step 2: Replace NewTMIPlanView with TMIPlanEditorView**

```swift
// Before:
.sheet(isPresented: $showingCreatePlan) {
    NewTMIPlanView(student: student)
}

// After:
.sheet(isPresented: $showingCreatePlan) {
    TMIPlanEditorView(preselectedStudent: student)
}
```

- [ ] **Step 3: Replace edit navigation with TMIPlanEditorView**

```swift
// Before:
EditTMIPlanView(plan: plan)

// After:
TMIPlanEditorView(existingPlan: plan)
```

- [ ] **Step 4: Verify it builds**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`

- [ ] **Step 5: Commit**

```bash
git add TMI/Views/TMIPlans/TMIPlanListView.swift
git commit -m "refactor: wire TMIPlanListView to unified TMIPlanEditorView"
```

---

## Task 11: Update MainTabView — Remove Old Tabs

**Files:**
- Modify: `TMI/Views/MainTabView.swift`

- [ ] **Step 1: Read current MainTabView.swift**

Identify the full `Tab` enum and all `TabView` entries.

- [ ] **Step 2: Remove tab enum cases**

Remove these cases from the `Tab` enum:
- `districtDashboard`
- `forms`
- `careerExplorer`
- `interests`
- `resources`

Keep: `dashboard`, `students`, `tmiPlans`, `settings`

- [ ] **Step 3: Remove corresponding TabView entries**

Remove the `Tab.ForEach` or individual tab views for the removed cases. Keep only:
- Dashboard tab
- Students tab
- TMI Plans tab
- Settings tab

- [ ] **Step 4: Update `isAccessible(for:)` method**

Remove role-access checks for the deleted tabs. Simplify the remaining 4 tabs' access rules.

- [ ] **Step 5: Remove related @State and @Environment properties**

Remove any state variables that only served the deleted tabs (e.g., `showingDistrictDashboard`).

- [ ] **Step 6: Verify it builds**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`

- [ ] **Step 7: Commit**

```bash
git add TMI/Views/MainTabView.swift
git commit -m "refactor: collapse MainTabView from 9 tabs to 4 (Dashboard, Students, TMI Plans, Settings)"
```

---

## Task 12: Delete Deprecated Files

**Files to delete:**
- `TMI/Views/Students/AddStudentView.swift`
- `TMI/Views/Students/EditStudentView.swift`
- `TMI/Views/TMIPlans/NewTMIPlanView.swift`
- `TMI/Views/TMIPlan/EditTMIPlanView.swift`
- `TMI/Views/TMIPlans/CreateTMIPlanView.swift`

- [ ] **Step 1: Search for remaining references to deleted views**

Run:
```bash
grep -r "AddStudentView\|EditStudentView\|NewTMIPlanView\|EditTMIPlanView\|CreateTMIPlanView" TMI/ --include="*.swift" -l
```

Any files still referencing these views must be updated before deletion. Fix references by replacing with `StudentProfileView` or `TMIPlanEditorView` as appropriate.

- [ ] **Step 2: Delete the files**

```bash
git rm TMI/Views/Students/AddStudentView.swift
git rm TMI/Views/Students/EditStudentView.swift
git rm TMI/Views/TMIPlans/NewTMIPlanView.swift
git rm TMI/Views/TMIPlan/EditTMIPlanView.swift
git rm TMI/Views/TMIPlans/CreateTMIPlanView.swift
```

- [ ] **Step 3: Remove files from Xcode project**

Open `TMI.xcodeproj/project.pbxproj` and remove file references for the deleted files. Alternatively, if using file system-based project organization (no explicit file references), this step may not be needed.

- [ ] **Step 4: Verify it builds**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove deprecated Add/Edit/New/Create views replaced by unified profiles"
```

---

## Task 13: Extract Shared Helper Views

**Files:**
- Create: `TMI/Views/Components/SharedSectionHelpers.swift`

During Tasks 2-6, several helper views were declared as `private` in their respective files: `FlowLayout`, `InterestChip`, `CareerCard`, `CareerRecommendationRow`, `ResourceRow`. Both Student and Plan sections need these.

- [ ] **Step 1: Create `SharedSectionHelpers.swift`**

Move the following from their current locations into a shared file:
- `FlowLayout` (from `StudentInterestsSection.swift`)
- `InterestChip` (from `StudentInterestsSection.swift`)
- `CareerCard` (from `StudentCareersSection.swift`)
- `CareerRecommendationRow` (from `StudentCareersSection.swift`)
- `ResourceRow` (from `StudentResourcesSection.swift`)

Remove `private` access control and make them `internal` (default).

- [ ] **Step 2: Remove duplicated private declarations from section files**

Remove the `private` copies from:
- `StudentInterestsSection.swift`
- `StudentCareersSection.swift`
- `StudentResourcesSection.swift`
- `PlanInterestsSection.swift`
- `PlanCareersSection.swift`
- `PlanResourcesSection.swift`

- [ ] **Step 3: Verify it builds**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`

- [ ] **Step 4: Commit**

```bash
git add TMI/Views/Components/SharedSectionHelpers.swift
git add TMI/Views/Students/Sections/
git add TMI/Views/TMIPlans/Sections/
git commit -m "refactor: extract shared section helpers (FlowLayout, chips, cards) to shared file"
```

---

## Task 14: Final Verification

- [ ] **Step 1: Full build**

```bash
xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -20
```

- [ ] **Step 2: Search for dead references**

```bash
grep -r "InterestsAndHobbiesView\|ResourcesView\|CareerExplorerView\|FormsAndSurveysView\|DistrictDashboardView" TMI/ --include="*.swift" -l
```

Any hits in MainTabView or navigation code indicate incomplete migration. Fix as needed. Hits in the actual view files themselves are expected (they still exist for sheet usage like CareerExplorerView).

- [ ] **Step 3: Verify tab count**

Read `MainTabView.swift` and confirm exactly 4 cases in the `Tab` enum: `dashboard`, `students`, `tmiPlans`, `settings`.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve remaining references from UI consolidation"
```
