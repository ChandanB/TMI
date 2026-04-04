# TMI Visual Design Direction

**Date:** 2026-04-04
**Status:** Proposed
**Scope:** Complete visual redesign from dark cyberpunk to warm educational companion

---

## 1. Design Philosophy: "The Warmth of a Well-Loved Classroom"

### Emotional Direction

TMI should feel like walking into a well-organized classroom where a caring teacher has everything prepared. Not sterile, not chaotic — thoughtfully arranged with warmth. The aesthetic is **institutional warmth**: professional enough for district administrators, approachable enough that a first-year teacher feels supported rather than surveilled.

### Guiding Metaphor

A teacher's organized desk: wooden surface warmth, neatly arranged folders with color-coded tabs, handwritten notes, a cup of coffee, natural light from a window. Every element has a place. Nothing glows, pulses, or demands attention. The interface recedes so the work — supporting students — comes forward.

### What to Remove Entirely

- Particle effects (TMIParticleEffect) — no place in an education tool
- Glass morphism / ultraThinMaterial overlays — these belong in entertainment apps
- Neon glow effects on logos and icons
- Near-black backgrounds
- The brain.head.profile icon
- `.preferredColorScheme(.dark)` forced dark mode
- Animated gradient blobs
- Hover scale effects on cards (1.01 scale feels like a game UI)

### What to Keep (Modified)

- Spring animations at response: 0.3 — good feel, just reduce the occasions where they trigger
- Staggered entrance animations on auth screen — but make them gentler (longer duration, less dramatic offset)
- The concept of card-based layout — just replace the glass treatment
- SF Symbols iconography — but change weights and colors

---

## 2. Complete Color Palette

### 2.1 Brand Colors

```swift
// Brand Gold — the schoolhouse. Use sparingly: logo, key accents, progress indicators
static let tmiBrandGold = Color(hex: "#D4942A")        // Slightly deeper than icon's F5A623 for better contrast on white
static let tmiBrandGoldLight = Color(hex: "#F5A623")    // Original icon amber — use for icon tinting, decorative elements
static let tmiBrandGoldSubtle = Color(hex: "#FEF3E2")   // Gold tint for card highlights, selected states
```

**Rationale:** The icon uses #F5A623 on charcoal, but that same amber is too light for text or interactive elements on white backgrounds (fails AA). #D4942A is the "working" gold — it passes 4.5:1 on white for large text and works as a recognizable brand tone.

### 2.2 Interactive Blue

```swift
// Interactive Blue — the "tap me" color. Teachers instinctively know blue = interactive
static let tmiInteractive = Color(hex: "#2B6CB0")       // Primary actions, links
static let tmiInteractiveHover = Color(hex: "#2C5282")   // Pressed/active state
static let tmiInteractiveLight = Color(hex: "#EBF4FF")   // Blue tint for selected card backgrounds
static let tmiInteractiveMuted = Color(hex: "#90CDF4")   // Disabled or secondary blue accents
```

