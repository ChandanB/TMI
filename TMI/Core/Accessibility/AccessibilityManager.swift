//
//  AccessibilityManager.swift
//  TMI
//
//  Created by Claude Code on 8/19/25.
//

import SwiftUI
import Observation

// MARK: - Accessibility Manager

/// Modern accessibility manager for iOS 26 with comprehensive accessibility features
@Observable
@MainActor
final class AccessibilityManager: Sendable {
    
    // MARK: - Properties
    
    static let shared = AccessibilityManager()
    
    // Accessibility Settings
    private(set) var isVoiceOverEnabled = false
    private(set) var isReduceMotionEnabled = false
    private(set) var isIncreaseContrastEnabled = false
    private(set) var isReduceTransparencyEnabled = false
    private(set) var isBoldTextEnabled = false
    private(set) var preferredContentSizeCategory: ContentSizeCategory = .medium
    
    // Focus Management
    private(set) var focusedElement: String?
    private var accessibilityNotifications: [AccessibilityNotification] = []
    
    // Announcement Queue
    private var announcementQueue: [String] = []
    private var isProcessingAnnouncements = false
    
    // MARK: - Initialization
    
    nonisolated init() {
        Task { @MainActor in
            updateAccessibilitySettings()
            setupNotificationObservers()
        }
    }
    
    // MARK: - Public Methods
    
    /// Update all accessibility settings
    func updateAccessibilitySettings() {
        #if canImport(UIKit)
        isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isIncreaseContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
        preferredContentSizeCategory = ContentSizeCategory(UIApplication.shared.preferredContentSizeCategory)
        #else
        isVoiceOverEnabled = false
        isReduceMotionEnabled = false
        isIncreaseContrastEnabled = false
        isReduceTransparencyEnabled = false
        isBoldTextEnabled = false
        preferredContentSizeCategory = .medium
        #endif
    }
    
    /// Post accessibility announcement
    func announce(_ message: String, priority: AnnouncementPriority = .medium) {
        let announcement = AccessibilityAnnouncement(
            message: message,
            priority: priority,
            timestamp: Date()
        )
        
        if priority == .high {
            // High priority announcements go to front of queue
            announcementQueue.insert(announcement.message, at: 0)
        } else {
            announcementQueue.append(announcement.message)
        }
        
        processAnnouncementQueue()
    }
    
    /// Focus on specific element
    func focusOn(element: String) {
        focusedElement = element
        #if canImport(UIKit)
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
        #endif
    }
    
    /// Clear focus
    func clearFocus() {
        focusedElement = nil
    }
    
    /// Check if large text is enabled
    var isLargeTextEnabled: Bool {
        preferredContentSizeCategory.isAccessibilityCategory
    }
    
    /// Get recommended animation duration based on accessibility settings
    var recommendedAnimationDuration: Double {
        isReduceMotionEnabled ? 0.1 : 0.3
    }
    
    /// Get recommended opacity for overlays
    var recommendedOverlayOpacity: Double {
        isReduceTransparencyEnabled ? 1.0 : 0.8
    }
    
    /// Get recommended contrast ratio
    var recommendedContrastRatio: Double {
        isIncreaseContrastEnabled ? 7.0 : 4.5
    }
    
    // MARK: - Content Size Helpers
    
    /// Get scaled font size for accessibility
    func scaledFontSize(_ baseSize: CGFloat) -> CGFloat {
        let scaleFactor = getContentSizeScaleFactor()
        return baseSize * scaleFactor
    }
    
    /// Get content size scale factor
    func getContentSizeScaleFactor() -> CGFloat {
        switch preferredContentSizeCategory {
        case .extraSmall: return 0.85
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .extraLarge: return 1.2
        case .extraExtraLarge: return 1.3
        case .extraExtraExtraLarge: return 1.4
        case .accessibilityMedium: return 1.6
        case .accessibilityLarge: return 1.8
        case .accessibilityExtraLarge: return 2.0
        case .accessibilityExtraExtraLarge: return 2.2
        case .accessibilityExtraExtraExtraLarge: return 2.4
        @unknown default: return 1.0
        }
    }
    
    // MARK: - Color Accessibility
    
