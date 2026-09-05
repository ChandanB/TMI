# TMI App Architecture Summary
## How the App Works End-to-End Today

**Last Updated**: 2025-01-27  
**Purpose**: One-page reference for current architecture, data flow, and refactor roadmap

---

## 1. Identity & Routing

### App Entry Flow
```
App Launch → ContentView
  ├─ Unauthenticated → AuthenticationView
  └─ Authenticated
      ├─ Student Role → StudentMainView (simplified experience)
      └─ Staff Role → MainTabView (full experience)
```

### Role-Based Access
- **AuthStateModel** owns: `currentUser`, `userRole`, `districtId`, auth session lifecycle
- **MainTabView.Tab.allowedRoles** gates tab visibility per role
- **StudentModeSession** manages temporary staff-initiated student sessions (UI-only restriction, not server-enforced)

### Two Student Experiences
1. **Signed-in Student**: `StudentMainView` - simplified student-facing surface
2. **Student Mode Session**: Staff-initiated from student detail → `StudentModeView(student:)` - restricted access via in-memory session

---

## 2. Navigation Architecture

### MainTabView (Canonical IA)
- **Structure**: `TabView` + `NavigationStack` per tab
- **Tab Destinations**: Mapped via `MainTabView.Tab.destinationView()`
  - Dashboard, DistrictDashboard, Students, TMIPlans, Forms, CareerExplorer, Interests, Resources, Settings
- **Student Mode Override**: When `studentModeSession.activeStudent != nil`, shows `StudentModeView` instead of full `MainTabView`

### Current Navigation Issues
- Default tab selection can mismatch role permissions
- No shared "active student/plan" context across tabs
- Mixed navigation patterns (push vs sheets vs nested flows)

---

## 3. Data & Services (Current Reality)

### Domain Services (Active)
- **Identity**: `AuthStateModel` + `FirebaseManager` + `/users/{uid}` profile
- **Students**: `StudentService` (CRUD)
- **Plans**: `TMIPlanService` (CRUD), `PlanApprovalService` (approvals)
- **Interests**: `InterestLibraryService` (global), `StudentInterestService` (edges)
- **Careers**: `CareerLibraryService` (global), `StudentCareerService` (state/bookmarks)
- **Resources**: `ResourceLibraryService` (canonical), `ResourceAssignmentService` (assignments), `PlanResourceLinkService` (plan-resource edges)
- **Meetings**: `MeetingService` (CRUD, linked by `relatedPlanId` + student IDs)
- **Recommendations**: `RecommendationsService` (generation + persistence)
- **District**: `DistrictService`, `DistrictAnalyticsService`, `ComplianceService`
- **Forms**: `FormTemplateService`, `FormAssignmentService`, `FormSubmissionService`

### Firestore Ownership (Mixed - Current Problem)
**Per-User Collections:**
- `/users/{uid}/students`
- `/users/{uid}/tmiPlans`
- `/users/{uid}/meetings`

**Top-Level Collections:**
- `/students/{studentId}/studentInterests`
- `/students/{studentId}/careerState`
- `/plans/{planId}/planResources`
- `/resourceAssignments`

**Result**: Modules can't reliably "meet in the middle" without glue code and repeated fetches.

---

## 4. Why It Feels Fragmented

1. **No shared context**: No "active student/plan" state across tabs
2. **Too many local fetches**: Non-authoritative derived state everywhere
3. **Data model edges**: Relationships (interests ↔ careers ↔ plans ↔ resources) not normalized
4. **District features**: Forced into scanning patterns instead of district-scoped collections

---

## 5. The Cohesive Product Loop (Target State)

```
Interests → Careers → TMI Plans → Goals/Meetings → Resources → Recommendations → (back to Interests/Plans)
```

**To achieve**: Define sources of truth + normalize scoping + add shared context object

---

## 6. Shared Sources of Truth (Target Architecture)

### Authoritative StateModels (Single Owners of UI State)

| StateModel | Owns |
|------------|------|
| **AuthStateModel** | `currentUser`, `userRole`, `districtId`, auth session lifecycle |
| **StudentModeSession** | `activeStudent`, session state (PIN/biometric), start/end |
| **StudentContextStateModel** (NEW) | `selectedStudentId`, `selectedPlanId`, scope (staff vs studentMode vs signed-in student) |

### Domain StateModels (Authoritative Within Domain, Context-Driven)

| StateModel | Owns |
|------------|------|
| **StudentListStateModel** | Students list, search, pagination |
| **TMIPlanListStateModel** | Plan list, filters, per-student plans |
| **InterestsAndHobbiesStateModel** | Interest library + student interest edges |
| **CareerExplorerStateModel** | Career library + student career state/bookmarks |
| **ResourcesStateModel** | Resource library + assigned resources |
| **RecommendationsStateModel** | Recommendations feed, generation + status |
| **MeetingsStateModel** | Upcoming meetings, per-student/per-plan views |
| **DistrictStateModel** | District metrics, approvals queue, compliance config |

### Service/Repository Boundaries (Single Owners of Firestore R/W)

