# Warm-Light Visual Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform TMI from a dark cyberpunk aesthetic to a warm, light education-app theme derived from the gold schoolhouse logo.

**Architecture:** Token-first approach — update color/design tokens in 2 centralized files, then rewrite the component library, then sweep all consumer views. This minimizes per-file changes because most views inherit colors from tokens and components.

**Tech Stack:** SwiftUI, iOS 26+, Swift 6, Montserrat font family

**Spec:** `docs/superpowers/specs/2026-04-04-warm-light-redesign-design.md`

---

### Task 1: Force Light Mode Globally

**Files:**
- Modify: `TMI/App/TMIApp.swift:56`
- Modify: 35 additional view files (remove `.preferredColorScheme(.dark)`)

- [ ] **Step 1: Update TMIApp.swift root color scheme**

In `TMI/App/TMIApp.swift`, change line 56 from `.preferredColorScheme(.dark)` to `.preferredColorScheme(.light)`.

- [ ] **Step 2: Remove all `.preferredColorScheme(.dark)` from Authentication views**

Remove the `.preferredColorScheme(.dark)` modifier from each of these files/lines:
- `TMI/Views/Authentication/AuthenticationView.swift` — lines 204, 209, 235
- `TMI/Views/Authentication/RegistrationView.swift` — line 288
- `TMI/Views/Authentication/RoleSelectionView.swift` — lines 114, 119, 131, 148, 466, 853

- [ ] **Step 3: Remove all `.preferredColorScheme(.dark)` from Forms views**

Remove from:
- `TMI/Views/Forms/FormPreviewView.swift` — line 123
- `TMI/Views/Forms/FormBuilderView.swift` — line 81
- `TMI/Views/Forms/FormImportView.swift` — line 116
- `TMI/Views/Forms/FormTemplateDetailView.swift` — line 124
- `TMI/Views/Forms/FormView.swift` — line 321
- `TMI/Views/Forms/FormCreationView.swift` — line 146
- `TMI/Views/Forms/FormsAndSurveysView.swift` — line 112

- [ ] **Step 4: Remove all `.preferredColorScheme(.dark)` from remaining views**

Remove from:
- `TMI/Views/InterestsAndHobbies/InterestsAndHobbiesView.swift` — lines 72, 1051
- `TMI/Views/Career Explorer/CareerExplorerView.swift` — lines 238, 1566, 2156
- `TMI/Views/Career Explorer/CareerDetailView.swift` — line 2376
- `TMI/Views/Goals/AddGoalView.swift` — line 180
- `TMI/Views/Goals/EditGoalView.swift` — line 88
- `TMI/Views/Resources/ResourcesView.swift` — lines 259, 926
- `TMI/Views/Resources/ResourceDetailView.swift` — line 152
- `TMI/Views/Resources/AddResourceView.swift` — line 119
- `TMI/Views/Recommendations/RecommendationsView.swift` — line 78
- `TMI/Views/Dashboard/DashboardInsightsView.swift` — lines 198, 374
- `TMI/Views/Dashboard/DashboardView.swift` — line 1349
- `TMI/Views/TMIPlans/TMIPlanDetailView.swift` — line 323
- `TMI/Views/TMIPlans/AddInterestToPlanView.swift` — line 137
- `TMI/Views/StudentMode/StudentModeView.swift` — line 65
- `TMI/Views/Students/StudentMainView.swift` — line 72
- `TMI/Views/Students/BulkActionsView.swift` — line 171
- `TMI/Views/Students/AddInterestToStudentView.swift` — line 139
- `TMI/Views/Students/StudentListFilterView.swift` — line 57
- `TMI/Views/User/UserProfileView.swift` — lines 393, 688
- `TMI/Views/Settings/SettingsView.swift` — line 100
- `TMI/Views/Settings/DataExportView.swift` — line 117
- `TMI/Views/Settings/DataImportView.swift` — line 82

