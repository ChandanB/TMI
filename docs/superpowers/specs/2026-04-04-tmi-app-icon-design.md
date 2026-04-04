# TMI App Icon Design Spec

**Date:** 2026-04-04
**Status:** Approved for implementation
**Scope:** iOS and macOS app icon — symbol mark + wordmark

---

## Summary

A minimal geometric school building mark in amber on a charcoal background, paired with the "TMI" wordmark. Professional and institutional in tone. Distinctive on the iOS home screen due to the dark + amber palette, which stands apart from the blue-dominant EdTech app category.

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Tone | Professional & Institutional | Primary audience is teachers and district admins, not students |
| Mark type | Symbol + Wordmark | More distinctive than wordmark alone; symbol carries meaning |
| Symbol | School building | Immediately communicates the educational/institutional context |
| Building style | Minimal geometric | Holds legibility down to 29×29px; avoids over-illustration |
| Color | Charcoal + Amber | Distinctive in the App Store; amber reads as warm authority |

---

## Visual Language

### Color Tokens

| Token | Hex | Usage |
|-------|-----|-------|
| Background | `#1C1C1E` | Icon background (matches Apple System Gray 6 / near-black) |
| Amber Accent | `#F5A623` | Building symbol, wordmark, flag pole |

**Contrast:** Amber on charcoal yields ~8.4:1 — passes WCAG AAA.

### Typography

- **Wordmark:** "TMI" in SF Pro Display (or system-ui equivalent), weight 800, letter-spacing 4px
- **Size:** Scales with icon — approximately 16–20% of icon height

---

## Symbol Construction

The school building mark is built from four geometric primitives:

### 1. Flag Pole
- Thin vertical rect at horizontal center, apex of roof
- Opacity 55% — subtle institutional signal, not dominant

### 2. Roof
- Two diagonal stroke lines meeting at apex (~15° pitch — shallow/institutional, not residential ~45°)
- Capped with a horizontal flat band rect
- **Critical:** Pitch must stay shallow. Steep triangular roofs read as residential houses (SF Symbols `house`). The flat-band cap reinforces the civic/institutional read.

### 3. Building Body
- Wide horizontal rectangle — wider than tall
- Fills the lower ~65% of the icon safe area
- Corner radius: 3–4pt at 100pt scale

### 4. Window Band (3 windows)
- Three equal-width windows in a horizontal row across the upper third of the body
- Equal spacing between windows and from body edges
- **Critical:** Must be 3 windows in a row, not 2 isolated squares. Two windows flanking a door is the universal house symbol. Three in a row reads as a school corridor/hallway.
- Fill: background color at 72% opacity (punched out of the amber body)

### 5. Door
- Centered below the window band
- Taller than windows, narrower than window width
- Extends to the bottom of the building body

---

## Icon Grid (100pt coordinate space)

All values are in a 100×86pt viewBox:

```
Flag pole:     x=49, y=2,  w=2,  h=10  (opacity 0.55)
Roof left:     line (6,26) → (50,13), stroke-width 5.5, linecap round
Roof right:    line (94,26) → (50,13), stroke-width 5.5, linecap round
Roof band:     x=4,  y=24, w=92, h=6,  rx=3
Body:          x=4,  y=30, w=92, h=54, rx=3
Window 1:      x=10, y=40, w=20, h=12, rx=2  (opacity 0.72)
Window 2:      x=40, y=40, w=20, h=12, rx=2  (opacity 0.72)
Window 3:      x=70, y=40, w=20, h=12, rx=2  (opacity 0.72)
Door:          x=38, y=58, w=24, h=26, rx=2.5
```

---

## Size Ladder

| Size | Context | Notes |
|------|---------|-------|
| 1024×1024 | App Store submission, iOS 1x | Full detail including flag pole and 3-window band |
| 512×512 | macOS 1x | Same as 1024, scaled |
| 60×60 | iOS home screen | All elements legible; wordmark readable |
| 29×29 | Notification / Settings | Drop flag pole; simplify windows or omit; door remains for silhouette read |

At 29×29, the building silhouette (shallow roof + wide body + door cutout) is sufficient to read as "institutional building." The wordmark is not legible at this size and should not be forced.

---

## What to Avoid

- **Steep triangular roof:** Immediately reads as the SF Symbols `house` icon. Keep pitch ≤ 15°.
- **Two isolated windows:** Classic house composition. Always use three windows in a horizontal band.
- **Centered composition with one door and two windows:** This is the exact geometry of every "home" icon — avoid at all costs.
- **All-dark or embossed treatment:** Prior AI-generated icon used dark-on-dark embossing, which has near-zero contrast and disappears on dark wallpapers.

---

## Implementation Notes

- Produce the icon as a vector SVG first, then export at required pixel sizes
- The iOS 1024×1024 submission asset must be a PNG with no alpha channel (App Store requirement)
- macOS icons can use the same mark; the rounded rect mask is applied by the OS
- Store all icon assets in `Assets.xcassets/AppIcon.appiconset/`
- Remove the existing AI-generated placeholder images (`ChatGPT Image Apr 1, 2026, 02_42_19 PM.png` variants) once replacement assets are produced

---

## Files to Update

| File | Change |
|------|--------|
| `Assets.xcassets/AppIcon.appiconset/Contents.json` | Point to new PNG assets at each required size |
| `Assets.xcassets/AppIcon.appiconset/*.png` | Replace with new icon exports |
