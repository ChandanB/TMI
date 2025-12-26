# TMI Project Map

> **Purpose**: This document tracks the active architecture, entry points, services, and features of the TMI application to make refactoring safe and measurable.
>
> **Last Updated**: 2025-12-26
> **Branch**: refactor/cleanup-phase-0-and-1

---

## 1. Application Entry Points

### Primary Entry Point
- **TMI/App/TMIApp.swift** (Line 23)
  - Configures Firebase (via AppDelegate)
  - Sets up environment state models:
    - `AuthStateModel` (authentication)
    - `DashboardStateModel` (dashboard state)
    - `InterestsAndHobbiesStateModel` (interests management)
  - Routes to `ContentView`

### Main Content Router
- **TMI/App/TMIApp.swift → ContentView** (Line 37)
  - **Authenticated + Student Role** → `StudentMainView()`
  - **Authenticated + Staff Role** → `MainTabView()`
  - **Unauthenticated** → `AuthenticationView()`

### Primary Navigation Hub
- **TMI/Views/MainTabView.swift**
  - Role-based tab navigation for educators/staff
  - **MVP Active Tabs** (Phase 1):
    - Dashboard (`DashboardView`)
    - Students (`StudentListView`)
    - TMI Plans (`TMIPlanListView`)
    - Settings (`SettingsView`)
  - **Disabled Tabs** (Post-MVP):
    - Forms & Surveys (temporarily disabled)
    - Career Explorer (temporarily disabled)
    - Interests & Hobbies (temporarily disabled)
    - Resources (temporarily disabled)

---

## 2. Active Services Layer

### Authentication & User Management
| Service | File | Status | Owner/Purpose |
|---------|------|--------|---------------|
| **TMIAuthService** | `Services/TMIAuthService.swift` | ✅ ACTIVE | Primary auth service (6 references) |
| AuthenticationService | `Services/AuthenticationService.swift` | ❌ DEPRECATED | Legacy (1 reference) - **DELETE** |

### Data Services
| Service | File | Status | Purpose |
|---------|------|--------|---------|
| **FirebaseManager** | `Services/FirebaseManager.swift` | ✅ ACTIVE | Central Firebase singleton |
| **StudentService** | `Services/StudentService.swift` | ✅ ACTIVE | Student CRUD operations |
| **TMIPlanService** | `Services/TMIPlanService.swift` | ✅ ACTIVE | TMI Plan management |
| **SurveyService** | `Services/SurveyService.swift` | ✅ ACTIVE | Survey/interest survey management |
| **MeetingService** | `Services/MeetingService.swift` | ✅ ACTIVE | Meeting scheduling |
| **FormService** | `Services/FormService.swift` | ✅ ACTIVE | Form template management |
| **ResourceService** | `Services/ResourceService.swift` | ✅ ACTIVE | Educational resource management |

### Specialized Services
| Service | File | Status | Purpose |
|---------|------|--------|---------|
| **CareerService** | `Services/CareerService.swift` | ✅ ACTIVE | AI-powered career search & generation |
| **CareerMatchingService** | `Services/CareerMatchingService.swift` | ✅ ACTIVE | Interest-to-career matching algorithm |
| **AIInsightsService** | `Services/AIInsightsService.swift` | ✅ ACTIVE | AI-generated insights for students |

### Utility Services
| Service | File | Status | Notes |
|---------|------|--------|-------|
| **StudentInterestSynchronizer** | `Services/StudentInterestSynchronizer.swift` | ⚠️ MINIMAL | 1 method call - consider merging into StudentService |
| **RecommendationsService** | `Services/RecommendationsService.swift` | ⚠️ MINIMAL | 1 view only - consider archiving |
| **DocumentService** | `Services/DocumentService.swift` | ⚠️ UNKNOWN | 2 references - needs audit |
| **AuditService** | `Services/AuditService.swift` | ⚠️ UNKNOWN | Usage unverified - needs audit |

### Navigation Services (UNUSED)
| Service | File | Status | Notes |
|---------|------|--------|-------|
| NavigationCoordinator | `Services/NavigationCoordinator.swift` | ❌ UNUSED | 0 active references - **DELETE** |

---

## 3. State Management Layer

### Environment State Models (Injectable)
| State Model | File | Scope | Purpose |
|-------------|------|-------|---------|
| **AuthStateModel** | `StateModels/AuthStateModel.swift` | App-wide | User authentication & session |
| **DashboardStateModel** | `StateModels/DashboardStateModel.swift` | Dashboard | Dashboard metrics & activity |
| **InterestsAndHobbiesStateModel** | `StateModels/InterestsAndHobbiesStateModel.swift` | App-wide | Interest/hobby management |

### View-Specific State Models
| State Model | File | Scope | Purpose |
|-------------|------|-------|---------|
| **StudentListStateModel** | `StateModels/StudentListStateModel.swift` | StudentListView | Student list management |
| **StudentDetailStateModel** | `StateModels/StudentDetailStateModel.swift` | StudentDetailView | Individual student details |
| **AddStudentStateModel** | `StateModels/AddStudentStateModel.swift` | AddStudentView | Student creation flow |
| **TMIPlanListStateModel** | `StateModels/TMIPlanListStateModel.swift` | TMIPlanListView | TMI Plan list management |
| **ResourcesStateModel** | `StateModels/ResourcesStateModel.swift` | ResourcesView | Resource library state |

