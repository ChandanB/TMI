//
//  TMIHaptics.swift
//  TMI
//
//  Created by Chandan Brown on 4/20/25.
//

import SwiftUI
import UIKit

/// Utility class for providing haptic feedback throughout the app
class TMIHaptics {
    /// Generates a light impact haptic feedback
    static func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Generates a medium impact haptic feedback
    static func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Generates a heavy impact haptic feedback
    static func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Generates a selection haptic feedback
    static func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    /// Generates a success notification haptic feedback
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    /// Generates a warning notification haptic feedback
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
    
    /// Generates an error notification haptic feedback
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
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


