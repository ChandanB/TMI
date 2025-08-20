# TMI Component Refactor Plan

## Overview
This document outlines a systematic 5-phase approach to consolidate duplicate components across the TMI codebase into a unified component library (TMIComponentLibrary.swift).

## Current Duplicate Component Analysis

### Major Duplicate Categories Identified:

#### 1. **Glass Card Components** (High Priority)
- `GlassCard` (AuthComponents.swift)
- `DashboardGlassCard` (UIComponents.swift)
- Various card implementations across views
- **Impact**: 8+ files affected

#### 2. **Background Components** (High Priority)
- `DynamicBackgroundView` (AuthComponents.swift)
- `DashboardBackgroundView` (UIComponents.swift)
- `BackgroundAnimationView` (CareerExplorerView.swift)
- `ParticleEffect` (multiple files)
- **Impact**: 6+ files affected

#### 3. **Button Styles & Components** (Medium Priority)
- `TMIButton` (AuthComponents.swift)
- `BaseButtonStyle` (ButtonFactory.swift)
- `TMIPrimaryButtonStyle` (TMIStatCard.swift)
- `FloatingActionButton` (TMIPlanListView.swift)
- Various filter and action buttons
- **Impact**: 12+ files affected

#### 4. **Card & Layout Components** (Medium Priority)
- `StatCard` variations (UIComponents.swift, TMIStatCard.swift)
- `TMIPlanCard` (TMIPlanCard.swift)
- Various selection cards (NewTMIPlanView.swift)
- **Impact**: 8+ files affected

#### 5. **Form & Input Components** (Low Priority)
- `TMITextField` (AuthComponents.swift)
- Filter components across career views
- Search components
- **Impact**: 5+ files affected

## 5-Phase Refactor Plan

### Phase 1: Foundation Components (Week 1)
**Priority**: Critical
**Status**: 🟡 Partially Started

#### 1.1 Background & Base Layout Components
- [ ] **TMIBackgroundView** - Unified animated background
- [ ] **TMIGlassCard** - Single glass morphism container
- [ ] **TMIParticleEffect** - Reusable particle animation
- [ ] **TMIGradientBackground** - Standardized gradient backgrounds

#### 1.2 Implementation Steps:
```swift
// Create consolidated components in TMIComponentLibrary.swift
struct TMIBackgroundView: View
struct TMIGlassCard<Content: View>: View  
struct TMIParticleEffect: View
```

#### 1.3 Files to Update:
- [x] AuthComponents.swift (Replace DynamicBackgroundView & GlassCard)
- [x] AuthenticationView.swift (Replaced with TMIBackgroundView & TMIGlassCard)
- [x] RegistrationView.swift (Replaced with TMIBackgroundView & TMIGlassCard)
- [x] CareerExplorerView.swift (Replaced BackgroundAnimationView with TMIBackgroundView)
- [ ] UIComponents.swift (Replace DashboardBackgroundView & DashboardGlassCard)
- [ ] TMIPlanListView.swift (Replace PlanBackgroundBlob)
- [ ] TMIPlanDetailView.swift (Replace ModelBackgroundBlob)

### Phase 2: Button & Interaction Components (Week 2)  
**Priority**: High
**Status**: 🔴 Not Started

#### 2.1 Button System Consolidation
- [ ] **TMIButton** - Primary action button with variants
- [ ] **TMIFloatingActionButton** - Floating action button
- [ ] **TMIFilterButton** - Filter and selection buttons
- [ ] **TMIIconButton** - Icon-only buttons

#### 2.2 Button Style Variants:
```swift
enum TMIButtonStyle {
    case primary, secondary, tertiary, destructive
    case floating, filter, icon
}
```

#### 2.3 Files to Update:
- [ ] AuthComponents.swift (TMIButton)
- [ ] ButtonFactory.swift (BaseButtonStyle, CustomButton)
- [ ] TMIStatCard.swift (TMIPrimaryButtonStyle, TMISecondaryButtonStyle)
- [ ] TMIPlanListView.swift (FloatingActionButton)
- [ ] CareerExplorerView.swift (FilterButton variants)

### Phase 3: Card & Layout Components (Week 3)
**Priority**: Medium
**Status**: 🔴 Not Started