- [ ] **Step 5: Build and verify**

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "refactor: force light mode globally, remove 46 .preferredColorScheme(.dark) directives"
```

---

### Task 2: Update Color Tokens

**Files:**
- Modify: `TMI/Helpers/Extensions/Color+Extensions.swift`
- Modify: `TMI/Core/DesignSystem/TMIDesignTokens.swift`

- [ ] **Step 1: Rewrite Color+Extensions.swift**

Replace the color definitions with the new warm-light palette. Key changes:
- `tmiPrimary` → `#D4930D` (gold)
- `tmiSecondary` → `#3B6FA0` (warm blue)
- `tmiBackground` → `#FDF8F3` (warm cream)
- `tmiText` → delete entirely (replaced by `tmiTextPrimary`). Any compile errors from consumers using `.tmiText` will be fixed in the foreground color sweep (Task 9).
- Delete `backgroundTop`, `backgroundBottom`
- Rename `tmiPrimaryDark` → `tmiPrimaryDeep` with value `#B87A0A`
- Rename `cardBackground` → `tmiCardBackground` with value `#FFFFFF`
- Add `tmiTextBrand` = `#D4930D`
- Add `tmiTextOnPrimary` = `#FFFFFF`
- Add `tmiTextOnSecondary` = `#FFFFFF`
- Add `tmiInputBackground` = `#F5F0EB`
- Update `tmiSuccess` → `#2D9F6F`
- Update `tmiWarning` → `#E8A817`
- Update `tmiError` → `#DC3545`
- Update `tmiInfo` → `#3B6FA0`
- Update `tmiSurface` → `#FFFFFF`
- Update `tmiSurfaceElevated` → `#FFFFFF`
- Update `tmiTextPrimary` → `#2D3436`
- Update `tmiTextSecondary` → `#636E72`
- Update `tmiTextTertiary` → `#94908B`
- Update `tmiBorder` → `#E8E2DA`
- Update `tmiDivider` → `#F0EBE4`

Remove the `Color(light:dark:)` initializer usage — all tokens are now single values (light-only for MVP). Remove `#if DEBUG` block with `debugTMI*` colors. Delete `backgroundTop`, `backgroundBottom` tokens entirely (zero active consumers). Delete `tmiText` token (replaced by `tmiTextPrimary`).

- [ ] **Step 2: Update TMIDesignTokens.swift elevation shadows**

Update `TMIElevation` shadow color from implicit black to `Color(hex: "#2D3436")`:
- `.raised`: radius 2, opacity 0.05, offset (0, 1)
- `.elevated`: radius 8, opacity 0.08, offset (0, 4)
- `.floating`: radius 16, opacity 0.12, offset (0, 8)

- [ ] **Step 3: Build and verify**

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (may have warnings about renamed tokens — that's fine, we'll fix consumers in later tasks)

- [ ] **Step 4: Commit**

```bash
git add TMI/Helpers/Extensions/Color+Extensions.swift TMI/Core/DesignSystem/TMIDesignTokens.swift && git commit -m "feat: update color tokens to warm-light palette"
```

---

### Task 3: Rewrite TMIBackgroundView

**Files:**
- Modify: `TMI/Views/Components/TMIComponentLibrary.swift:31-156`

- [ ] **Step 1: Replace TMIBackgroundView implementation**

Replace the entire `TMIBackgroundView` struct (lines 31-156) with a simplified version. Remove:
- All 5 gradient color definitions
- Animated blob overlays (primary/secondary circles with blur)
- `TMIParticleEffect` conditional rendering
- `@State` animation properties

New implementation has 2 variants:
- `.default` (also covers `.dashboard`, `.career`, `.plans`): Solid `Color.tmiBackground` with `.ignoresSafeArea()`
- `.auth`: `LinearGradient` from `Color(hex: "#FDF8F3")` to `Color(hex: "#F5EDE3")` top-to-bottom with `.ignoresSafeArea()`

Keep the `BackgroundVariant` enum but simplify — `.dashboard`, `.career`, `.plans` all resolve to the same solid background as `.default`.

- [ ] **Step 2: Delete TMIParticleEffect struct**

Remove the entire `TMIParticleEffect` struct (lines 408-481) and the `Particle` model it uses. Also remove the `import SpriteKit` at the top of the file if it's only used by particles.

- [ ] **Step 3: Build and verify**

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add TMI/Views/Components/TMIComponentLibrary.swift && git commit -m "refactor: simplify TMIBackgroundView to warm-light solid/gradient, delete TMIParticleEffect"
```

---

### Task 4: Rewrite TMIGlassCard → TMICard

**Files:**
- Modify: `TMI/Views/Components/TMIComponentLibrary.swift:159-349`
- Modify: `TMI/Core/DesignSystem/RedesignBridge.swift:117-145`

- [ ] **Step 1: Replace TMIGlassCardStyle enum with TMICardStyle**

Replace the `TMIGlassCardStyle` enum (lines 159-230) with a new `TMICardStyle` enum that has 3 cases: `.default`, `.elevated`, `.outlined`.

Properties for each:
- `.default`: cornerRadius 12, padding 20, border 1px `#E8E2DA`, shadow raised (2px, 0.05), bg `#FFFFFF`
- `.elevated`: cornerRadius 16, padding 24, no border, shadow elevated (8px, 0.08), bg `#FFFFFF`
- `.outlined`: cornerRadius 12, padding 20, border 1px `#E8E2DA`, no shadow, bg transparent

