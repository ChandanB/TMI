# TMI Visual Redesign -- Developer Handoff Spec

**Date:** 2026-04-04
**Direction:** Dark cyberpunk to warm, light, professional theme for educators and counselors
**Summary:** Gold/amber branding, warm blue interactives, warm off-white backgrounds, solid opaque cards (no glass morphism)

---

## 1. Design Tokens -- New Color Palette

### 1.1 Primary Colors

| Token | Old Value | New Hex | New RGB | Usage |
|---|---|---|---|---|
| `tmiPrimary` | `#4A90E2` (rgb 0.29, 0.56, 0.89) | `#C8870E` | rgb(200, 135, 14) | Brand gold/amber -- logos, accents, active states |
| `tmiPrimaryDark` | `#3871B4` | `#A06D0B` | rgb(160, 109, 11) | Pressed/dark variant of primary |
| `tmiSecondary` | `#3DACED` (rgb 0.24, 0.67, 0.97) | `#3B7DD8` | rgb(59, 125, 216) | Interactive blue -- buttons, links, focus rings |

### 1.2 Background Colors

| Token | Old Value | New Hex | Usage |
|---|---|---|---|
| `tmiBackground` | `#000000` (pure black) | `#FAF8F5` | App-level background (warm off-white) |
| `tmiSurface` | dark: `#000F24` / light: `#F9FAFB` | `#FFFFFF` | Card surfaces, elevated containers |
| `tmiSurfaceElevated` | dark: `rgba(46,46,61)` / light: `#FFFFFF` | `#FFFFFF` | Sheets, modals |
| `cardBackground` | `rgba(0,0,0,0.5)` | `#FFFFFF` | All card backgrounds |

### 1.3 Text Colors

| Token | Old Value | New Hex | Usage |
|---|---|---|---|
| `tmiText` | `#D9F2F4` (light cyan) | `#1A1A1A` | Primary body text |
| `tmiTextPrimary` | dark: `#F9FAFB` | `#1A1A1A` | Headlines, titles |
| `tmiTextSecondary` | dark: `#9CA3AF` | `#6B7280` | Subtitles, captions |
| `tmiTextTertiary` | dark: `#D1D5DB` | `#9CA3AF` | Placeholder text, disabled labels |
| All `.foregroundColor(.white)` | `#FFFFFF` | `#1A1A1A` or `tmiTextPrimary` | All text on light backgrounds |
| All `.white.opacity(0.7)` | semi-white | `#6B7280` (`tmiTextSecondary`) | Secondary text |
| All `.white.opacity(0.6)` | semi-white | `#9CA3AF` (`tmiTextTertiary`) | Tertiary/placeholder |

### 1.4 Border and Divider Colors

| Token | Old Value | New Hex | Usage |
|---|---|---|---|
| `tmiBorder` | dark: `#374151` | `#E5E7EB` | Card borders, input borders |
| `tmiDivider` | dark: `#1F2937` | `#F3F4F6` | Section dividers |

### 1.5 Semantic Colors (keep as-is, they already have light variants)

| Token | Light Value | Notes |
|---|---|---|
| `tmiSuccess` | `#10B981` | Keep |
| `tmiWarning` | `#F59E0B` | Keep |
| `tmiError` | `#EF4444` | Keep |
| `tmiInfo` | `#3B82F6` | Keep |

### 1.6 Shadow Colors for Light Theme

| Elevation | Color | Radius | Y-Offset |
|---|---|---|---|
| `flat` | none | 0 | 0 |
| `raised` | `rgba(0,0,0,0.06)` | 2 | 1 |
| `elevated` | `rgba(0,0,0,0.08)` | 8 | 4 |
| `floating` | `rgba(0,0,0,0.12)` | 16 | 8 |

---

## 2. What to Remove -- Glass Morphism, Particles, Blurs, Neon

### 2.1 Glass Morphism (`.ultraThinMaterial` and related)

Every usage of `.ultraThinMaterial`, `.thinMaterial`, `.regularMaterial` must be replaced with solid `Color.tmiSurface` or `Color.white` backgrounds.

**Files requiring changes (31 files):**

