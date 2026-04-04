# Teacher-District MVP Focus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refocus the app around a faster teacher intervention workflow with a lightweight district evidence layer for pilot MVP use.

**Architecture:** Keep the existing SwiftUI and `@Observable` structure, but narrow the active product flow around five seams: staff navigation, teacher dashboard, student detail, plan creation, and district summary. Prefer folding existing features into the teacher workflow over building new top-level modules, and use `Testing`-based unit tests plus targeted `xcodebuild` runs to verify behavior incrementally.

**Tech Stack:** Swift 6, SwiftUI, Observation (`@Observable`), Firebase-backed services, Swift Testing, Xcodebuild

---

## File Structure

### Primary files to modify

- `TMI/Views/MainTabView.swift`
  Responsibility: MVP tab reduction and role-based primary navigation.
- `TMI/Views/Dashboard/DashboardView.swift`
  Responsibility: teacher-first dashboard actions and next-step emphasis.
- `TMI/StateModels/StudentDetailStateModel.swift`
  Responsibility: central student-detail data loading and engagement summary inputs.
- `TMI/Views/Students/StudentDetailView.swift`
  Responsibility: student command center and action-first workflow.
- `TMI/Views/TMIPlans/TMIPlanEditorView.swift`
  Responsibility: faster plan creation with templates/defaults and fewer required decisions.
- `TMI/ViewModels/DistrictDashboardViewModel.swift`
  Responsibility: district adoption and engagement rollups.
- `TMI/Views/District/DistrictDashboardView.swift`
  Responsibility: simplified district evidence presentation.

### New files to create

- `TMITests/StateModels/StudentDetailStateModelTests.swift`
  Responsibility: verify student command-center summary and quick-action derivation.
- `TMITests/StateModels/DashboardStateModelTests.swift`
  Responsibility: verify teacher dashboard next-best-action prioritization.
- `TMITests/ViewModels/DistrictDashboardViewModelTests.swift`
  Responsibility: verify district KPI reduction and evidence-oriented summaries.
- `TMITests/Views/MainTabViewTests.swift`
  Responsibility: verify role-based tab availability for MVP navigation.

### Existing tests to extend if useful

- `TMITests/StateModels/StudentContextStateModelTests.swift`
- `TMITests/Models/RecentActivityTests.swift`

---

### Task 1: Reduce MVP Navigation to Core Teacher and District Surfaces

**Files:**
- Modify: `TMI/Views/MainTabView.swift`
- Test: `TMITests/Views/MainTabViewTests.swift`

- [ ] **Step 1: Write the failing tab-availability tests**

```swift
import Testing
@testable import TMI

@Suite("Main Tab View")
struct MainTabViewTests {
    @Test("Teacher sees only the MVP teacher tabs")
    func teacherTabs() {
        let tabs = MainTabView.Tab.mvpTabs(for: .teacher)
        #expect(tabs == [.dashboard, .students, .tmiPlans])
    }

    @Test("District admin sees district evidence tab in addition to teacher workflow")
    func districtAdminTabs() {
        let tabs = MainTabView.Tab.mvpTabs(for: .districtAdmin)
        #expect(tabs == [.dashboard, .students, .tmiPlans, .district])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter MainTabViewTests`
Expected: FAIL with errors indicating `district` and `mvpTabs(for:)` do not exist yet.

- [ ] **Step 3: Add an explicit MVP tab model in `MainTabView`**

```swift
enum Tab: String, CaseIterable, Identifiable {
    case dashboard
    case students
    case tmiPlans
    case district

    static func mvpTabs(for role: UserRole?) -> [Tab] {
        switch role {
        case .districtAdmin, .superintendent:
            return [.dashboard, .students, .tmiPlans, .district]
        case .teacher, .counselor, .administrator, .admin, .socialWorker:
            return [.dashboard, .students, .tmiPlans]
        default:
            return [.dashboard]
        }
    }
}
```

- [ ] **Step 4: Route the new district tab to `DistrictDashboardView` and remove non-MVP primary surfaces**

```swift
var availableTabs: [Tab] {
    Tab.mvpTabs(for: authStateModel.currentUser?.role)
}

@ViewBuilder
func destinationView(for tab: Tab) -> some View {
    switch tab {
    case .dashboard:
        DashboardView()
    case .students:
        StudentListView()
    case .tmiPlans:
        TMIPlanListView()
    case .district:
        DistrictDashboardView()
    }
}
```

- [ ] **Step 5: Re-run the tests**

