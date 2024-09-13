//
//  RecentActivity.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import Foundation
import SwiftData
import FirebaseFirestore

struct RecentActivity: Codable, Identifiable {
    @DocumentID var id: String?
    let icon: String
    let title: String
    let description: String
    let date: Date
    
    init(id: String? = nil, icon: String, title: String, description: String, date: Date) {
        self.id = id
        self.icon = icon
        self.title = title
        self.description = description
        self.date = date
    }
}

extension RecentActivity {
    static var sampleRecentActivity: RecentActivity {
        return RecentActivity(icon: "doc.fill", title: "New TMI Plan Created", description: "For student John Doe", date: Date())
    }
    
    static var sampleRecentActivities: [RecentActivity] {
        return [
            RecentActivity(icon: "doc.fill", title: "New TMI Plan Created", description: "For student John Doe", date: Date()),
            RecentActivity(icon: "list.clipboard.fill", title: "Interest Survey Completed", description: "By student Jane Smith", date: Date().addingTimeInterval(-3600)),
            RecentActivity(icon: "person.fill.checkmark", title: "Student Goal Achieved", description: "Alex Johnson completed Python course", date: Date().addingTimeInterval(-7200)),
            RecentActivity(icon: "doc.fill", title: "New TMI Plan Created", description: "For student Jane Doo", date: Date().addingTimeInterval(-8600)),
            RecentActivity(icon: "doc.fill", title: "New TMI Plan Created", description: "For student Jake Dee", date: Date().addingTimeInterval(-10600))
        ]
    }
}


