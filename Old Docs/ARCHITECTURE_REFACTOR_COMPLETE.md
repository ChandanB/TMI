# Architecture Refactoring Implementation - Complete

## Summary

This document outlines the comprehensive architecture refactoring implemented to address the fragmentation and consistency issues identified in the TMI application codebase.

## Core Problem Solved

The application had a fundamental issue: **No shared "active student / active plan" context across tabs**. This led to:
- Inconsistent data passing between modules
- Duplicated state management
- Mixed Firestore ownership patterns
- Fragmented navigation

## Key Components Added

### 1. StudentContextStateModel (NEW - Critical)
**Location:** `TMI/StateModels/StudentContextStateModel.swift`

The central piece of this refactoring. Provides:
- `selectedStudentId` / `selectedPlanId` - authoritative context
- `scope` - tracks whether we're in staff/studentMode/signedInStudent mode
- `cachedStudent` / `cachedPlan` - quick access without re-fetching
- `prefetchedInterests` / `prefetchedCareerState` / `prefetchedPlans` - warm cache for fast navigation
- Deep link handling via `DeepLinkDestination`

### 2. AppBootstrapService (NEW)
**Location:** `TMI/Core/AppBootstrapService.swift`

Post-authentication warming service:
- Primes shared domain caches (interests, careers, resources)
- Loads district context for district roles
- Pre-fetches student and plan lists for staff

### 3. StudentAccessPolicy (NEW)
**Location:** `TMI/Core/StudentAccessPolicy.swift`

Unified access control policy:
- `allowedTabs(in: mode)` - determines which tabs are accessible
- `canEdit(in: mode)` - editing permissions
- `canBookmarkCareers(in: mode)` - feature-specific permissions
- `visibleDataFields(in: mode)` - data visibility control
- Used by both `StudentModeView` and `StudentMainView` for consistency

### 4. DeepLinkRouter (NEW)
**Location:** `TMI/Core/DeepLinkRouter.swift`

Centralized deep link handling:
- Parses URL scheme (`tmi://student/123/interests`)
- Creates navigation actions with proper tab + context
- Queues navigation for processing after context is ready

### 5. ScheduleMeetingCoordinator (NEW)
**Location:** `TMI/Core/ScheduleMeetingCoordinator.swift`

Unified meeting scheduling:
- Single entry point from Dashboard, Student Detail, or Plan Detail
- Draft meeting management with validation
- Consistent scheduling flow across the app

## State Models Added

### MeetingsStateModel
**Location:** `TMI/StateModels/MeetingsStateModel.swift`

Manages meeting list state with:
- Context filtering (by student or plan)
- Upcoming/past meeting categorization
- Meeting lifecycle operations (create, update, cancel)

### DistrictStateModel
**Location:** `TMI/StateModels/DistrictStateModel.swift`

District-level state management:
- District metrics and analytics
- Pending plan approvals queue
- Compliance settings
- School filtering

### RecommendationsStateModel
**Location:** `TMI/StateModels/RecommendationsStateModel.swift`

AI/Rule-based recommendations:
- Context-aware recommendation fetching
- Status management (pending → accepted → applied → completed)
- Feedback loop integration
- Action execution

## Data Repositories Added

### GoalsRepository
**Location:** `TMI/Data/GoalsRepository.swift`

Single-writer pattern for goal mutations:
- All goal changes go through one path
- Prevents race conditions
- Maintains plan integrity
- Handles progress and status updates

### PlanRepository
**Location:** `TMI/Data/PlanRepository.swift`

Unified plan operations:
- CRUD for plans
- Goals management (delegates to GoalsRepository)
- Resource linking
- Status management for approval workflow

## Services Added

### RecommendationsService
**Location:** `TMI/Services/RecommendationsService.swift`

### ResourceAssignmentService
**Location:** `TMI/Services/ResourceAssignmentService.swift`

### PlanApprovalService
**Location:** `TMI/Services/PlanApprovalService.swift`

### ComplianceService
**Location:** `TMI/Services/ComplianceService.swift`

### DistrictAnalyticsService
**Location:** `TMI/Services/DistrictAnalyticsService.swift`

## Views Updated