### Session State
| State Model | File | Purpose |
|-------------|------|---------|
| **StudentModeSession** | `StateModels/StudentModeSession.swift` | Student mode switching for educators |

---

## 4. Core Features & Their Locations

### 🟢 MVP Phase 1 Features (ACTIVE)

#### Authentication Flow
- **Entry**: `TMI/Views/Authentication/AuthenticationView.swift`
- **State**: `AuthStateModel`
- **Service**: `TMIAuthService`
- **Models**: `TMIUser`, `UserRole`

#### Dashboard
- **Entry**: `TMI/Views/Dashboard/DashboardView.swift`
- **State**: `DashboardStateModel`
- **Components**:
  - Dashboard stats (Quick Stats Row)
  - Recent activity feed
  - Engagement charts
  - Priority actions
- **Note**: ⚠️ **Large file** - needs decomposition in Phase 4

#### Student Management
- **Entry**: `TMI/Views/Students/StudentListView.swift`
- **Detail**: `TMI/Views/Students/StudentDetailView.swift`
- **Add/Edit**: `TMI/Views/Students/AddStudentView.swift`, `StudentEditView.swift`
- **State**: `StudentListStateModel`, `StudentDetailStateModel`, `AddStudentStateModel`
- **Service**: `StudentService`
- **Models**: `Student`, `Interest`, `Hobby`

#### TMI Plans
- **List**: `TMI/Views/TMIPlans/TMIPlanListView.swift`
- **Detail**: `TMI/Views/TMIPlans/TMIPlanDetailView.swift`
- **Create**: `TMI/Views/TMIPlans/CreateTMIPlanView.swift`
- **State**: `TMIPlanListStateModel`
- **Service**: `TMIPlanService`
- **Models**: `TMIPlan` (6 plan types)

#### Student Mode
- **Entry**: `TMI/Views/StudentMode/StudentModeView.swift`
- **State**: `StudentModeSession`
- **Purpose**: Restricted student-facing interface for educators

#### Settings
- **Entry**: `TMI/Views/Settings/SettingsView.swift`
- **Sub-views**:
  - User profile management
  - Data import/export
  - App preferences

---

### 🟡 Post-MVP Features (DISABLED/INCOMPLETE)

#### Career Explorer
- **Location**: `TMI/Views/Career Explorer/`
- **Status**: Tab disabled in MainTabView
- **Services**: `CareerService`, `CareerMatchingService`
- **Models**: Dual career models (needs consolidation - see Phase 2)

#### Forms & Surveys
- **Location**: `TMI/Views/Forms/`
- **Status**: Tab disabled in MainTabView
- **Service**: `FormService`
- **Note**: ⚠️ **19 files** - fragmented, needs consolidation in Phase 3

#### Interests & Hobbies Management
- **Location**: `TMI/Views/Interests/`
- **Status**: Tab disabled in MainTabView
- **State**: `InterestsAndHobbiesStateModel`

#### Resources Library
- **Location**: `TMI/Views/Resources/`
- **Status**: Tab disabled in MainTabView
- **Service**: `ResourceService`
- **State**: `ResourcesStateModel`

---

### 🔴 Orphaned/Unintegrated Features (DELETE CANDIDATES)

#### Goals Management
- **Location**: `TMI/Views/Goals/`
- **Files**:
  - `AddGoalView.swift`
  - `EditGoalView.swift`
- **Status**: ❌ **NEVER INTEGRATED** - No references in navigation
- **Action**: **DELETE in Phase 1**

#### Recommendations
- **Location**: `TMI/Views/Recommendations/RecommendationsView.swift`
- **Status**: ⚠️ Minimal usage (1 view only, not in tab navigation)
- **Action**: Consider archiving

---

## 5. Component Libraries & Design System

### Active Component Library
- **TMI/Views/Components/TMIComponentLibrary.swift**
  - 8 component types:
    - Backgrounds
    - Cards
    - Buttons
    - Input fields
    - Headers
    - Loading states
    - Empty states
    - Error views

### Design System (Fragmented - Needs Consolidation)
| File | Location | Purpose | Status |
|------|----------|---------|--------|
| **TMIDesignTokens** | `Core/DesignSystem/TMIDesignTokens.swift` | Colors, spacing, typography | ✅ ACTIVE |
| RedesignBridge | `Core/DesignSystem/RedesignBridge.swift` | Alias wrapper | ❌ DELETE - unnecessary abstraction |
| RedesignComponents | `Core/DesignSystem/RedesignComponents.swift` | Component variants | ⚠️ Review overlap |
| UIComponents | (location unknown) | Legacy components | ⚠️ Find & consolidate |