| Service | Owns |
|---------|------|
| **StudentService** | Student CRUD |
| **StudentInterestService** | Student-interest edges CRUD + collectionGroup queries |
| **StudentCareerService** | Career state (bookmarks, explored) |
| **TMIPlanService** | Plan CRUD |
| **PlanApprovalService** | Approval mutations |
| **MeetingService** | Meeting CRUD (linked by `relatedPlanId` + student IDs) |
| **ResourceLibraryService** | Canonical library |
| **ResourceAssignmentService** | Assignment edges |
| **PlanResourceLinkService** | Plan-resource edges |
| **RecommendationsService** | Generation + persistence + status transitions |

### Caching/Listeners Policy
- **StateModels own listeners**, not Views
- Each domain state model gets:
  - `startListening(context:)` - attach Firestore snapshot listeners keyed by `districtId`, `studentId`, `planId`
  - `stopListening()` - on tab change / context change
  - Lightweight in-memory cache keyed by IDs

---

## 7. Scoping Policy (Target State)

### Global Libraries (Same for All Districts)
- `/interests`
- `/careers`
- `/resources_global` (or `/resources` with `scope = global`)

### District-Scoped Canonical Entities (Recommended)
- `/districts/{districtId}/students/{studentId}`
- `/districts/{districtId}/plans/{planId}`
- `/districts/{districtId}/resources/{resourceId}` (district library/custom)
- Subcollections: `studentInterests`, `careerState`, `planResources`, `meetings`

### User-Scoped
- `/users/{uid}` - profile + preferences + "my drafts"

### Student-Scoped
- Edges live under student doc: `interests`, `careerState`, `surveys`

### Plan-Scoped
- Edges live under plan doc: `goals`, `planResources`, `recommendationStates`

**Migration Rule**: Pick one canonical shape and temporary-adapt services to read old + new until backfilled.

---

## 8. Module Refactor Plan (18 Modules)

### Core Modules

| Module | Entry Points | Current Dependencies | Key Problems | Refactor Priority |
|--------|--------------|---------------------|--------------|-------------------|
| **Authentication** | App launch (unauthenticated) | `AuthStateModel`, Firebase Auth | Registration sets role/district inconsistently; no post-auth bootstrap | Phase 1: Split UI files; Phase 2: Normalize profile schema; Phase 3: District join code |
| **MainTabView** | Post-auth (staff) | `AuthStateModel.userRole`, `StudentModeSession` | Default tab mismatch; no shared active student context | Phase 1: Fix default tab; Phase 2: Introduce `StudentContextStateModel`; Phase 3: Workspace button + global search |
| **Dashboard** | Dashboard tab | `DashboardStateModel`, aggregates services | Repeated fetch logic; summary models drift | Phase 1: Split components; Phase 2: Pull from shared caches; Phase 3: "Next best action" card |
| **District** | District tab (districtAdmin/superintendent) | `DistrictService`, `PlanApprovalService` | Forced into scanning if students/plans per-user | Phase 1: Extract submodules; Phase 2: Normalize district-scoped collections; Phase 3: District reporting |
| **Students** | Students tab | `StudentListStateModel`, `StudentService` | Student selection doesn't persist as context | Phase 1: Add `onStudentSelected()` → sets `StudentContext`; Phase 2: Normalize storage; Phase 3: Student timeline |
| **StudentMode** | From StudentDetailView | `StudentModeSession` | UI-only restrictions (not Firestore-enforced) | Phase 1: Centralize restriction policy; Phase 2: Align signed-in student experience; Phase 3: Guided loop UX |

### Content Modules

| Module | Entry Points | Current Dependencies | Key Problems | Refactor Priority |
|--------|--------------|---------------------|--------------|-------------------|
| **TMIPlans** (list) | TMIPlans tab, student detail | `TMIPlanListStateModel`, `TMIPlanService` | Not anchored to student context | Phase 1: Make context-aware; Phase 2: Normalize to district scope; Phase 3: Plan templates |
| **TMIPlan** (detail) | Tap plan from list | `TMIPlanService`, `MeetingService`, `PlanResourceLinkService`, `RecommendationsService` | Subflows split across collections | Phase 1: Single hub layout; Phase 2: Normalize subcollections; Phase 3: Closed-loop analytics |
| **InterestsAndHobbies** | Interests tab, student detail, Student Mode | `InterestsAndHobbiesStateModel`, `InterestLibraryService`, `StudentInterestService` | Survey/interest selection uses mock structs | Phase 1: Standardize models; Phase 2: Canonicalize edge location; Phase 3: Interest evolution UX |
| **Career Explorer** | Careers tab, from interests, Student Mode | `CareerExplorerStateModel`, `CareerLibraryService`, `StudentCareerService` | Hardcoded careers; bookmark flows split | Phase 1: Remove hardcoded; Phase 2: Normalize library + indexing; Phase 3: Career-to-plan quickstart |
| **Resources** | Resources tab, plan detail, recommendations | `ResourcesStateModel`, `ResourceLibraryService`, `ResourceAssignmentService` | Siloed (global vs user vs district) | Phase 1: Clarify precedence; Phase 2: Move assignments under district/plan scope; Phase 3: Efficacy tracking |
| **Recommendations** | Inside plan detail | `RecommendationsStateModel`, `RecommendationsService` | Generated without stable context | Phase 1: Deterministic generation; Phase 2: Canonicalize storage; Phase 3: Feedback loop |