#### 3.1 Card Component System
- [ ] **TMIStatCard** - Statistical display cards
- [ ] **TMIContentCard** - General content containers
- [ ] **TMISelectionCard** - Interactive selection cards
- [ ] **TMIListCard** - List item cards

#### 3.2 Layout Components
- [ ] **TMISection** - Section headers with dividers
- [ ] **TMIEmptyState** - Empty state views
- [ ] **TMIProgressIndicator** - Progress displays

#### 3.3 Files to Update:
- [ ] UIComponents.swift (StatCard)
- [ ] TMIStatCard.swift (StatCard variants)
- [ ] TMIPlanCard.swift (TMIPlanCard)
- [ ] NewTMIPlanView.swift (Selection cards)
- [ ] StudentCard.swift (StudentCard)

### Phase 4: Navigation & Tab Components (Week 4)
**Priority**: Medium  
**Status**: 🔴 Not Started

#### 4.1 Navigation System
- [ ] **TMITabBar** - Unified tab bar component
- [ ] **TMISidebar** - Sidebar navigation for larger screens
- [ ] **TMINavigationHeader** - Standardized navigation headers

#### 4.2 Files to Update:
- [ ] UIComponents.swift (PremiumGlassTabBar, PremiumSidebarList)
- [ ] MainTabView.swift (Tab view implementations)

### Phase 5: Form & Input Components (Week 5)
**Priority**: Low
**Status**: 🔴 Not Started

#### 5.1 Input Components
- [ ] **TMITextField** - Standardized text inputs
- [ ] **TMISearchBar** - Search components
- [ ] **TMIFilter** - Filter components
- [ ] **TMISelector** - Selection components

#### 5.2 Files to Update:
- [ ] AuthComponents.swift (TMITextField)
- [ ] CareerExplorerView.swift (Search and filter components)
- [ ] Various views with search functionality

## Implementation Strategy

### Phase Execution Order:
1. **Foundation First** - Establish base components that others depend on
2. **Button System** - High-usage components with significant duplication
3. **Card System** - Medium complexity, moderate impact
4. **Navigation** - Complex but contained to specific files
5. **Forms** - Lowest priority, least duplication

### Migration Approach:
1. **Create** consolidated component in TMIComponentLibrary.swift
2. **Update** one file at a time to use new component
3. **Test** each file after migration
4. **Remove** old duplicate component when all usages migrated

### Code Quality Standards:
- **Consistent naming**: TMI prefix for all components
- **Comprehensive documentation**: Each component documented
- **Animation consistency**: Standardized animation parameters
- **Accessibility**: Proper accessibility support
- **Responsive design**: Support for various screen sizes

## Success Metrics

### Quantitative Goals:
- [ ] Reduce duplicate components by **80%+**
- [ ] Reduce total lines of component code by **40%+**
- [ ] Consolidate **25+ duplicate implementations** into **8-10 base components**

### Qualitative Goals:  
- [ ] **Consistent visual design** across all views
- [ ] **Easier maintenance** with single source of truth
- [ ] **Improved developer experience** with clear component API
- [ ] **Better performance** with optimized shared components

## Risk Mitigation

### Potential Risks:
1. **Breaking changes** in existing functionality
2. **Animation inconsistencies** during migration
3. **Performance regressions** from component changes

### Mitigation Strategies:
1. **Incremental migration** - One file at a time
2. **Comprehensive testing** after each change
3. **Backup branches** before major changes
4. **Feature flags** for gradual rollout

## Timeline

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| Phase 1 | Week 1 | Foundation components (Background, GlassCard) |
| Phase 2 | Week 2 | Button system consolidation |
| Phase 3 | Week 3 | Card and layout components |
| Phase 4 | Week 4 | Navigation components |
| Phase 5 | Week 5 | Form and input components |

**Total Duration**: 5 weeks  
**Review Points**: End of each phase  
**Go-Live**: After Phase 5 completion and full testing

## Next Steps

### Immediate Actions:
1. ✅ **Create this refactor plan**
2. ⏳ **Complete Phase 1** foundation components
3. ⏳ **Begin systematic migration** of duplicate components
4. ⏳ **Set up component testing** framework

### Phase 1 Priority:
Start with **TMIBackgroundView** and **TMIGlassCard** as they have the highest duplication and impact across the codebase. 