Add a `typealias TMIGlassCardStyle = TMICardStyle` for backward compatibility during migration.

Add mapping from old names: `.auth` → `.elevated`, `.dashboard` → `.default`, `.form` → `.default`, `.minimal` → `.outlined`, `.error` → `.default` (error styling handled separately with left accent border).

- [ ] **Step 2: Replace TMIGlassCard struct with TMICard**

Replace the `TMIGlassCard<Content>` struct (lines 234-349) with `TMICard<Content>`. Remove:
- `ultraThinMaterial` overlay
- `positionBasedGradient()` method
- `shadowOffset(for:)` geometry-based shadow method
- Gradient border overlay
- `@State private var isHovering` and hover scale effect

New implementation:
```swift
struct TMICard<Content: View>: View {
    let style: TMICardStyle
    let content: Content

    init(style: TMICardStyle = .default, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        content
            .padding(style.padding)
            .background(style.background)
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
            .overlay(
                style.hasBorder
                    ? RoundedRectangle(cornerRadius: style.cornerRadius)
                        .stroke(Color.tmiBorder, lineWidth: 1)
                    : nil
            )
            .shadow(
                color: Color(hex: "#2D3436").opacity(style.shadowOpacity),
                radius: style.shadowRadius,
                x: 0, y: style.shadowOffset
            )
    }
}
```

Add `typealias TMIGlassCard = TMICard` for backward compatibility.

- [ ] **Step 3: Update the `tmiGlassCard(style:)` view modifier**

Rename to `tmiCard(style:)` and update implementation to use the new solid card styling. Keep `tmiGlassCard(style:)` as a deprecated alias.

- [ ] **Step 4: Remove TMICardStyle from RedesignBridge.swift**

Delete the duplicate `TMICardStyle` enum (lines 117-145) and the `tmiCard()` view extension from `RedesignBridge.swift`. The single `TMICardStyle` in `TMIComponentLibrary.swift` now serves both purposes.

- [ ] **Step 5: Build and verify**

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (typealiases ensure backward compat)

- [ ] **Step 6: Commit**

```bash
git add TMI/Views/Components/TMIComponentLibrary.swift TMI/Core/DesignSystem/RedesignBridge.swift && git commit -m "refactor: replace TMIGlassCard with solid TMICard, consolidate card style enums"
```

---

### Task 5: Rewrite TMIButton, TMITextField, TMIProgressViewStyle, TMILogoView

**Files:**
- Modify: `TMI/Views/Components/TMIComponentLibrary.swift` (buttons: 487-680, textfield: 686-752, progress: 758-787, logo: 353-404)

- [ ] **Step 1: Update TMIButton colors**

In the `TMIButton` struct, update the color properties for each style:
- `.primary`: foreground `#FFFFFF`, background `Color.tmiSecondary` (`#3B6FA0`), shadow `Color.tmiSecondary.opacity(0.15)`
- `.secondary`: foreground `Color.tmiSecondary`, background `.clear`, border `Color.tmiSecondary` 1.5px
- `.tertiary`: foreground `Color.tmiSecondary`, background `Color(hex: "#F0EBE4")`
- `.destructive`: foreground `#FFFFFF`, background `Color.tmiError`
- `.floating`: foreground `#FFFFFF`, background `Color.tmiPrimary` (`#D4930D`), shadow `Color.tmiPrimary.opacity(0.15)`
- `.filter` selected: foreground `#FFFFFF`, background `Color.tmiSecondary`
- `.filter` unselected: foreground `Color.tmiTextSecondary`, background `Color(hex: "#F0EBE4")`, border `Color.tmiBorder` 1px
- `.icon`: foreground `Color.tmiTextSecondary`, background `Color(hex: "#F0EBE4")`

- [ ] **Step 2: Update TMITextField**

Replace the dark background + material implementation:
- Background: `Color.tmiInputBackground` (`#F5F0EB`) solid — remove `ultraThinMaterial` overlay
- Text color: `Color.tmiTextPrimary` (was `.white`)
- Placeholder: `Color.tmiTextTertiary` (was `white.opacity(0.6)`)
- Icon default: `Color.tmiTextTertiary` (was `white.opacity(0.6)`)
- Icon focused: `Color.tmiSecondary` (keep)
- Border unfocused: `Color.tmiBorder` 1px solid (was white gradient)
- Border focused: `Color.tmiSecondary` 1.5px solid (was gradient)
- Shadow: `Color(hex: "#2D3436").opacity(0.04)` radius 5

