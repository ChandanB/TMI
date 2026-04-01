import SwiftUI

#if canImport(AppKit) && !canImport(UIKit)
import AppKit

public typealias UIColor = NSColor
public typealias UIFont = NSFont
public typealias UIImage = NSImage

enum UIKeyboardType: Sendable {
    case `default`
    case decimalPad
    case emailAddress
    case numberPad
    case phonePad
    case URL
}

struct UIRectCorner: OptionSet, Sendable {
    let rawValue: Int

    static let topLeft = UIRectCorner(rawValue: 1 << 0)
    static let topRight = UIRectCorner(rawValue: 1 << 1)
    static let bottomLeft = UIRectCorner(rawValue: 1 << 2)
    static let bottomRight = UIRectCorner(rawValue: 1 << 3)
    static let allCorners: UIRectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

enum UIContentSizeCategory: Sendable {
    case extraSmall
    case small
    case medium
    case large
    case extraLarge
    case extraExtraLarge
    case extraExtraExtraLarge
    case accessibilityMedium
    case accessibilityLarge
    case accessibilityExtraLarge
    case accessibilityExtraExtraLarge
    case accessibilityExtraExtraExtraLarge

    static let didChangeNotification = Notification.Name("UIContentSizeCategory.didChangeNotification")
}

enum UIAccessibility {
    enum Announcement: Sendable {
        case announcement
        case layoutChanged
    }

    static let isVoiceOverRunning = false
    static let isReduceMotionEnabled = false
    static let isDarkerSystemColorsEnabled = false
    static let isReduceTransparencyEnabled = false
    static let isBoldTextEnabled = false

    static let voiceOverStatusDidChangeNotification = Foundation.Notification.Name("UIAccessibility.voiceOverStatusDidChangeNotification")
    static let reduceMotionStatusDidChangeNotification = Foundation.Notification.Name("UIAccessibility.reduceMotionStatusDidChangeNotification")
    static let darkerSystemColorsStatusDidChangeNotification = Foundation.Notification.Name("UIAccessibility.darkerSystemColorsStatusDidChangeNotification")

    static func post(notification: Announcement, argument: Any?) {}
}

final class UIApplication {
    static let shared = UIApplication()

    static let didBecomeActiveNotification = NSApplication.didBecomeActiveNotification
    static let didEnterBackgroundNotification = NSApplication.didResignActiveNotification
    static let didReceiveMemoryWarningNotification = Notification.Name("UIApplication.didReceiveMemoryWarningNotification")

    var preferredContentSizeCategory: UIContentSizeCategory { .large }
    var connectedScenes: [Any] { [] }

    @MainActor
    func canOpenURL(_ url: URL) -> Bool {
        NSWorkspace.shared.urlForApplication(toOpen: url) != nil || url.scheme != nil
    }

    @MainActor
    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func endEditing(_ force: Bool) {}
}

final class UIDevice {
    static let current = UIDevice()

    static let batteryLevelDidChangeNotification = Foundation.Notification.Name("UIDevice.batteryLevelDidChangeNotification")

    var isBatteryMonitoringEnabled = false
    var batteryLevel: Float { -1 }
    var model: String { Host.current().localizedName ?? "Mac" }
    var systemName: String { "macOS" }
    var systemVersion: String { ProcessInfo.processInfo.operatingSystemVersionString }
}

final class UIScreen {
    static let main = UIScreen()

    var bounds: CGRect {
        NSScreen.main?.frame ?? .zero
    }
}

extension View {
    func keyboardType(_ keyboardType: UIKeyboardType) -> some View {
        self
    }

    func navigationBarTitleDisplayMode(_ displayMode: TMINavigationBarTitleDisplayMode) -> some View {
        self
    }

    func navigationBarTitle<S>(_ title: S) -> some View where S: StringProtocol {
        navigationTitle(title)
    }

    func navigationBarTitle(_ title: Text) -> some View {
        navigationTitle(title)
    }

    func navigationBarItems<Leading: View, Trailing: View>(
        leading: Leading,
        trailing: Trailing
    ) -> some View {
        toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                leading
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                trailing
            }
        }
    }

    func navigationBarItems<Trailing: View>(trailing: Trailing) -> some View {
        toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                trailing
            }
        }
    }

    func toolbarBackground<S: ShapeStyle>(_ style: S, for bars: ToolbarPlacement...) -> some View {
        self
    }

    func fullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }

    func textInputAutocapitalization(_ autocapitalization: TMITextInputAutocapitalization) -> some View {
        self
    }
}

enum TMINavigationBarTitleDisplayMode {
    case automatic
    case inline
    case large
}

enum TMITextInputAutocapitalization {
    case never
    case sentences
    case words
    case characters
}

extension ToolbarItemPlacement {
    static var navigationBarLeading: ToolbarItemPlacement { .cancellationAction }
    static var navigationBarTrailing: ToolbarItemPlacement { .primaryAction }
    static var topBarLeading: ToolbarItemPlacement { .cancellationAction }
    static var topBarTrailing: ToolbarItemPlacement { .primaryAction }
}

extension ToolbarPlacement {
    static var navigationBar: ToolbarPlacement { .automatic }
}

typealias InsetGroupedListStyle = InsetListStyle

extension UIColor {
    static var systemBackground: UIColor { .windowBackgroundColor }
    static var secondarySystemBackground: UIColor { .underPageBackgroundColor }
    static var placeholderText: UIColor { .placeholderTextColor }
    static var systemGray3: UIColor { .systemGray }
    static var systemGray5: UIColor { .quinaryLabel }
    static var systemGray6: UIColor { .quaternaryLabelColor }
}

extension UIImage {
    var scale: CGFloat { 1 }
}
#endif
