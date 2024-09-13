//
//  ProgressData.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation

// MARK: - Supporting Models

struct ProgressData: Identifiable {
    let id = UUID()
    let date: String
    let progress: Double
}