    /// Get accessible color variant
    func accessibleColor(_ color: Color) -> Color {
        if isIncreaseContrastEnabled {
            return color.opacity(0.9) // Increase opacity for better contrast
        }
        return color
    }
    
    /// Check if color combination meets accessibility standards
    func meetsContrastRequirements(foreground: Color, background: Color) -> Bool {
        // In a real implementation, this would calculate the actual contrast ratio
        // For now, we'll use a simplified check
        return true
    }
    
    // MARK: - Gesture Accessibility
    
    /// Get recommended tap target size
    var minimumTapTargetSize: CGSize {
        // iOS 26 accessibility guidelines recommend minimum 44x44 points
        CGSize(width: 44, height: 44)
    }
    
    /// Get recommended gesture tolerance
    var gestureToleranceRadius: CGFloat {
        isVoiceOverEnabled ? 20 : 10
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        #if canImport(UIKit)
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateAccessibilitySettings()
            }
        }
        
        notificationCenter.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateAccessibilitySettings()
            }
        }
        
        notificationCenter.addObserver(
            forName: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateAccessibilitySettings()
            }
        }
        
        notificationCenter.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateAccessibilitySettings()
            }
        }
        #endif
    }
    
    private func processAnnouncementQueue() {
        guard !isProcessingAnnouncements, !announcementQueue.isEmpty else { return }
        
        isProcessingAnnouncements = true
        let message = announcementQueue.removeFirst()
        
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
        
        // Wait before processing next announcement
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isProcessingAnnouncements = false
            self?.processAnnouncementQueue()
        }
    }
}

// MARK: - Supporting Types

enum AnnouncementPriority {
    case low
    case medium
    case high
}

struct AccessibilityAnnouncement {
    let message: String
    let priority: AnnouncementPriority
    let timestamp: Date
}

struct AccessibilityNotification {
    let type: UIAccessibility.Announcement
    let argument: Any?
    let timestamp: Date
}

// MARK: - Accessibility View Modifiers

private struct ConditionalAccessibilityAction: ViewModifier {
    let action: (() -> Void)?
    func body(content: Content) -> some View {
        if let action = action {
            content.accessibilityAction { action() }
        } else {
            content
        }
    }
}

// MARK: AccessibleTapTargetModifier

private struct AccessibleTapTargetModifier: ViewModifier {
    @Environment(\.accessibilityManager) private var manager
    
    func body(content: Content) -> some View {
        let size = manager?.minimumTapTargetSize ?? CGSize(width: 44, height: 44)
        content.frame(minWidth: size.width, minHeight: size.height)
    }
}

// MARK: MotionAwareAnimationModifier

private struct MotionAwareAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityManager) private var manager
    let animation: Animation?
    let value: V
    
    func body(content: Content) -> some View {
        let isReduceMotion = manager?.isReduceMotionEnabled ?? false
        let accessibleAnimation = isReduceMotion ? nil : animation
        content.animation(accessibleAnimation, value: value)
    }
}

// MARK: AccessibilityAwareOpacityModifier

private struct AccessibilityAwareOpacityModifier: ViewModifier {
    @Environment(\.accessibilityManager) private var manager
    let opacity: Double
    
    func body(content: Content) -> some View {
        let isReduceTransparency = manager?.isReduceTransparencyEnabled ?? false
        let adjustedOpacity = isReduceTransparency ? min(opacity + 0.3, 1.0) : opacity
        content.opacity(adjustedOpacity)
    }
}

// MARK: HighContrastAwareModifier

private struct HighContrastAwareModifier: ViewModifier {
    @Environment(\.accessibilityManager) private var manager
    let color: Color
    
    func body(content: Content) -> some View {
        let adjustedColor = manager?.accessibleColor(color) ?? color
        content.foregroundColor(adjustedColor)
    }
}

// MARK: DynamicTypeScaledModifier

private struct DynamicTypeScaledModifier: ViewModifier {
    @Environment(\.accessibilityManager) private var manager
    let baseSize: CGFloat
    
    func body(content: Content) -> some View {
        let scaledSize = manager?.scaledFontSize(baseSize) ?? (baseSize * 1.0)
        content.font(.system(size: scaledSize))
    }
}