- [ ] **Step 3: Update TMIProgressViewStyle**

Update the `TMIProgressViewStyle`:
- Track: `Color.tmiBorder` (`#E8E2DA`) — was `Color.white.opacity(0.1)`
- Fill: `LinearGradient` of `Color.tmiPrimary` to `Color.tmiPrimary.opacity(0.8)` — was `tmiSecondary`
- Remove shadow on fill (was `color.opacity(0.5)`)

- [ ] **Step 4: Update TMILogoView**

Replace the neon brain logo:
- Remove the radial gradient glow circle
- Replace `Image(systemName: "brain.head.profile")` with `Image("schoolhouse-mark")` (asset to be created in Task 11)
- **Note: The schoolhouse image asset is a design dependency** — the actual PNG files need to be created by a designer from the app icon spec. As a temporary fallback until the asset exists, use `Image(systemName: "building.columns")` with `Color.tmiPrimary` foreground
- Remove rotation and scale animations
- Change "TMI" text color from `.white` to `Color.tmiTextPrimary`
- Add subtitle "TANGIBLE MODIFICATION INTERVENTION" in `Color.tmiTextBrand`, 12pt, weight `.semibold`, letter spacing 1

- [ ] **Step 5: Build and verify**

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add TMI/Views/Components/TMIComponentLibrary.swift && git commit -m "refactor: update buttons, text fields, progress bar, and logo to warm-light theme"
```

---

### Task 6: Delete Dead Code (PremiumGlassTabBar, PremiumSidebarList)

**Files:**
- Modify: `TMI/Views/Components/UIComponents.swift:15-234`
- Modify: `TMI/Views/MainTabView.swift:140`

- [ ] **Step 1: Delete PremiumGlassTabBar and PremiumSidebarList**

In `UIComponents.swift`:
- Delete `PremiumGlassTabBar` struct (lines 15-127)
- Delete `PremiumSidebarList` struct (lines 131-234)

These are confirmed dead code — `MainTabView` uses native `.tabViewStyle(.sidebarAdaptable)`.

- [ ] **Step 2: Update MainTabView accent color**

In `TMI/Views/MainTabView.swift`, change line 140 from:
```swift
.accentColor(.tmiSecondary)
```
to:
```swift
.tint(.tmiPrimary)
```

- [ ] **Step 3: Clean up remaining UIComponents.swift glass effects**

In the remaining components in `UIComponents.swift` (StatCircle, LottieLoadingView, RecommendationRow, TimeFrameSelector, InsightsButtonView, DashboardAlignmentChartView, StatCard):
- Replace any `.ultraThinMaterial` with `Color.tmiSurface`
- Replace `Color.white.opacity(X)` foreground colors with `Color.tmiTextPrimary` / `Color.tmiTextSecondary` as appropriate
- Replace `Color.black.opacity(X)` backgrounds with `Color.tmiSurface`
- Replace `Color.tmiSecondary` accent colors — keep for interactive elements, but update any that should be `Color.tmiPrimary` (gold) for branding elements

- [ ] **Step 4: Build and verify**

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add TMI/Views/Components/UIComponents.swift TMI/Views/MainTabView.swift && git commit -m "refactor: delete PremiumGlassTabBar/SidebarList, update tab tint to gold, clean UIComponents"
```

---

### Task 7: Update RedesignComponents.swift

**Files:**
- Modify: `TMI/Core/DesignSystem/RedesignComponents.swift`

- [ ] **Step 1: Update component colors in RedesignComponents.swift**

These components already use semantic tokens (`Color.tmiTextPrimary`, `Color.tmiSurface`, etc.) which will auto-update from Task 2. But verify and fix any hardcoded colors:

- `TMIListRow`: Should already work — uses `tmiTextPrimary`, `tmiTextSecondary`, `tmiSurface`
- `TMIStatChip`: Should already work — uses `tmiTextSecondary`, `tmiSurface`
- `TMIEmptyState`: Should already work — uses `tmiTextTertiary`, `tmiTextPrimary`, `tmiTextSecondary`
- `TMISearchBar`: Should already work — uses `tmiSurface`, `tmiTextSecondary`, `tmiTextPrimary`
- `TMIFilterChip`: Update selected background from `tmiPrimary` (now gold) — verify this is the desired behavior for filter chips. If filter chips should be blue, change to `tmiSecondary`.
- `TMIFAB`: Uses `tmiPrimary` — now gold, correct per spec
- `TMIAvatar`: Update fallback background from solid color to `color.opacity(0.15)` tint per spec. Remove any 2px border styling. Change initials text color from white to the matching accent color at full saturation. Example: for a blue-assigned student, background becomes `Color.blue.opacity(0.15)` and initials become `Color.blue`.
- `TMIProgressCircle`: Track uses `tmiBorder` (auto-updated), progress uses `tmiPrimary` (now gold, correct)

