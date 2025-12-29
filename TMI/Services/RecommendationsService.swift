//
//  RecommendationsService.swift
//  TMI
//
//  Phase 5: ID-based Recommendations Service
//  Returns lightweight ID arrays instead of full objects
//  Views resolve IDs via library services
//

import Foundation
import FirebaseAuth
import Observation

// MARK: - Recommendation Models

struct StudentRecommendations: Codable, Sendable, Equatable {
    let studentId: String
    let generatedAt: Date
    let interestIds: [String]
    let careerIds: [String]
    let resourceIds: [String]
    let nextSteps: [String]

    init(
        studentId: String,
        generatedAt: Date = Date(),
        interestIds: [String] = [],
        careerIds: [String] = [],
        resourceIds: [String] = [],
        nextSteps: [String] = []
    ) {
        self.studentId = studentId
        self.generatedAt = generatedAt
        self.interestIds = interestIds
        self.careerIds = careerIds
        self.resourceIds = resourceIds
        self.nextSteps = nextSteps
    }
}

struct PersonalizedDashboard: Sendable {
    let recommendedCareers: [Career]
    let recommendedResources: [Resource]
    let trendingCareers: [Career]
    let featuredResources: [Resource]
}

struct TMIPlanSuggestion: Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let actionItem: String
    let type: TMIPlanType

    enum TMIPlanType: Sendable {
        case chaseYourSpace
        case acknowledgeInterests
        case meetStudentNeeds
        case yourBehaviorMyResponse
        case planningAndGoalSetting
        case celebrateEffort

        var icon: String {
            switch self {
            case .chaseYourSpace: return "figure.run"
            case .acknowledgeInterests: return "star.fill"
            case .meetStudentNeeds: return "heart.fill"
            case .yourBehaviorMyResponse: return "arrow.left.arrow.right"
            case .planningAndGoalSetting: return "target"
            case .celebrateEffort: return "party.popper.fill"
            }
        }
    }
}

// MARK: - Recommendations Service

@Observable
final class RecommendationsService: @unchecked Sendable {
    static let shared = RecommendationsService()

    // Phase 5: Library Services
    private let interestLibraryService = InterestLibraryService.shared
    private let careerLibraryService = CareerLibraryService.shared
    private let resourceLibraryService = ResourceLibraryService.shared
    private let studentInterestService = StudentInterestService.shared
    private let studentCareerService = StudentCareerService.shared

    private init() {}

    // MARK: - Error Types

    enum RecommendationsError: Error, LocalizedError {
        case generationFailed(String)
        case invalidStudentId
        case userNotAuthenticated

        var errorDescription: String? {
            switch self {
            case .generationFailed(let message):
                return "Failed to generate recommendations: \(message)"
            case .invalidStudentId:
                return "Invalid student ID"
            case .userNotAuthenticated:
                return "User not authenticated"
            }
        }
    }

    // MARK: - Main Recommendation Generation

    /// Phase 5: Generate comprehensive recommendations for a student
    /// Returns IDs only - caller resolves via library services
    func generateRecommendations(for student: Student) async throws -> StudentRecommendations {
        guard let studentId = student.id else {
            throw RecommendationsError.invalidStudentId
        }

        print("[RecommendationsService] Generating recommendations for student \(student.name)")

        async let interestIds = recommendInterests(for: student, studentId: studentId)
        async let careerIds = recommendCareers(for: student, studentId: studentId)
        async let resourceIds = recommendResources(for: student, studentId: studentId)
        async let nextSteps = generateNextSteps(for: student, studentId: studentId)

        let recommendations = StudentRecommendations(
            studentId: studentId,
            generatedAt: Date(),
            interestIds: try await interestIds,
            careerIds: try await careerIds,
            resourceIds: try await resourceIds,
            nextSteps: try await nextSteps
        )

        print("[RecommendationsService] Generated \(recommendations.interestIds.count) interests, \(recommendations.careerIds.count) careers, \(recommendations.resourceIds.count) resources")

        return recommendations
    }

    // MARK: - Interest Recommendations

    /// Recommend interests based on student's current interests
    private func recommendInterests(for student: Student, studentId: String) async throws -> [String] {
        // Fetch all global interests
        let allInterests = try await interestLibraryService.fetchAllInterests()

        // Get student's existing interest IDs
        let existingInterests = try await studentInterestService.getStudentInterests(studentId: studentId)
        let existingInterestIds = Set(existingInterests.map { $0.interestId })

        // Find related interests based on categories and tags
        var scoredInterests: [(id: String, score: Double)] = []

        for interest in allInterests {
            guard let interestId = interest.id else { continue }

            // Skip if student already has this interest
            if existingInterestIds.contains(interestId) {
                continue
            }

            var score = 0.0

            // Score based on category overlap with existing interests
            for existingEdge in existingInterests {
                if let existingInterest = try? await interestLibraryService.fetchInterest(id: existingEdge.interestId) {
                    // Same category = high score
                    if interest.primaryCategory == existingInterest.primaryCategory {
                        score += Double(existingEdge.level) * 0.5
                    }

                    // Tag overlap
                    let tagOverlap = Set(interest.tags).intersection(Set(existingInterest.tags))
                    score += Double(tagOverlap.count) * 0.3
                }
            }

            if score > 0 {
                scoredInterests.append((id: interestId, score: score))
            }
        }

        // Return top 10 recommendations
        return scoredInterests
            .sorted { $0.score > $1.score }
            .prefix(10)
            .map { $0.id }
    }