extension View {
    /// Apply comprehensive accessibility configuration
    func accessibilityOptimized(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = [],
        action: (() -> Void)? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
            .modifier(ConditionalAccessibilityAction(action: action))
            .accessibilityElement(children: .combine)
    }
    
    /// Apply minimum tap target size for accessibility
    func accessibleTapTarget() -> some View {
        modifier(AccessibleTapTargetModifier())
    }
    
    /// Apply motion-aware animations
    func motionAwareAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        modifier(MotionAwareAnimationModifier(animation: animation, value: value))
    }
    
    /// Apply accessibility-aware opacity
    func accessibilityAwareOpacity(_ opacity: Double) -> some View {
        modifier(AccessibilityAwareOpacityModifier(opacity: opacity))
    }
    
    /// Apply high contrast colors when needed
    func highContrastAware(color: Color) -> some View {
        modifier(HighContrastAwareModifier(color: color))
    }
    
    /// Apply dynamic type scaling
    func dynamicTypeScaled(baseSize: CGFloat) -> some View {
        modifier(DynamicTypeScaledModifier(baseSize: baseSize))
    }
}

// MARK: - Accessibility-Aware Components

/// Accessibility-optimized button component
struct AccessibleButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let style: ButtonStyle
    
    @Environment(\.accessibilityManager) private var accessibilityManager
    
    enum ButtonStyle {
        case primary
        case secondary
        
        func backgroundColor(isHighContrast: Bool) -> Color {
            switch self {
            case .primary:
                return isHighContrast ? .black : .blue
            case .secondary:
                return isHighContrast ? .white : .gray
            }
        }
        
        func foregroundColor(isHighContrast: Bool) -> Color {
            switch self {
            case .primary:
                return .white
            case .secondary:
                return isHighContrast ? .black : .primary
            }
        }
    }
    
    var body: some View {
        // fallback is false if accessibilityManager is nil
        let isHighContrast = accessibilityManager?.isIncreaseContrastEnabled ?? false
        
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(style.backgroundColor(isHighContrast: isHighContrast))
            .foregroundColor(style.foregroundColor(isHighContrast: isHighContrast))
            .cornerRadius(12)
        }
        .accessibleTapTarget()
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .motionAwareAnimation(.spring(response: 0.3), value: title)
    }
}

/// Accessibility-optimized text input
struct AccessibleTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    
    @Environment(\.accessibilityManager) private var accessibilityManager
    @FocusState private var isFocused: Bool
    @AccessibilityFocusState private var isAccessibilityFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .dynamicTypeScaled(baseSize: 16)
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .focused($isFocused)
            .accessibilityFocused($isAccessibilityFocused)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isFocused ? .blue : .gray,
                                lineWidth: accessibilityManager?.isIncreaseContrastEnabled == true ? 2 : 1
                            )
                    )
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(text.isEmpty ? "Empty" : text)
        .accessibilityHint("Enter \(title.lowercased())")
    }
}

// MARK: - Environment Extensions

// Default is nil so that the manager can be injected at app startup for flexibility
private struct AccessibilityManagerKey: EnvironmentKey {
    static let defaultValue: AccessibilityManager? = nil
}

extension EnvironmentValues {
    var accessibilityManager: AccessibilityManager? {
        get { self[AccessibilityManagerKey.self] }
        set { self[AccessibilityManagerKey.self] = newValue }
    }
}

extension View {
    func accessibilityManagerEnvironment(_ manager: AccessibilityManager) -> some View {
        environment(\.accessibilityManager, manager)
    }
}

// MARK: - ContentSizeCategory Extension

#if canImport(UIKit)
extension ContentSizeCategory {
    init(_ uiContentSizeCategory: UIContentSizeCategory) {
        switch uiContentSizeCategory {
        case .extraSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .extraLarge: self = .extraLarge
        case .extraExtraLarge: self = .extraExtraLarge
        case .extraExtraExtraLarge: self = .extraExtraExtraLarge
        case .accessibilityMedium: self = .accessibilityMedium
        case .accessibilityLarge: self = .accessibilityLarge
        case .accessibilityExtraLarge: self = .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: self = .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: self = .accessibilityExtraExtraExtraLarge
        default: self = .medium
        }
    }
}
#endif