- [ ] **Step 2: Build and verify**

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TMI/Core/DesignSystem/RedesignComponents.swift && git commit -m "refactor: verify and fix RedesignComponents for warm-light palette"
```

---

### Task 8: Global `.ultraThinMaterial` Sweep

**Files:** 26 files with ~90 occurrences (see list below)

Replace every `.ultraThinMaterial` with the appropriate solid alternative. The replacement depends on context:
- Card/container background: `Color.tmiSurface` (white)
- Overlay/sheet background: `Color.tmiSurface`
- Toolbar/bar background: `Color.tmiSurface`
- Also remove any associated `.opacity(X)` on the material, and any `backdrop-filter`/`.blur()` modifiers that were part of the glass effect

- [ ] **Step 1: Sweep Career Explorer views (35 occurrences)**

Files:
- `TMI/Views/Career Explorer/CareerDetailView.swift` — 20 occurrences
- `TMI/Views/Career Explorer/CareerExplorerView.swift` — 14 occurrences

Replace each `.ultraThinMaterial` with `Color.tmiSurface`. Where it's used as a background overlay, replace with `Color.tmiSurface` and appropriate shadow from `TMIElevation`.

- [ ] **Step 2: Sweep TMI Plans views (8 occurrences)**

Files:
- `TMI/Views/TMIPlans/TMIPlanDetailView.swift` — 8 occurrences
- `TMI/Views/TMIPlans/TMIPlanCard.swift` — 1 occurrence

- [ ] **Step 3: Sweep Meetings views (8 occurrences)**

Files:
- `TMI/Views/Meetings/MeetingListView.swift` — 1 occurrence
- `TMI/Views/Meetings/MeetingCalendarView.swift` — 4 occurrences
- `TMI/Views/Meetings/CreateEditMeetingView.swift` — 8 occurrences

- [ ] **Step 4: Sweep Resources views (7 occurrences)**

Files:
- `TMI/Views/Resources/AddResourceView.swift` — 4 occurrences
- `TMI/Views/Resources/ResourcesView.swift` — 2 occurrences
- `TMI/Views/Resources/ResourceDetailView.swift` — 2 occurrences
- `TMI/Views/Resources/ResourceCard.swift` — 1 occurrence

- [ ] **Step 5: Sweep Interests, Compliance, Recommendations, and remaining views**

Files:
- `TMI/Views/InterestsAndHobbies/InterestsAndHobbiesView.swift` — 1 occurrence
- `TMI/Views/InterestsAndHobbies/InterestsAndHobbiesHelpers.swift` — 4 occurrences
- `TMI/Views/Compliance/ConsentManagementView.swift` — 1 occurrence
- `TMI/Views/Compliance/AuditLogListView.swift` — 1 occurrence
- `TMI/Views/Recommendations/RecommendationsView.swift` — 4 occurrences
- `TMI/Views/District/PendingApprovalsWidget.swift` — 1 occurrence
- `TMI/Views/StudentMode/StudentModeView.swift` — 1 occurrence
- `TMI/Views/Goals/AddGoalView.swift` — 1 occurrence
- `TMI/Views/Students/StudentListFilterView.swift` — 1 occurrence
- `TMI/Views/Students/StudentListComponents.swift` — 1 occurrence
- `TMI/Views/Dashboard/InsightsView.swift` — 2 occurrences
- `TMI/Views/Components/SharedSectionHelpers.swift` — 1 occurrence

- [ ] **Step 6: Build and verify**

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "refactor: replace all .ultraThinMaterial with solid surfaces across 26 files"
```

---

### Task 9: Global Foreground Color Sweep

**Files:** 84 files with ~570 occurrences

This is the largest single task. Replace `.foregroundColor(.white)` and `.foregroundStyle(.white)` with semantic color tokens based on context:
- **Text on light backgrounds** → `Color.tmiTextPrimary` (charcoal `#2D3436`)
- **Secondary text on light backgrounds** → `Color.tmiTextSecondary` (`#636E72`)
- **Text on colored button backgrounds** (blue/gold/red) → `Color.tmiTextOnSecondary` (white) — these stay white, no change needed
- **Icon tints on light backgrounds** → `Color.tmiTextSecondary` or `Color.tmiTextTertiary`

Also replace `.foregroundColor(.tmiText)` (3 occurrences in `TMIStatCard.swift`) with `Color.tmiTextPrimary`.

