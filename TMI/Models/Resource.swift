//
//  Resource.swift
//  TMI
//
//  Created by Chandan Brown on 4/21/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore

struct Resource: Identifiable, Codable, @unchecked Sendable, Hashable {
    @DocumentID var id: String?
    let title: String
    let description: String
    let category: ResourceCategory
    let url: String
    let createdAt: Date
    var updatedAt: Date
    let tags: [String]
    let recommendedFor: [String]
    var isFeatured: Bool = false
    var thumbnail: String? = nil

    // Library Scope Properties
    let scope: ResourceScope?
    let districtId: String?
    let ownerUid: String?

    enum ResourceCategory: String, CaseIterable, Codable, Sendable {
        case article, video, course, book, tool, interactiveContent

        var color: Color {
            switch self {
            case .article: return .blue
            case .video: return .red
            case .course: return .green
            case .book: return .purple
            case .tool: return .orange
            case .interactiveContent: return .pink
            }
        }

        var icon: String {
            switch self {
            case .article: return "doc.text.fill"
            case .video: return "play.rectangle.fill"
            case .course: return "book.fill"
            case .book: return "book.closed.fill"
            case .tool: return "hammer.fill"
            case .interactiveContent: return "gamecontroller.fill"
            }
        }
    }

    enum ResourceScope: String, CaseIterable, Codable, Sendable {
        case global = "global"
        case district = "district"
        case personal = "personal"
    }

    public static func == (lhs: Resource, rhs: Resource) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static var sampleResources: [Resource] {
        [
            // Featured Resources
            Resource(
                title: "Understanding Student Engagement",
                description: "A comprehensive guide to measuring and improving student engagement in educational settings.",
                category: .article,
                url: "https://www.edutopia.org/article/understanding-student-engagement",
                createdAt: Date().addingTimeInterval(-86400 * 7),
                updatedAt: Date().addingTimeInterval(-86400 * 7),
                tags: ["engagement", "research", "metrics", "classroom-management"],
                recommendedFor: ["Teachers", "Counselors", "Administrators"],
                isFeatured: true,
                scope: .global,
                districtId: nil,
                ownerUid: nil
            ),
            Resource(
                title: "TMI Implementation Course",
                description: "Step-by-step course on implementing Tangible Modification Intervention in your school or district.",
                category: .course,
                url: "https://www.coursera.org/learn/trauma-informed-education",
                createdAt: Date().addingTimeInterval(-86400 * 30),
                updatedAt: Date().addingTimeInterval(-86400 * 30),
                tags: ["implementation", "training", "certification", "trauma-informed"],
                recommendedFor: ["Administrators", "Program Coordinators", "Counselors"],
                isFeatured: true,
                scope: .global,
                districtId: nil,
                ownerUid: nil
            ),
            Resource(
                title: "Student Interest Assessment Toolkit",
                description: "Comprehensive toolkit with validated instruments for assessing student interests across age groups.",
                category: .tool,
                url: "https://www.assessmenttools.edu/interest-inventory",
                createdAt: Date().addingTimeInterval(-86400 * 15),
                updatedAt: Date().addingTimeInterval(-86400 * 15),
                tags: ["assessment", "interests", "toolkit", "validated-instruments"],
                recommendedFor: ["Counselors", "Teachers", "Researchers"],
                isFeatured: true,
                scope: .global,
                districtId: nil,
                ownerUid: nil
            )
        ]
    }
}
