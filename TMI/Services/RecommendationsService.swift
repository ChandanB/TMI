//
//  RecommendationsService.swift
//  TMI
//
//  Created by Chandan Brown on 8/11/25.
//

import Foundation

@Observable
final class RecommendationsService: @unchecked Sendable {
    static let shared = RecommendationsService()
    
    private let careerService = CareerService.shared
    private let resourceService = ResourceService.shared
    
    private init() {}
    
    // MARK: - Career Recommendations
    
    /// Get career recommendations based on student's interests and hobbies
    func getCareerRecommendations(for student: Student) async throws -> [Career] {
        return try await careerService.getCareerRecommendations(for: student)
    }
    
    /// Get career recommendations based on specific interests
    func getCareerRecommendations(for interests: [Interest]) async throws -> [Career] {
        let allCareers = try await careerService.fetchAllCareers()
        
        var scoredCareers: [(career: Career, score: Double)] = []
        
        for career in allCareers {
            var score = 0.0
            
            // Score based on interests
            for interest in interests {
                // Check if career field matches interest
                if career.field.lowercased().contains(interest.name.lowercased()) ||
                   career.title.lowercased().contains(interest.name.lowercased()) ||
                   career.description.lowercased().contains(interest.name.lowercased()) {
                    let scoreMultiplier = Double(interest.popularityScore ?? 5) / 10.0
                    score += scoreMultiplier * 0.4
                }
                
                // Check if career skills match interest
                for skill in career.skills {
                    if skill.lowercased().contains(interest.name.lowercased()) {
                        let scoreMultiplier = Double(interest.popularityScore ?? 5) / 10.0
                        score += scoreMultiplier * 0.2
                    }
                }
            }
            
            if score > 0 {
                scoredCareers.append((career: career, score: score))
            }
        }
        
        // Return top 10 recommendations sorted by score
        return Array(scoredCareers.sorted { $0.score > $1.score }.prefix(10).map { $0.career })
    }
    
    // MARK: - Resource Recommendations
    
    /// Get resource recommendations based on student's interests and current career exploration
    func getResourceRecommendations(for student: Student) async throws -> [Resource] {
        var recommendations: [Resource] = []
        
        // Get resources based on interests
        for interest in student.interests {
            let interestResources = try await resourceService.searchResources(query: interest.name)
            recommendations.append(contentsOf: interestResources.prefix(2))
        }
        
        // Note: Hobbies are now included in interests array above
        
        // Remove duplicates and return top 8
        let uniqueRecommendations = Array(Set(recommendations.map { $0.id ?? "" }))
            .compactMap { id in recommendations.first { $0.id == id } }
        
        return Array(uniqueRecommendations.prefix(8))
    }
    
    /// Get resources recommended for a specific career
    func getResourcesForCareer(_ career: Career) async throws -> [Resource] {
        var resources: [Resource] = []
        
        // Get resources based on career field
        let fieldResources = try await resourceService.searchResources(query: career.field)
        resources.append(contentsOf: fieldResources.prefix(3))
        
        // Get resources based on career skills
        for skill in career.skills.prefix(3) {
            let skillResources = try await resourceService.searchResources(query: skill)
            resources.append(contentsOf: skillResources.prefix(1))
        }
        
        // Get resources by tags that match career
        let careerTags = [career.field.lowercased(), "career", "skills"]
        let taggedResources = try await resourceService.fetchResources(withTags: careerTags)
        resources.append(contentsOf: taggedResources.prefix(2))
        
        // Remove duplicates and return top 6
        let uniqueResources = Array(Set(resources.map { $0.id ?? "" }))
            .compactMap { id in resources.first { $0.id == id } }
        
        return Array(uniqueResources.prefix(6))
    }
    
    // MARK: - Personalized Recommendations
    