**Strategy:** Work through files grouped by feature area, largest concentrations first.

- [ ] **Step 1: Sweep Career Explorer (74 occurrences)**

Files:
- `TMI/Views/Career Explorer/CareerExplorerView.swift` — 36 occurrences
- `TMI/Views/Career Explorer/CareerDetailView.swift` — 38 occurrences

For each `.foregroundColor(.white)`, determine from context:
- If it's body/heading text → `.foregroundColor(.tmiTextPrimary)`
- If it's subtitle/caption text → `.foregroundColor(.tmiTextSecondary)`
- If it's on a colored background (button, badge) → leave as white or use `.tmiTextOnSecondary`
- If it's an icon → `.foregroundColor(.tmiTextSecondary)`

- [ ] **Step 2: Sweep Forms (52 occurrences)**

Files:
- `TMI/Views/Forms/FormView.swift` — 8
- `TMI/Views/Forms/FormSubmissionsView.swift` — 8
- `TMI/Views/Forms/FormComponents.swift` — 8
- `TMI/Views/Forms/FormTemplateDetailView.swift` — 6
- `TMI/Views/Forms/FormCreationView.swift` — 6
- `TMI/Views/Forms/FormBuilderView.swift` — 3
- `TMI/Views/Forms/FormPreviewView.swift` — 3
- `TMI/Views/Forms/FormImportView.swift` — 3
- `TMI/Views/Forms/FormsAndSurveysView.swift` — 2
- `TMI/Views/Forms/FormStoreCardView.swift` — 2
- `TMI/Views/Forms/MyFormsView.swift` — 2
- `TMI/Views/Forms/StudentFormListView.swift` — 1

- [ ] **Step 3: Sweep TMI Plans (52 occurrences)**

Files:
- `TMI/Views/TMIPlans/TMIPlanDetailView.swift` — 41
- `TMI/Views/TMIPlans/TMIPlanCard.swift` — 5
- `TMI/Views/TMIPlans/AddInterestToPlanView.swift` — 4
- `TMI/Views/TMIPlans/PlanTemplateLibraryView.swift` — 1
- `TMI/Views/TMIPlans/Sections/PlanInterestsSection.swift` — 1 (`.foregroundStyle(.white)`)
- `TMI/Views/TMIPlans/Sections/PlanCareersSection.swift` — 1 (`.foregroundStyle(.white)`)

- [ ] **Step 4: Sweep Interests & Hobbies (48 occurrences)**

Files:
- `TMI/Views/InterestsAndHobbies/InterestsAndHobbiesView.swift` — 17
- `TMI/Views/InterestsAndHobbies/InterestDetailView.swift` — 15
- `TMI/Views/InterestsAndHobbies/StudentInterestProfileView.swift` — 11

- [ ] **Step 5: Sweep Compliance (43 occurrences)**

Files:
- `TMI/Views/Compliance/ComplianceSettingsView.swift` — 22
- `TMI/Views/Compliance/ConsentManagementView.swift` — 15
- `TMI/Views/Compliance/AuditLogListView.swift` — 6

- [ ] **Step 6: Sweep Resources (42 occurrences)**

Files:
- `TMI/Views/Resources/ResourcesView.swift` — 14
- `TMI/Views/Resources/ResourceDetailView.swift` — 14
- `TMI/Views/Resources/AddResourceView.swift` — 8
- `TMI/Views/Resources/AssignedResourcesView.swift` — 5
- `TMI/Views/Resources/ResourceCard.swift` — 1

- [ ] **Step 7: Sweep Student Mode (38 occurrences)**

Files:
- `TMI/Views/StudentMode/StudentModeView.swift` — 17
- `TMI/Views/StudentMode/StudentTMIPlanDetailView.swift` — 10
- `TMI/Views/StudentMode/StudentInterestDetailView.swift` — 6
- `TMI/Views/StudentMode/StudentPeerProfileView.swift` — 5

- [ ] **Step 8: Sweep Meetings (36 occurrences)**

Files:
- `TMI/Views/Meetings/CreateEditMeetingView.swift` — 13
- `TMI/Views/Meetings/MeetingDetailView.swift` — 12
- `TMI/Views/Meetings/MeetingListView.swift` — 6
- `TMI/Views/Meetings/MeetingCalendarView.swift` — 5

- [ ] **Step 9: Sweep Students, Dashboard, Settings, Goals, Auth, User, Recommendations, District, Components, App**

