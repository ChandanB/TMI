# UI Consolidation Refactor: 9 Tabs to 4

**Date:** 2026-03-31
**Approach:** In-Place Refactor (Approach A)
**Scope:** Collapse Career Explorer, Interests & Hobbies, Resources, Forms, and District Dashboard into the three primary flows (Dashboard, Students, TMI Plans) plus Settings.

---

## 1. Target Tab Structure

### Before (9 tabs, role-filtered)
Dashboard | District Dashboard | Students | TMI Plans | Forms | Career Explorer | Interests & Hobbies | Resources | Settings

### After (4 tabs)
| Tab | Absorbs | Notes |
|-----|---------|-------|
| **Dashboard** | District Dashboard | Admin/superintendent roles see additional district sections inline |
| **Students** | Interests & Hobbies, Career Explorer, Resources | Full CRUD for all three within student profile |
| **TMI Plans** | Forms, Interests & Hobbies, Career Explorer, Resources | Full CRUD for all within plan editor |
| **Settings** | (unchanged) | User preferences, account, notifications |

---

## 2. Student Profile View

### Architecture
`AddStudentView` and `EditStudentView` are unified into a single `StudentProfileView` that serves both creation and editing. The view uses an accordion (expandable sections) pattern.

### Accordion Sections

| # | Section | Required | Content |
|---|---------|----------|---------|
| 1 | **Student Information** | Yes | First name, last name, grade, school, DOB, student ID. Expanded by default. |
| 2 | **Guardian Information** | No | Guardian name, phone, email, relationship. |
| 3 | **Interests & Hobbies** | No | Search bar + "+ New" button. Selected interests as removable chips. Suggested interests based on existing data. Full CRUD: search global library, create new interests, assign/remove. Count badge on collapsed header. |
| 4 | **Career Exploration** | No | Simplified picker with search bar. "Explore" button opens full `CareerExplorerView` as a sheet for deep discovery. Selected careers shown as cards with match info. AI recommendations section based on student's interests (match percentage). Full CRUD: search, add from recommendations, create new, remove. Count badge on collapsed header. |
| 5 | **Resources** | No | Search bar + "+ New" button. Assigned resources as cards with category badges (Article, Video, Course, etc.). Full CRUD: search global library, create new resources, assign/remove. Count badge on collapsed header. |
| 6 | **Notes & Additional Info** | No | Behavioral notes, emergency contact, free-form notes. |

### Behavior
- All sections available during both creation and editing
- Only Student Information is required to save
- Collapsed sections show count badges when items are added (e.g., "3 added")
- Each section manages its own loading/error states
- Interests, careers, and resources are persisted to the **student record** (edge collections)

### Career Explorer Sheet
When "Explore" is tapped in the Career section, the existing `CareerExplorerView` opens as a `.sheet` with the student context set. The educator can search, filter, and discover careers, then select ones to add. Selections flow back to the Career section's selected list.

---

## 3. TMI Plan Editor View

### Architecture
`NewTMIPlanView`, `EditTMIPlanView`, and `CreateTMIPlanView` are unified into a single `TMIPlanEditorView` that serves both creation and editing. Uses the same accordion pattern as the Student profile.

### Accordion Sections

| # | Section | Required | Content |
|---|---------|----------|---------|
| 1 | **Plan Details** | Yes | Plan title (auto-generated suggestion), TMI Model selector (6 models as a grid), description. Expanded by default. |
| 2 | **Students** | Yes | Student search/selector. Shows selected students as cards. Count badge. |
| 3 | **Interests & Hobbies** | No | Same UI pattern as Student profile. Can pull from selected students' existing interests. Full CRUD. Interests are **linked to the plan** (not the student). Count badge shows "X linked". |
| 4 | **Career Pathways** | No | Same UI pattern as Student profile career section. Can pull from selected students' existing careers. Full CRUD. Careers linked to the plan. |
| 5 | **Resources** | No | Same UI pattern as Student profile. Can pull from selected students' existing resources. Full CRUD. Resources linked to the plan. |
| 6 | **Forms & Surveys** | No | Previously the standalone Forms tab. Shows assigned forms with status (Pending, Complete). "+ Assign Form or Survey" action. Manage form assignments, view completion status, send reminders. Status badge (e.g., "1 pending"). |
| 7 | **Goals & Progress** | No | Goal setting, progress tracking, milestone management. |
| 8 | **Approval** | No | Approval workflow status (Draft, Submitted, Approved, Rejected). Submit for approval action. Approval history. Status badge shows current state. |

### Key Difference from Student Profile
- In the Student profile, interests/careers/resources belong to the **student**
- In the TMI Plan editor, interests/careers/resources are **linked to the plan**
- The plan editor can pre-populate from selected students' existing data as a convenience
- The plan editor includes Forms & Surveys, Goals & Progress, and Approval sections that don't exist on the student profile

---

## 4. Dashboard Changes

### Educator View (Teacher, Counselor)
No structural changes. The existing Dashboard content remains:
- Welcome header with role context
- Key metrics (students, active plans, interests, pending items)
- Quick action buttons (Add Student, New Plan, View Reports)
- Recent activity feed
- Role-specific sections (counselor caseload, teacher classroom data)

### Admin/Superintendent View
The existing District Dashboard content is absorbed as additional sections appended below the standard educator content:
- **District Overview** metrics row (schools, total students, active plans, staff)
- **By School** breakdown with per-school student/plan counts and engagement bars
- **Engagement Trend** chart (district-wide over time)
- Any other existing District Dashboard components

### Implementation
- `DistrictDashboardView` content moves into `DashboardView` behind a role check
- Existing district components (`DistrictInsightsSummary`, `DistrictKPICard`, `StudentsNeedingAttentionList`, etc.) are reused as-is within the Dashboard
- `MainTabView` removes the District Dashboard tab entry

