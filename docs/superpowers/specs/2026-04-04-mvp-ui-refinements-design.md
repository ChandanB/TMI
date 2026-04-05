# MVP UI Refinements Design Spec

**Date:** 2026-04-04
**Status:** Approved

## Overview

Four UI refinements to reach MVP quality: fix form alignment, inline the interest entry flow, fix a button color, and add visual depth/hierarchy across card surfaces app-wide.

## Changes

### 1. Student Intake Form — Leading Alignment

**Problem:** Section content within the student creation form (grade picker, date of birth, school field labels) is centered instead of leading-justified, creating a disjointed layout.

**Fix:** In `StudentProfileView.swift`, ensure all section content VStacks use `alignment: .leading`. Specific targets:
- Grade Level label + picker
- Date of Birth label + picker
- School label + field
- Student ID label + field
- Any other centered labels within accordion sections

**Files:** `TMI/Views/Students/StudentProfileView.swift`

### 2. Inline Interest Entry — Remove Sheet

**Problem:** Adding a new interest requires opening a modal sheet with a single text field — too much friction for a simple action.

**Fix:** Replace the sheet-based flow with an inline text field + add button at the bottom of the interests list. The text field placeholder reads "Add an interest..." and a "+" button (or return key) creates the interest inline.

**Behavior:**
- Text field is always visible at the bottom of the interests chip list
- Typing a name and tapping "+" (or pressing return) creates the interest
- No sheet, no Cancel/Add toolbar buttons
- Remove `showNewInterestSheet` state and the `.sheet` modifier
- Keep the search/filter functionality for existing interests if present — this only replaces the "New" interest creation path

**Files:**
- `TMI/Views/Students/Sections/StudentInterestsSection.swift`
- `TMI/Views/TMIPlans/Sections/PlanInterestsSection.swift`

### 3. Career Explorer — Close Button Color

**Problem:** The dismiss button (`xmark.circle.fill`) in the Career Explorer toolbar renders with a blue tint. It should be white.

**Fix:** Change `.foregroundColor(Color.tmiTextSecondary)` to `.foregroundColor(.white)` on the dismiss button in the toolbar (line ~230).

**Files:** `TMI/Views/Career Explorer/CareerExplorerView.swift`

### 4. Layered Depth System — App-Wide Contrast

**Problem:** White cards on warm cream background with subtle 1px borders creates visual flatness. Cards blend into the background with no sense of hierarchy.

**Fix:** Implement a layered depth system with three changes:

#### 4a. New Color Tokens

Add to `Color+Extensions.swift`:
- `tmiBorderStrong`: `#D9D2C9` — warmer, more visible card border (replaces `#E8E2DA` for cards)
- `tmiSurfaceTinted`: `#F8F3ED` — subtle warm tint for section header backgrounds

#### 4b. Updated Shadow System

Update `TMIDesignTokens.swift` TMIElevation values:
- **Raised** (default cards): radius `4px`, y-offset `2px`, opacity `0.10` + secondary shadow radius `2px`, opacity `0.06`
- **Elevated**: radius `10px`, y-offset `4px`, opacity `0.12` + secondary shadow radius `4px`, opacity `0.08`
- **Floating**: radius `20px`, y-offset `8px`, opacity `0.14`

#### 4c. Updated TMICard Component

In `TMIComponentLibrary.swift`, update TMICard:
- **Default style:** border color from `tmiBorder` → `tmiBorderStrong`, apply updated raised shadow
- **Elevated style:** border `tmiBorderStrong`, apply updated elevated shadow
- **Outlined style:** border `tmiBorderStrong` (no shadow change)

#### 4d. Section Header Styling

For accordion sections in plan and student forms, add:
- Left accent border (3px `tmiSecondary` blue) on required/key sections
- Tinted header band (`tmiSurfaceTinted` background) for section headers within cards
- Apply to `TMIPlanEditorView.swift`, `TMIPlanDetailView.swift`, and `StudentProfileView.swift`

**Files:**
- `TMI/Helpers/Extensions/Color+Extensions.swift`
- `TMI/Core/DesignSystem/TMIDesignTokens.swift`
- `TMI/Views/Components/TMIComponentLibrary.swift`
- `TMI/Views/TMIPlans/TMIPlanEditorView.swift`
- `TMI/Views/TMIPlans/TMIPlanDetailView.swift`
- `TMI/Views/Students/StudentProfileView.swift`

## Out of Scope

- Career catalog expansion (user will handle separately)
- Dark mode support
- Text contrast changes (text readability is fine as-is)

## Files Summary

| File | Changes |
|------|---------|
| `Color+Extensions.swift` | Add `tmiBorderStrong`, `tmiSurfaceTinted` |
| `TMIDesignTokens.swift` | Update TMIElevation shadow values |
| `TMIComponentLibrary.swift` | Update TMICard border/shadow defaults |
| `StudentProfileView.swift` | Leading-justify sections, section header styling |
| `StudentInterestsSection.swift` | Inline interest entry |
| `PlanInterestsSection.swift` | Inline interest entry |
| `CareerExplorerView.swift` | Close button → white |
| `TMIPlanEditorView.swift` | Section header styling, accent borders |
| `TMIPlanDetailView.swift` | Section header styling, accent borders |