    // MARK: - Career Recommendations

    /// Recommend careers based on student interests and career exploration
    private func recommendCareers(for student: Student, studentId: String) async throws -> [String] {
        // Get student's interest affinities
        let studentInterests = try await studentInterestService.getHighAffinityInterests(studentId: studentId)

        // Get all careers from global library
        let allCareers = try await careerLibraryService.fetchAllCareers(districtId: nil)

        // Get careers student is already exploring
        let exploredCareers = try await studentCareerService.getStudentCareers(studentId: studentId)
        let exploredCareerIds = Set(exploredCareers.map { $0.careerId })

        var scoredCareers: [(id: String, score: Double)] = []

        for career in allCareers {
            guard let careerId = career.id else { continue }

            // Skip if already exploring
            if exploredCareerIds.contains(careerId) {
                continue
            }

            var score = 0.0

            // Score based on interest alignment
            for interestEdge in studentInterests {
                if let interest = try? await interestLibraryService.fetchInterest(id: interestEdge.interestId) {
                    // Check if career field matches interest
                    if career.field.lowercased().contains(interest.name.lowercased()) {
                        score += Double(interestEdge.level) * 0.6
                    }

                    // Check tags
                    if career.tags.contains(where: { tag in
                        interest.tags.contains(where: { $0.lowercased() == tag.lowercased() })
                    }) {
                        score += Double(interestEdge.level) * 0.4
                    }

                    // Check related interests
                    if career.relatedInterests.contains(interestEdge.interestId) {
                        score += Double(interestEdge.level) * 0.5
                    }
                }
            }

            // Boost high-growth careers slightly
            if career.growthRate > 0.1 {
                score += career.growthRate * 0.2
            }

            if score > 0 {
                scoredCareers.append((id: careerId, score: score))
            }
        }

        // Return top 8 recommendations
        return scoredCareers
            .sorted { $0.score > $1.score }
            .prefix(8)
            .map { $0.id }
    }

    // MARK: - Resource Recommendations

    /// Recommend resources based on interests and career goals
    private func recommendResources(for student: Student, studentId: String) async throws -> [String] {
        // Get student interests and careers
        let studentInterests = try await studentInterestService.getStudentInterests(studentId: studentId)
        let studentCareers = try await studentCareerService.getActiveCareers(studentId: studentId)

        // Get all resources from global library
        let allResources = try await resourceLibraryService.fetchResources(scope: nil, districtId: nil)

        var scoredResources: [(id: String, score: Double)] = []

        for resource in allResources {
            guard let resourceId = resource.id else { continue }

            var score = 0.0

            // Score based on interest alignment
            for interestEdge in studentInterests {
                if let interest = try? await interestLibraryService.fetchInterest(id: interestEdge.interestId) {
                    // Tag matching
                    let tagMatches = resource.tags.filter { tag in
                        interest.tags.contains(where: { $0.lowercased() == tag.lowercased() })
                    }
                    score += Double(tagMatches.count) * Double(interestEdge.level) * 0.3

                    // Title/description matching
                    if resource.title.lowercased().contains(interest.name.lowercased()) {
                        score += Double(interestEdge.level) * 0.4
                    }
                }
            }

            // Score based on career alignment
            for careerEdge in studentCareers {
                if let career = try? await careerLibraryService.fetchCareer(id: careerEdge.careerId) {
                    // Tag matching
                    let careerTagMatches = resource.tags.filter { tag in
                        career.tags.contains(where: { $0.lowercased() == tag.lowercased() })
                    }
                    score += Double(careerTagMatches.count) * careerEdge.progress * 0.5

                    // Field matching
                    if resource.tags.contains(where: { $0.lowercased().contains(career.field.lowercased()) }) {
                        score += careerEdge.progress * 0.6
                    }
                }
            }

            if score > 0 {
                scoredResources.append((id: resourceId, score: score))
            }
        }

        // Return top 12 recommendations
        return scoredResources
            .sorted { $0.score > $1.score }
            .prefix(12)
            .map { $0.id }
    }

    // MARK: - Next Steps

    /// Generate actionable next steps for the student
    private func generateNextSteps(for student: Student, studentId: String) async throws -> [String] {
        var steps: [String] = []

        // Check interest exploration
        let studentInterests = try await studentInterestService.getStudentInterests(studentId: studentId)
        if studentInterests.isEmpty {
            steps.append("Complete the interest survey to discover activities you enjoy")
        } else if studentInterests.count < 5 {
            steps.append("Explore more interests to find what excites you")
        }

        // Check career exploration
        let studentCareers = try await studentCareerService.getStudentCareers(studentId: studentId)
        if studentCareers.isEmpty {
            steps.append("Browse careers that match your interests")
        } else {
            let activeCareers = studentCareers.filter { $0.isActivePursuit }
            if activeCareers.isEmpty {
                steps.append("Mark careers you're interested in pursuing")
            } else if activeCareers.count >= 3 {
                steps.append("Focus on your top 2-3 career paths for deeper exploration")
            }
        }

        // Engagement-based steps
        if student.engagementScore < 0.5 {
            steps.append("Connect with a counselor to discuss your goals")
        }

        // Generic helpful steps
        steps.append("Set up a meeting to create your personalized TMI plan")

        return Array(steps.prefix(4))
    }

