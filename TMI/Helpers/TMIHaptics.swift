//
//  TMIHaptics.swift
//  TMI
//
//  Created by Chandan Brown on 4/20/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Utility class for providing haptic feedback throughout the app
class TMIHaptics {
    /// Generates a light impact haptic feedback
    static func lightImpact() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
    
    /// Generates a medium impact haptic feedback
    static func mediumImpact() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
    
    /// Generates a heavy impact haptic feedback
    static func heavyImpact() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
    
    /// Generates a selection haptic feedback
    static func selectionChanged() {
        #if canImport(UIKit)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }
    
    /// Generates a success notification haptic feedback
    static func success() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }
    
    /// Generates a warning notification haptic feedback
    static func warning() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
        #endif
    }
    
    /// Generates an error notification haptic feedback
    static func error() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
        #endif
    }
}

/// Extension to make haptics available via View modifier
extension View {
    /// Performs a light impact haptic when the condition changes to true
    func hapticOnChange<Value: Equatable>(of value: Value, hapticType: @escaping () -> Void = TMIHaptics.lightImpact) -> some View {
        onChange(of: value) { _, _ in
            hapticType()
        }
    }
    
    /// Performs a haptic when the view appears
    func hapticOnAppear(hapticType: @escaping () -> Void = TMIHaptics.lightImpact) -> some View {
        onAppear {
            hapticType()
        }
    }
}