Run: `swift test --filter MainTabViewTests`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add TMI/Views/MainTabView.swift TMITests/Views/MainTabViewTests.swift
git commit -m "feat: narrow main navigation for MVP workflow"
```

### Task 2: Make the Teacher Dashboard an Action Board Instead of a Broad Metrics Page

**Files:**
- Modify: `TMI/Views/Dashboard/DashboardView.swift`
- Test: `TMITests/StateModels/DashboardStateModelTests.swift`

- [ ] **Step 1: Write failing tests for next-best-action prioritization**

```swift
import Foundation
import Testing
@testable import TMI

@Suite("Dashboard State Model")
struct DashboardStateModelTests {
    @Test("Teacher prioritizes creating a plan when students have no plans")
    func teacherCreatePlanPriority() {
        let student = Student.sampleStudents[0]
        let action = DashboardStateModel.determineNextBestAction(
            role: .teacher,
            students: [student],
            plans: [],
            surveysCompleted: 1
        )

        #expect(action?.type == .createPlan)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter DashboardStateModelTests`
Expected: FAIL because `determineNextBestAction` does not exist yet.

- [ ] **Step 3: Extract the action-priority logic into a testable helper**

```swift
extension DashboardStateModel {
    static func determineNextBestAction(
        role: UserRole?,
        students: [Student],
        plans: [TMIPlan],
        surveysCompleted: Int
    ) -> NextBestAction? {
        let studentsWithoutPlans = students.filter { student in
            plans.contains(where: { plan in
                plan.students.contains(where: { $0.id == student.id })
            }) == false
        }

        if let firstStudent = studentsWithoutPlans.first, role == .teacher {
            return NextBestAction(
                id: "create_plan_\(firstStudent.id ?? "unknown")",
                type: .createPlan,
                title: "Create First Intervention",
                description: "Start a plan for \(firstStudent.name) using the guided workflow",
                priority: .high,
                targetStudentId: firstStudent.id,
                targetPlanId: nil
            )
        }

        return nil
    }
}
```

- [ ] **Step 4: Update `fetchWithRole(_:)` to use the helper and simplify the teacher dashboard sections**

```swift
let nextAction = Self.determineNextBestAction(
    role: userRole,
    students: students,
    plans: plans,
    surveysCompleted: surveysCompleted
)
```

```swift
if let action = data.nextBestAction {
    PriorityActionButton(action: action)
}

TeacherWorkflowSummaryCard(
    studentsNeedingPlans: data.totalStudents - data.plansAligned,
    activePlans: data.activeTMIPlans,
    surveysCompleted: data.surveysCompleted
)
```

- [ ] **Step 5: Re-run the tests**

Run: `swift test --filter DashboardStateModelTests`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add TMI/Views/Dashboard/DashboardView.swift TMITests/StateModels/DashboardStateModelTests.swift
git commit -m "feat: focus dashboard on teacher actions"
```

### Task 3: Turn Student Detail Into the Teacher Command Center

**Files:**
- Modify: `TMI/StateModels/StudentDetailStateModel.swift`
- Modify: `TMI/Views/Students/StudentDetailView.swift`
- Test: `TMITests/StateModels/StudentDetailStateModelTests.swift`

- [ ] **Step 1: Write failing tests for student summary and follow-up status**

```swift
import Foundation
import Testing
@testable import TMI

@Suite("Student Detail State Model")
struct StudentDetailStateModelTests {
    @Test("Student summary exposes plan and engagement counts for command center UI")
    func summaryBuildsCounts() {
        let summary = StudentDetailStateModel.Summary(
            activePlanCount: 2,
            assignedNextStepCount: 1,
            needsFollowUp: true
        )

        #expect(summary.activePlanCount == 2)
        #expect(summary.assignedNextStepCount == 1)
        #expect(summary.needsFollowUp)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter StudentDetailStateModelTests`
Expected: FAIL because `Summary` does not exist yet.

- [ ] **Step 3: Add a summary model and derive command-center state in `StudentDetailStateModel`**

```swift
extension StudentDetailStateModel {
    struct Summary: Equatable, Sendable {
        var activePlanCount: Int
        var assignedNextStepCount: Int
        var needsFollowUp: Bool
    }
}

var summary: Summary {
    Summary(
        activePlanCount: tmiPlans.count,
        assignedNextStepCount: tmiPlans.reduce(into: 0) { count, plan in
            count += plan.linkedResources.count
        },
        needsFollowUp: tmiPlans.contains(where: { $0.approvalStatus == .pendingApproval || $0.approvalStatus == .draft })
    )
}
```

- [ ] **Step 4: Rebuild `StudentDetailView` section order around action and follow-up**

```swift
VStack(spacing: TMISpacing.lg) {
    heroSection(student: student)
    commandCenterSection(student: student, summary: stateModel.summary)
    quickActionsRow(student: student)
    tmiPlansSection(student: student)
    interestsSection(student: student)
    savedCareersSection(student: student)
    meetingsSection(student: student)
}
```

```swift
private func commandCenterSection(student: Student, summary: StudentDetailStateModel.Summary) -> some View {
    TMIInfoCard(title: "Next Best Move") {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text(summary.needsFollowUp ? "Follow up on current intervention" : "Create or refine an intervention")
            Text("Active plans: \(summary.activePlanCount)")
            Text("Assigned next steps: \(summary.assignedNextStepCount)")
        }
    }
}
```

- [ ] **Step 5: Re-run the tests**

Run: `swift test --filter StudentDetailStateModelTests`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add TMI/StateModels/StudentDetailStateModel.swift TMI/Views/Students/StudentDetailView.swift TMITests/StateModels/StudentDetailStateModelTests.swift
git commit -m "feat: make student detail the teacher command center"
```

### Task 4: Simplify Plan Creation Around Defaults, Templates, and a Clear Student Next Step

**Files:**
- Modify: `TMI/Views/TMIPlans/TMIPlanEditorView.swift`
- Modify: `TMI/Views/TMIPlans/Sections/PlanResourcesSection.swift`
- Modify: `TMI/Views/TMIPlans/Sections/PlanInterestsSection.swift`
- Test: `TMITests/Models/RecentActivityTests.swift`

- [ ] **Step 1: Add a failing test for deterministic default plan-title behavior**

```swift
import Testing
@testable import TMI

extension RecentActivityTests {
    @Test("Default guided plan title uses model and student name")
    func guidedPlanTitle() {
        let student = Student.sampleStudents[0]
        let title = TMIPlanEditorView.defaultTitle(
            selectedModel: .chaseYourSpace,
            selectedStudents: [student]
        )

        #expect(title.contains(student.name))
        #expect(title.contains(TMIPlanModel.chaseYourSpace.rawValue))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter guidedPlanTitle`
Expected: FAIL because `defaultTitle(selectedModel:selectedStudents:)` does not exist yet.

- [ ] **Step 3: Extract defaulting logic and collapse editor sections to the MVP sequence**

```swift
extension TMIPlanEditorView {
    static func defaultTitle(selectedModel: TMIPlanModel, selectedStudents: [Student]) -> String {
        let studentName = selectedStudents.first?.name ?? ""
        return studentName.isEmpty ? selectedModel.rawValue : "\(selectedModel.rawValue) - \(studentName)"
    }
}

private var autoGeneratedTitle: String {
    Self.defaultTitle(selectedModel: selectedModel, selectedStudents: selectedStudents)
}
```

```swift
VStack(spacing: TMISpacing.sm) {
    sectionCard { planDetailsAccordion }
    sectionCard { studentsAccordion }
    sectionCard { interestsAccordion }
    sectionCard { resourcesAccordion }
    sectionCard { goalsAccordion }
}
```

- [ ] **Step 4: Add a dedicated "Student Next Step" field near save and keep advanced sections behind progressive disclosure**

```swift
@State private var studentNextStep: String = ""

fieldGroup(label: "Student Next Step") {
    TextField(
        "",
        text: $studentNextStep,
        prompt: Text("Example: Complete the robotics interest reflection before Friday")
    )
}
```

```swift
guard isValid, studentNextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
    errorMessage = "Add a clear next step before saving."
    return
}
```

- [ ] **Step 5: Re-run the test**

Run: `swift test --filter guidedPlanTitle`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add TMI/Views/TMIPlans/TMIPlanEditorView.swift TMI/Views/TMIPlans/Sections/PlanResourcesSection.swift TMI/Views/TMIPlans/Sections/PlanInterestsSection.swift TMITests/Models/RecentActivityTests.swift
git commit -m "feat: streamline plan creation for MVP"
```

### Task 5: Refocus the District Dashboard on Adoption and Engagement Evidence

**Files:**
- Modify: `TMI/ViewModels/DistrictDashboardViewModel.swift`
- Modify: `TMI/Views/District/DistrictDashboardView.swift`
- Test: `TMITests/ViewModels/DistrictDashboardViewModelTests.swift`

- [ ] **Step 1: Write failing tests for evidence-oriented district summaries**

```swift
import Testing
@testable import TMI

@Suite("District Dashboard View Model")
struct DistrictDashboardViewModelTests {
    @Test("Priority KPI titles reflect adoption and engagement evidence")
    func priorityKPIs() {
        let titles = DistrictDashboardViewModel.priorityKPITitles
        #expect(titles == ["Active Teachers", "Active Plans", "Engagement Rate", "Needs Attention"])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter DistrictDashboardViewModelTests`
Expected: FAIL because `priorityKPITitles` does not exist yet.

- [ ] **Step 3: Add a small district-summary API oriented around pilot proof**

```swift
extension DistrictDashboardViewModel {
    static let priorityKPITitles = [
        "Active Teachers",
        "Active Plans",
        "Engagement Rate",
        "Needs Attention"
    ]

    var activeTeacherCount: Int {
        max(1, schoolMetrics.reduce(0) { $0 + $1.activeStaffCount })
    }
}
```

- [ ] **Step 4: Replace low-signal KPI rows and keep exports/filters secondary**

```swift
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
    DistrictKPICard(title: "Active Teachers", value: "\(viewModel.activeTeacherCount)", icon: "person.2.fill", color: .blue)
    DistrictKPICard(title: "Active Plans", value: "\(viewModel.metrics.activePlansCount)", icon: "doc.text.fill", color: .orange)
    DistrictKPICard(title: "Engagement Rate", value: viewModel.metrics.engagementPercentage, icon: "chart.line.uptrend.xyaxis", color: .green)
    DistrictKPICard(title: "Needs Attention", value: "\(viewModel.metrics.flaggedStudentsCount)", icon: "exclamationmark.triangle.fill", color: .red)
}
```

```swift
Section("Pilot Readout") {
    Text("Teachers using TMI today: \(viewModel.activeTeacherCount)")
    Text("Students with active interventions: \(viewModel.metrics.activePlansCount)")
}
```

- [ ] **Step 5: Re-run the tests**

Run: `swift test --filter DistrictDashboardViewModelTests`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add TMI/ViewModels/DistrictDashboardViewModel.swift TMI/Views/District/DistrictDashboardView.swift TMITests/ViewModels/DistrictDashboardViewModelTests.swift
git commit -m "feat: focus district dashboard on pilot evidence"
```

### Task 6: Verify the End-to-End MVP Story and Remove Demo Dead Ends

**Files:**
- Modify: `TMI/Views/Dashboard/DashboardView.swift`
- Modify: `TMI/Views/Students/StudentDetailView.swift`
- Modify: `TMI/Views/District/DistrictDashboardView.swift`
- Test: `TMITests/Modern/ModernComponentTests.swift`

- [ ] **Step 1: Add a failing smoke test for the MVP empty-state language**

```swift
import Testing
@testable import TMI

extension ModernComponentTests {
    @Test("MVP empty states guide the user to the core workflow")
    func mvpEmptyStates() {
        #expect(TMIEmptyState.copyForStudents == "Add your first student to start building interventions.")
        #expect(TMIEmptyState.copyForPlans == "Create a guided plan with one clear student next step.")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter mvpEmptyStates`
Expected: FAIL because the `TMIEmptyState` copy constants do not exist yet.

- [ ] **Step 3: Add centralized MVP copy and replace dead-end empty states**

```swift
enum TMIEmptyState {
    static let copyForStudents = "Add your first student to start building interventions."
    static let copyForPlans = "Create a guided plan with one clear student next step."
    static let copyForDistrict = "Teacher activity will appear here once schools start creating plans."
}
```

```swift
TMIEmptyView(
    title: "No Students Yet",
    message: TMIEmptyState.copyForStudents,
    actionTitle: "Add Student"
)
```

- [ ] **Step 4: Run targeted app tests and a focused simulator build**

Run: `swift test --filter mvpEmptyStates`
Expected: PASS

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | rg -n 'error:|warning:|BUILD SUCCEEDED|BUILD FAILED'`
Expected: `BUILD SUCCEEDED` and no new `error:` lines tied to the modified files.

- [ ] **Step 5: Commit**

```bash
git add TMI/Views/Dashboard/DashboardView.swift TMI/Views/Students/StudentDetailView.swift TMI/Views/District/DistrictDashboardView.swift TMITests/Modern/ModernComponentTests.swift
git commit -m "chore: polish MVP empty states and verify core flow"
```

## Spec Coverage Check

- Navigation reduction is covered by Task 1.
- Teacher dashboard and faster intervention entry are covered by Task 2.
- Student profile as operational hub is covered by Task 3.
- Faster plan creation and explicit student next step are covered by Task 4.
- District evidence-layer simplification is covered by Task 5.
- Demoability, empty states, and final verification are covered by Task 6.

## Placeholder Scan

- No `TODO`, `TBD`, or deferred placeholders remain in the plan body.
- Each task contains exact file paths, explicit commands, and concrete code examples.
- Verification commands are listed alongside expected outcomes.

## Type Consistency Check

- `MainTabView.Tab.mvpTabs(for:)` is introduced once and reused consistently.
- `DashboardStateModel.determineNextBestAction(...)` is named consistently across test and implementation steps.
- `StudentDetailStateModel.Summary` is introduced before use in `StudentDetailView`.
- `DistrictDashboardViewModel.priorityKPITitles` is introduced before use in the district tests.

