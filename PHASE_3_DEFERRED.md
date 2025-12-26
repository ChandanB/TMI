# Phase 3: Component System Cleanup - DEFERRED

> **Status**: Deferred to future iteration
> **Reason**: Large scope, lower priority than Dashboard refactor (Phase 4)
> **Date**: 2025-12-26

---

## Current State Analysis

### Form Components (22 files total)

**Views/Forms/** (19 files):
- FormsDashboardView.swift
- FormTemplateBuilderViewModel.swift & FormTemplateBuilderView.swift
- MyFormsView.swift
- FormSectionCard.swift
- FormSubmissionsView.swift
- FormView.swift
- FormDetailEditorView.swift
- ValidationRulesEditor.swift
- FormStoreViewModel.swift & FormStoreView.swift
- FormCreationView.swift
- FormBuilderView.swift
- FormImportView.swift
- FormPreviewView.swift
- FormComponents.swift
- FormStoreCardView.swift
- FormTemplateDetailView.swift
- FormsAndSurveysView.swift

**Helpers/Components/FormComponents/** (3 files):
- DefaultFormTemplate.swift (actively used - 8 references)
- GenericFormFields.swift
- DefaultSectionTemplate.swift (actively used - 8 references)

### Bucket Component Files

**UIComponents.swift** - 881 lines
- Mixed component definitions
- Needs extraction into individual files

**TMIComponentLibrary.swift** - 878 lines
- 8 component types in one file
- Needs extraction into folder structure

---

## Recommended Future Work

### 3A. Form Components Consolidation

**Target Structure**:
```
Views/Components/Form/
├── Fields/
│   ├── TMITextField.swift
│   ├── TMIPickerField.swift
│   ├── TMIToggleField.swift
│   └── TMIDateField.swift
├── Templates/
│   ├── DefaultFormTemplate.swift
│   └── DefaultSectionTemplate.swift
├── Validation/
│   └── ValidationRulesEditor.swift
└── FormComponents.swift (consolidated)
```

**Actions**:
1. Move Helpers/Components/FormComponents/* to Views/Components/Form/Templates/
2. Extract GenericFormFields into individual field files
3. Consolidate FormBuilderView, FormCreationView, FormTemplateBuilderView (overlap)
4. Move ValidationRulesEditor to Validation subfolder

**Estimated Impact**: Reduce 22 files to ~15 well-organized files

### 3B. Component Library Refactoring

**Current**:
- UIComponents.swift (881 lines, mixed concerns)
- TMIComponentLibrary.swift (878 lines, 8 component types)

**Target Structure**:
```
Views/Components/
├── Backgrounds/
│   └── TMIBackgroundView.swift
├── Cards/
│   └── TMICard.swift
├── Buttons/
│   └── TMIButton.swift
├── Inputs/
│   ├── TMITextField.swift
│   └── TMISearchBar.swift
├── Headers/
│   └── TMISectionHeader.swift
├── States/
│   ├── TMILoadingView.swift
│   ├── TMIEmptyState.swift
│   └── TMIErrorView.swift
└── Form/ (from 3A above)
```

**Actions**:
1. Extract each component type from TMIComponentLibrary into individual files
2. Break up UIComponents.swift by component type
3. Merge overlapping definitions
4. Update all import statements across codebase

**Estimated Impact**:
- Remove 1759 lines of bucket files
- Create ~12-15 focused component files (~50-150 lines each)
- Improved discoverability and maintainability

---

## Dependencies & Risks

### Blockers
- Forms module is disabled in MVP (MainTabView.swift:38)
- Low user impact until Forms feature is re-enabled

### Risks
- Large refactor with potential for breaking changes across many views
- Requires comprehensive reference updates (estimated 50+ files affected)
- Time-consuming with moderate business value in current MVP state

---

## Decision

**Defer Phase 3** in favor of:
- **Phase 4**: Dashboard Refactor (High Priority, high user impact)
- **Phase 5**: Architecture fixes (Foundation improvements)

Phase 3 can be revisited when:
1. Forms module is re-enabled for MVP
2. Component reusability becomes a pain point
3. After higher-priority phases are complete

---

**Document Created**: 2025-12-26
**Next Phase**: Phase 4 - Dashboard Refactor (High Priority View Decomposition)