---

## 5. Shared Accordion Component

To avoid duplicating the expandable section pattern across Student and Plan views, extract a reusable component:

```swift
struct AccordionSection<Content: View>: View {
    let icon: String          // SF Symbol name
    let title: String
    let badge: String?        // e.g., "3 added", "Draft"
    let badgeColor: Color
    let isRequired: Bool
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content
}
```

This component handles:
- Expand/collapse animation
- Header layout with icon, title, badge, required tag, chevron
- Consistent styling across all accordion sections

---

## 6. Files to Modify

### MainTabView.swift
- Remove tab entries: District Dashboard, Career Explorer, Interests & Hobbies, Resources, Forms
- Keep: Dashboard, Students, TMI Plans, Settings
- Update role-based filtering logic

### Student Flow
- **Merge** `AddStudentView` + `EditStudentView` → unified `StudentProfileView`
- **Modify** to add accordion sections for Interests, Careers, Resources, Notes
- Create section child views:
  - `StudentInterestsSection.swift` — inline interest management
  - `StudentCareersSection.swift` — simplified picker + explore sheet trigger
  - `StudentResourcesSection.swift` — inline resource management

### TMI Plan Flow
- **Merge** `NewTMIPlanView` + `EditTMIPlanView` + `CreateTMIPlanView` → unified `TMIPlanEditorView`
- **Modify** to add accordion sections for all 8 sections
- Create section child views:
  - `PlanInterestsSection.swift` — interest management linked to plan
  - `PlanCareersSection.swift` — career pathway management
  - `PlanResourcesSection.swift` — resource management
  - `PlanFormsSection.swift` — forms & surveys (absorbs Forms tab content)

### Dashboard
- **Modify** `DashboardView.swift` to include district content for admin roles
- Reuse existing district components in-place

### Shared Components
- **Create** `AccordionSection.swift` — reusable expandable section component

## 7. Files to Delete (after migration)

These standalone tab views and their dedicated state models become unused once their content is absorbed:

- `TMI/Views/Career Explorer/CareerExplorerView.swift` — content embedded in Student/Plan sections (but kept as a sheet for deep exploration)
- `TMI/Views/InterestsAndHobbies/InterestsAndHobbiesView.swift` — content embedded in Student/Plan sections
- `TMI/Views/Resources/ResourcesView.swift` — content embedded in Student/Plan sections
- `TMI/Views/Forms/` — form management content moves into TMI Plan editor
- `TMI/Views/District/DistrictDashboardView.swift` — content moves into main Dashboard (keep child components)
- `AddStudentView.swift` — replaced by unified `StudentProfileView`
- `EditStudentView.swift` — replaced by unified `StudentProfileView`
- `NewTMIPlanView.swift` — replaced by unified `TMIPlanEditorView`
- `EditTMIPlanView.swift` — replaced by unified `TMIPlanEditorView`
- `CreateTMIPlanView.swift` — replaced by unified `TMIPlanEditorView`

**Note:** `CareerExplorerView` may be kept as-is for the "Explore" sheet. Evaluate during implementation whether it can be used directly or needs adaptation for sheet presentation.

## 8. State Model Changes

### Retained (no changes)
- `StudentContextStateModel` — continues as the source of truth for student context
- `DashboardStateModel` — may need minor additions for district data
- `CareerExplorerStateModel` — used by the career explorer sheet

### Modified
- `StudentListStateModel` — may need to support the unified profile view
- `TMIPlanListStateModel` — may need to support the unified editor view
- `AddStudentStateModel` — evolves into the state backing for `StudentProfileView`

### Potentially Removable
- `InterestsAndHobbiesStateModel` — if interest management is fully handled by section-level state
- `ResourcesStateModel` — if resource management is fully handled by section-level state

Evaluate during implementation whether these state models are still needed or if their logic is better housed in the section child views.

---

## 9. Data Flow

```
MainTabView (4 tabs)
├── DashboardView
│   ├── Standard educator content (unchanged)
│   └── District sections (admin only, from DistrictDashboardView)
│
├── StudentListView → StudentProfileView (accordion)
│   ├── Student Info section
│   ├── Guardian Info section
│   ├── Interests section (StudentInterestsSection)
│   ├── Careers section (StudentCareersSection)
│   │   └── "Explore" → CareerExplorerView (sheet)
│   ├── Resources section (StudentResourcesSection)
│   └── Notes section
│
├── TMIPlanListView → TMIPlanEditorView (accordion)
│   ├── Plan Details section
│   ├── Students section
│   ├── Interests section (PlanInterestsSection)
│   ├── Careers section (PlanCareersSection)
│   │   └── "Explore" → CareerExplorerView (sheet)
│   ├── Resources section (PlanResourcesSection)
│   ├── Forms & Surveys section (PlanFormsSection)
│   ├── Goals & Progress section
│   └── Approval section
│
└── SettingsView (unchanged)
```

---

## 10. Migration Strategy

1. **Create shared `AccordionSection` component** first — this unblocks all other work
2. **Build `StudentProfileView`** with all accordion sections, replacing Add/Edit flows
3. **Build `TMIPlanEditorView`** with all accordion sections, replacing New/Edit/Create flows
4. **Modify `DashboardView`** to absorb district content
5. **Update `MainTabView`** to remove old tabs (this is the "switch-over" moment)
6. **Delete deprecated files** once everything is verified working

---

## 11. Out of Scope

- No changes to the data models (`Student`, `TMIPlan`, `Interest`, `Career`, `Resource`)
- No changes to Firebase services or data architecture
- No changes to authentication or RBAC
- No changes to the Settings tab