Files:
- `TMI/Views/Students/StudentMainView.swift` — 7
- `TMI/Views/Students/AddInterestToStudentView.swift` — 7
- `TMI/Views/Students/BulkActionsView.swift` — 6
- `TMI/Views/Students/StudentCard.swift` — 3
- `TMI/Views/Students/StudentListComponents.swift` — 2
- `TMI/Views/Students/StudentListFilterView.swift` — 2
- `TMI/Views/Students/Sections/StudentCareersSection.swift` — 1
- `TMI/Views/Students/Sections/StudentInterestsSection.swift` — 1
- `TMI/Views/Dashboard/DashboardInsightsView.swift` — 8
- `TMI/Views/Dashboard/Components/TMIStatCard.swift` — 4 (includes 3x `.tmiText`)
- `TMI/Views/Dashboard/DashboardView.swift` — 1
- `TMI/Views/Dashboard/InsightsView.swift` — 1
- `TMI/Views/Settings/DataImportView.swift` — 11
- `TMI/Views/Settings/DataExportView.swift` — 7
- `TMI/Views/Settings/SettingsView.swift` — 5
- `TMI/Views/Goals/AddGoalView.swift` — 9
- `TMI/Views/Goals/EditGoalView.swift` — 9
- `TMI/Views/Authentication/RoleSelectionView.swift` — 8
- `TMI/Views/Authentication/AuthenticationView.swift` — 3
- `TMI/Views/Authentication/RegistrationView.swift` — 3
- `TMI/Views/Authentication/SimplifiedRegistrationView.swift` — 2
- `TMI/Views/User/UserProfileView.swift` — 16
- `TMI/Views/Recommendations/RecommendationsView.swift` — 11
- `TMI/Views/District/StudentsNeedingAttentionList.swift` — 5
- `TMI/Views/Components/NotificationCenterView.swift` — 2
- `TMI/Views/Components/AccordionSection.swift` — 2
- `TMI/App/TMIApp.swift` — 3
- `TMI/Core/DesignSystem/RedesignComponents.swift` — 1
- `TMI/Services/StudentAccessPolicy.swift` — 1
- `TMI/StateModels/BaseStateModel.swift` — 1

- [ ] **Step 10: Build and verify**

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 11: Commit**

```bash
git add -A && git commit -m "refactor: replace ~570 hardcoded white foreground colors with semantic tokens across 84 files"
```

---

### Task 10: Rename TMIGlassCard → TMICard Across All Consumers

**Files:** 48 files with 143 occurrences

Now that the typealiases are in place (from Task 4), do the actual rename in all consumer files. This is a find-and-replace operation.

- [ ] **Step 1: Global find-and-replace `TMIGlassCard(` → `TMICard(`**

Run across all `.swift` files in the `TMI/` directory. This replaces the struct usage.

Also replace:
- `TMIGlassCardStyle.` → `TMICardStyle.`
- `.tmiGlassCard(` → `.tmiCard(`

Map old style names to new:
- `.default` → `.default`
- `.elevated` → `.elevated`
- `.auth` → `.elevated`
- `.dashboard` → `.default`
- `.form` → `.default`
- `.minimal` → `.outlined`
- `.error` → `.default` (add left accent border where error card was used)

- [ ] **Step 2: Remove typealiases from TMIComponentLibrary.swift**

Now that all consumers are updated, remove:
```swift
typealias TMIGlassCard = TMICard
typealias TMIGlassCardStyle = TMICardStyle
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "refactor: rename TMIGlassCard to TMICard across 48 consumer files"
```

---

### Task 11: Create Schoolhouse Logo Asset

**Files:**
- Create: `TMI/Assets.xcassets/schoolhouse-mark.imageset/`
- Modify: `TMI/Views/Components/TMIComponentLibrary.swift` (TMILogoView)

- [ ] **Step 1: Create imageset directory structure**

```bash
mkdir -p "TMI/Assets.xcassets/schoolhouse-mark.imageset"
```

- [ ] **Step 2: Create Contents.json for the imageset**

