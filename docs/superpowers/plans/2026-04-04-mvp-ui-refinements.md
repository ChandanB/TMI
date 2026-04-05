# MVP UI Refinements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix four UI issues — form alignment, inline interest entry, close button color, and app-wide card depth/hierarchy — to reach MVP visual quality.

**Architecture:** Targeted changes to the design token layer (colors, shadows), the component library (TMICard), and three feature views. No new files created.

**Tech Stack:** SwiftUI, existing TMIComponentLibrary design system

---

### Task 1: Add New Color Tokens

**Files:**
- Modify: `TMI/Helpers/Extensions/Color+Extensions.swift:36-37`

- [ ] **Step 1: Add `tmiBorderStrong` and `tmiSurfaceTinted` color tokens**

In `Color+Extensions.swift`, add two new colors after the existing border colors:

```swift
// MARK: - Border Colors
static let tmiBorder = Color(hex: "#E8E2DA")
static let tmiBorderStrong = Color(hex: "#D9D2C9")    // Warmer, more visible card border
static let tmiDivider = Color(hex: "#F0EBE4")

// MARK: - Surface Colors (add tmiSurfaceTinted after existing surface colors)
static let tmiSurface = Color(hex: "#FFFFFF")
static let tmiSurfaceElevated = Color(hex: "#FFFFFF")
static let tmiSurfaceTinted = Color(hex: "#F8F3ED")    // Warm tint for section headers
static let tmiCardBackground = Color(hex: "#FFFFFF")
static let tmiInputBackground = Color(hex: "#F5F0EB")
```

- [ ] **Step 2: Verify the project builds**

Run: `xcodebuild -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TMI/Helpers/Extensions/Color+Extensions.swift
git commit -m "feat: add tmiBorderStrong and tmiSurfaceTinted color tokens"
```

---

### Task 2: Update Shadow/Elevation System

**Files:**
- Modify: `TMI/Core/DesignSystem/TMIDesignTokens.swift:50-86`

- [ ] **Step 1: Update TMIElevation shadow values for stronger depth**

Replace the three computed properties in `TMIElevation`:

```swift
enum TMIElevation {
    case flat
    case raised
    case elevated
    case floating

    var shadowColor: Color {
        Color(hex: "#2D3436")
    }

    var shadowRadius: CGFloat {
        switch self {
        case .flat: return 0
        case .raised: return 4
        case .elevated: return 10
        case .floating: return 20
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .flat: return 0
        case .raised: return 0.10
        case .elevated: return 0.12
        case .floating: return 0.14
        }
    }

    var shadowOffset: CGSize {
        switch self {
        case .flat: return .zero
        case .raised: return CGSize(width: 0, height: 2)
        case .elevated: return CGSize(width: 0, height: 4)
        case .floating: return CGSize(width: 0, height: 8)
        }
    }

    /// Secondary shadow for layered depth effect
    var secondaryShadowRadius: CGFloat {
        switch self {
        case .flat: return 0
        case .raised: return 2
        case .elevated: return 4
        case .floating: return 8
        }
    }

    var secondaryShadowOpacity: Double {
        switch self {
        case .flat: return 0
        case .raised: return 0.06
        case .elevated: return 0.08
        case .floating: return 0.10
        }
    }
}
```

- [ ] **Step 2: Verify the project builds**

Run: `xcodebuild -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TMI/Core/DesignSystem/TMIDesignTokens.swift
git commit -m "feat: increase shadow depth and add secondary shadow layer to TMIElevation"
```

---

### Task 3: Update TMICard Component for Stronger Depth

**Files:**
- Modify: `TMI/Views/Components/TMIComponentLibrary.swift:66-151`

- [ ] **Step 1: Update TMICardStyle border and shadow values**

Replace the `TMICardStyle` enum:

```swift
enum TMICardStyle {
    case `default`
    case elevated
    case outlined

    var cornerRadius: CGFloat {
        switch self {
        case .default, .outlined: return 12
        case .elevated: return 16
        }
    }

    var padding: CGFloat {
        switch self {
        case .default, .outlined: return 20
        case .elevated: return 24
        }
    }

    var hasBorder: Bool {
        switch self {
        case .default, .outlined: return true
        case .elevated: return true
        }
    }

    var borderColor: Color {
        switch self {
        case .default, .elevated: return Color.tmiBorderStrong
        case .outlined: return Color.tmiBorderStrong
        }
    }

    var background: Color {
        switch self {
        case .default, .elevated: return Color.tmiSurface
        case .outlined: return .clear
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .default: return 4
        case .elevated: return 10
        case .outlined: return 0
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .default: return 0.10
        case .elevated: return 0.12
        case .outlined: return 0
        }
    }

    var shadowOffset: CGFloat {
        switch self {
        case .default: return 2
        case .elevated: return 4
        case .outlined: return 0
        }
    }

    var secondaryShadowRadius: CGFloat {
        switch self {
        case .default: return 2
        case .elevated: return 4
        case .outlined: return 0
        }
    }

    var secondaryShadowOpacity: Double {
        switch self {
        case .default: return 0.06
        case .elevated: return 0.08
        case .outlined: return 0
        }
    }
}
```

