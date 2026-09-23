# Golden Hour Redesign: Design Spec

**Date:** 2026-09-23
**Status:** Approved. The owner chose the Golden Hour direction on 2026-09-23 and asked that bugs found along the way be fixed as part of the work.
**Branch:** `feat/golden-hour-redesign`
**Supersedes:** `docs/design/TMI-Visual-Design-Direction.md` and `docs/design-handoff/REDESIGN-HANDOFF.md`.

## 1. Goal

Make TMI feel world-class: Stripe-level clarity and polish, Apple-native feel, and one coherent brand. Treat the phone and the desk as two separate products built from the same system:

- **iPhone:** one hand, one job, glanceable.
- **Mac and iPad (regular width):** density, parallel panes, keyboard and pointer.

Non-goals: new product features, backend or rules changes, a new data model.

## 2. Brand and palette

The app icon, an amber schoolhouse on charcoal, *is* the brand. The in-app aubergine, teal and stray system blue are retired.

| Role | Token (`TMIColors.`) | Light | Dark | Use |
|---|---|---|---|---|
| Canvas | `background` | `#F6F5F2` | `#11100F` | Screen background |
| Surface | `surface` | `#FFFFFF` | `#1A1917` | Cards, rows, table bodies |
| Inset | `surfaceSecondary` | `#FAF9F6` | `#201E1C` | Inspectors, table headers |
| Raised | `surfaceRaised` | `#FFFFFF` | `#252321` | Sheets, popovers |
| Fill | `fill` / `fillStrong` | `#EFEDE8` / `#E6E3DD` | `#2A2826` / `#34312E` | Control fills, hover |
| Text | `textPrimary` / `textSecondary` / `textTertiary` | `#1C1917` / `#5C5650` / `#78716B` | `#F5F2EE` / `#ADA69F` / `#8A837C` | All tertiary text still meets 4.5:1 |
| Lines | `separator` / `border` / `interactiveBorder` | 10% / 16% ink, `#8F8881` | 9% / 15% cream, `#6F6862` | Hairlines, edges, input outlines (≥3:1) |
| Brand | `brand` + `onBrand` | `#F5A524` + ink | `#F5AE35` + ink | **Fills only**: primary buttons, hero accents |
| Accent | `accent` + `onAccent` | `#A35F00` + white | `#F7B84A` + ink | "Amber ink": tint, links, selected symbols |
| Accent wash | `accentSoft` / `selection` | `#FCEFD8` | amber at 15% / 13% | Selected chips, icon tiles, selected rows |
| Status | `success*`, `warning*`, `error*`, `info*` | text + surface pairs, AA | same | Warning is **orange** `#B93C0B`, never brand amber |
| Charts | `chartPrimary`, `chartTrack`, `chartSeries` | `#C77C07` … | `#F5AE35` … | Marks meet 3:1 |

Rules:

- Brand amber is never text on light surfaces. Accent text uses `accent`.
- Only one primary (amber) button per view.
- Status color always comes with shape or text (badge dot, symbol, label). Color is never the only signal.
- The Golden Hour mesh gradient (`TMIGoldenHourBackground` / `TMIGoldenHourCard`) appears only at brand moments: sign-in, the Today "next best step" card, Student Mode welcome, and plan completion. Never put it behind dense content.
- Liquid Glass is for the **navigation layer only** (system tab bars, toolbars, sidebars, floating controls). Content stays on opaque surfaces. Never build custom fake glass.

## 3. Typography

- Every role maps to a Dynamic Type text style (`Font.tmi*` in `FontConstants.swift`). **New code never uses `.system(size:)`** for text. Where a size must scale with text, use `@ScaledMetric`.
- `Font.tmiEditorial(_:)` (New York serif, semibold) is the single editorial moment per screen: greetings, a person's name in a record header, record titles. Controls always use SF Pro.
- Numbers in tables, metrics and counts use `.monospacedDigit()` (`Font.tmiMetric`, `tmiMetricLarge`). Values that change animate with `.contentTransition(.numericText())`.
- `.tmiEyebrow()` gives small uppercase tracked labels. Use them rarely, and only when they encode real grouping.
- Test at the accessibility sizes. Layouts switch to vertical stacks (`ViewThatFits` or `dynamicTypeSize.isAccessibilitySize`) instead of truncating.

## 4. Shape, space, depth, motion

- Radii: `TMIRadius.card` (iPhone 20 / Mac 12), `.control` (14 / 8), `.chip` (8 / 6), `.tile` (9 / 7). Always `.continuous` (`TMIShape.*`). Use `ConcentricRectangle` for content nested in system containers where it applies.
- Spacing scale: 2, 4, 8, 12 (`ms`), 16, 20 (`ml`), 24, 32, 48. Screen margin is 16 on iPhone, 24 on Mac. Constrain readable content to `TMISizing.readableWidth` (720) and dashboards to `maxContentWidth` (1180).
- Depth: `.tmiSurface(_:)` gives a surface fill plus a hairline, with one soft shadow in light mode only. Don't nest cards inside cards. Don't combine a border with heavy shadows.
- Motion: `TMIAnimation.smooth` (state), `.snappy` (press/toggle), `.bouncy` (celebration and Student Mode only). Use `.sensoryFeedback` on commit, selection and success (iPhone). Always respect Reduce Motion.
- Loading: keep content in place. First load uses `.tmiPlaceholder(true)` on real layout. **Refreshes never replace content with a spinner.**