| File | What to remove |
|---|---|
| `TMI/Views/Components/TMIComponentLibrary.swift` | `TMIGlassCard`: Remove `.ultraThinMaterial` fill (line 263), remove `positionBasedGradient` border overlay, remove `Color.white.opacity(style.backgroundOpacity)` fill. Replace with solid `Color.tmiSurface` background + `tmiBorder` stroke + elevation shadow |
| `TMI/Views/Components/UIComponents.swift` | `PremiumGlassTabBar`: Remove `.ultraThinMaterial` on tab bar background (line 39). `PremiumSidebarList`: Remove `.ultraThinMaterial` on sidebar items (lines 189-194). `StatCard`: Remove `.ultraThinMaterial.opacity(0.4)` (line 842). `TimeFrameSelector`: Replace `.white.opacity(0.05)` bg |
| `TMI/Views/TMIPlans/TMIPlanDetailView.swift` | Remove all `.ultraThinMaterial` backgrounds |
| `TMI/Views/TMIPlans/Sections/PlanInterestsSection.swift` | Remove material backgrounds |
| `TMI/Views/Students/Sections/StudentInterestsSection.swift` | Remove material backgrounds |
| `TMI/Views/Career Explorer/CareerExplorerView.swift` | Remove material backgrounds |
| `TMI/Views/Goals/AddGoalView.swift` | Remove material backgrounds |
| `TMI/Views/StudentMode/StudentModeView.swift` | Remove material backgrounds |
| `TMI/Views/Resources/ResourceDetailView.swift` | Remove material backgrounds |
| `TMI/Views/Meetings/MeetingListView.swift` | Remove material backgrounds |
| `TMI/Views/Meetings/MeetingCalendarView.swift` | Remove material backgrounds |
| `TMI/Views/Meetings/CreateEditMeetingView.swift` | Remove material backgrounds |
| `TMI/Views/Compliance/AuditLogListView.swift` | Remove material backgrounds |
| `TMI/Views/Compliance/ConsentManagementView.swift` | Remove material backgrounds |
| `TMI/Views/Resources/ResourcesView.swift` | Remove material backgrounds |
| `TMI/Views/InterestsAndHobbies/InterestsAndHobbiesView.swift` | Remove material backgrounds |
| `TMI/Views/InterestsAndHobbies/InterestDetailView.swift` | Remove material backgrounds |
| `TMI/Views/Career Explorer/CareerDetailView.swift` | Remove material backgrounds |
| `TMI/Views/Components/SharedSectionHelpers.swift` | Remove material backgrounds |
| `TMI/Views/Authentication/RegistrationView.swift` | Remove material backgrounds |
| `TMI/Views/District/PendingApprovalsWidget.swift` | Remove material backgrounds |
| `TMI/Views/Students/StudentListComponents.swift` | Remove material backgrounds |
| `TMI/Views/Students/StudentListFilterView.swift` | Remove material backgrounds |
| `TMI/Views/Dashboard/InsightsView.swift` | Remove material backgrounds |
| `TMI/Views/Dashboard/Components/AlignmentChartView.swift` | Remove material backgrounds |
| `TMI/Views/Recommendations/RecommendationsView.swift` | Remove material backgrounds |
| `TMI/Views/TMIPlans/TMIPlanCard.swift` | Remove material backgrounds |
| `TMI/Views/Resources/AddResourceView.swift` | Remove material backgrounds |
| `TMI/Views/Resources/ResourceCard.swift` | Remove material backgrounds |
| `TMI/Views/InterestsAndHobbies/InterestsAndHobbiesHelpers.swift` | Remove material backgrounds |
| `TMI/Core/Errors/ErrorHandler.swift` | Remove material backgrounds |

### 2.2 Particle Effects

| File | What to remove |
|---|---|
| `TMI/Views/Components/TMIComponentLibrary.swift` | Remove entire `TMIParticleEffect` struct (lines 408-481). Remove `SpriteKit` import (line 10). Remove `animateParticles` state var from `TMIBackgroundView`. Remove particle overlay from `TMIBackgroundView` (currently commented out but delete entirely). |

### 2.3 Animated Blobs / Gradient Overlays

| File | What to remove |
|---|---|
| `TMI/Views/Components/TMIComponentLibrary.swift` | Remove entire `animatedOverlays` computed property (lines 104-155) including primary blob, secondary blob, and `additionalCareerOverlays`. Remove `animateGradient` state variable. |

### 2.4 Neon Glow / Color Shadow Effects

| File | What to change |
|---|---|
| `TMI/Views/Components/TMIComponentLibrary.swift` | `TMILogoView`: Remove `RadialGradient` glowing circle background (lines 361-377). Remove neon `.shadow(color: Color.tmiSecondary.opacity(0.8))` on brain icon (line 385). Remove pulsing/rotation animation. |
| `TMI/Views/Components/UIComponents.swift` | `LottieLoadingView`: Remove `AngularGradient` ring (line 307). Remove pulsing inner circle. Replace with standard `ProgressView()`. |
| `TMI/Views/Components/UIComponents.swift` | `StatCircle`: Remove `.shadow(color: color.opacity(0.5), radius: 4)` neon glow on circle stroke (line 259). |
| All chart glow effects | Remove `.shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 0)` from progress bars in `TMIProgressViewStyle` (line 782). |

### 2.5 Dark Color Scheme Overrides

| File | What to remove |
|---|---|
| `TMI/Views/Authentication/AuthenticationView.swift` | Remove `.preferredColorScheme(.dark)` on sheets (lines 205, 209) and on the main view (line 235). |
| All views using `.preferredColorScheme(.dark)` | Remove -- the app should use light mode by default. |

---

## 3. What to Keep

### 3.1 Spacing System (keep entirely)

`TMISpacing` -- all values are correct and layout-agnostic:
- `xxs: 2`, `xs: 4`, `sm: 8`, `md: 16`, `lg: 24`, `xl: 32`, `xxl: 48`
- Aliases: `small`, `medium`, `large`, `extraLarge`, `cardPadding`, `sectionSpacing`, `screenPadding`

