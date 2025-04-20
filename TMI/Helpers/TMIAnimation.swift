//
//  TMIAnimation.swift
//  TMI
//
//  Created by Chandan Brown on 4/20/25.
//


import SwiftUI

/// Design system animation duration constants
struct TMIAnimation {
    /// Quick animation - 0.15 seconds
    static let quick: Double = 0.15
    
    /// Standard animation - 0.3 seconds
    static let standard: Double = 0.3
    
    /// Medium animation - 0.5 seconds
    static let medium: Double = 0.5
    
    /// Slow animation - 0.8 seconds
    static let slow: Double = 0.8
    
    /// Extra slow animation - 1.2 seconds
    static let extraSlow: Double = 1.2
    
    /// Standard spring animation
    static func spring(response: Double = 0.3, dampingFraction: Double = 0.7) -> Animation {
        return .spring(response: response, dampingFraction: dampingFraction)
    }
    
    /// Easing functions
    struct Easing {
        /// Standard ease-in-out animation
        static func easeInOut(duration: Double = standard) -> Animation {
            return .easeInOut(duration: duration)
        }
        
        /// Standard ease-out animation
        static func easeOut(duration: Double = standard) -> Animation {
            return .easeOut(duration: duration)
        }
        
        /// Standard ease-in animation
        static func easeIn(duration: Double = standard) -> Animation {
            return .easeIn(duration: duration)
        }
    }
}
