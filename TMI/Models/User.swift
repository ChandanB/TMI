//
//  User.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var role: UserRole
    var createdAt: Date
    var lastLoginAt: Date?
    var profileImageURL: String?
    var associatedStudentIds: [String]?
    var preferences: UserPreferences
    var formTemplates: [String] = []

    enum UserRole: String, Codable {
        case admin
        case teacher
        case counselor
        case parent
    }
    
    struct UserPreferences: Codable {
        var notificationsEnabled: Bool
        var darkModeEnabled: Bool
        var language: String
    }
    
    init(id: String? = nil, name: String, email: String, role: UserRole, createdAt: Date = Date(), lastLoginAt: Date? = nil, profileImageURL: String? = nil, associatedStudentIds: [String]? = nil, preferences: UserPreferences = UserPreferences(notificationsEnabled: true, darkModeEnabled: false, language: "en")) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
        self.profileImageURL = profileImageURL
        self.associatedStudentIds = associatedStudentIds
        self.preferences = preferences
    }
}

extension User {
    static var sampleUser: User {
        User(
            id: "sample_user_1",
            name: "John Doe",
            email: "john.doe@example.com",
            role: .teacher,
            createdAt: Date(),
            lastLoginAt: Date(),
            profileImageURL: "https://example.com/profile.jpg",
            associatedStudentIds: ["student_1", "student_2"],
            preferences: UserPreferences(notificationsEnabled: true, darkModeEnabled: true, language: "en")
        )
    }
}