### 3.2 Radius System (keep entirely)

`TMIRadius` -- all values are correct:
- `none: 0`, `xs: 2`, `sm: 4`, `md: 8`, `lg: 12`, `xl: 16`, `full: 9999`
- Aliases: `card`, `button`, `modal`, `sheet`, `pill`, `small`, `medium`

### 3.3 Sizing Constants (keep entirely)

`TMISizing` -- all values remain valid:
- Icon sizes: `iconSm: 16`, `iconMd: 24`, `iconLg: 32`
- Avatar sizes: `avatarSm: 40`, `avatarMd: 56`, `avatarLg: 80`
- Component heights: `buttonHeight: 48`, `textFieldHeight: 48`, `listRowHeight: 64`, `tabBarHeight: 72`
- `fabSize: 56`, `minTouchTarget: 44`

### 3.4 Animation Timing Tokens (keep entirely)

- `springInteractive`: `spring(response: 0.35, dampingFraction: 0.75)` -- keep
- `easeInOutStandard`: `easeInOut(duration: 0.25)` -- keep
- `easeInOutQuick`: `easeInOut(duration: 0.15)` -- keep
- Button press spring: `spring(response: 0.3, dampingFraction: 0.7)` -- keep
- View appear spring: `spring(response: 0.6, dampingFraction: 0.8)` -- keep
- `ScaleButtonStyle` with `scaleAmount: 0.95` -- keep

### 3.5 Typography Scale (keep entirely)

- `tmiDisplay1`, `tmiHeading1`, `tmiHeading3`, `tmiBody`, `tmiCaption`, `tmiCaptionSmall`
- `tmiButton: .system(size: 16, weight: .semibold)`
- `tmiNavTitle: .system(size: 20, weight: .bold)`

### 3.6 Elevation System (keep, update shadow color)

`TMIElevation` enum values are fine. Update the shadow color from `Color.black.opacity(x)` to slightly warmer `Color(hex: "#1A1A1A").opacity(x)`.

### 3.7 Haptic Patterns

Keep all haptic feedback patterns as-is.

### 3.8 Staggered Appear Animations

Keep the staggered entrance animations on AuthenticationView (email, password, buttons appearing sequentially). Just update colors.

### 3.9 SF Symbols

Keep all SF Symbol icon choices. They are theme-agnostic.

### 3.10 Accessibility

Keep all `.accessibilityLabel`, `.accessibilityValue`, `.accessibilityHint` modifiers.

---

## 4. Screen-by-Screen Layout Specs

### 4.1 Auth / Login Screen

**File:** `TMI/Views/Authentication/AuthenticationView.swift`