    /// Generate a comprehensive recommendation dashboard for a student
    func getPersonalizedDashboard(for student: Student) async throws -> PersonalizedDashboard {
        async let careerRecs = getCareerRecommendations(for: student)
        async let resourceRecs = getResourceRecommendations(for: student)
        async let trendingCareers = careerService.fetchTrendingCareers()
        async let featuredResources = resourceService.fetchFeaturedResources()
        
        return PersonalizedDashboard(
            recommendedCareers: try await careerRecs,
            recommendedResources: try await resourceRecs,
            trendingCareers: try await trendingCareers,
            featuredResources: try await featuredResources,
            student: student
        )
    }
    
    /// Get recommendations based on what similar students are exploring
    func getSimilarStudentRecommendations(for student: Student) async throws -> [Career] {
        // This would use collaborative filtering in a real implementation
        // For now, return careers that match the student's top interests
        let topInterests = student.interests.sorted { ($0.popularityScore ?? 0) > ($1.popularityScore ?? 0) }.prefix(3)
        return try await getCareerRecommendations(for: Array(topInterests))
    }
    
    // MARK: - Smart Suggestions
    
    /// Get smart suggestions for improving TMI plans
    func getTMIPlanSuggestions(for student: Student) async throws -> [TMIPlanSuggestion] {
        var suggestions: [TMIPlanSuggestion] = []
        
        // Suggest careers based on interests not yet explored
        let careerSuggestions = try await getCareerRecommendations(for: student)
        for career in careerSuggestions.prefix(3) {
            suggestions.append(
                TMIPlanSuggestion(
                    type: .careerExploration,
                    title: "Explore \(career.title)",
                    description: "Based on your interests in \(student.interests.map { $0.name }.joined(separator: ", "))",
                    actionItem: "Learn about \(career.title) and add it to your career exploration list",
                    relatedCareer: career
                )
            )
        }
        
        // Suggest resources for skill development
        let resourceSuggestions = try await getResourceRecommendations(for: student)
        for resource in resourceSuggestions.prefix(2) {
            suggestions.append(
                TMIPlanSuggestion(
                    type: .skillDevelopment,
                    title: "Develop skills with \(resource.title)",
                    description: "This \(resource.category.rawValue) can help you build relevant skills",
                    actionItem: "Review \(resource.title) and apply the concepts to your interests",
                    relatedResource: resource
                )
            )
        }
        
        return suggestions
    }
}

// MARK: - Supporting Models

struct PersonalizedDashboard {
    let recommendedCareers: [Career]
    let recommendedResources: [Resource]
    let trendingCareers: [Career]
    let featuredResources: [Resource]
    let student: Student
    let generatedAt: Date = Date()
}

struct TMIPlanSuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let title: String
    let description: String
    let actionItem: String
    let relatedCareer: Career?
    let relatedResource: Resource?
    let createdAt: Date = Date()
    
    init(type: SuggestionType, title: String, description: String, actionItem: String, relatedCareer: Career? = nil, relatedResource: Resource? = nil) {
        self.type = type
        self.title = title
        self.description = description
        self.actionItem = actionItem
        self.relatedCareer = relatedCareer
        self.relatedResource = relatedResource
    }
}

enum SuggestionType: String, CaseIterable {
    case careerExploration = "career_exploration"
    case skillDevelopment = "skill_development"
    case interestExpansion = "interest_expansion"
    case resourceReview = "resource_review"
    case planOptimization = "plan_optimization"
    
    var icon: String {
        switch self {
        case .careerExploration: return "briefcase.fill"
        case .skillDevelopment: return "star.fill"
        case .interestExpansion: return "heart.fill"
        case .resourceReview: return "book.fill"
        case .planOptimization: return "chart.line.uptrend.xyaxis"
        }
    }
    
    var color: String {
        switch self {
        case .careerExploration: return "blue"
        case .skillDevelopment: return "green"
        case .interestExpansion: return "purple"
        case .resourceReview: return "orange"
        case .planOptimization: return "red"
        }
    }
}
