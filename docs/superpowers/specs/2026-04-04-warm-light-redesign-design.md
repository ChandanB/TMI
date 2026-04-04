# TMI Visual Redesign: Dark Cyberpunk → Warm Light Theme

**Date:** 2026-04-04
**Status:** Approved
**Scope:** Complete visual theme overhaul — colors, components, backgrounds, screens

---

## Summary

Replace the app's dark cyberpunk aesthetic (near-black backgrounds, glass morphism, neon glows, cyan accents) with a warm, light theme derived from the gold schoolhouse logo. The goal: the app should feel like a trusted teacher companion, not a gaming dashboard.

**Design direction:** Gold/amber for brand identity + warm blue for interactive elements. Teachers intuitively know "blue = tappable."

**Dark mode:** Not supported for MVP. The app forces light mode via `.preferredColorScheme(.light)` at the root. All 46 existing `.preferredColorScheme(.dark)` directives across 36 files must be removed, and a single `.preferredColorScheme(.light)` applied at the `TMIApp` level. Dark mode tokens are omitted from this spec — they can be added in a future release.

---

## Color System

### Brand Colors

| Token | Value | Role |
|---|---|---|
| `tmiPrimary` | `#D4930D` | Brand gold — tab bar, FAB, branding accents |
| `tmiPrimaryDeep` | `#B87A0A` | Emphasis, pressed states |
| `tmiSecondary` | `#3B6FA0` | Interactive blue — buttons, links, focus rings |

**Reference:** Icon spec canonical amber is `#F5A623`. The in-app `tmiPrimary` is slightly deeper for better contrast on white surfaces.

### Surfaces

| Token | Value |
|---|---|
| `tmiBackground` | `#FDF8F3` (warm cream) |
| `tmiSurface` | `#FFFFFF` |
| `tmiSurfaceElevated` | `#FFFFFF` |
| `tmiInputBackground` (new) | `#F5F0EB` |

### Text Hierarchy

| Token | Value |
|---|---|
| `tmiTextPrimary` | `#2D3436` (warm charcoal) |
| `tmiTextSecondary` | `#636E72` |
| `tmiTextTertiary` | `#94908B` |
| `tmiTextBrand` (new) | `#D4930D` |
| `tmiTextOnPrimary` (new) | `#FFFFFF` |
| `tmiTextOnSecondary` (new) | `#FFFFFF` |

### Borders & Dividers

| Token | Value |
|---|---|
| `tmiBorder` | `#E8E2DA` |
| `tmiDivider` | `#F0EBE4` |

### Semantic Colors

| Token | Value |
|---|---|
| `tmiSuccess` | `#2D9F6F` |
| `tmiWarning` | `#E8A817` |
| `tmiError` | `#DC3545` |
| `tmiInfo` | `#3B6FA0` |

### Quick Action Accent Colors

| Name | Hex | Usage |
|---|---|---|
| Gold | `#D4930D` | Add Student action |
| Sage | `#5B8C5A` | TMI Plans action |
| Coral | `#E07A5F` | Reports action |
| Blue | `#3B6FA0` | All Students action |

### Shadows

All shadows use `#2D3436` as base color instead of pure black (warmer on light backgrounds).

| Level | Radius | Opacity | Y-Offset |
|---|---|---|---|
| Raised | 2px | 0.05 | 1px |
| Elevated | 8px | 0.08 | 4px |
| Floating | 16px | 0.12 | 8px |

### Tokens to Delete

- `backgroundTop` / `backgroundBottom` — dark gradient artifacts
- `cardBackground` — black @ 50% opacity, no longer needed
- `tmiText` — deprecate, replaced by `tmiTextPrimary`
- `debugTMI*` colors — update or remove

---

## Component Redesign

### TMIBackgroundView

**Current:** 5 near-black gradient variants with animated blobs and particle effects.

**New:** 2 variants.

| Variant | Implementation |
|---|---|
| `.default` | Solid `tmiBackground` (`#FDF8F3`) |
| `.auth` | LinearGradient from `#FDF8F3` to `#F5EDE3` |

`.dashboard`, `.career`, `.plans` all map to `.default`.

**Delete:** `TMIParticleEffect` struct, animated primary/secondary blob overlays.

### TMICard (renamed from TMIGlassCard)

**Current:** 7 glass card variants with `ultraThinMaterial`, position-based gradient borders, blur overlays.