### TMIApp.swift
- Injects all new state models into environment
- Performs bootstrap on authentication
- Handles deep link URLs
- Clears context on logout

### MainTabView.swift
- Integrates `studentContext` for workspace awareness
- Shows workspace button when student is selected
- Processes pending deep links
- Provides `WorkspacePanelView` for context overview

### StudentModeView.swift
- Uses `StudentAccessPolicy` for consistent access control
- Sets student context with `.studentMode` scope
- Uses `StudentTab` enum matching `StudentMainView`

### StudentDetailView.swift
- Sets student context on appear via `studentContext.setActiveStudent()`
- Uses prefetched data for faster loading
- Integrates `ScheduleMeetingCoordinator`

### InterestsAndHobbiesView.swift
- Context-aware: shows student-specific interests when context is set
- Uses `StudentAccessPolicy` for edit permissions
- Leverages prefetched interests from context

### CareerExplorerView.swift
- Context-aware with `studentContext`
- Uses `StudentAccessPolicy` for bookmark permissions
- Leverages prefetched career state

### ResourcesView.swift
- Context-aware for student-specific recommendations
- Uses context student for personalization

### DashboardView.swift
- Added `NextBestAction` for intelligent guidance
- Uses shared caches from bootstrap

### SettingsView.swift
- Role-based sections:
  - Staff Settings (student mode config, notifications, meeting defaults)
  - District Admin (compliance, audits, staff management)
  - Student Settings (interest preferences, privacy)
  - Parent Settings (progress notifications, consent management)

## Architecture Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         TMIApp                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Environment:                                                 ││
│  │  - authStateModel                                            ││
│  │  - studentContext (NEW - authoritative)                      ││
│  │  - deepLinkRouter (NEW)                                      ││
│  │  - dashboardStateModel                                       ││
│  │  - interestsStateModel                                       ││
│  │  - meetingsStateModel (NEW)                                  ││
│  │  - districtStateModel (NEW)                                  ││
│  │  - recommendationsStateModel (NEW)                           ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     AppBootstrapService                          │
│  - Primes caches on login                                        │
│  - Loads interests, careers, resources                          │
│  - Prepares district context                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Navigation Layer                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │  MainTabView │  │StudentMode   │  │StudentMain   │           │
│  │  (staff)     │  │View (kiosk)  │  │View (student)│           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│         │                  │                  │                  │
│         └──────────────────┴──────────────────┘                  │
│                            │                                     │
│                            ▼                                     │
│              ┌─────────────────────────┐                         │
│              │  StudentAccessPolicy    │                         │
│              │  (unified restrictions) │                         │
│              └─────────────────────────┘                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    StudentContextStateModel                      │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Authoritative State:                                        ││
│  │  - selectedStudentId / selectedPlanId                        ││
│  │  - scope: staff | studentMode | signedInStudent              ││
│  │  - cachedStudent / cachedPlan                                ││
│  │  - prefetchedInterests / prefetchedCareerState               ││
│  └─────────────────────────────────────────────────────────────┘│
│                            │                                     │
│              All modules read from this context                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Data Layer                                  │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐        │
│  │GoalsRepository│  │PlanRepository │  │StudentInterest│        │
│  │(single writer)│  │(unified plan) │  │Service (edge) │        │
│  └───────────────┘  └───────────────┘  └───────────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

## Product Loop (Now Connected)

```
Interests → Careers → TMI Plans → Goals/Meetings → Resources → Recommendations
     ↑                                                              │
     └──────────────────────────────────────────────────────────────┘
                    (feedback loop via recommendations)
```

## Migration Notes

1. **Existing code continues to work** - the refactoring is additive
2. **Views can opt-in to context** - check `studentContext.hasActiveStudent`
3. **Prefetched data is optional** - views can still fetch directly if needed
4. **Deep links are queued** - processed after context is ready

## Future Improvements

1. **Firestore Normalization** - Move to top-level `/students/` collection with proper security rules
2. **Offline Support** - Add persistence layer for prefetched data
3. **Real-time Sync** - Add Firestore listeners to context for live updates
4. **Analytics** - Track context changes for user behavior analysis
5. **Testing** - Add unit tests for state models and repositories

