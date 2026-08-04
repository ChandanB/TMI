//
//  SurveyModels.swift
//  TMI
//
//  Core survey data models for interest discovery and career matching
//

import Foundation
import SwiftUI

// MARK: - Survey Step

struct SurveyStep: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let type: SurveyStepType
    let options: [LegacySurveyOption]
    let isRequired: Bool

    init(id: String, title: String, subtitle: String? = nil, type: SurveyStepType, options: [LegacySurveyOption] = [], isRequired: Bool = true) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.options = options
        self.isRequired = isRequired
    }
}

enum SurveyStepType {
    case intro
    case multiSelect      // Multiple choice, can select many
    case singleSelect     // Single choice only
    case scale           // 1-5 rating scale
    case openEnded       // Text input
    case dreamJob        // Special career dream input
}

struct LegacySurveyOption: Identifiable {
    let id: String
    let text: String
    let icon: String
    let interestCategory: String?
    let weight: Double

    init(id: String, text: String, icon: String, interestCategory: String? = nil, weight: Double = 1.0) {
        self.id = id
        self.text = text
        self.icon = icon
        self.interestCategory = interestCategory
        self.weight = weight
    }
}

// MARK: - Survey Response

nonisolated struct LegacySurveyResponse: Codable, Identifiable, Sendable {
    let id: UUID
    let studentId: String
    let responses: [String: SurveyAnswerValue]
    let interestClusters: [InterestCluster]
    let topInterests: [String]
    let completedAt: Date
    let completionTime: TimeInterval // In seconds

    nonisolated enum SurveyAnswerValue: Codable, Sendable {
        case text(String)
        case options([String])
        case scale(Int)

        enum CodingKeys: String, CodingKey {
            case type, value
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let string):
                try container.encode("text", forKey: .type)
                try container.encode(string, forKey: .value)
            case .options(let array):
                try container.encode("options", forKey: .type)
                try container.encode(array, forKey: .value)
            case .scale(let int):
                try container.encode("scale", forKey: .type)
                try container.encode(int, forKey: .value)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "text":
                let value = try container.decode(String.self, forKey: .value)
                self = .text(value)
            case "options":
                let value = try container.decode([String].self, forKey: .value)
                self = .options(value)
            case "scale":
                let value = try container.decode(Int.self, forKey: .value)
                self = .scale(value)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
            }
        }
    }
}

// MARK: - Interest Cluster

nonisolated struct InterestCluster: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let displayName: String
    let weight: Double // 0.0 - 1.0 (strength of interest)
    let relatedCareers: [String] // Career IDs
    let icon: String
    let color: String // Hex color

    init(id: UUID = UUID(), name: String, displayName: String, weight: Double, relatedCareers: [String] = [], icon: String, color: String) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.weight = weight
        self.relatedCareers = relatedCareers
        self.icon = icon
        self.color = color
    }
}

// MARK: - Predefined Interest Categories

nonisolated extension InterestCluster {
    static let audioMedia = InterestCluster(
        name: "audio_media",
        displayName: "Audio & Media",
        weight: 0.0,
        relatedCareers: ["podcaster", "radio_host", "audio_engineer", "content_creator"],
        icon: "mic.fill",
        color: "#9B59B6"
    )

    static let healthWellness = InterestCluster(
        name: "health_wellness",
        displayName: "Health & Wellness",
        weight: 0.0,
        relatedCareers: ["fitness_trainer", "nutritionist", "physical_therapist", "nurse"],
        icon: "heart.fill",
        color: "#16A085"
    )

    static let technology = InterestCluster(
        name: "technology",
        displayName: "Technology",
        weight: 0.0,
        relatedCareers: ["game_developer", "app_designer", "software_engineer", "data_analyst"],
        icon: "laptopcomputer",
        color: "#3498DB"
    )

    static let creativeArts = InterestCluster(
        name: "creative_arts",
        displayName: "Creative Arts",
        weight: 0.0,
        relatedCareers: ["graphic_designer", "photographer", "film_director", "animator"],
        icon: "paintpalette.fill",
        color: "#E74C3C"
    )

    static let sportsAthletics = InterestCluster(
        name: "sports_athletics",
        displayName: "Sports & Athletics",
        weight: 0.0,
        relatedCareers: ["coach", "athletic_trainer", "sports_analyst", "physical_education_teacher"],
        icon: "figure.run",
        color: "#F39C12"
    )

    static let businessEntrepreneurship = InterestCluster(
        name: "business_entrepreneurship",
        displayName: "Business & Entrepreneurship",
        weight: 0.0,
        relatedCareers: ["entrepreneur", "marketing_specialist", "financial_advisor", "business_analyst"],
        icon: "briefcase.fill",
        color: "#2ECC71"
    )

    static let education = InterestCluster(
        name: "education",
        displayName: "Education & Teaching",
        weight: 0.0,
        relatedCareers: ["teacher", "tutor", "education_specialist", "school_counselor"],
        icon: "book.fill",
        color: "#E67E22"
    )

    static let socialServices = InterestCluster(
        name: "social_services",
        displayName: "Social Services",
        weight: 0.0,
        relatedCareers: ["social_worker", "counselor", "community_organizer", "nonprofit_director"],
        icon: "hands.sparkles.fill",
        color: "#1ABC9C"
    )

    static let scienceResearch = InterestCluster(
        name: "science_research",
        displayName: "Science & Research",
        weight: 0.0,
        relatedCareers: [],
        icon: "atom",
        color: "#2980B9"
    )

    static let engineeringBuilding = InterestCluster(
        name: "engineering_building",
        displayName: "Engineering & Building",
        weight: 0.0,
        relatedCareers: [],
        icon: "gearshape.2.fill",
        color: "#2C3E50"
    )

    static let lawGovernment = InterestCluster(
        name: "law_government",
        displayName: "Law & Government",
        weight: 0.0,
        relatedCareers: [],
        icon: "scale.3d",
        color: "#34495E"
    )

    static let agricultureNature = InterestCluster(
        name: "agriculture_nature",
        displayName: "Agriculture & Nature",
        weight: 0.0,
        relatedCareers: [],
        icon: "leaf.fill",
        color: "#27AE60"
    )

    static let hospitalityTourism = InterestCluster(
        name: "hospitality_tourism",
        displayName: "Hospitality & Tourism",
        weight: 0.0,
        relatedCareers: [],
        icon: "fork.knife",
        color: "#D35400"
    )

    static let transportationLogistics = InterestCluster(
        name: "transportation_logistics",
        displayName: "Transportation & Logistics",
        weight: 0.0,
        relatedCareers: [],
        icon: "airplane",
        color: "#5D6D7E"
    )

    static let allCategories: [InterestCluster] = [
        .audioMedia,
        .healthWellness,
        .technology,
        .creativeArts,
        .sportsAthletics,
        .businessEntrepreneurship,
        .education,
        .socialServices,
        .scienceResearch,
        .engineeringBuilding,
        .lawGovernment,
        .agricultureNature,
        .hospitalityTourism,
        .transportationLogistics
    ]
}