**Background:**
- Remove: `TMIBackgroundView(variant: .auth)` with dark gradient
- Replace: Solid `Color.tmiBackground` (#FAF8F5) with `.ignoresSafeArea()`

**Logo (`TMILogoView`):**
- Remove: Glowing radial gradient circle, neon shadow, pulsing/rotation animation
- Keep: `brain.head.profile` SF Symbol icon
- New: Icon color = `tmiPrimary` (#C8870E gold), size 60pt. Simple subtle scale-in animation on appear.
- "TMI" text: `.foregroundColor(.tmiTextPrimary)` (#1A1A1A), keep 36pt bold rounded
- Add: Subtle shadow `Color.black.opacity(0.06), radius: 2, y: 1` under icon circle

**Welcome Text:**
- "Welcome to TMI": `.foregroundColor(.tmiTextPrimary)`
- "Tangible Modification Intervention": `.foregroundColor(.tmiTextSecondary)` (#6B7280)

**Login Card:**
- Remove: `TMIGlassCard(style: .auth)` with glass morphism
- Replace: Solid white card with properties:
  - Background: `Color.white`
  - Corner radius: `20` (keep existing)
  - Padding: `EdgeInsets(top: 30, leading: 24, bottom: 30, trailing: 24)` (keep existing)
  - Border: `1px Color.tmiBorder` (#E5E7EB)
  - Shadow: `rgba(0,0,0,0.08), radius: 8, x: 0, y: 4`
  - No hover scale effect on the card itself

**Text Fields:**
- Remove: `Color.black.opacity(0.3)` fill, `.ultraThinMaterial` inner fill
- New background: `Color(hex: "#F5F3F0")` (warm light gray), corner radius 12
- Border unfocused: `1px Color.tmiBorder` (#E5E7EB)
- Border focused: `2px Color.tmiSecondary` (#3B7DD8 blue)
- Icon unfocused: `Color.tmiTextTertiary` (#9CA3AF)
- Icon focused: `Color.tmiSecondary` (#3B7DD8)
- Text color: `Color.tmiTextPrimary` (#1A1A1A)
- Placeholder color: `Color.tmiTextTertiary` (#9CA3AF)
- Padding: keep `vertical: 16, horizontal: 20`

**Buttons:**
- Primary "Log In": Background `Color.tmiSecondary` (#3B7DD8 blue), text white, corner radius 14
  - Shadow: `rgba(59,125,216,0.25), radius: 6, y: 3`
  - Pressed: `scaleEffect(0.98)`, shadow shrinks
  - Hover: `scaleEffect(1.02)`, shadow grows
- "Forgot Password?" link: `Color.tmiSecondary` (#3B7DD8)
- "Create Account" link: `Color.tmiSecondary` (#3B7DD8), keep semi-bold

**Error View (`TraumaInformedErrorView`):**
- Remove: `TMIGlassCard(style: .error)`
- Replace: Solid card with `Color(hex: "#FEF2F2")` (light red) background
- Border: `1px Color.tmiError.opacity(0.3)`
- Icon and "Get Support" link: `Color.tmiError` (#EF4444)
- Text: `Color.tmiTextPrimary`
- Corner radius: 16

### 4.2 Registration Screen

**File:** `TMI/Views/Authentication/SimplifiedRegistrationView.swift`

**Background:** Solid `Color.tmiBackground` (#FAF8F5), remove `TMIBackgroundView(variant: .auth)`

**Header:**
- Icon: `person.crop.circle.badge.plus` in `Color.tmiPrimary` (#C8870E)
- "Create Account": `Color.tmiTextPrimary`
- "Join the TMI community": `Color.tmiTextSecondary`

**Account Type Pills:**
- Unselected: `Color.tmiSurface` bg, `1px Color.tmiBorder`, text `Color.tmiTextPrimary`
- Selected: `accountType.color` bg (keep blue/purple/orange/pink per role), text white
- Corner radius: 12

**Form Fields:**
- Same spec as Login text fields (section 4.1)

**Submit Button:**
- Same spec as Login primary button

### 4.3 Dashboard

**File:** `TMI/Views/Dashboard/DashboardView.swift` and `TMI/Views/Dashboard/Components/`

**Background:** Solid `Color.tmiBackground`, remove `TMIBackgroundView(variant: .dashboard)`

**Stat Cards (`StatCard` in UIComponents.swift):**
- Remove: `.ultraThinMaterial.opacity(0.4)` inner background, gradient border stroke
- New:
  - Background: `Color.white`
  - Corner radius: 16 (keep)
  - Border: `1px color.opacity(0.2)` (tinted with the stat's semantic color)
  - Shadow: `rgba(0,0,0,0.06), radius: 4, y: 2`
  - Icon circle: `color.opacity(0.1)` background (keep)
  - Title text: `Color.tmiTextSecondary`
  - Value text: `Color.tmiTextPrimary`
  - Keep: `contentTransition(.numericText())`, hover scale, icon rotation animation

**Alignment Chart (`DashboardAlignmentChartView`):**
- Remove: `TMIGlassCard(style: .dashboard)` wrapper
- Replace: White card with `elevated` shadow
- Chart title: `Color.tmiTextPrimary`
- Chart subtitle: `Color.tmiTextSecondary`
- Axis labels: `Color.tmiTextSecondary` (replace `.white.opacity(0.8)`)
- Grid lines: `Color.tmiBorder` (replace `.white.opacity(0.2)`)
- Area gradient: `Color.tmiSecondary.opacity(0.15)` to `Color.tmiSecondary.opacity(0.03)` (lighter)
- Line color: `Color.tmiSecondary`
- Divider: `Color.tmiDivider` (replace `.white.opacity(0.2)`)

**Time Frame Selector (`TimeFrameSelector`):**
- Remove: `.white.opacity(0.05)` background
- New: `Color(hex: "#F5F3F0")` background, corner radius 10
- Selected segment: `Color.tmiSecondary` fill, white text
- Unselected text: `Color.tmiTextSecondary`

**Insights Button (`InsightsButtonView`):**
- Keep gradient background but change to: `Color.tmiSecondary` to `Color.tmiSecondary.opacity(0.85)`
- Text: white (keep, it is on blue background)
- Shadow: `Color.tmiSecondary.opacity(0.2)` (reduced from 0.3/0.5)

**Quick Action Cards:**
- Replace glass cards with solid white cards, `raised` elevation shadow

**Empty State (`MVPEmptyStateCopy`):**
- Icon: `Color.tmiTextTertiary` (keep)
- Title: `Color.tmiTextPrimary`
- Message: `Color.tmiTextSecondary`
- Action button: `Color.tmiSecondary` background, white text

### 4.4 Student List

**File:** `TMI/Views/Students/StudentListView.swift`

**Background:** `Color.tmiBackground`

**Search Bar (`TMISearchBar`):**
- Background: `Color(hex: "#F5F3F0")`
- Border: `1px Color.tmiBorder`, focus: `2px Color.tmiSecondary`
- Icon: `Color.tmiTextSecondary`
- Text: `Color.tmiTextPrimary`
- Placeholder: `Color.tmiTextTertiary`

**Filter Chips (`TMIFilterChip`):**
- Unselected: `Color.tmiSurface` bg, `1px Color.tmiBorder`, text `Color.tmiTextPrimary`
- Selected: `Color.tmiPrimary` (#C8870E) bg, white text
- Corner radius: `TMIRadius.pill`

**Student Card (`StudentCard`):**

**File:** `TMI/Views/Students/StudentCard.swift`
- Remove: `TMIGlassCard(style: .default)` wrapper
- Replace: Solid white card
  - Background: `Color.white`
  - Corner radius: 20
  - Border: `1px Color.tmiBorder`
  - Shadow: `rgba(0,0,0,0.06), radius: 4, y: 2`
  - Padding: 20 all sides
- Avatar initials: Keep current gradient (`tmiSecondary` to `tmiSecondary.opacity(0.8)`) -- this still works on light bg
  - Circle border: Change `.white.opacity(0.2)` to `Color.tmiBorder`
- Student name: `Color.tmiTextPrimary` (replace `.white`)
- Grade text: `Color.tmiTextSecondary` (replace `.white.opacity(0.7)`)
- Engagement bar label: `Color.tmiTextSecondary` (replace `.white.opacity(0.7)`)
- Progress track: `Color.tmiBorder` (replace `.white.opacity(0.1)`)

### 4.5 TMI Plan Views

**File:** `TMI/Views/TMIPlans/TMIPlanListView.swift`

**Background:** `Color.tmiBackground`

**Plan Tab Selector (Active/Completed):**
- Same spec as `TimeFrameSelector`
- Selected: `Color.tmiSecondary` bg, white text
- Unselected: transparent, `Color.tmiTextSecondary` text

**Plan Cards:**
- Solid white card, `raised` shadow
- Title: `Color.tmiTextPrimary`
- Status badge: Use semantic colors (success/warning/info) with `color.opacity(0.1)` bg and `color` text
- Progress bar: `Color.tmiSecondary` fill on `Color.tmiBorder` track
- Meta text (dates, counts): `Color.tmiTextSecondary`

**Tooltip (`TMIHelpTooltipButton`):**
- Remove: `Color.black.opacity(0.85)` tooltip bg, `tmiPrimary.opacity(0.7)` border
- Replace: `Color.white` bg, `1px Color.tmiBorder`, `floating` elevation shadow
- Text: `Color.tmiTextPrimary`
- Trigger icon: Keep `Color.tmiPrimary`

### 4.6 Settings / Profile

**File:** `TMI/Views/Settings/SettingsView.swift`, `TMI/Views/User/UserProfileView.swift`

**Background:** `Color.tmiBackground`, remove `TMIBackgroundView(variant: .default)`

**Section Headers:**
- Text: `Color.tmiTextSecondary`, size 14 medium

**Setting Rows:**
- Background: `Color.white`
- Corner radius: 12
- Divider between rows: `Color.tmiDivider`
- Label text: `Color.tmiTextPrimary`
- Value/description text: `Color.tmiTextSecondary`
- Toggle tint: `Color.tmiSecondary`
- Destructive items (Sign Out): `Color.tmiError`

**Profile Card:**
- White card, `elevated` shadow
- Avatar: Keep `TMIAvatar` component, update `color` default to `Color.tmiPrimary`
- Name: `Color.tmiTextPrimary`
- Role/email: `Color.tmiTextSecondary`

---

## 5. Component Specs -- Detailed Changes

### 5.1 TMIBackgroundView (simplify drastically)

**File:** `TMI/Views/Components/TMIComponentLibrary.swift`

Remove all gradient variants, particle support, animated overlays. Replace with:

```swift
struct TMIBackgroundView: View {
    var variant: BackgroundVariant = .default

    enum BackgroundVariant {
        case `default`, auth, dashboard, career, plans
        // All variants use the same warm off-white
    }

    var body: some View {
        Color.tmiBackground
            .ignoresSafeArea()
    }
}
```

### 5.2 TMIGlassCard -> TMISolidCard

**File:** `TMI/Views/Components/TMIComponentLibrary.swift`

Replace glass morphism with solid opaque cards:

| Property | Old (Glass) | New (Solid) |
|---|---|---|
| Background | `Color.white.opacity(0.03-0.08)` + `.ultraThinMaterial` | `Color.white` (solid) |
| Border | Position-based gradient `white.opacity(0.1-0.7)` | `1px Color.tmiBorder` (#E5E7EB) |
| Shadow | `black.opacity(0.15), radius: 5-20` | See elevation table below |
| Hover | `scaleEffect(1.01)` | Keep `scaleEffect(1.01)` |
| Corner radius | Keep per style (16-24) | Keep per style (16-24) |
| Padding | Keep per style | Keep per style |

**Shadow by card style:**

| Style | Shadow |
|---|---|
| `.default` | `rgba(0,0,0,0.06), radius: 4, y: 2` |
| `.elevated` | `rgba(0,0,0,0.08), radius: 8, y: 4` |
| `.minimal` | `rgba(0,0,0,0.04), radius: 2, y: 1` |
| `.auth` | `rgba(0,0,0,0.08), radius: 8, y: 4` |
| `.dashboard` | `rgba(0,0,0,0.06), radius: 4, y: 2` |
| `.error` | `rgba(239,68,68,0.08), radius: 8, y: 4` (tinted with error color) |
| `.form` | `rgba(0,0,0,0.06), radius: 4, y: 2` |

### 5.3 TMIButton

**File:** `TMI/Views/Components/TMIComponentLibrary.swift`

| Style | Old BG | New BG | Old FG | New FG | Border |
|---|---|---|---|---|---|
| `.primary` | `.tmiSecondary` (cyan) | `Color.tmiSecondary` (#3B7DD8 blue) | white | white | none |
| `.secondary` | clear + border | clear | `.tmiSecondary` | `Color.tmiSecondary` | `1.5px Color.tmiSecondary` |
| `.tertiary` | `.white.opacity(0.1)` | `Color(hex: "#F5F3F0")` | `.tmiSecondary` | `Color.tmiSecondary` | none |
| `.destructive` | `.red` | `Color.tmiError` | white | white | none |
| `.floating` | `.tmiSecondary` | `Color.tmiSecondary` | white | white | none |
| `.filter(selected)` | `.tmiSecondary` | `Color.tmiPrimary` | white | white | none |
| `.filter(unselected)` | `.white.opacity(0.05)` | `Color.tmiSurface` | `.white.opacity(0.8)` | `Color.tmiTextPrimary` | `1px Color.tmiBorder` |
| `.icon` | `.white.opacity(0.1)` | `Color(hex: "#F5F3F0")` | `.white.opacity(0.7)` | `Color.tmiTextSecondary` | none |

**Shadow updates:**
- Primary/Floating: `Color.tmiSecondary.opacity(0.2), radius: 6, y: 3`
- Destructive: `Color.tmiError.opacity(0.2), radius: 6, y: 3`
- All others: none

**Keep:** All animation timings, scale effects, hover states, loading spinner.

### 5.4 TMITextField

**File:** `TMI/Views/Components/TMIComponentLibrary.swift`

| Property | Old | New |
|---|---|---|
| Background fill | `Color.black.opacity(0.3)` | `Color(hex: "#F5F3F0")` |
| Inner material | `.ultraThinMaterial.opacity(0.2)` | Remove entirely |
| Border default | `white.opacity(0.3)` gradient | `1px Color.tmiBorder` solid |
| Border focused | `tmiSecondary.opacity(0.8)` gradient | `2px Color.tmiSecondary` solid |
| Icon default | `.white.opacity(0.6)` | `Color.tmiTextTertiary` |
| Icon focused | `Color.tmiSecondary` | Keep |
| Text | `.white` | `Color.tmiTextPrimary` |
| Placeholder | `.white.opacity(0.6)` | `Color.tmiTextTertiary` |
| Corner radius | 12 | 12 (keep) |
| Padding | `v:16 h:20` | Keep |

### 5.5 TMIProgressViewStyle

**File:** `TMI/Views/Components/TMIComponentLibrary.swift`

| Property | Old | New |
|---|---|---|
| Track | `.white.opacity(0.1)` | `Color.tmiBorder` (#E5E7EB) |
| Fill gradient | Keep `color` to `color.opacity(0.8)` | Keep |
| Glow shadow | `color.opacity(0.5), radius: 4` | Remove |

### 5.6 TMILogoView

**File:** `TMI/Views/Components/TMIComponentLibrary.swift`

| Property | Old | New |
|---|---|---|
| Glow circle | `RadialGradient` with `.tmiSecondary` pulsing | Remove entirely |
| Icon | 70pt white, neon shadow | 60pt `Color.tmiPrimary` (#C8870E), no glow shadow |
| Icon shadow | `tmiSecondary.opacity(0.8), radius: 10` | `rgba(0,0,0,0.08), radius: 4, y: 2` |
| Rotation animation | 5-degree wiggle | Remove |
| Scale animation | Pulsing 0.9-1.1 | Simple appear: `scaleEffect(0.8 -> 1.0)` with `spring(response: 0.5)` |
| "TMI" text | `.foregroundColor(.white)` | `.foregroundColor(.tmiTextPrimary)` |
| Text shadow | `black.opacity(0.2)` | Remove |

### 5.7 PremiumGlassTabBar

**File:** `TMI/Views/Components/UIComponents.swift`

Note: MainTabView now uses `.tabViewStyle(.sidebarAdaptable)` with system tab bar. If the `PremiumGlassTabBar` is still used anywhere:

| Property | Old | New |
|---|---|---|
| Background | `black.opacity(0.2)` + `.ultraThinMaterial.opacity(0.8)` | `Color.white` |
| Border | Gradient `white.opacity(0.5)` to transparent | `1px Color.tmiBorder` |
| Shadow | `black.opacity(0.3), radius: 15, y: 8` | `rgba(0,0,0,0.08), radius: 8, y: 4` |
| Selected tab bg | `tmiSecondary.opacity(0.2-0.4)` gradient | `Color.tmiSecondary.opacity(0.1)` solid |
| Selected icon/text | white | `Color.tmiSecondary` |
| Unselected icon/text | `white.opacity(0.6)` | `Color.tmiTextTertiary` |
| Corner radius | 30 (keep) | Keep |

### 5.8 StatCard

**File:** `TMI/Views/Components/UIComponents.swift`

| Property | Old | New |
|---|---|---|
| Background | `color.opacity(0.05)` + `.ultraThinMaterial.opacity(0.4)` | `Color.white` |
| Border | Gradient `color.opacity(0.4)` to `color.opacity(0.1)` | `1px color.opacity(0.15)` solid |
| Shadow | None explicitly | `rgba(0,0,0,0.06), radius: 4, y: 2` |
| Title | `.white.opacity(0.7)` | `Color.tmiTextSecondary` |
| Value | `.white` | `Color.tmiTextPrimary` |
| Icon circle bg | `color.opacity(0.15)` | `color.opacity(0.1)` |
| Keep | Hover scale, icon rotation animation, `contentTransition(.numericText())` | Keep all |

### 5.9 ChartStatistic

**File:** `TMI/Views/Components/UIComponents.swift`

| Property | Old | New |
|---|---|---|
| Title | `.white.opacity(0.6)` | `Color.tmiTextSecondary` |
| Value | `.white` | `Color.tmiTextPrimary` |
| Background | `.white.opacity(0.05)` | `Color(hex: "#F5F3F0")` |

### 5.10 LottieLoadingView

**File:** `TMI/Views/Components/UIComponents.swift`

Replace entirely with a simpler loading view:
- Standard `ProgressView()` with `.tint(.tmiSecondary)`
- Or: Simple rotating ring with `Color.tmiSecondary` on `Color.tmiBorder` track
- Keep the `brain.head.profile` icon centered, color `Color.tmiPrimary`

### 5.11 TMIAvatar

**File:** `TMI/Core/DesignSystem/RedesignComponents.swift`

| Property | Old | New |
|---|---|---|
| Default color | `.tmiPrimary` | `Color.tmiPrimary` (#C8870E) -- same token, new value |
| Initials bg | `color.opacity(0.2)` | `color.opacity(0.12)` (slightly lighter on white) |
| Initials text | `color` | Keep |

### 5.12 TMIEmptyState

**File:** `TMI/Core/DesignSystem/RedesignComponents.swift`

| Property | Old | New |
|---|---|---|
| Icon | `.tmiTextTertiary` | Keep |
| Title | `.tmiTextPrimary` | Keep |
| Message | `.tmiTextSecondary` | Keep |
| Action button | Already uses `TMIButton(.primary)` | Will inherit new blue button |

---

## 6. Interaction States

### 6.1 Buttons

| State | Visual |
|---|---|
| Default | Per style specs above |
| Hover | `scaleEffect(1.02)`, shadow radius +4, shadow y +3 |
| Pressed | `scaleEffect(0.98)`, shadow radius -2, shadow y -2 |
| Focused | `2px Color.tmiSecondary` ring, 2pt offset from edge |
| Disabled | `opacity(0.5)`, no shadow, no hover/press effects |
| Loading | Centered `ProgressView()` tinted with foreground color, label hidden |

### 6.2 Cards

| State | Visual |
|---|---|
| Default | Per shadow specs above |
| Hover | `scaleEffect(1.01)`, shadow radius +2 |
| Pressed | `scaleEffect(0.99)` |
| Selected | `2px Color.tmiSecondary` border, `Color.tmiSecondary.opacity(0.04)` bg tint |

### 6.3 Text Fields

| State | Visual |
|---|---|
| Default | `1px Color.tmiBorder` border |
| Focused | `2px Color.tmiSecondary` border, icon transitions to `Color.tmiSecondary` |
| Error | `2px Color.tmiError` border, error message below in `Color.tmiError` |
| Disabled | `opacity(0.5)`, `Color(hex: "#F0EEEB")` bg |

### 6.4 Tab / Segment Controls

| State | Visual |
|---|---|
| Unselected | No bg, `Color.tmiTextSecondary` text |
| Hover | `Color(hex: "#F5F3F0")` bg |
| Selected | `Color.tmiSecondary` bg, white text, `matchedGeometryEffect` transition |

---

## 7. Responsive / Adaptive (iPad vs iPhone)

### 7.1 Navigation

- **iPhone:** Standard TabView (`.tabViewStyle(.sidebarAdaptable)` already handles this)
- **iPad:** Sidebar + detail layout via `.sidebarAdaptable` -- keep existing behavior
- `.accentColor(.tmiSecondary)` on tab bar -- update to `Color.tmiSecondary` (new blue)

### 7.2 Card Grids

- **iPhone (compact):** Single column, full-width cards with `screenPadding` (16pt) horizontal margins
- **iPad (regular):** 2-column grid for student cards, stat cards. Use `LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))])`
- Max content width: 720pt (already set in SimplifiedRegistrationView as `Layout.contentWidth`)

### 7.3 Auth Screen

- **iPhone:** Full-width card with 24pt horizontal padding
- **iPad:** Card centered, `maxWidth: 500` (reduce from current 800)

### 7.4 Dashboard

- **iPhone compact:** Stacked layout -- stats row scrolls horizontally, chart full width
- **iPad regular:** 2-column stat cards, chart spans full width below

### 7.5 Sheets

- Keep `TMISheetStyle` with `minWidth: 600, minHeight: 400` for iPad
- iPhone: System default sheet presentation
- Remove `.presentationDragIndicator(.visible)` -- not needed if using standard drag

---

## 8. Edge Cases

### 8.1 Empty States

All empty states should use `TMIEmptyState` component:
- Background: inherits `Color.tmiBackground`
- Icon: 48pt light weight, `Color.tmiTextTertiary`
- Title: `tmiTitle3` font, `Color.tmiTextPrimary`
- Message: `tmiBody` font, `Color.tmiTextSecondary`, multiline center
- CTA button: `TMIButton(.primary)` (blue)

### 8.2 Error States

- **Inline errors** (form validation): Red text below field, `Color.tmiError`, `tmiCaption` font
- **Card errors** (network/data): Light red card `Color(hex: "#FEF2F2")`, `1px Color.tmiError.opacity(0.3)` border
- **Full-screen errors**: `TMIEmptyState` with `exclamationmark.triangle` icon in `Color.tmiWarning`, retry button

### 8.3 Loading States

- **Inline**: `ProgressView().tint(.tmiSecondary)` -- standard SwiftUI
- **Full-screen**: Centered `ProgressView()` with "Loading..." text in `Color.tmiTextSecondary`
- **Skeleton**: Use `Color(hex: "#F0EEEB")` rectangles with `cornerRadius(8)` and subtle pulse animation (opacity 0.6 to 1.0, duration 1.2s, repeating)
- **Pull-to-refresh**: Standard `.refreshable {}` -- inherits `tmiSecondary` tint

### 8.4 Destructive Confirmations

- Alert title: System default
- Destructive button: `Color.tmiError`
- Cancel: System default

### 8.5 Dark Mode Support

For MVP, force light mode:
```swift
.preferredColorScheme(.light)
```
Set this once at the `TMIApp` level. Post-MVP, the `Color(light:dark:)` initializer already in `TMIDesignTokens.swift` can support dark mode with appropriate dark-variant tokens.

---

## 9. Implementation Priority

### Phase 1: Token Layer (do first)

1. Update `Color+Extensions.swift` -- change `tmiPrimary`, `tmiSecondary`, `tmiBackground`, `tmiText`, `cardBackground` values
2. Update `TMIDesignTokens.swift` -- update elevation shadow colors
3. Add `.preferredColorScheme(.light)` to `TMIApp.swift`
4. Remove all `.preferredColorScheme(.dark)` from individual views

### Phase 2: Foundation Components

5. Rewrite `TMIBackgroundView` to solid color
6. Rewrite `TMIGlassCard` to solid card (rename to `TMICard`)
7. Update `TMITextField` backgrounds and borders
8. Update `TMIButton` colors
9. Update `TMILogoView`
10. Delete `TMIParticleEffect`

### Phase 3: Screen-Level Sweeps

11. Auth screens (AuthenticationView, SimplifiedRegistrationView, RegistrationView)
12. Dashboard + components
13. Student views (list, card, detail, profile)
14. TMI Plan views (list, detail, editor)
15. Settings / Profile
16. Support views (resources, meetings, forms, surveys)

### Phase 4: Cleanup

17. Remove `SpriteKit` import and any remaining particle references
18. Search for remaining `.white` foreground colors and replace
19. Search for remaining `opacity` patterns that encode dark-theme colors
20. Remove unused `animateGradient` / `animateParticles` state variables
21. Verify all screens in both iPhone and iPad layouts

---

## 10. File Reference Summary

**Core design system files to change:**
- `/TMI/Helpers/Extensions/Color+Extensions.swift` -- primary token updates
- `/TMI/Core/DesignSystem/TMIDesignTokens.swift` -- shadow/elevation updates
- `/TMI/Core/DesignSystem/RedesignComponents.swift` -- component updates
- `/TMI/Core/DesignSystem/RedesignBridge.swift` -- no changes needed (spacing/radius aliases)
- `/TMI/Helpers/TMISpacing.swift` -- no changes needed
- `/TMI/Helpers/TMIRadius.swift` -- no changes needed
- `/TMI/Views/Components/TMIComponentLibrary.swift` -- major rewrite (glass -> solid)
- `/TMI/Views/Components/UIComponents.swift` -- update all components

**App entry point:**
- `/TMI/App/TMIApp.swift` -- add `.preferredColorScheme(.light)`

**76 view files** reference design tokens and need varying degrees of color/background updates (see Grep results for `tmiPrimary|tmiSecondary|tmiBackground` matches).

**31 files** use `.ultraThinMaterial` and need material removal.