### Workflow Modules

| Module | Entry Points | Current Dependencies | Key Problems | Refactor Priority |
|--------|--------------|---------------------|--------------|-------------------|
| **Forms** | Forms & Surveys tab | `FormTemplateService`, `FormAssignmentService` | Forms/Survey not clearly separated | Phase 1: Rename consistently; Phase 2: Store submissions under student; Phase 3: Auto-generate meeting agenda |
| **Survey** | Within Forms, student detail, Student Mode | `InterestSurveyView`, student model fields | Survey logic drifts from canonical interest model | Phase 1: Write directly to `StudentInterestService`; Phase 2: Store submissions separately; Phase 3: Adaptive surveys |
| **Meetings** | Inside plan, meeting list | `MeetingService` | Stored separately from plan; feels detached | Phase 1: Always launched from plan context; Phase 2: Move under plan subcollection; Phase 3: Post-meeting outcome capture |
| **Scheduling** | Subflow of Meetings | `MeetingService` | Exists in multiple places (duplicated UI) | Phase 1: Single `ScheduleMeetingCoordinator`; Phase 2: Store metadata on meeting docs; Phase 3: District calendar constraints |
| **Goals** | Inside plan detail | Plan + goal models | Can become "UI-only" if not normalized | Phase 1: Single `GoalsRepository`; Phase 2: Move to plan subcollection; Phase 3: Goal progress automation |
| **Settings** | Settings tab (all roles) | `AuthStateModel` | Becomes junk drawer; student mode security inconsistent | Phase 1: Split by role; Phase 2: Persist preferences; Phase 3: Admin settings |

---

## 9. Naming/Structure Mismatches to Fix

| Current | Standardized |
|---------|--------------|
| Tab: "Forms & Surveys" → `FormsAndSurveysView` | Module: `FormsAndSurveys`; Submodules: `Forms` + `Survey` |
| Tab: "Careers" → `CareersView` | Product name: "Career Explorer"; Struct: `CareerExplorerView` |
| Goals/Meetings/Scheduling | Treat as "Plan Features" under `TMIPlan` with shared repositories |

---

## 10. Dependency Graph (Text Adjacency List)

```
Authentication
  → AuthStateModel
  → MainTabView (post-auth)
  → StudentMainView (if signed-in student)

MainTabView
  → AuthStateModel (role gating, districtId)
  → StudentModeSession (override routing)
  → [Dashboard, District, Students, TMIPlans, Forms, Interests, Careers, Resources, Settings]

Students
  → StudentService
  → StudentContext (NEW)
  → StudentModeSession (start)
  → [Interests, TMIPlans, Meetings, Forms] (student subviews)

InterestsAndHobbies
  → InterestLibraryService
  → StudentInterestService
  → Career Explorer (downstream)
  → Recommendations (downstream)

Career Explorer
  → CareerLibraryService
  → StudentCareerService
  → TMIPlans (plan creation)
  → Recommendations

TMIPlans
  → TMIPlanService
  → TMIPlan (detail)
  → PlanApprovalService (district workflow)
  → Recommendations (inside plan)

TMIPlan (detail)
  → [Goals, Meetings/Scheduling, Resources, Recommendations, Forms/Survey]

Resources
  → ResourceLibraryService
  → ResourceAssignmentService
  → PlanResourceLinkService
  → Recommendations (inputs/outputs)

Recommendations
  → [StudentInterestService, StudentCareerService, ResourceLibraryService, Goals/Meetings status]
  → writes back into [Goals, Resources, Plans]

District
  → DistrictService
  → PlanApprovalService
  → ComplianceService
  → affects Forms/Survey gating and plan status
```

---

## 11. Key Architectural Principles

1. **Single Source of Truth**: Each domain has one authoritative StateModel + Service
2. **Context-Driven**: All domain operations keyed by `districtId`, `studentId`, `planId` from shared context
3. **Normalized Scoping**: District-scoped canonical collections; user-scoped for preferences/drafts
4. **Listener Ownership**: StateModels own Firestore listeners, not Views
5. **Cohesive Loop**: Interests → Careers → Plans → Goals/Meetings → Resources → Recommendations → (loop back)

---

## 12. Migration Strategy

1. **Phase 1 (Safe)**: Add `StudentContextStateModel`, fix default tab selection, split UI components
2. **Phase 2 (Normalization)**: Normalize Firestore collections to district scope, consolidate edge storage
3. **Phase 3 (Enhancement)**: Add closed-loop analytics, feedback mechanisms, guided UX

**Migration Rule**: Services read old + new locations during transition; backfill data; then remove old paths.