**New:** 3 solid card variants.

| Style | Background | Border | Shadow | Corner Radius | Replaces |
|---|---|---|---|---|---|
| `.default` | `#FFFFFF` | 1px `#E8E2DA` | Raised (2px, 0.05) | 12 | default, dashboard, form |
| `.elevated` | `#FFFFFF` | none | Elevated (8px, 0.08) | 16 | elevated, auth |
| `.outlined` | transparent | 1px `#E8E2DA` | none | 12 | minimal |

**Error states:** Default card + 3px left accent border in `#DC3545` — not a separate card variant.

**Delete:** `ultraThinMaterial` usage, `positionBasedGradient()`, `shadowOffset(for:)`, gradient border overlays, hover glass shimmer.

**Merge:** `TMIGlassCardStyle` (ComponentLibrary) and `TMICardStyle` (RedesignBridge) into single `TMICardStyle` enum.

### TMIButton

Same 7 styles, new colors:

| Style | Foreground | Background | Border |
|---|---|---|---|
| `.primary` | `#FFFFFF` | `#3B6FA0` | none |
| `.secondary` | `#3B6FA0` | transparent | 1.5px `#3B6FA0` |
| `.tertiary` | `#3B6FA0` | `#F0EBE4` | none |
| `.destructive` | `#FFFFFF` | `#DC3545` | none |
| `.floating` (FAB) | `#FFFFFF` | `#D4930D` (gold) | none |
| `.filter` (selected) | `#FFFFFF` | `#3B6FA0` | none |
| `.filter` (unselected) | `#636E72` | `#F0EBE4` | 1px `#E8E2DA` |
| `.icon` | `#636E72` | `#F0EBE4` | none |

Shadow for primary: `#3B6FA0` at 15% opacity. Shadow for FAB: `#D4930D` at 15% opacity.

### Interaction States

| Element | State | Behavior |
|---|---|---|
| TMIButton `.primary` | Default | `#3B6FA0` bg, white text |
| TMIButton `.primary` | Pressed | Scale 0.98 + darken 10% → `#335E88` |
| TMIButton `.primary` | Disabled | `#3B6FA0` at 40% opacity |
| TMIButton `.primary` | Loading | Spinner replaces label, bg unchanged |
| TMIButton `.floating` | Default | `#D4930D` bg, white text |
| TMIButton `.floating` | Pressed | Scale 0.98 + darken 10% → `#BF840C` |
| TMICard `.default` | Default | White + raised shadow |
| TMICard `.default` | Pressed/Tap | Scale 0.98, spring 0.3s (keep existing) |
| TMICard `.elevated` | Pressed/Tap | Scale 0.98 + shadow reduces to raised level |
| TMITextField | Default | 1px `#E8E2DA` border |
| TMITextField | Focused | 1.5px `#3B6FA0` border |
| TMITextField | Error | 1.5px `#DC3545` border |
| TMITextField | Disabled | `#F5F0EB` bg at 60% opacity, `#94908B` text |

### TMITextField

| Property | New Value |
|---|---|
| Background | `#F5F0EB` solid |
| Text color | `#2D3436` |
| Placeholder color | `#94908B` |
| Icon default | `#94908B` |
| Icon focused | `#3B6FA0` |
| Border default | 1px `#E8E2DA` solid |
| Border focused | 1.5px `#3B6FA0` solid |
| Shadow | `#2D3436` at 0.04 opacity |
| Corner radius | 12 (keep) |

### TMIProgressViewStyle

**Current:** Default color `tmiSecondary` (cyan), white track at 10% opacity, cyan shadow on fill.

**New:**

| Property | Value |
|---|---|
| Track color | `#E8E2DA` (`tmiBorder`) |
| Fill color | Linear gradient `tmiPrimary` → `tmiPrimary` at 80% (gold) |
| Height | 4pt (keep) |
| Corner radius | 10pt (keep) |
| Shadow on fill | Remove — unnecessary on light backgrounds |

### Tab Bar

`PremiumGlassTabBar` in `UIComponents.swift` is **dead code** — `MainTabView` already uses native `.tabViewStyle(.sidebarAdaptable)`. Delete `PremiumGlassTabBar` and `PremiumSidebarList` entirely.

Update native TabView styling:

| Property | Current | New |
|---|---|---|
| Accent/tint | `.accentColor(.tmiSecondary)` | `.tint(.tmiPrimary)` (gold) |

### TMILogoView

**Prerequisite:** No schoolhouse image asset currently exists in `Assets.xcassets`. A `schoolhouse-mark` imageset must be created (charcoal rounded square with amber schoolhouse symbol, matching the app icon design at display sizes). This is a blocker for the logo redesign step.

| Property | Current | New |
|---|---|---|
| Icon | `brain.head.profile` SF Symbol | App icon asset `schoolhouse-mark` (charcoal square with schoolhouse) |
| Glow | Radial gradient, cyan @ 0.7 | None — clean drop shadow only |
| Animation | Rotation 5deg, scale 0.9-1.1 | Remove animation — static mark |
| Text | "TMI" white, black shadow | "TMI" `#2D3436`, gold subtitle underneath |
| Subtitle | None | "TANGIBLE MODIFICATION INTERVENTION" in `#D4930D`, 12pt, weight 600 |

### TMIAvatar (in student cards)

| Property | Current | New |
|---|---|---|
| Fallback background | Gradient circle | Soft tinted circle (color @ 0.15 opacity) |
| Border | 2px `tmiPrimary` | None |
| Initials color | White | Matching accent color at full saturation |

---

## Screen Redesign

### Auth / Login

- Background: Linear gradient `#FDF8F3` → `#F5EDE3`
- Logo: App icon mark (charcoal rounded square, 72x72, 16pt radius) with elevated shadow
- "TMI" in `#2D3436`, gold subtitle below
- Form container: Elevated card (white, 16pt radius, elevated shadow)
- Inputs: Solid `#F5F0EB` with `#E8E2DA` border
- "Forgot Password?": `#3B6FA0`, 13pt, weight 500 (not tiny cyan)
- Primary button: `#3B6FA0` warm blue
- "New here? Create an account" in `#636E72` with `#3B6FA0` link

### Dashboard

- Header: Schoolhouse icon (32x32) + "Good morning!" greeting in `#2D3436`
- Subheader: "Here's your classroom overview" in `#636E72`
- Metric cards: White with subtle raised shadow, `#2D3436` numbers, `#636E72` labels
- Quick Action cards: White with 3px left accent borders (gold, sage, coral, blue) — each visually distinct
- Empty state: Dashed `#E8E2DA` border, wave emoji, encouraging copy ("Welcome! Let's get started"), warm blue CTA button

### Student List

- Cards: White with 1px `#E8E2DA` border, raised shadow
- Avatar: Soft tinted initials circle (e.g., blue tint `#E8F0F8` for blue-assigned students, coral tint `#FBEEE8` for coral-assigned)
- Name: `#2D3436` weight 600
- Details: `#636E72` 11pt
- Chevron disclosure indicator: `#94908B`

### TMI Plans

- Same card treatment as student list
- Plan type indicators use the Quick Action accent palette
- Progress bars: `tmiPrimary` gold fill on `#E8E2DA` track

### Settings / Profile

- Standard white cards on cream background
- Section headers in `#636E72` uppercase 12pt
- List rows: White background, `#E8E2DA` dividers

---

## What Stays Untouched

- **TMISpacing** — 8pt grid system (xxs through xxl)
- **TMIRadius** — Border radius scale (xs through full)
- **TMISizing** — Icon, avatar, control sizing constants
- **TMIAnimation** — All timing tokens (quick, standard, medium, slow, extraSlow) and spring presets
- **TMIHaptics** — All haptic feedback patterns
- **Typography scale** — Montserrat font family, all size/weight definitions
- **SF Symbols** — Iconography system
- **Staggered entrance animations** — Keep timing, just update colors
- **Semantic color structure** — Success/warning/error/info pattern (values updated, pattern preserved)

---

## Naming Changes

| Current | Action |
|---|---|
| `TMIGlassCard` | Rename → `TMICard` |
| `TMIGlassCardStyle` | Rename + merge with RedesignBridge's `TMICardStyle` → single `TMICardStyle` |
| `tmiGlassCard(style:)` | Rename → `tmiCard(style:)` |
| `PremiumGlassTabBar` | **Delete** (dead code — MainTabView uses native TabView) |
| `PremiumSidebarList` | **Delete** or rename → `TMISidebar` if used |
| `tmiPrimaryDark` | Rename → `tmiPrimaryDeep` |
| `tmiText` | Deprecate → `tmiTextPrimary` |
| `cardBackground` | Rename → `tmiCardBackground` |