- [ ] **Step 2: Update TMICard body to use new border color and dual shadows**

Replace the `TMICard` struct body:

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
                        .stroke(style.borderColor, lineWidth: 1)
                    : nil
            )
            .shadow(
                color: Color(hex: "#2D3436").opacity(style.secondaryShadowOpacity),
                radius: style.secondaryShadowRadius,
                x: 0,
                y: 1
            )
            .shadow(
                color: Color(hex: "#2D3436").opacity(style.shadowOpacity),
                radius: style.shadowRadius,
                x: 0,
                y: style.shadowOffset
            )
    }
}
```

- [ ] **Step 3: Verify the project builds**

Run: `xcodebuild -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add TMI/Views/Components/TMIComponentLibrary.swift
git commit -m "feat: update TMICard with stronger borders, dual shadows for layered depth"
```

---

### Task 4: Fix Student Intake Form Alignment

**Files:**
- Modify: `TMI/Views/Students/StudentProfileView.swift:122, 243, 253, 278, 283-293, 303, 308-313`

- [ ] **Step 1: Add leading alignment to the main content VStack**

At line 122, change:

```swift
VStack(spacing: TMISpacing.lg) {
```

to:

```swift
VStack(alignment: .leading, spacing: TMISpacing.lg) {
```

- [ ] **Step 2: Left-align the header subtitle**

At line 253, change:

```swift
.multilineTextAlignment(.center)
```

to:

```swift
.multilineTextAlignment(.leading)
```

- [ ] **Step 3: Make the header VStack leading-aligned**

At line 243, change:

```swift
VStack(spacing: TMISpacing.md) {
```

to:

```swift
VStack(alignment: .leading, spacing: TMISpacing.md) {
```

- [ ] **Step 4: Make the Grade picker fill width with leading alignment**

At lines 283-293, the Picker is inside a `VStack(alignment: .leading)` but the Picker itself centers. Add `.frame(maxWidth: .infinity, alignment: .leading)` after the `.cornerRadius`:

```swift
Picker("Grade", selection: $selectedGrade) {
    ForEach(grades, id: \.self) { grade in
        Text("Grade \(grade)").tag(grade)
    }
}
.pickerStyle(.menu)
.tint(.tmiPrimary)
.padding(TMISpacing.md)
.background(Color.tmiSurface)
.cornerRadius(TMIRadius.sm)
.frame(maxWidth: .infinity, alignment: .leading)
```

- [ ] **Step 5: Make the DatePicker leading-aligned**

At lines 308-313, add `.frame(maxWidth: .infinity, alignment: .leading)`:

```swift
DatePicker("", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
    .datePickerStyle(.compact)
    .tint(.tmiPrimary)
    .padding(TMISpacing.sm)
    .background(Color.tmiSurface)
    .cornerRadius(TMIRadius.sm)
    .frame(maxWidth: .infinity, alignment: .leading)
```

- [ ] **Step 6: Verify the project builds**

Run: `xcodebuild -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add TMI/Views/Students/StudentProfileView.swift
git commit -m "fix: leading-justify all sections in student intake form"
```

---

### Task 5: Inline Interest Entry — StudentInterestsSection

**Files:**
- Modify: `TMI/Views/Students/Sections/StudentInterestsSection.swift`

- [ ] **Step 1: Remove sheet-related state and the sheet view**

Remove these state variables:

```swift
@State private var showNewInterestSheet: Bool = false
```

Remove the entire `newInterestSheetView` computed property (lines 149-181).

Remove the `.sheet` modifier from the body (lines 141-144):

```swift
.sheet(isPresented: $showNewInterestSheet) {
    newInterestSheetView
        .tmiSheetStyle()
}
```

- [ ] **Step 2: Replace the "New" button with an inline text field + add button**

Replace the search bar + New button HStack (lines 52-81) with a search bar and a separate inline add row:

```swift
// Search bar
HStack {
    Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
    TextField("Search interests…", text: $searchText)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.search)
}
.padding(.horizontal, 10)
.padding(.vertical, 8)
.background(Color(.systemGray6))
.clipShape(RoundedRectangle(cornerRadius: 10))
```

Then after the "Suggested" section (after the closing brace of the available interests VStack, before the closing brace of the outer VStack), add the inline creation row:

```swift
// Inline new interest entry
HStack(spacing: 8) {
    TextField("Add an interest…", text: $newInterestName)
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .submitLabel(.done)
        .onSubmit {
            Task { await createAndAddInterest() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.tmiInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.tmiBorder, lineWidth: 1)
        )

    Button {
        Task { await createAndAddInterest() }
    } label: {
        Image(systemName: "plus")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Color.tmiSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .disabled(newInterestName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
    .opacity(newInterestName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
}
```

- [ ] **Step 3: Update `createAndAddInterest` to remove sheet dismissal**

Remove the last two lines from `createAndAddInterest()`:

```swift
// Remove these lines:
// newInterestName = ""           <-- keep this one
// showNewInterestSheet = false   <-- remove this one
```

The method should end with:

```swift
        newInterestName = ""
    }
```

(Only remove the `showNewInterestSheet = false` line, keep `newInterestName = ""`)

- [ ] **Step 4: Verify the project builds**

Run: `xcodebuild -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add TMI/Views/Students/Sections/StudentInterestsSection.swift
git commit -m "feat: replace interest sheet with inline text field entry in student form"
```

---

### Task 6: Inline Interest Entry — PlanInterestsSection

**Files:**
- Modify: `TMI/Views/TMIPlans/Sections/PlanInterestsSection.swift`

- [ ] **Step 1: Remove sheet-related state and the sheet view**

Remove this state variable:

```swift
@State private var showNewInterestSheet: Bool = false
```

Remove the entire `newInterestSheetView` computed property (lines 161-191).

Remove the `.sheet` modifier from the body (lines 153-156):

```swift
.sheet(isPresented: $showNewInterestSheet) {
    newInterestSheetView
        .tmiSheetStyle()
}
```

- [ ] **Step 2: Replace the "New" button with an inline text field + add button**

Replace the search bar + New button HStack (lines 57-87) with just the search bar:

```swift
// Search bar
HStack {
    Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
    TextField("Search interests…", text: $searchText)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.search)
}
.padding(.horizontal, 10)
.padding(.vertical, 8)
.background(Color(.systemGray6))
.clipShape(RoundedRectangle(cornerRadius: 10))
```

Then after the suggestions section (before the closing brace of the outer VStack), add:

```swift
// Inline new interest entry
HStack(spacing: 8) {
    TextField("Add an interest…", text: $newInterestName)
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .submitLabel(.done)
        .onSubmit {
            Task { await createAndLinkInterest() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.tmiInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.tmiBorder, lineWidth: 1)
        )

    Button {
        Task { await createAndLinkInterest() }
    } label: {
        Image(systemName: "plus")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Color.tmiSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .disabled(newInterestName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
    .opacity(newInterestName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
}
```

- [ ] **Step 3: Update `createAndLinkInterest` to remove sheet dismissal**

Remove the `showNewInterestSheet = false` line from `createAndLinkInterest()`. Keep the `newInterestName = ""` line.

- [ ] **Step 4: Verify the project builds**

Run: `xcodebuild -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add TMI/Views/TMIPlans/Sections/PlanInterestsSection.swift
git commit -m "feat: replace interest sheet with inline text field entry in plan form"
```

---

### Task 7: Fix Career Explorer Close Button Color

**Files:**
- Modify: `TMI/Views/Career Explorer/CareerExplorerView.swift:230`

- [ ] **Step 1: Change the close button foreground color to white**

At line 230, change:

```swift
.foregroundColor(Color.tmiTextSecondary)
```

to:

```swift
.foregroundColor(.white)
```

- [ ] **Step 2: Verify the project builds**

Run: `xcodebuild -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add "TMI/Views/Career Explorer/CareerExplorerView.swift"
git commit -m "fix: change Career Explorer close button to white"
```

---

### Task 8: Add Section Header Styling to Plan Editor

**Files:**
- Modify: `TMI/Views/Components/AccordionSection.swift`

- [ ] **Step 1: Add accent border support to AccordionSection**

Add an optional `accentColor` parameter and apply it as a left border on the card:

```swift
struct AccordionSection<Content: View>: View {
    let icon: String
    let title: String
    var badge: String? = nil
    var badgeColor: Color = .blue
    var isRequired: Bool = false
    var accentColor: Color? = nil
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if isRequired {
                        Text("REQUIRED")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.tmiTextPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red, in: RoundedRectangle(cornerRadius: 4))
                    }

                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.tmiTextPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(badgeColor, in: Capsule())
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    accentColor != nil ? Color.tmiSurfaceTinted : Color.clear
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                content()
                    .padding(16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(alignment: .leading) {
            if let accentColor {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 2: Apply accent colors to required sections in StudentProfileView**

In `StudentProfileView.swift`, add `accentColor: .tmiSecondary` to the Student Information accordion (the required one):

```swift
AccordionSection(
    icon: "person.fill",
    title: "Student Information",
    isRequired: true,
    accentColor: .tmiSecondary,
    isExpanded: $infoExpanded
) {
    studentInformationContent
}
.tmiCard()
```

- [ ] **Step 3: Apply accent colors to required sections in TMIPlanEditorView**

In `TMIPlanEditorView.swift`, add `accentColor: .tmiSecondary` to the Plan Details and Students accordion sections (the required ones). Find the AccordionSection calls with `isRequired: true` and add the parameter.

- [ ] **Step 4: Verify the project builds**

Run: `xcodebuild -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add TMI/Views/Components/AccordionSection.swift TMI/Views/Students/StudentProfileView.swift TMI/Views/TMIPlans/TMIPlanEditorView.swift
git commit -m "feat: add accent border and tinted headers to required accordion sections"
```
