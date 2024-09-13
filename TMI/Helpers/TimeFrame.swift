//
//  TimeFrame.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import Foundation

enum TimeFrame: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    case year = "Year"
    var id: Self { self }
}
