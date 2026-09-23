//
//  TMIComponentLibrary.swift
//  TMI
//
//  Created by Chandan Brown on 4/21/25.
//

import Charts
import Combine
import SwiftUI

extension DynamicTypeSize {
    var tmiFontScale: CGFloat {
        switch self {
        case .xSmall, .small, .medium, .large:
            1
        case .xLarge:
            1.1
        case .xxLarge:
            1.2
        case .xxxLarge:
            1.3
        case .accessibility1:
            1.4
        case .accessibility2:
            1.55
        case .accessibility3:
            1.7
        case .accessibility4:
            1.85
        case .accessibility5:
            2
        @unknown default:
            1
        }
    }
}

// MARK: - Component Library Overview
/*
 This file serves as the single source of truth for all reusable UI components
 in the TMI app. It consolidates duplicate components from across the codebase
 into a unified, consistent library.

 Component Categories:
 - Foundation: Background, Card
 - Buttons: Primary, Secondary, Floating, Filter
 - Cards: Stat, Content, Selection, List
 - Navigation: Tab Bar, Sidebar, Headers
 - Forms: Text Fields, Search, Filters
 */

// MARK: - Foundation Components

/// Unified solid background component.
struct TMIBackgroundView: View {
    var variant: BackgroundVariant = .base

    enum BackgroundVariant {
        case base
        case auth
        case dashboard
        case career
        case plans

        // dashboard, career, plans all resolve to .base behaviour
        var resolvedVariant: BackgroundVariant {
            switch self {
            case .dashboard, .career, .plans: return .base
            default: return self
            }
        }
    }

    var body: some View {
        switch variant.resolvedVariant {
        case .auth:
            TMIColors.background
                .ignoresSafeArea()
        default:
            Color.tmiBackground
                .ignoresSafeArea()
        }
    }
}

// MARK: - Card Style

enum TMICardStyle {
    /// Surface fill, hairline edge, faint shadow.
    case `default`
    /// Lifted: popovers, featured cards.
    case elevated
    /// Transparent with an outline, for secondary groupings.
    case outlined

    var cornerRadius: CGFloat { TMIRadius.card }

    var padding: CGFloat {
        switch self {
        case .default, .outlined: TMISpacing.cardPadding
        case .elevated: TMISpacing.ml
        }
    }

    var elevation: TMIElevation {
        switch self {
        case .default: .raised
        case .elevated: .elevated
        case .outlined: .flat
        }
    }

    var background: Color {
        switch self {
        case .default, .elevated: TMIColors.surface
        case .outlined: .clear
        }
    }
}

/// Unified card component (Golden Hour surface).
struct TMICard<Content: View>: View {
    let style: TMICardStyle
    let accentColor: Color?
    let content: Content

    init(style: TMICardStyle = .default, accentColor: Color? = nil, @ViewBuilder content: () -> Content) {
        self.style = style
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                // An accent gives the card a faint wash rather than a side rail.
                if let accentColor {
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .fill(accentColor.opacity(0.06))
                        .padding(-style.padding)
                }
            }
            .tmiSurface(style.elevation, padding: style.padding, fill: style.background, radius: style.cornerRadius)
    }
}

// MARK: - Logo View

struct TMILogoView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var markSize: CGFloat = 72

    var body: some View {
        VStack(spacing: TMISpacing.ms) {
            TMISchoolhouseMark(size: markSize, onTile: true)
                .shadow(color: .black.opacity(0.18), radius: 14, y: 8)

            VStack(spacing: 4) {
                Text("TMI")
                    .font(.tmiEditorial(.largeTitle))
                    .foregroundStyle(TMIColors.textPrimary)
                Text("Tangible Modification Intervention")
                    .tmiEyebrow(TMIColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("TMI, Tangible Modification Intervention")
    }
}

// MARK: - Button Components

/// Unified button component. Prefer `Button` + `.buttonStyle(.tmiPrimary)` in new code.
struct TMIButton: View {
    let text: String
    let icon: String?
    let style: TMIButtonStyle
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var tapCount = 0

    enum TMIButtonStyle: Equatable {
        case primary
        case secondary
        case tertiary
        case destructive
        case floating
        case filter(isSelected: Bool = false)
        case icon

        var prominence: TMIButtonProminence {
            switch self {
            case .primary, .floating: .primary
            case .secondary, .icon: .secondary
            case .tertiary: .tertiary
            case .destructive: .destructive
            case .filter(let isSelected): isSelected ? .primary : .secondary
            }
        }

        /// iPhone stretches primary actions to the thumb-friendly full width;
        /// the Mac keeps intrinsic-width buttons like native controls.
        var fillsWidth: Bool {
#if os(macOS)
            false
#else
            switch self {
            case .primary, .secondary, .destructive: true
            case .tertiary, .floating, .filter, .icon: false
            }
#endif
        }

        var foregroundColor: Color {
            switch prominence {
            case .primary: TMIColors.onBrand
            case .secondary: TMIColors.textPrimary
            case .tertiary: TMIColors.accent
            case .destructive: TMIColors.errorText
            }
        }
    }

    init(
        text: String,
        icon: String? = nil,
        style: TMIButtonStyle = .primary,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.text = text
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            HStack(spacing: TMISpacing.sm) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(style.foregroundColor)
                } else if let icon {
                    Image(systemName: icon)
                        .fontWeight(.semibold)
                }
                if style != .icon {
                    Text(text)
                }
            }
        }
        .buttonStyle(TMIActionButtonStyle(prominence: style.prominence, fullWidth: style.fillsWidth))
        .disabled(isLoading || isDisabled)
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
        .accessibilityLabel(text)
        .accessibilityValue(isLoading ? "In progress" : "")
    }
}