## 5. Component kit (`TMI/Core/DesignSystem/TMIKit.swift` + restyled legacy components)

Use these instead of hand-styling:

- `.tmiSurface`, `TMICard`, `.tmiScreenBackground()`
- `.buttonStyle(.tmiPrimary / .tmiSecondary / .tmiTertiary / .tmiDestructive / .tmi(_:fullWidth:))`, `TMIButton`, `.tmiPressable`
- `TMIStatusBadge(_:tone:systemImage:)`, `TMITone`
- `TMIIconTile`, `TMISectionHeader`, `TMIMetricTile`, `TMISparkline`, `TMIProgressBar`, `TMIKeyValueRow`
- `TMIEmptyState`, `TMISearchBar` (only where `.searchable` can't be used), `TMIFilterChip`, `TMIFAB` (glass), `TMIAvatar` (stable per-person color)
- `TMIGoldenHourBackground`, `TMIGoldenHourCard`, `TMISchoolhouseMark`

Prefer native containers: `List`, `Form`, `Table`, `LabeledContent`, `ContentUnavailableView`, `Menu`, `ControlGroup`, `.searchable`, `.inspector`, `.confirmationDialog`.

## 6. iPhone blueprint

- **Shell:** `TabView` with `Tab` values, each tab owning its own `NavigationStack` so the glass tab bar persists while pushing. Add `Tab(role: .search)` for global search, `.tabBarMinimizeBehavior(.onScrollDown)`, and optionally a `.tabViewBottomAccessory` for sync/offline status. Profile, settings and tasks move into the Today header avatar menu.
- **Today (Dashboard):** greeting (editorial) → Golden Hour "next best step" card → three KPI tiles → time-ordered agenda → caseload pulse. The whole first screen answers "what needs me now?".
- **Lists:** rich-but-calm rows, `.swipeActions` for common actions, `.contextMenu` with previews, `.searchable` with tokens and scopes, filters in a detented sheet.
- **Records:** a scrolling hub with a pinned identity header, `.navigationTransition(.zoom)` from the row, and sections as surfaces.
- **Editing:** guided flows in sheets, one decision per step, with a primary action pinned at the bottom (`.safeAreaBar(edge: .bottom)`) within thumb reach. Use `.presentationDetents` where content is short, and haptics on commit.

## 7. Mac and iPad blueprint

- **Shell:** `NavigationSplitView` with a native `List(selection:)` sidebar using `.listStyle(.sidebar)`, sections, `.badge` counts, and ⌘1–⌘4. The toolbar is unified with `.searchable` in it. Add a `Settings` scene (⌘,) and `Commands` for every primary action, with shortcuts shown in menus. Use `.inspector` for record details. Allow opening records in their own window where it's safe.
- **Lists:** `Table` with sortable, customizable columns (`TableColumnCustomization`), multi-select, `contextMenu(forSelectionType:primaryAction:)`, and double-click or Return to open.
- **Records:** list → record → inspector. Use a multi-column composed layout within `maxContentWidth`.
- **Editing:** form plus live preview, or a form in an inspector. ⌘↩ submits, Esc cancels, and `.help` tooltips cover every icon-only control.
- **Pointer:** hover affordances (`.tmiPressable` and TMI button styles already hover on Mac) and a visible focus ring.

## 8. Invariants (must hold for every change)

1. Preserve every `accessibilityIdentifier` that UI tests or unit tests reference (grep `TMIUITests/` and `TMITests/` before renaming). New interactive elements get identifiers.
2. A view pushed onto an existing stack never introduces its own `NavigationStack`.
3. Router security semantics stay: policy validation, the path reset on policy change, and deep-link queuing. Existing `AppRouter` tests keep passing.
4. Student Mode containment is never weakened.
5. Fixtures and previews never touch Firebase. Use injected in-memory repositories. `FirebaseSession.currentUserID()` is the safe accessor.
6. Swift 6 strict concurrency with the project's default MainActor isolation. No new warnings in touched files.
7. Every change builds for iOS Simulator and macOS, and `TMITests` passes.

## 9. Verification

For each work package:

- Build iOS and macOS.
- Run `xcodebuild test -only-testing:TMITests`.
- Capture before/after fixture screenshots in light and dark: `-uiTesting -fixture <name> [-appearance dark]`, plus `-content-size accessibility5` where the fixture supports it.

The owner reviews screenshots per phase.

## 10. Phases

0. **Foundation:** done in `5f0d558`. Tokens, type ramp, kit, dark mode, tint, fixture appearance flag, fixture crash fixes.
1. **Shell** for iPhone, iPad and Mac, plus the `app-shell` fixture.
2. **Screen clusters in parallel:** Today; Students; Plans; Reports & Admin; Forms, Surveys & Meetings; Student Mode & Careers; Auth; Settings, Profile & Compliance. Each cluster fixes the bugs the audit found in it.
3. **Polish pass:** motion, haptics, accessibility sizes, dark-mode QA, the Mac window pass, and the screenshot review.

The per-screen findings and the consolidated bug list are in the audit synthesis (`UI-AUDIT.md`, produced by the audit workflow). The work-package briefs are derived from it.