---

## Code Deletion

- `TMIParticleEffect` struct + all references
- Animated gradient blob overlays in `TMIBackgroundView`
- `positionBasedGradient()` method
- `shadowOffset(for:)` position-based shadow method
- Radial glow circle in `TMILogoView`
- `brain.head.profile` SF Symbol in logo
- `backgroundTop` / `backgroundBottom` color tokens
- `debugTMI*` color tokens
- `PremiumGlassTabBar` component (dead code — not used by MainTabView)
- `PremiumSidebarList` component (verify usage first)
- 46 `.preferredColorScheme(.dark)` directives across 36 files (replaced by single `.light` at root)
- `ultraThinMaterial` usage across all components (~90 occurrences in 26 files)

---

## Implementation Order

1. **Force light mode** — Remove all 46 `.preferredColorScheme(.dark)` directives across 36 files. Add single `.preferredColorScheme(.light)` at `TMIApp` root level.
2. **Color tokens** — Update `Color+Extensions.swift` and `TMIDesignTokens.swift`. Single-file changes, all consumers update automatically.
3. **Component library** — Rewrite `TMIComponentLibrary.swift`: backgrounds, cards, buttons, text fields, progress view style.
4. **Delete dead code** — Remove `PremiumGlassTabBar`, `PremiumSidebarList`, `TMIParticleEffect`, animated blobs, glass helpers, deprecated tokens (`backgroundTop`, `backgroundBottom`, `debugTMI*`).
5. **Merge card styles** — Unify `TMIGlassCardStyle` + `TMICardStyle` into single `TMICardStyle` enum. Rename `TMIGlassCard` → `TMICard` across 143 occurrences in 48 files.
6. **Global material/blur sweep** — Replace ~90 `.ultraThinMaterial` occurrences across 26 files with solid colors and `TMIElevation` shadows.
7. **Global foreground color sweep** — Replace ~570 occurrences of `.foregroundColor(.white)` and `.foregroundColor(.tmiText)` across 84 files with `tmiTextPrimary` / `tmiTextOnPrimary` / `tmiTextOnSecondary` based on context.
8. **Tab bar** — Update MainTabView accent from `.accentColor(.tmiSecondary)` to `.tint(.tmiPrimary)`.
9. **Logo replacement** — Create `schoolhouse-mark` imageset in Assets.xcassets. Update `TMILogoView` to use it.
10. **Screen-specific fixes** — Touch up individual screens (dashboard greeting, empty states, student card avatars) that need layout changes beyond token swaps.

---

## WCAG Compliance Notes

| Pairing | Contrast Ratio | Passes |
|---|---|---|
| `#2D3436` on `#FFFFFF` | 14.7:1 | AAA |
| `#2D3436` on `#FDF8F3` | 13.8:1 | AAA |
| `#636E72` on `#FFFFFF` | 5.2:1 | AA |
| `#3B6FA0` on `#FFFFFF` | 5.0:1 | AA |
| `#D4930D` on `#FFFFFF` | 3.8:1 | AA Large text only — use for headings/icons, not body |
| `#FFFFFF` on `#3B6FA0` | 5.0:1 | AA |
| `#FFFFFF` on `#D4930D` | 3.8:1 | AA Large — acceptable for buttons (16pt+ bold) |
| Icon amber `#F5A623` on `#1C1C1E` | 8.4:1 | AAA |

---

## Blast Radius Summary

| Change | Files | Occurrences |
|---|---|---|
| Remove `.preferredColorScheme(.dark)` | 36 | 46 |
| Replace `.ultraThinMaterial` | 26 | ~90 |
| Rename `TMIGlassCard` → `TMICard` | 48 | 143 |
| Replace `.foregroundColor(.white/.tmiText)` | 84 | ~570 |
| Delete `TMIParticleEffect` | 1 | 2 |
| Delete `PremiumGlassTabBar` | 1 | 0 active |
| Delete `backgroundTop/Bottom` | 1 | 0 active |
| Replace glass/blur helpers | 31 | ~90+ |
| Create schoolhouse asset | N/A | N/A |
| **Total estimated** | **~120 unique files** | **~940+ occurrences** |