// MARK: - Survey Configuration

struct SurveyConfiguration {
    static let steps: [SurveyStep] = [
        // Step 1: Welcome
        SurveyStep(
            id: "welcome",
            title: "Let's discover what you love!",
            subtitle: "This survey helps us understand your interests and match you with exciting career possibilities.",
            type: .intro
        ),

        // Step 2: Interest Categories
        SurveyStep(
            id: "interests",
            title: "What excites you?",
            subtitle: "Select all that interest you",
            type: .multiSelect,
            options: [
                LegacySurveyOption(id: "audio_media", text: "Audio & Media", icon: "mic.fill", interestCategory: "audio_media", weight: 1.0),
                LegacySurveyOption(id: "health_wellness", text: "Health & Wellness", icon: "heart.fill", interestCategory: "health_wellness", weight: 1.0),
                LegacySurveyOption(id: "technology", text: "Technology & Gaming", icon: "laptopcomputer", interestCategory: "technology", weight: 1.0),
                LegacySurveyOption(id: "creative_arts", text: "Creative Arts", icon: "paintpalette.fill", interestCategory: "creative_arts", weight: 1.0),
                LegacySurveyOption(id: "sports", text: "Sports & Athletics", icon: "figure.run", interestCategory: "sports_athletics", weight: 1.0),
                LegacySurveyOption(id: "business", text: "Business & Entrepreneurship", icon: "briefcase.fill", interestCategory: "business_entrepreneurship", weight: 1.0),
                LegacySurveyOption(id: "education", text: "Education & Teaching", icon: "book.fill", interestCategory: "education", weight: 1.0),
                LegacySurveyOption(id: "social_services", text: "Helping Others", icon: "hands.sparkles.fill", interestCategory: "social_services", weight: 1.0)
            ]
        ),

        // Step 3: Hobbies (Open-ended)
        SurveyStep(
            id: "hobbies",
            title: "What do you do for fun?",
            subtitle: "Tell us about your favorite activities and hobbies",
            type: .openEnded
        ),

        // Step 4: Learning Style
        SurveyStep(
            id: "learning_style",
            title: "How do you like to learn?",
            subtitle: "Choose your preferred way",
            type: .singleSelect,
            options: [
                LegacySurveyOption(id: "video", text: "Watching videos", icon: "play.rectangle.fill"),
                LegacySurveyOption(id: "reading", text: "Reading articles & books", icon: "book.fill"),
                LegacySurveyOption(id: "hands_on", text: "Hands-on practice", icon: "hand.raised.fill"),
                LegacySurveyOption(id: "collaboration", text: "Working with others", icon: "person.2.fill")
            ]
        ),

        // Step 5: Career Passion Scale
        SurveyStep(
            id: "career_passion",
            title: "How important is following your passion in a career?",
            subtitle: "1 = Not important, 5 = Very important",
            type: .scale
        ),

        // Step 6: Dream Job
        SurveyStep(
            id: "dream_job",
            title: "If you could be anything...",
            subtitle: "What would your dream job be?",
            type: .dreamJob
        )
    ]
}
