//
//  Resource.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation
import FirebaseFirestore

struct Resource: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var category: ResourceCategory
    var url: String
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    var recommendedFor: [String]

    enum ResourceCategory: String, Codable, CaseIterable {
        case article
        case video
        case course
        case book
        case tool
        case interactiveContent
    }

    init(id: String? = nil, title: String, description: String, category: ResourceCategory, url: String, createdAt: Date, updatedAt: Date, tags: [String] = [], recommendedFor: [String] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.url = url
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.recommendedFor = recommendedFor
    }
}

extension Resource {
    static var sampleResources: [Resource] {
        [
            Resource(
                id: "resource_1",
                title: "Introduction to Python Programming",
                description: "A beginner-friendly course on Python programming",
                category: .course,
                url: "https://example.com/python-course",
                createdAt: Date(),
                updatedAt: Date(),
                tags: ["programming", "python", "beginner"],
                recommendedFor: ["technology", "computer science"]
            ),
            Resource(
                id: "resource_2",
                title: "Effective Study Techniques",
                description: "An article on improving study habits and productivity",
                category: .article,
                url: "https://example.com/study-techniques",
                createdAt: Date(),
                updatedAt: Date(),
                tags: ["study", "productivity", "learning"],
                recommendedFor: ["all students"]
            )
        ]
    }
}
