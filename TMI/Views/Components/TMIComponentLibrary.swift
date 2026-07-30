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

/// Unified solid card component
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
            .padding(style.padding)
            .background(style.background)
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
            .overlay(
                style.hasBorder
                    ? RoundedRectangle(cornerRadius: style.cornerRadius)
                        .stroke(style.borderColor, lineWidth: 1)
                    : nil
            )
            .overlay(alignment: .leading) {
                if let accentColor {
                    UnevenRoundedRectangle(
                        topLeadingRadius: style.cornerRadius,
                        bottomLeadingRadius: style.cornerRadius,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                    .fill(accentColor)
                    .frame(width: 3)
                }
            }
            .shadow(
                color: TMIColors.textPrimary.opacity(style.secondaryShadowOpacity),
                radius: style.secondaryShadowRadius,
                x: 0,
                y: 1
            )
            .shadow(
                color: TMIColors.textPrimary.opacity(style.shadowOpacity),
                radius: style.shadowRadius,
                x: 0,
                y: style.shadowOffset
            )
    }
}

// MARK: - Logo View

struct TMILogoView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: "building.columns")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 70, height: 70)
                .foregroundColor(Color.tmiPrimary)
                .padding(.bottom, 10)

            Text("TMI")
                .font(
                    .system(
                        size: 36 * dynamicTypeSize.tmiFontScale,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundColor(Color.tmiTextPrimary)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)

            Text("TANGIBLE MODIFICATION INTERVENTION")
                .font(
                    .system(
                        size: 12 * dynamicTypeSize.tmiFontScale,
                        weight: .semibold
                    )
                )
                .foregroundColor(Color.tmiTextBrand)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Button Components

/// Unified button component with multiple styles
struct TMIButton: View {
    let text: String
    let icon: String?
    let style: TMIButtonStyle
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var isPressed = false
    @State private var isHovered = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    enum TMIButtonStyle: Equatable {
        case primary
        case secondary
        case tertiary
        case destructive
        case floating
        case filter(isSelected: Bool = false)
        case icon

        static func == (lhs: TMIButtonStyle, rhs: TMIButtonStyle) -> Bool {
            switch (lhs, rhs) {
            case (.primary, .primary),
                (.secondary, .secondary),
                (.tertiary, .tertiary),
                (.destructive, .destructive),
                (.floating, .floating),
                (.icon, .icon):
                return true
            case (.filter(let lhsSelected), .filter(let rhsSelected)):
                return lhsSelected == rhsSelected
            default:
                return false
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary, .destructive, .floating: return .white
            case .secondary: return Color.tmiSecondary
            case .tertiary: return Color.tmiSecondary
            case .filter(let isSelected): return isSelected ? .white : Color.tmiTextSecondary
            case .icon: return Color.tmiTextSecondary
            }
        }

        var backgroundColor: Color {
            switch self {
            case .primary: return Color.tmiSecondary
            case .secondary: return .clear
            case .tertiary: return TMIColors.aubergineSoft
            case .destructive: return Color.tmiError
            case .floating: return Color.tmiPrimary
            case .filter(let isSelected): return isSelected ? TMIColors.teal : TMIColors.aubergineSoft
            case .icon: return TMIColors.aubergineSoft
            }
        }

        var borderColor: Color? {
            switch self {
            case .secondary: return Color.tmiSecondary
            case .filter(let isSelected): return isSelected ? nil : Color.tmiBorder
            default: return nil
            }
        }

        var borderWidth: CGFloat {
            switch self {
            case .secondary: return 1.5
            case .filter: return 1.0
            default: return 1.5
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .floating: return 30
            case .filter: return 24
            case .icon: return 12
            default: return 14
            }
        }

        var height: CGFloat {
            switch self {
            case .floating: return 60
            case .filter: return 48
            case .icon: return 44
            default: return 56
            }
        }

        var shadowColor: Color {
            switch self {
            case .primary: return Color.tmiSecondary.opacity(0.15)
            case .floating: return Color.tmiPrimary.opacity(0.15)
            case .destructive: return Color.tmiError.opacity(0.15)
            default: return .clear
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
        Button(action: handleTap) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(
                                tint: style.foregroundColor
                            )
                        )
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(
                                .system(
                                    size: 18 * dynamicTypeSize.tmiFontScale,
                                    weight: .medium
                                )
                            )
                    }

                    if style != .icon {
                        Text(text)
                            .font(
                                .system(
                                    size: 17 * dynamicTypeSize.tmiFontScale,
                                    weight: .semibold
                                )
                            )
                    }
                }
            }
            .padding(.horizontal, {
                switch style {
                case .filter: return 20
                case .floating, .icon: return 16
                default: return 24
                }
            }())
            .foregroundColor(style.foregroundColor)
            .frame(
                minWidth: {
                    switch style {
                    case .floating: return style.height
                    case .filter: return 80
                    default: return nil
                    }
                }(),
                maxWidth: {
                    switch style {
                    case .floating, .icon, .filter: return nil
                    default: return .infinity
                    }
                }()
            )
            .frame(minHeight: style.height)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(style.backgroundColor)
                    .overlay(
                        style.borderColor != nil
                            ? RoundedRectangle(cornerRadius: style.cornerRadius)
                                .stroke(style.borderColor!, lineWidth: style.borderWidth) : nil
                    )
            )
            .shadow(
                color: style.shadowColor,
                radius: isHovered ? 12 : 8,
                x: 0,
                y: isHovered ? 8 : 5
            )
            .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .animation(.easeInOut(duration: 0.2), value: isPressed)
        }
        .buttonStyle(.plain)
        .disabled(isLoading || isDisabled)
        .accessibilityLabel(text)
        .accessibilityValue(isLoading ? "In progress" : "")
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func handleTap() {
        withAnimation(.easeInOut(duration: 0.1)) {
            isPressed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = false
            }
            action()
        }
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
                .foregroundColor(isFocused ? Color.tmiSecondary : Color.tmiTextTertiary)
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
            .font(.system(size: 17 * dynamicTypeSize.tmiFontScale))
            .foregroundColor(Color.tmiTextPrimary)
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
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.tmiInputBackground)
                .shadow(color: TMIColors.textPrimary.opacity(0.04), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isFocused ? Color.tmiSecondary : Color.tmiBorder,
                    lineWidth: isFocused ? 1.5 : 1.0
                )
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        )
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
    var color: Color = TMIColors.teal
    var height: CGFloat = 4
    var cornerRadius: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.tmiBorder)
                    .frame(height: height)

                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(color)
                    .frame(
                        width: geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0),
                        height: height
                    )
            }
        }
        .frame(height: height)
    }
}

// MARK: - Animation and Transition Helpers

/// Standard button scale effect
struct ScaleButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
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
    func tmiProgressStyle(color: Color = TMIColors.teal, height: CGFloat = 4) -> some View {
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