Create `TMI/Assets.xcassets/schoolhouse-mark.imageset/Contents.json`:
```json
{
  "images" : [
    {
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Note: The actual image files need to be designed and exported from the app icon design. For now, the `TMILogoView` uses the SF Symbol fallback (`building.columns`) set up in Task 5. When the schoolhouse-mark images are ready, add them to this imageset and update `TMILogoView` to use `Image("schoolhouse-mark")`.

- [ ] **Step 3: Commit**

```bash
git add TMI/Assets.xcassets/schoolhouse-mark.imageset/ && git commit -m "chore: add schoolhouse-mark imageset placeholder for logo asset"
```

---

### Task 12: Screen-Specific Layout Fixes

**Files:**
- Modify: `TMI/Views/Authentication/AuthenticationView.swift`
- Modify: `TMI/Views/Dashboard/DashboardView.swift`
- Modify: `TMI/Views/Students/StudentCard.swift`

- [ ] **Step 1: Update AuthenticationView layout**

In `AuthenticationView.swift`:
- The `TMILogoView` is already updated from Task 5
- The `TMIGlassCard(style: .auth)` is now `TMICard(style: .elevated)` from Task 10
- The `TMITextField` and `TMIButton` components are updated from Task 5
- Check for any remaining hardcoded colors (white text, dark backgrounds) missed by the sweep
- Verify the "Forgot Password?" link uses `Color.tmiSecondary` with font size 13 and weight `.medium`
- Verify "New here? Create an account" uses `Color.tmiTextSecondary` with `Color.tmiSecondary` for the link portion

- [ ] **Step 2: Update DashboardView greeting and empty state**

In `TMI/Views/Dashboard/DashboardView.swift`:
- If the dashboard header currently says "Teacher Action Board", update to show a greeting: "Good morning!" (or time-appropriate greeting) with `Color.tmiTextPrimary`
- Add a 32x32 icon next to the greeting using `Image(systemName: "building.columns").foregroundColor(.tmiPrimary)` (temporary until schoolhouse asset)
- Update the subheader to "Here's your classroom overview" in `Color.tmiTextSecondary`
- For Quick Action cards: add 3px left accent borders using `.overlay(alignment: .leading)` with a `Rectangle().frame(width: 3).foregroundColor(accentColor)`. Accent colors per action:
  - Add Student: `Color(hex: "#D4930D")` (gold)
  - TMI Plans: `Color(hex: "#5B8C5A")` (sage)
  - Reports: `Color(hex: "#E07A5F")` (coral)
  - All Students: `Color(hex: "#3B6FA0")` (blue)
- For empty state: use dashed border via `.overlay(RoundedRectangle(cornerRadius: 12).stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 3])).foregroundColor(.tmiBorder))`, wave emoji, encouraging copy "Welcome! Let's get started" with `Color.tmiTextPrimary`, subtitle "Add your first student to begin building TMI plans" in `Color.tmiTextSecondary`, and a `TMIButton(style: .primary)` CTA

- [ ] **Step 3: Update StudentCard avatar styling**

In `TMI/Views/Students/StudentCard.swift`:
- Replace gradient avatar circle with soft tinted initials
- Background: student accent color at 0.15 opacity (e.g., `Color.blue.opacity(0.15)`)
- Remove 2px `tmiPrimary` border
- Initials text: matching accent color at full saturation, weight `.bold`
- Add chevron disclosure indicator (`Image(systemName: "chevron.right")` in `Color.tmiTextTertiary`)

- [ ] **Step 4: Build and verify**

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add TMI/Views/Authentication/AuthenticationView.swift TMI/Views/Dashboard/DashboardView.swift TMI/Views/Students/StudentCard.swift && git commit -m "feat: update auth, dashboard, and student card layouts for warm-light theme"
```

---

### Task 13: Final Cleanup and Verification

**Files:** Various

- [ ] **Step 1: Search for any remaining dark-theme artifacts**

Run these searches and fix any hits:
- `grep -r "Color.black" TMI/ --include="*.swift" | grep -v ".xcassets" | grep -v "shadow"` — any non-shadow black references
- `grep -r "opacity(0\." TMI/ --include="*.swift" | grep "white"` — any `Color.white.opacity()` still in use
- `grep -r "ultraThinMaterial\|ultraThickMaterial\|thinMaterial\|thickMaterial" TMI/ --include="*.swift"` — any remaining material effects
- `grep -r "preferredColorScheme" TMI/ --include="*.swift"` — should only be `.light` in TMIApp.swift
- `grep -r "backgroundTop\|backgroundBottom" TMI/ --include="*.swift"` — should be zero hits
- `grep -r "debugTMI" TMI/ --include="*.swift"` — should be zero hits
- `grep -r "tmiText[^PSOBT]" TMI/ --include="*.swift"` — should be zero hits (old `tmiText` token deleted, only `tmiTextPrimary`/`tmiTextSecondary`/etc. remain)
- `grep -r "TMIGlassCard\|tmiGlassCard\|TMIGlassCardStyle" TMI/ --include="*.swift"` — should be zero hits (aliases removed)

- [ ] **Step 2: Fix any remaining issues found in Step 1**

Address each finding from the grep searches.

- [ ] **Step 3: Full build**

Run: `xcodebuild build -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED with zero errors

- [ ] **Step 4: Commit final cleanup**

```bash
git add -A && git commit -m "chore: final cleanup of dark-theme artifacts"
```
