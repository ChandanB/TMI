//
//  EngagementData.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation

struct EngagementData: Identifiable {
    let id = UUID()
    let day: String
    let week: String
    let engagement: Double
}

extension EngagementData {
    static var sampleData: [EngagementData] = [
        EngagementData(day: "Mon", week: "Week 1", engagement: 0.5),
        EngagementData(day: "Tue", week: "Week 2", engagement: 0.6),
        EngagementData(day: "Wed", week: "Week 3", engagement: 0.8),
        EngagementData(day: "Thu", week: "Week 4", engagement: 0.7),
        EngagementData(day: "Fri", week: "Week 5", engagement: 0.9),
        EngagementData(day: "Sat", week: "Week 6", engagement: 0.4),
        EngagementData(day: "Sun", week: "Week 7", engagement: 0.3)
    ]
}