### Legacy Components (DELETE CANDIDATES)
- **ZLHNComponents/** (from old CAMP APP - 3/31/24)
  - `ButtonFactory.swift` - ❌ Unused
  - `CustomNavigationLink.swift` - ❌ Unused
  - `CustomComponents.swift` - ⚠️ Minimal usage
  - `TextAndTypographyFactory/` - ⚠️ Replaced by native SwiftUI

---

## 6. Data Models Architecture

### Core Models
| Model | Location | Status | Notes |
|-------|----------|--------|-------|
| **TMIUser** | `Models/TMIUser.swift` | ✅ ACTIVE | 7+ user roles |
| **Student** | `Models/Student.swift` | ✅ ACTIVE | Core educational entity |
| **TMIPlan** | `Models/TMIPlan.swift` | ✅ ACTIVE | 6 intervention plan types |

### Domain Models (Fragmented - Phase 2 Consolidation)
| Domain | Current Files | Status | Action |
|--------|---------------|--------|--------|
| **Career** | `Career.swift` + `Career/CareerModels.swift` | ⚠️ DUPLICATE | Consolidate into `Models/Career/` |
| **Survey** | `Survey.swift` + `Survey/SurveyModels.swift` | ⚠️ DUPLICATE | Consolidate into `Models/Survey/` |
| **Form** | `FormModels/` (multiple files) | ✅ ACTIVE | Review structure |

### Utility Models
| Model | Location | Status |
|-------|----------|--------|
| Interest | `Models/Interest.swift` | ✅ ACTIVE |
| Hobby | `Models/Hobby.swift` | ✅ ACTIVE |
| Meeting | `Models/Meeting.swift` | ✅ ACTIVE |

### DELETE CANDIDATES
- **Models/Models.swift** - Mixed concerns dump file (52 lines)

---

## 7. Firebase Architecture

### Firebase Services
- **FirebaseManager** (`Services/FirebaseManager.swift`) - Singleton coordinator
- **FirebaseConfigurationHelper** (`Services/FirebaseConfigurationHelper.swift`) - Setup validation

### Data Structure
```
Firestore:
  users/{uid}/
    ├── students/
    ├── tmiPlans/
    ├── interests/
    ├── hobbies/
    ├── meetings/
    ├── forms/
    └── resources/
```

### Authentication
- Firebase Auth with role-based access control
- COPPA/FERPA compliance with consent tracking

---

## 8. Testing & Preview Strategy

### Active Testing Approach
- SwiftUI Previews for visual testing
- Unit tests for business logic (location TBD)

### Preview Usage
- Most views include `#Preview` macros
- Sample data defined in:
  - `SampleData.swift`
  - Various `Sample*.swift` files

---

## 9. Dependencies & External Libraries

### Package Dependencies
- **Firebase SDK 11.2.0**: Auth, Firestore, Analytics, Storage
- **SDWebImageSwiftUI**: Image loading/caching
- **Charts**: SwiftUI Charts for data visualization

### Minimum Platform
- iOS 26+ (uses latest SwiftUI features)

---

## 10. Known Technical Debt & Refactoring Targets

### Phase 1 Deletions (This Phase)
- [ ] `Views/Goals/` directory
- [ ] `ZLHNComponents/ButtonFactory.swift`
- [ ] `ZLHNComponents/CustomNavigationLink.swift`
- [ ] `Core/DesignSystem/RedesignBridge.swift`
- [ ] `Services/AuthenticationService.swift`
- [ ] `Services/NavigationCoordinator.swift`
- [ ] `Models/Models.swift`

### Phase 2 Consolidations (Next)
- [ ] Career models → single source
- [ ] Survey models → single source
- [ ] Form components → unified structure

### Phase 3 Cleanups
- [ ] Design system consolidation
- [ ] Form builder refactor (19 files)

### Phase 4 Decomposition
- [ ] DashboardView.swift (large file)

---

## 11. Reference Audit Status

### Files Audited for Deletion
- [x] Goals views
- [x] ZLHNComponents
- [x] RedesignBridge
- [x] AuthenticationService
- [x] NavigationCoordinator
- [ ] Models.swift (pending verification)

### Service Usage Verified
- [x] TMIAuthService (6 refs - KEEP)
- [x] AuthenticationService (1 ref - DELETE)
- [ ] DocumentService (2 refs - pending)
- [ ] AuditService (unknown - pending)
- [ ] RecommendationsService (1 view - consider archive)

---

## 12. Refactoring Branch Strategy

### Current Branch
- `refactor/cleanup-phase-0-and-1`

### Future Branches
- `refactor/cleanup-phase-2` (Model consolidation)
- `refactor/cleanup-phase-3` (Component cleanup)
- `refactor/cleanup-phase-4` (View decomposition)

### Merge Strategy
- Each phase merges to `main` after checkpoint verification
- App must build + launch successfully before merge

---

## Appendix: Quick Reference Commands

### Find Service Usage
```bash
grep -r "AuthenticationService" TMI/ --include="*.swift"
grep -r "NavigationCoordinator" TMI/ --include="*.swift"
```

### Build & Run Checkpoint
```bash
swift build
# Or use Xcode: Cmd+B
```

### Git Status
```bash
git status
git diff
```

---

**Document Maintainer**: Update this file when adding/removing major features or services.