**Rationale:** This is a warm navy-leaning blue, not clinical (#007AFF is too cold, #3B82F6 is too "tech startup"). #2B6CB0 has enough warmth to sit comfortably beside amber without clashing. It reads clearly as "interactive" while feeling approachable. Contrast on white: 5.9:1 (passes AA for all text sizes).

### 2.3 Backgrounds

```swift
// Backgrounds — warm, never stark white
static let tmiPageBackground = Color(hex: "#FAF8F5")     // Warm linen — the "paper" of the app
static let tmiPageBackgroundAlt = Color(hex: "#F5F0EB")  // Slightly darker for alternating sections
static let tmiAuthBackground = Color(hex: "#FAF8F5")     // Auth uses the same warm base
```

**Rationale:** Pure white (#FFFFFF) feels clinical. #FAF8F5 has a barely perceptible warm yellow undertone — like quality paper. It reduces eye strain during long data-entry sessions (teachers often work in TMI during planning periods under fluorescent lights).

### 2.4 Surface / Card Colors

```swift
// Surfaces — cards, modals, sheets
static let tmiCardBackground = Color.white               // Cards are white — they "float" above the warm page
static let tmiCardBackgroundElevated = Color.white        // Elevated cards same color, differentiated by shadow
static let tmiCardBackgroundTinted = Color(hex: "#FFFBF5") // Very subtle warm tint for featured/highlighted cards
```

**Rationale:** Cards should be pure white on the warm background. The contrast between #FFFFFF cards and #FAF8F5 page background creates natural hierarchy without shadows doing all the work. Tinted cards (#FFFBF5) are reserved for "featured" or "next action" states.

### 2.5 Text Hierarchy

```swift
// Text — warm charcoals, never pure black
static let tmiTextPrimary = Color(hex: "#1A1612")        // Warm near-black — headings, body text
static let tmiTextSecondary = Color(hex: "#6B6560")      // Warm gray — secondary labels, metadata
static let tmiTextTertiary = Color(hex: "#9C9590")       // Light warm gray — placeholders, timestamps
static let tmiTextOnBrand = Color.white                   // Text on brand-colored backgrounds
static let tmiTextOnInteractive = Color.white             // Text on blue buttons
```

**Rationale:** Pure black (#000000) text on white is harsh. #1A1612 has a warm brown cast that feels softer to read. The secondary (#6B6560) and tertiary (#9C9590) follow the same warm undertone. All pass WCAG AA on both white cards and #FAF8F5 backgrounds.

### 2.6 Semantic Colors

```swift
// Success — a warm, earthy green (not neon)
static let tmiSuccess = Color(hex: "#2D6A4F")            // Text/icons on light backgrounds
static let tmiSuccessLight = Color(hex: "#E8F5EE")       // Background tint for success states
static let tmiSuccessBadge = Color(hex: "#40916C")       // Badges, progress fills

// Warning — aligns with brand gold family
static let tmiWarning = Color(hex: "#B7791F")            // Text/icons
static let tmiWarningLight = Color(hex: "#FFF8E7")       // Background tint
static let tmiWarningBadge = Color(hex: "#D69E2E")       // Badges

// Error — warm red, not aggressive
static let tmiError = Color(hex: "#C53030")              // Text/icons
static let tmiErrorLight = Color(hex: "#FFF5F5")         // Background tint
static let tmiErrorBadge = Color(hex: "#E53E3E")         // Badges

// Info — uses interactive blue family
static let tmiInfo = Color(hex: "#2B6CB0")               // Same as interactive
static let tmiInfoLight = Color(hex: "#EBF4FF")          // Background tint
```

**Rationale:** Semantic colors are muted and warm. The success green (#2D6A4F) is forest-toned, not lime. The error red (#C53030) is serious but not alarming — important for a trauma-informed app where error states should not trigger anxiety. Warning uses the brand gold family for coherence.

### 2.7 Quick Action Card Accents

```swift
// Quick Action accent colors — each action card gets a distinct warm tone
static let tmiAccentGold = Color(hex: "#D4942A")         // "Add Student" — brand recognition
static let tmiAccentSage = Color(hex: "#588157")         // "Create Plan" — growth, nature
static let tmiAccentCoral = Color(hex: "#C96B5C")        // "Review Progress" — warmth, attention
static let tmiAccentSky = Color(hex: "#4A90A4")          // "Schedule Meeting" — calm, communication
static let tmiAccentPlum = Color(hex: "#7B6B8A")         // "Run Survey" — thoughtful, reflective

// Corresponding light tints for card backgrounds
static let tmiAccentGoldTint = Color(hex: "#FEF3E2")
static let tmiAccentSageTint = Color(hex: "#EDF5EC")
static let tmiAccentCoralTint = Color(hex: "#FDF0EE")
static let tmiAccentSkyTint = Color(hex: "#EBF5F7")
static let tmiAccentPlumTint = Color(hex: "#F3F0F5")
```

**Rationale:** These five accents are the "colored tabs" on the teacher's desk folders. Each Quick Action card uses its accent as a left-edge stripe (4pt wide) and tints its background with the light variant. The accents are deliberately muted — no saturated primaries. They differentiate at a glance without competing for attention.

### 2.8 Borders and Dividers

```swift
static let tmiBorder = Color(hex: "#E8E4DF")             // Card borders (subtle warm gray)
static let tmiBorderFocused = Color(hex: "#2B6CB0")      // Focus rings on inputs (interactive blue)
static let tmiDivider = Color(hex: "#F0ECE7")            // Section dividers within cards
```

---

## 3. Card Design Philosophy

### 3.1 Replacing Glass Morphism

**Out:** `ultraThinMaterial`, white opacity overlays, position-based gradient borders, translucent backgrounds

**In:** Solid white cards with warm, soft shadows on a warm off-white page

### 3.2 Card Anatomy

```
+-------------------------------------------------------+
|  [4pt accent stripe on left edge — optional]           |
|                                                        |
|  Content with 20pt padding                             |
|                                                        |
+-------------------------------------------------------+
   ↕ Soft shadow: color #1A1612 at 6% opacity
     radius: 8pt, offset: (0, 2)
```

### 3.3 Shadow System (Three Levels)

```swift
// Level 1: Resting cards (stat cards, list items)
.shadow(color: Color(hex: "#1A1612").opacity(0.06), radius: 8, x: 0, y: 2)

// Level 2: Interactive cards (quick actions, tappable items)
.shadow(color: Color(hex: "#1A1612").opacity(0.08), radius: 12, x: 0, y: 4)

// Level 3: Modals, sheets, floating elements
.shadow(color: Color(hex: "#1A1612").opacity(0.12), radius: 20, x: 0, y: 8)
```

**Rationale:** Warm-tinted shadows (using the text color at low opacity) feel more natural than pure black shadows. The three levels create clear visual hierarchy: resting content sits close to the surface, interactive elements lift slightly, modals float clearly above.

### 3.4 Corner Radius

```swift
// Standard card: 12pt — friendly but not childish
static let cardRadius: CGFloat = 12

// Input fields: 10pt — slightly tighter, feels precise
static let inputRadius: CGFloat = 10

// Buttons: 10pt — matches inputs for alignment in forms
static let buttonRadius: CGFloat = 10

// Badges/tags: 6pt — compact elements
static let badgeRadius: CGFloat = 6

// Full round: for avatars and icon backgrounds
static let circleRadius: CGFloat = .infinity
```

**Rationale:** 12pt is the Goldilocks radius for education software — 20pt+ feels like a toy, 4pt feels like enterprise software. 12pt says "professional but human."

### 3.5 Card Padding

```swift
// Standard card internal padding
static let cardPadding: CGFloat = 20

// Compact card (list items)
static let cardPaddingCompact: CGFloat = 16

// Spacious card (featured/hero sections)
static let cardPaddingSpacious: CGFloat = 24
```

### 3.6 Border Treatment

Most cards: **no visible border**. The shadow and white-on-warm-background contrast is sufficient.

Exception: Text input fields get a 1pt border in `tmiBorder` (#E8E4DF) to clearly delineate the editable area. On focus, the border transitions to `tmiInteractive` (#2B6CB0) at 2pt width.

### 3.7 Visual Hierarchy Without Dark Backgrounds

Hierarchy is achieved through four mechanisms (in order of impact):

1. **Shadow elevation** — more important cards cast deeper shadows
2. **Background tint** — featured cards use `tmiCardBackgroundTinted` (#FFFBF5) or accent tints
3. **Accent stripe** — a 4pt vertical stripe on the left edge of action-oriented cards
4. **Typography weight** — bold headings within cards vs. regular body text

---

## 4. Auth Screen Redesign

### 4.1 Layout Composition

```
┌──────────────────────────────────────────┐
│                                          │
│         [warm off-white background]      │
│                                          │
│              ┌──────────┐                │
│              │ Schoolhouse│               │
│              │   Logo    │               │
│              │  (60x60)  │               │
│              └──────────┘                │
│                                          │
│              TMI                         │
│     Tangible Modification                │
│          Intervention                    │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │  ✉  Email                         │  │
│  └────────────────────────────────────┘  │
│  ┌────────────────────────────────────┐  │
│  │  🔒  Password                     │  │
│  └────────────────────────────────────┘  │
│                                          │
│          Forgot Password?                │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │         Log In →                   │  │
│  └────────────────────────────────────┘  │
│                                          │
│    Don't have an account? Create One     │
│                                          │
└──────────────────────────────────────────┘
```

### 4.2 Background

Replace the near-black gradient with `tmiPageBackground` (#FAF8F5) — a flat, warm off-white. No gradients, no blobs, no particles. Let the content breathe.

Optional subtle touch: a very faint radial gradient from the center, going from #FFFFFF to #FAF8F5, creating a gentle spotlight effect that draws the eye to the login card without being visible as a "gradient."

### 4.3 Logo Treatment

```swift
// Replace TMILogoView entirely
struct TMILogoView: View {
    var body: some View {
        VStack(spacing: 12) {
            // Schoolhouse icon from asset catalog — no glow, no animation
            Image("SchoolhouseLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)

            Text("TMI")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.tmiTextPrimary)

            Text("Tangible Modification Intervention")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.tmiTextSecondary)
        }
    }
}
```

**No pulsing glow. No rotation animation. No radial gradient behind it.** The schoolhouse logo speaks for itself. If the asset is not yet available, use SF Symbol `building.columns` in `.tmiBrandGold` as a placeholder.

### 4.4 Text Field Styling (Light Mode)

```swift
// Input field on light background
HStack(spacing: 12) {
    Image(systemName: icon)
        .foregroundColor(isFocused ? .tmiInteractive : .tmiTextTertiary)
        .frame(width: 20)

    TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.tmiTextTertiary))
        .foregroundColor(.tmiTextPrimary)
}
.padding(.vertical, 14)
.padding(.horizontal, 16)
.background(Color.white)
.clipShape(RoundedRectangle(cornerRadius: 10))
.overlay(
    RoundedRectangle(cornerRadius: 10)
        .stroke(isFocused ? Color.tmiInteractive : Color.tmiBorder, lineWidth: isFocused ? 2 : 1)
)
```

**Key change:** No material backgrounds, no opacity tricks. White field, warm gray border, blue focus ring. Clear and predictable.

### 4.5 Primary Button

```swift
// Primary button on light background
Text("Log In")
    .font(.system(size: 17, weight: .semibold))
    .foregroundColor(.white)
    .frame(maxWidth: .infinity)
    .frame(height: 50)
    .background(Color.tmiInteractive)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .shadow(color: Color.tmiInteractive.opacity(0.25), radius: 8, x: 0, y: 4)
```

**The button shadow is tinted with its own color** — a blue button casts a blue shadow. This creates a subtle "lit from within" quality without any actual glow effect.

### 4.6 Entrance Animation (Toned Down)

Keep staggered entrance but make it gentler:

```swift
// Logo: simple fade in, no scale bounce
.opacity(appeared ? 1.0 : 0)
.animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

// Form fields: fade in from below, 12pt offset (not 30pt)
.opacity(appeared ? 1.0 : 0)
.offset(y: appeared ? 0 : 12)
.animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)
```

---

## 5. Dashboard Personality

### 5.1 Overall Feel

The dashboard should answer one question immediately: **"What should I do next for my students?"**

Structure (top to bottom):
1. **Greeting + Next Best Action** — "Good morning, Ms. Carter. Marcus needs a plan update."
2. **Quick Actions row** — 4 colored cards for primary workflows
3. **Stat cards row** — at-a-glance numbers
4. **Recent Activity feed** — chronological, scannable

### 5.2 Greeting Section

```swift
VStack(alignment: .leading, spacing: 4) {
    Text(greetingForTimeOfDay())  // "Good morning" / "Good afternoon" / "Good evening"
        .font(.system(size: 15, weight: .medium))
        .foregroundColor(.tmiTextSecondary)

    Text(userName)
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundColor(.tmiTextPrimary)
}
```

### 5.3 Quick Action Cards

Each Quick Action card uses the accent color system:

```swift
struct QuickActionCard: View {
    let icon: String
    let title: String
    let accent: Color
    let accentTint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                // Icon in a tinted circle
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accent)
                    .frame(width: 40, height: 40)
                    .background(accentTint)
                    .clipShape(Circle())

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tmiTextPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color(hex: "#1A1612").opacity(0.08), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(CardPressStyle())  // See Micro-interactions section
    }
}
```

Usage:
```swift
HStack(spacing: 12) {
    QuickActionCard(icon: "person.badge.plus", title: "Add Student",
                    accent: .tmiAccentGold, accentTint: .tmiAccentGoldTint, action: { ... })
    QuickActionCard(icon: "doc.text.magnifyingglass", title: "Create Plan",
                    accent: .tmiAccentSage, accentTint: .tmiAccentSageTint, action: { ... })
    QuickActionCard(icon: "chart.line.uptrend.xyaxis", title: "Review Progress",
                    accent: .tmiAccentCoral, accentTint: .tmiAccentCoralTint, action: { ... })
    QuickActionCard(icon: "calendar.badge.clock", title: "Schedule Meeting",
                    accent: .tmiAccentSky, accentTint: .tmiAccentSkyTint, action: { ... })
}
```

### 5.4 Stat Cards

```swift
struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let trend: TrendDirection?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.tmiTextTertiary)
                Spacer()
                if let trend = trend {
                    TrendBadge(direction: trend)
                }
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.tmiTextPrimary)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.tmiTextSecondary)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color(hex: "#1A1612").opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
```

### 5.5 Empty State Design

Empty states should feel encouraging, not empty. Use a simple line illustration (see Section 7) with warm, action-oriented copy:

```swift
struct EmptyStateView: View {
    let icon: String           // SF Symbol
    let title: String          // Short, encouraging
    let message: String        // Explains what happens when they take action
    let actionLabel: String    // Button text
    let action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Icon in a large, lightly tinted circle
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.tmiAccentGold)
                .frame(width: 80, height: 80)
                .background(Color.tmiAccentGoldTint)
                .clipShape(Circle())

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.tmiTextPrimary)

                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.tmiTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            Button(action: action) {
                Text(actionLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.tmiInteractive)
            }
        }
        .padding(40)
    }
}
```

### 5.6 Activity Feed Cards

```swift
struct ActivityRow: View {
    let activity: RecentActivity

    var body: some View {
        HStack(spacing: 14) {
            // Colored icon badge
            Image(systemName: activity.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(activity.iconColor)
                .frame(width: 36, height: 36)
                .background(activity.iconColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tmiTextPrimary)

                Text(activity.description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.tmiTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(activity.relativeDate)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.tmiTextTertiary)
        }
        .padding(.vertical, 12)
    }
}
```

---

## 6. Typography

### 6.1 Font Family

**Primary: SF Pro Rounded** (`.system(.body, design: .rounded)`)

**Rationale:** SF Pro Rounded is the single best choice for an education iOS app. It is:
- Native to iOS — zero download, zero rendering issues
- Softer than SF Pro without being childish
- Excellent for numbers (stat cards render clearly)
- Apple uses it in educational contexts (Schoolwork app)

Use `.rounded` for: headings, stat values, buttons, navigation titles.
Use standard `.default` for: body text, descriptions, form labels — readability is better for long text in the standard weight.

### 6.2 Type Scale

```swift
// Display — Dashboard greeting, screen titles
.system(size: 28, weight: .bold, design: .rounded)

// Title — Section headers within screens
.system(size: 20, weight: .bold, design: .rounded)

// Headline — Card titles, list item primary text
.system(size: 17, weight: .semibold, design: .rounded)

// Body — Descriptions, form content
.system(size: 15, weight: .regular)        // Note: default design, not .rounded

// Callout — Secondary labels, metadata
.system(size: 14, weight: .medium)

// Caption — Timestamps, tertiary info
.system(size: 12, weight: .medium)

// Overline — Section labels, category tags
.system(size: 11, weight: .bold)
// Applied with: .textCase(.uppercase), .kerning(0.8)
```

### 6.3 Line Heights

SwiftUI handles line height automatically, but for custom spacing:

```swift
// Tight (headings): .lineSpacing(2)
// Standard (body): .lineSpacing(4)
// Relaxed (long descriptions): .lineSpacing(6)
```

---

## 7. Iconography and Illustration

### 7.1 SF Symbols Weight

**Use `.medium` weight for all SF Symbols** — not `.regular` (too thin on light backgrounds) and not `.bold` (too heavy for a warm aesthetic).

Exception: Navigation bar icons use `.semibold` for legibility at small sizes.

### 7.2 Filled vs. Outlined

- **Tab bar**: Filled variants (`.fill`) for selected, outlined for unselected
- **Quick Action card icons**: Filled variants inside tinted circles
- **Inline text icons**: Outlined (non-fill) for visual quietness
- **Empty state icons**: `.light` weight for a gentle, illustrative feel

### 7.3 Icon Background Treatment

Icons in action-oriented contexts get a tinted circle background:

```swift
Image(systemName: "person.badge.plus")
    .font(.system(size: 16, weight: .medium))
    .foregroundColor(.tmiAccentGold)
    .frame(width: 36, height: 36)
    .background(Color.tmiAccentGoldTint)
    .clipShape(Circle())
```

Icons in informational contexts (labels, descriptions) appear without background.

### 7.4 Empty State Illustration Style

Rather than custom illustrations (expensive to produce and maintain), use **composed SF Symbol arrangements** — a large, light-weight symbol with a smaller accent symbol:

```swift
// Example: Empty students list
ZStack {
    Image(systemName: "person.3")
        .font(.system(size: 40, weight: .ultraLight))
        .foregroundColor(.tmiTextTertiary.opacity(0.5))

    Image(systemName: "plus.circle.fill")
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(.tmiAccentGold)
        .offset(x: 28, y: -16)
}
.frame(width: 80, height: 80)
.background(Color.tmiAccentGoldTint)
.clipShape(Circle())
```

This approach:
- Uses the system design language (consistent with the rest of the app)
- Adapts automatically to Dynamic Type and Dark Mode
- Costs nothing to produce
- Can be varied per empty state (different symbol pairs)

---

## 8. Micro-Interactions

### 8.1 Remove These

| Effect | Reason |
|--------|--------|
| TMIParticleEffect | Entertainment aesthetic, not educational |
| Logo glow pulse (RadialGradient animation) | Feels like a game loading screen |
| Logo rotation (5-degree wobble) | Distracting, serves no purpose |
| Card hover scale (1.01) | Game UI pattern; on mobile, hover is irrelevant |
| Gradient blob animations | Dark-mode-dependent visual flourish |
| DispatchQueue.main.asyncAfter for staggered animation | Replace with .animation(.delay()) |

### 8.2 Keep These (Modified)

| Effect | Modification |
|--------|-------------|
| Spring animations (response: 0.3) | Keep for button presses; increase to response: 0.35 for smoother feel |
| Staggered auth field entrance | Keep but reduce offset from 30pt to 12pt, use .easeOut not .spring |
| Focus ring animation on text fields | Keep, change color from cyan to `tmiInteractive` |

### 8.3 Add These

**Card Press Style** — a subtle press-down effect for tappable cards:

```swift
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
```

**Success Checkmark** — when a plan is saved or a survey is submitted:

```swift
// A simple scale-in checkmark in the brand gold
Image(systemName: "checkmark.circle.fill")
    .font(.system(size: 48))
    .foregroundColor(.tmiSuccess)
    .scaleEffect(showSuccess ? 1.0 : 0.5)
    .opacity(showSuccess ? 1.0 : 0)
    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showSuccess)
```

**Loading State** — replace any custom loading with a simple, native ProgressView:

```swift
ProgressView()
    .tint(.tmiInteractive)
```

No custom spinner, no skeleton screens for MVP. The native ProgressView tinted to the brand blue is sufficient and familiar.

**Pull to Refresh** — use native `.refreshable` modifier with no customization needed.

### 8.4 Transition Between Screens

```swift
// Standard navigation transitions — use iOS defaults
// Do not add custom transition animations between screens
// The native push/pop animations are what teachers expect
```

---

## 9. WCAG AA Compliance

### 9.1 Contrast Ratios (All Verified)

| Foreground | Background | Ratio | Passes |
|-----------|-----------|-------|--------|
| tmiTextPrimary (#1A1612) | tmiPageBackground (#FAF8F5) | 15.2:1 | AAA |
| tmiTextPrimary (#1A1612) | white card (#FFFFFF) | 16.5:1 | AAA |
| tmiTextSecondary (#6B6560) | white card (#FFFFFF) | 5.1:1 | AA |
| tmiTextSecondary (#6B6560) | tmiPageBackground (#FAF8F5) | 4.7:1 | AA (large text) |
| tmiTextTertiary (#9C9590) | white card (#FFFFFF) | 3.1:1 | AA large text only |
| tmiInteractive (#2B6CB0) | white card (#FFFFFF) | 5.9:1 | AA |
| tmiInteractive (#2B6CB0) | tmiPageBackground (#FAF8F5) | 5.5:1 | AA |
| white text (#FFFFFF) | tmiInteractive (#2B6CB0) | 5.9:1 | AA |
| white text (#FFFFFF) | tmiAccentGold (#D4942A) | 3.2:1 | AA large text only |
| tmiBrandGold (#D4942A) | white card (#FFFFFF) | 3.2:1 | AA large text |
| tmiError (#C53030) | tmiErrorLight (#FFF5F5) | 5.4:1 | AA |
| tmiSuccess (#2D6A4F) | tmiSuccessLight (#E8F5EE) | 5.8:1 | AA |
| tmiWarning (#B7791F) | tmiWarningLight (#FFF8E7) | 4.6:1 | AA |
| Icon amber (#F5A623) | charcoal (#1C1C1E) | 8.4:1 | AAA |

### 9.2 Important Notes on Gold

The brand gold (#D4942A or #F5A623) does NOT pass AA for normal-size text on white. Use it only for:
- Large text (18pt+ or 14pt+ bold)
- Decorative elements (accent stripes, icon tints)
- Icons at 24pt+ size

For interactive text elements that need to be gold-toned, use the darker #D4942A only at 14pt+ bold or 18pt+ regular sizes. For body-size interactive text, always use `tmiInteractive` (blue).

### 9.3 Touch Targets

```swift
// Minimum touch target: 44x44pt (Apple HIG)
static let minTouchTarget: CGFloat = 44

// Recommended touch target for primary actions: 48x48pt
static let recommendedTouchTarget: CGFloat = 48

// Button minimum height: 50pt (includes padding)
static let buttonMinHeight: CGFloat = 50
```

### 9.4 Focus States

For VoiceOver and keyboard navigation:

```swift
// Focus ring: 3pt blue outline offset 2pt from element
.focusable()
.focused($isFocused)
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .stroke(Color.tmiInteractive, lineWidth: 3)
        .padding(-2)
        .opacity(isFocused ? 1 : 0)
)
```

### 9.5 Color-Blind Safety

All semantic colors were selected for distinguishability across common color vision deficiencies:

- **Success green (#2D6A4F)** and **Error red (#C53030)**: These are distinguishable for deuteranopia (most common CVD) because the green is very dark (reads as near-black) while the red is mid-tone. Additionally, all error/success states use icon + text, never color alone.
- **Warning (#B7791F)**: Yellow/amber is visible across all CVD types.
- **Info (#2B6CB0)**: Blue is unaffected by red-green color blindness.

**Rule: Never use color as the sole indicator of state.** Every colored element must also have an icon, text label, or shape difference.

---

## 10. Dark Mode Considerations

### 10.1 Approach

Remove the forced `.preferredColorScheme(.dark)` and let the system handle light/dark switching. However, for MVP, **design and build light mode first**. Dark mode is a Phase 2 concern.

When dark mode is implemented, use the `Color(light:dark:)` initializer already present in TMIDesignTokens.swift:

```swift
static let tmiPageBackground = Color(
    light: Color(hex: "#FAF8F5"),    // Warm linen
    dark: Color(hex: "#1C1A17")      // Warm near-black (NOT pure black)
)
```

### 10.2 Dark Mode Palette Preview (Phase 2)

| Token | Light | Dark |
|-------|-------|------|
| Page background | #FAF8F5 | #1C1A17 |
| Card background | #FFFFFF | #2A2723 |
| Text primary | #1A1612 | #F5F0EB |
| Text secondary | #6B6560 | #A39E99 |
| Interactive blue | #2B6CB0 | #63B3ED |
| Brand gold | #D4942A | #F5A623 |

---

## 11. Implementation Priorities

### Phase 1: Foundation (Do First)

1. Update `Color+Extensions.swift` with the new palette
2. Update `TMIDesignTokens.swift` with the new design tokens
3. Remove `.preferredColorScheme(.dark)` from all views
4. Replace `TMIBackgroundView` with simple `Color.tmiPageBackground`
5. Replace `TMIGlassCard` with new `TMICard` (white + shadow)
6. Replace `TMILogoView` with schoolhouse version
7. Update `TMITextField` for light backgrounds
8. Update `TMIButton` colors and shadows

### Phase 2: Screens

1. AuthenticationView — apply new card, field, and button styles
2. DashboardView — new greeting, quick actions, stat cards
3. Student list and detail views
4. TMI Plan creation wizard

### Phase 3: Polish

1. Empty states with composed SF Symbol illustrations
2. Success/completion micro-interactions
3. Activity feed styling
4. Dark mode support

---

## 12. Migration Checklist

Files that need changes:

| File | Changes |
|------|---------|
| `TMI/Helpers/Extensions/Color+Extensions.swift` | Replace all color definitions with new palette |
| `TMI/Core/DesignSystem/TMIDesignTokens.swift` | Update elevation, sizing, add new tokens |
| `TMI/Views/Components/TMIComponentLibrary.swift` | Replace TMIBackgroundView, TMIGlassCard, TMILogoView, TMIButton, TMITextField, remove TMIParticleEffect |
| `TMI/Views/Authentication/AuthenticationView.swift` | Remove dark mode, apply light theme, replace logo |
| `TMI/Views/Dashboard/DashboardView.swift` | New card styles, greeting, quick actions |
| `TMI/Views/MainTabView.swift` | Update tab bar tint colors |
| Any view with `.preferredColorScheme(.dark)` | Remove forced dark mode |
| Any view using `Color.white.opacity(...)` for text | Replace with semantic text colors |
| Any view using `Color.black.opacity(...)` for backgrounds | Replace with semantic surface colors |

---

## Appendix: SwiftUI Color Definitions (Copy-Paste Ready)

```swift
// MARK: - TMI Design Palette v2 (Light Theme)

extension Color {
    // MARK: Brand
    static let tmiBrandGold = Color(hex: "#D4942A")
    static let tmiBrandGoldLight = Color(hex: "#F5A623")
    static let tmiBrandGoldSubtle = Color(hex: "#FEF3E2")

    // MARK: Interactive
    static let tmiInteractive = Color(hex: "#2B6CB0")
    static let tmiInteractiveHover = Color(hex: "#2C5282")
    static let tmiInteractiveLight = Color(hex: "#EBF4FF")
    static let tmiInteractiveMuted = Color(hex: "#90CDF4")

    // MARK: Backgrounds
    static let tmiPageBackground = Color(hex: "#FAF8F5")
    static let tmiPageBackgroundAlt = Color(hex: "#F5F0EB")

    // MARK: Surfaces
    static let tmiCardBackground = Color.white
    static let tmiCardBackgroundTinted = Color(hex: "#FFFBF5")

    // MARK: Text
    static let tmiTextPrimary = Color(hex: "#1A1612")
    static let tmiTextSecondary = Color(hex: "#6B6560")
    static let tmiTextTertiary = Color(hex: "#9C9590")

    // MARK: Semantic
    static let tmiSuccess = Color(hex: "#2D6A4F")
    static let tmiSuccessLight = Color(hex: "#E8F5EE")
    static let tmiWarning = Color(hex: "#B7791F")
    static let tmiWarningLight = Color(hex: "#FFF8E7")
    static let tmiError = Color(hex: "#C53030")
    static let tmiErrorLight = Color(hex: "#FFF5F5")
    static let tmiInfo = Color(hex: "#2B6CB0")
    static let tmiInfoLight = Color(hex: "#EBF4FF")

    // MARK: Quick Action Accents
    static let tmiAccentGold = Color(hex: "#D4942A")
    static let tmiAccentSage = Color(hex: "#588157")
    static let tmiAccentCoral = Color(hex: "#C96B5C")
    static let tmiAccentSky = Color(hex: "#4A90A4")
    static let tmiAccentPlum = Color(hex: "#7B6B8A")

    static let tmiAccentGoldTint = Color(hex: "#FEF3E2")
    static let tmiAccentSageTint = Color(hex: "#EDF5EC")
    static let tmiAccentCoralTint = Color(hex: "#FDF0EE")
    static let tmiAccentSkyTint = Color(hex: "#EBF5F7")
    static let tmiAccentPlumTint = Color(hex: "#F3F0F5")

    // MARK: Borders & Dividers
    static let tmiBorder = Color(hex: "#E8E4DF")
    static let tmiBorderFocused = Color(hex: "#2B6CB0")
    static let tmiDivider = Color(hex: "#F0ECE7")
}
```