// MARK: - Text Input Components

/// Unified text field component — warm-light redesign
struct TMITextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var capitalization: TMITextInputAutocapitalization? = nil
    var onSubmit: (() -> Void)? = nil
    var focus: Binding<Bool>? = nil

    @FocusState private var isFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(isFocused ? TMIColors.accent : TMIColors.textTertiary)
                .frame(width: 20)
                .animation(.easeOut(duration: 0.2), value: isFocused)

            Group {
                if isSecure {
                    SecureField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundColor(Color.tmiTextTertiary)
                    )
                    .focused($isFocused)
                } else {
                    TextField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundColor(Color.tmiTextTertiary)
                    )
                    .focused($isFocused)
                }
            }
            .font(.body)
            .foregroundStyle(TMIColors.textPrimary)
            .autocorrectionDisabled()
            .tmiTextInputAutocapitalization(effectiveCapitalization)
            .textContentType(isSecure ? .password : nil)
            .keyboardType(keyboardType)
            .submitLabel(isSecure ? .done : .next)
            .onSubmit {
                onSubmit?()
            }
            .onChange(of: isFocused) { _, value in
                if focus?.wrappedValue != value {
                    focus?.wrappedValue = value
                }
            }
            .onChange(of: focus?.wrappedValue ?? false) { _, value in
                if isFocused != value {
                    isFocused = value
                }
            }
            .onAppear {
                if focus?.wrappedValue == true {
                    isFocused = true
                }
            }
        }
#if os(macOS)
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
#else
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
#endif
        .background(TMIColors.fill, in: TMIShape.control)
        .overlay {
            TMIShape.control
                .strokeBorder(isFocused ? TMIColors.accent : Color.clear, lineWidth: 2)
                .animation(TMIAnimation.snappy, value: isFocused)
        }
    }

    private var effectiveCapitalization: TMITextInputAutocapitalization? {
        if let capitalization {
            return capitalization
        }
        return isSecure || keyboardType == .emailAddress ? .never : nil
    }
}

// MARK: - Progress Components

/// Unified progress view style.
struct TMIProgressViewStyle: ProgressViewStyle {
    var color: Color = TMIColors.chartPrimary
    var height: CGFloat = 6
    var cornerRadius: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        TMIProgressBar(value: configuration.fractionCompleted ?? 0, color: color, height: height)
    }
}

// MARK: - Animation and Transition Helpers

/// Standard button scale effect
struct ScaleButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(TMIAnimation.snappy, value: configuration.isPressed)
    }
}

// MARK: - Sheet Style

struct TMISheetStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentationDragIndicator(.visible)
#if os(macOS)
            .frame(minWidth: 700, maxHeight: 900)
        #endif
    }
}

extension View {
    func tmiSheetStyle() -> some View {
        modifier(TMISheetStyle())
    }
}

// MARK: - Extensions for View Modifiers

extension View {
    /// Apply TMI card styling
    func tmiCard(style: TMICardStyle = .default, accentColor: Color? = nil) -> some View {
        TMICard(style: style, accentColor: accentColor) {
            self
        }
    }

    /// Apply TMI progress view styling
    func tmiProgressStyle(color: Color = TMIColors.chartPrimary, height: CGFloat = 6) -> some View {
        self.progressViewStyle(TMIProgressViewStyle(color: color, height: height))
    }

    /// Apply scale button effect
    func tmiScaleButton(scaleAmount: CGFloat = 0.95) -> some View {
        self.buttonStyle(ScaleButtonStyle(scaleAmount: scaleAmount))
    }
}

// MARK: - Preview Helpers

#if DEBUG
    #Preview("TMI Background Variants") {
        VStack {
            TMIBackgroundView(variant: .auth)
                .frame(height: 200)
                .overlay(Text("Auth Background").foregroundColor(Color.tmiTextPrimary))

            TMIBackgroundView(variant: .dashboard)
                .frame(height: 200)
                .overlay(Text("Dashboard Background").foregroundColor(Color.tmiTextPrimary))
        }
    }

    #Preview("TMI Cards") {
        ZStack {
            TMIBackgroundView(variant: .base)

            VStack(spacing: 20) {
                TMICard(style: .default) {
                    Text("Default Card")
                        .foregroundColor(Color.tmiTextPrimary)
                        .padding()
                }

                TMICard(style: .elevated) {
                    Text("Elevated Card")
                        .foregroundColor(Color.tmiTextPrimary)
                        .padding()
                }

                TMICard(style: .outlined) {
                    Text("Outlined Card")
                        .foregroundColor(Color.tmiTextPrimary)
                        .padding()
                }
            }
            .padding()
        }
    }

    #Preview("TMI Buttons") {
        ZStack {
            TMIBackgroundView(variant: .base)

            VStack(spacing: 16) {
                TMIButton(text: "Primary Button", style: .primary) {}
                TMIButton(text: "Secondary Button", style: .secondary) {}
                TMIButton(text: "Filter Button", style: .filter()) {}
                TMIButton(text: "Loading", style: .primary, isLoading: true) {}
            }
            .padding()
        }
    }
#endif
