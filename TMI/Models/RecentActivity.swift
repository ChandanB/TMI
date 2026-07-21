//
//  RecentActivity.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import Foundation
import SwiftUI

/// Represents a recent activity in the application
nonisolated struct RecentActivity: Identifiable, Equatable, Sendable {
    // MARK: - Properties
    
    /// Firestore document ID when persisted, otherwise a generated in-memory ID.
    private var documentID: String?
    
    /// Stable identifier for SwiftUI lists when no Firestore ID exists.
    private let fallbackID: String
    
    /// Icon name for the activity (SF Symbol name)
    let icon: String
    
    /// Title of the activity
    let title: String
    
    /// Detailed description of the activity
    let description: String
    
    /// Date when the activity occurred
    let date: Date
    
    /// Color for the icon (stored as string for Firestore compatibility)
    let iconColorName: String
    
    /// Whether to show progress for this activity
    var showProgress: Bool
    
    /// Progress value between 0.0 and 1.0
    var progressValue: Double
    
    // MARK: - Computed Properties
    
    /// Human-readable time ago string (e.g., "2h ago")
    var timeAgo: String {
        return date.timeAgoDisplay()
    }
    
    var id: String {
        documentID ?? fallbackID
    }
    
    /// Icon color converted from string to SwiftUI Color
    var iconColor: Color {
        return Color.fromString(iconColorName)
    }
    
    /// Progress percentage as a formatted string
    var progressPercentage: String {
        return "\(Int(progressValue * 100))%"
    }
    
    // MARK: - Initialization
    
    init(
        id: String? = nil,
        icon: String,
        title: String,
        description: String,
        date: Date = Date(),
        iconColorName: String = "blue",
        showProgress: Bool = false,
        progressValue: Double = 0.0
    ) {
        self.documentID = id
        self.fallbackID = id ?? UUID().uuidString
        self.icon = icon
        self.title = title
        self.description = description
        self.date = date
        self.iconColorName = iconColorName
        self.showProgress = showProgress
        self.progressValue = min(max(progressValue, 0.0), 1.0) // Ensure value is between 0 and 1
    }
    
    /// Convenience initializer that accepts a Color and converts it to a string
    init(
        id: String? = nil,
        icon: String,
        title: String,
        description: String,
        date: Date = Date(),
        iconColor: Color,
        showProgress: Bool = false,
        progressValue: Double = 0.0
    ) {
        self.documentID = id
        self.fallbackID = id ?? UUID().uuidString
        self.icon = icon
        self.title = title
        self.description = description
        self.date = date
        self.iconColorName = iconColor.toStringName()
        self.showProgress = showProgress
        self.progressValue = min(max(progressValue, 0.0), 1.0) // Ensure value is between 0 and 1
    }
}

// MARK: - Firestore Codable Support

nonisolated extension RecentActivity: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case fallbackID
        case icon
        case title
        case description
        case date
        case iconColorName
        case showProgress
        case progressValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        documentID = try container.decodeIfPresent(String.self, forKey: .id)
        fallbackID = try container.decodeIfPresent(String.self, forKey: .fallbackID) ?? UUID().uuidString
        icon = try container.decode(String.self, forKey: .icon)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        date = try container.decode(Date.self, forKey: .date)
        iconColorName = try container.decode(String.self, forKey: .iconColorName)
        showProgress = try container.decodeIfPresent(Bool.self, forKey: .showProgress) ?? false
        progressValue = try container.decodeIfPresent(Double.self, forKey: .progressValue) ?? 0.0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(documentID, forKey: .id)
        try container.encode(fallbackID, forKey: .fallbackID)
        try container.encode(icon, forKey: .icon)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(date, forKey: .date)
        try container.encode(iconColorName, forKey: .iconColorName)
        try container.encode(showProgress, forKey: .showProgress)
        try container.encode(progressValue, forKey: .progressValue)
    }
}

// MARK: - Sample Data

nonisolated extension RecentActivity {
    /// A single sample activity for previews
    static var sampleActivity: RecentActivity {
        return RecentActivity(
            id: "sample1",
            icon: "doc.fill",
            title: "New TMI Plan Created",
            description: "For student John Doe",
            date: Date(),
            iconColor: .blue
        )
    }
    
    /// Sample activities for previews and testing
    static var sampleActivities: [RecentActivity] {
        return [
            RecentActivity(
                id: "1",
                icon: "checkmark.circle.fill",
                title: "New Survey Completed",
                description: "Student #1234 completed the interest survey",
                date: Date().addingTimeInterval(-7200), // 2 hours ago
                iconColor: .green
            ),
            RecentActivity(
                id: "2",
                icon: "pencil.circle.fill",
                title: "Plan Updated",
                description: "You updated the TMI plan for Student #5678",
                date: Date().addingTimeInterval(-18000), // 5 hours ago
                iconColor: .blue,
                showProgress: true,
                progressValue: 0.75
            ),
            RecentActivity(
                id: "3",
                icon: "person.fill.badge.plus",
                title: "New Student Added",
                description: "Student #9012 was added to your roster",
                date: Date().addingTimeInterval(-86400), // 1 day ago
                iconColor: .purple
            ),
            RecentActivity(
                id: "4",
                icon: "list.clipboard.fill",
                title: "Interest Survey Completed",
                description: "By student Jane Smith",
                date: Date().addingTimeInterval(-172800), // 2 days ago
                iconColor: .orange,
                showProgress: true,
                progressValue: 0.33
            ),
            RecentActivity(
                id: "5",
                icon: "person.fill.checkmark",
                title: "Student Goal Achieved",
                description: "Alex Johnson completed Python course",
                date: Date().addingTimeInterval(-259200), // 3 days ago
                iconColor: .teal,
                showProgress: true,
                progressValue: 1.0
            )
        ]
    }
}

// MARK: - Helper Extensions

nonisolated extension Date {
    /// Converts a date to a human-readable "time ago" string
    func timeAgoDisplay() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear, .month, .year], from: self, to: now)
        
        if let years = components.year, years > 0 {
            return years == 1 ? "1y ago" : "\(years)y ago"
        }
        
        if let months = components.month, months > 0 {
            return months == 1 ? "1mo ago" : "\(months)mo ago"
        }
        
        if let weeks = components.weekOfYear, weeks > 0 {
            return weeks == 1 ? "1w ago" : "\(weeks)w ago"
        }
        
        if let days = components.day, days > 0 {
            return days == 1 ? "1d ago" : "\(days)d ago"
        }
        
        if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1h ago" : "\(hours)h ago"
        }
        
        if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1m ago" : "\(minutes)m ago"
        }
        
        return "Just now"
    }
}

nonisolated extension Color {
    /// Convert a Color to a string representation
    func toStringName() -> String {
        // This is a simplified implementation
        // In a real app, you might use UIColor components or a more sophisticated approach
        if self == .red { return "red" }
        if self == .blue { return "blue" }
        if self == .green { return "green" }
        if self == .yellow { return "yellow" }
        if self == .orange { return "orange" }
        if self == .purple { return "purple" }
        if self == .pink { return "pink" }
        if self == .teal { return "teal" }
        return "blue" // Default
    }
    
    /// Create a Color from a string name
    static func fromString(_ name: String) -> Color {
        switch name.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        default: return .blue
        }
    }
}