    // MARK: - Dashboard & Suggestions (for UI)

    /// Get personalized dashboard with resolved objects for the student
    func getPersonalizedDashboard(for student: Student) async throws -> PersonalizedDashboard {
        guard let studentId = student.id else {
            throw RecommendationsError.invalidStudentId
        }

        // Generate recommendations (IDs only)
        let recommendations = try await generateRecommendations(for: student)

        // Resolve career IDs to Career objects
        let recommendedCareers = try await resolveCareers(ids: recommendations.careerIds)

        // Resolve resource IDs to Resource objects
        let recommendedResources = try await resolveResources(ids: recommendations.resourceIds)

        // Get trending careers (high growth rate)
        let allCareers = try await careerLibraryService.fetchAllCareers(districtId: nil)
        let trendingCareers = allCareers
            .filter { $0.growthRate > 0.1 }
            .sorted { $0.growthRate > $1.growthRate }
            .prefix(4)
            .map { $0 }

        // Get featured resources
        let featuredResources = try await resourceLibraryService.fetchFeaturedResources(districtId: nil)
            .prefix(4)
            .map { $0 }

        return PersonalizedDashboard(
            recommendedCareers: recommendedCareers,
            recommendedResources: recommendedResources,
            trendingCareers: Array(trendingCareers),
            featuredResources: Array(featuredResources)
        )
    }

    /// Get TMI plan suggestions for the student
    func getTMIPlanSuggestions(for student: Student) async throws -> [TMIPlanSuggestion] {
        guard let studentId = student.id else {
            throw RecommendationsError.invalidStudentId
        }

        var suggestions: [TMIPlanSuggestion] = []

        // Get student data
        let studentInterests = try await studentInterestService.getStudentInterests(studentId: studentId)
        let studentCareers = try await studentCareerService.getStudentCareers(studentId: studentId)

        // Chase Your Space - if student has low engagement
        if student.engagementScore < 0.5 {
            suggestions.append(TMIPlanSuggestion(
                id: UUID().uuidString,
                title: "Create Your Space",
                description: "Build a comfortable environment that reflects your interests",
                actionItem: "Set up a personalized learning space based on your favorite activities",
                type: .chaseYourSpace
            ))
        }

        // Acknowledge Interests - if student has interests but no careers
        if !studentInterests.isEmpty && studentCareers.isEmpty {
            suggestions.append(TMIPlanSuggestion(
                id: UUID().uuidString,
                title: "Explore Career Paths",
                description: "Connect your interests to potential careers",
                actionItem: "Review careers that match your top interests",
                type: .acknowledgeInterests
            ))
        }

        // Meet Student Needs - general suggestion
        suggestions.append(TMIPlanSuggestion(
            id: UUID().uuidString,
            title: "Set Personal Goals",
            description: "Identify what you want to achieve this semester",
            actionItem: "Schedule a meeting with your counselor to create goals",
            type: .meetStudentNeeds
        ))

        // Planning and Goal Setting - if student has careers
        if !studentCareers.isEmpty {
            suggestions.append(TMIPlanSuggestion(
                id: UUID().uuidString,
                title: "Create Action Plan",
                description: "Build a roadmap toward your career goals",
                actionItem: "Develop a step-by-step plan with milestones and resources",
                type: .planningAndGoalSetting
            ))
        }

        // Celebrate Effort - if student is engaged
        if student.engagementScore >= 0.7 {
            suggestions.append(TMIPlanSuggestion(
                id: UUID().uuidString,
                title: "Celebrate Progress",
                description: "Recognize your achievements and growth",
                actionItem: "Share your successes with teachers and peers",
                type: .celebrateEffort
            ))
        }

        return suggestions
    }

    // MARK: - Helper Methods

    /// Resolve career IDs to Career objects
    private func resolveCareers(ids: [String]) async throws -> [Career] {
        try await withThrowingTaskGroup(of: Career?.self) { group in
            for id in ids {
                group.addTask {
                    try? await self.careerLibraryService.fetchCareer(id: id)
                }
            }

            var careers: [Career] = []
            for try await career in group {
                if let career = career {
                    careers.append(career)
                }
            }
            return careers
        }
    }

    /// Resolve resource IDs to Resource objects
    private func resolveResources(ids: [String]) async throws -> [Resource] {
        try await withThrowingTaskGroup(of: Resource?.self) { group in
            for id in ids {
                group.addTask {
                    try? await self.resourceLibraryService.fetchResource(id: id)
                }
            }

            var resources: [Resource] = []
            for try await resource in group {
                if let resource = resource {
                    resources.append(resource)
                }
            }
            return resources
        }
    }
}
