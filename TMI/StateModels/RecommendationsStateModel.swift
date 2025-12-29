//
//  RecommendationsStateModel.swift
//  TMI
//
//  Authoritative state model for recommendations.
//  Manages recommendation generation, status tracking, and feedback loop.
//

import Foundation
import Observation
import SwiftUI

// MARK: - Recommendation

/// A recommendation for a student/plan
struct Recommendation: Identifiable, Codable, Hashable {
    var id: String
    let type: RecommendationType
    let title: String
    let description: String
    let rationale: String
    var status: RecommendationStatus
    let priority: RecommendationPriority
    let createdAt: Date
    var updatedAt: Date
    
    // Context
    let studentId: String
    let planId: String?
    
    // Linked entities
    let linkedInterestIds: [String]
    let linkedCareerIds: [String]
    let linkedResourceIds: [String]
    let linkedGoalIds: [String]
    
    // Action data
    let actionType: RecommendationActionType
    let actionPayload: [String: String]?
    
    // Feedback
    var feedback: RecommendationFeedback?
}

enum RecommendationType: String, Codable, CaseIterable {
    case resource = "resource"
    case goal = "goal"
    case career = "career"
    case interest = "interest"
    case meeting = "meeting"
    case activity = "activity"
}

enum RecommendationStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case viewed = "viewed"
    case accepted = "accepted"
    case rejected = "rejected"
    case applied = "applied"
    case completed = "completed"
    case expired = "expired"
}

enum RecommendationPriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
}

enum RecommendationActionType: String, Codable {
    case assignResource = "assign_resource"
    case createGoal = "create_goal"
    case scheduleMeeting = "schedule_meeting"
    case exploreCareer = "explore_career"
    case addInterest = "add_interest"
    case viewContent = "view_content"
}

struct RecommendationFeedback: Codable, Hashable {
    let rating: Int // 1-5
    let helpful: Bool
    let comment: String?
    let createdAt: Date
}

// MARK: - Recommendations State Model

@Observable
final class RecommendationsStateModel: BaseStateModel<[Recommendation], IdentifiableError> {
    
    // MARK: - Dependencies
    
    private let recommendationsService: RecommendationsService
    
    // MARK: - State
    
    /// All recommendations for current context
    private(set) var recommendations: [Recommendation] = []
    
    /// Pending recommendations (not yet acted upon)
    private(set) var pendingRecommendations: [Recommendation] = []
    
    /// Active recommendations (accepted, being applied)
    private(set) var activeRecommendations: [Recommendation] = []
    
    /// Completed recommendations
    private(set) var completedRecommendations: [Recommendation] = []
    
    /// Currently selected recommendation
    private(set) var selectedRecommendation: Recommendation?
    
    /// Whether recommendations are being generated
    private(set) var isGenerating: Bool = false
    
    /// Last generation time
    private(set) var lastGeneratedAt: Date?
    
    // MARK: - Context
    
    /// Current student context for recommendations
    private(set) var contextStudentId: String?
    
    /// Current plan context for recommendations
    private(set) var contextPlanId: String?
    
    // MARK: - Computed Properties
    
    /// High priority recommendations
    var highPriorityRecommendations: [Recommendation] {
        pendingRecommendations.filter { $0.priority == .high || $0.priority == .urgent }
    }
    
    /// Recommendations by type
    func recommendations(ofType type: RecommendationType) -> [Recommendation] {
        recommendations.filter { $0.type == type }
    }
    
    /// Acceptance rate (for feedback loop)
    var acceptanceRate: Double {
        let decided = recommendations.filter { $0.status == .accepted || $0.status == .rejected }
        guard !decided.isEmpty else { return 0 }
        let accepted = decided.filter { $0.status == .accepted || $0.status == .applied || $0.status == .completed }
        return Double(accepted.count) / Double(decided.count)
    }
    
    // MARK: - Initialization
    
    init(recommendationsService: RecommendationsService = .shared) {
        self.recommendationsService = recommendationsService
        super.init()
    }
    
    // MARK: - Context Management
    
    /// Set the context for recommendations
    @MainActor
    func setContext(studentId: String?, planId: String?) async {
        contextStudentId = studentId
        contextPlanId = planId
        
        await fetch()
    }
    
    // MARK: - Fetch Operations
    
    @MainActor
    override func fetch() async {
        guard contextStudentId != nil || contextPlanId != nil else {
            print("[RecommendationsStateModel] No context set, skipping fetch")
            return
        }
        
        updateState(.loading)
        
        do {
            let fetched: [Recommendation]
            
            if let planId = contextPlanId {
                fetched = try await recommendationsService.fetchRecommendations(forPlanId: planId)
            } else if let studentId = contextStudentId {
                fetched = try await recommendationsService.fetchRecommendations(forStudentId: studentId)
            } else {
                fetched = []
            }
            
            recommendations = fetched
            updateDerivedCollections()
            updateState(.loaded(recommendations))
            
            print("[RecommendationsStateModel] Fetched \(recommendations.count) recommendations")
        } catch {
            let identifiableError = IdentifiableError(message: error.localizedDescription)
            updateState(.error(identifiableError))
            print("[RecommendationsStateModel] Error fetching recommendations: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Generation
    
    /// Generate new recommendations for the current context
    @MainActor
    func generateRecommendations() async throws {
        guard let studentId = contextStudentId else {
            throw RecommendationsError.noStudentContext
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        print("[RecommendationsStateModel] Generating recommendations for student: \(studentId)")
        
        do {
            let newRecommendations = try await recommendationsService.generateRecommendations(
                studentId: studentId,
                planId: contextPlanId
            )
            
            // Merge with existing (don't duplicate)
            let existingIds = Set(recommendations.map { $0.id })
            let uniqueNew = newRecommendations.filter { !existingIds.contains($0.id) }
            
            recommendations.append(contentsOf: uniqueNew)
            updateDerivedCollections()
            updateState(.loaded(recommendations))
            
            lastGeneratedAt = Date()
            
            print("[RecommendationsStateModel] Generated \(uniqueNew.count) new recommendations")
        } catch {
            print("[RecommendationsStateModel] Error generating recommendations: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Status Management
    
    /// Accept a recommendation
    @MainActor
    func acceptRecommendation(_ recommendation: Recommendation) async throws {
        var updated = recommendation
        updated.status = .accepted
        updated.updatedAt = Date()
        
        try await updateRecommendation(updated)
        print("[RecommendationsStateModel] Accepted recommendation: \(recommendation.id)")
    }
    
    /// Reject a recommendation
    @MainActor
    func rejectRecommendation(_ recommendation: Recommendation) async throws {
        var updated = recommendation
        updated.status = .rejected
        updated.updatedAt = Date()
        
        try await updateRecommendation(updated)
        print("[RecommendationsStateModel] Rejected recommendation: \(recommendation.id)")
    }
    
    /// Mark a recommendation as applied
    @MainActor
    func markAsApplied(_ recommendation: Recommendation) async throws {
        var updated = recommendation
        updated.status = .applied
        updated.updatedAt = Date()
        
        try await updateRecommendation(updated)
        print("[RecommendationsStateModel] Marked recommendation as applied: \(recommendation.id)")
    }
    
    /// Mark a recommendation as completed
    @MainActor
    func markAsCompleted(_ recommendation: Recommendation) async throws {
        var updated = recommendation
        updated.status = .completed
        updated.updatedAt = Date()
        
        try await updateRecommendation(updated)
        print("[RecommendationsStateModel] Marked recommendation as completed: \(recommendation.id)")
    }
    
    /// Add feedback to a recommendation
    @MainActor
    func addFeedback(_ recommendation: Recommendation, rating: Int, helpful: Bool, comment: String?) async throws {
        var updated = recommendation
        updated.feedback = RecommendationFeedback(
            rating: rating,
            helpful: helpful,
            comment: comment,
            createdAt: Date()
        )
        updated.updatedAt = Date()
        
        try await updateRecommendation(updated)
        print("[RecommendationsStateModel] Added feedback to recommendation: \(recommendation.id)")
    }
    
    // MARK: - Actions
    
    /// Apply a recommendation (execute its action)
    @MainActor
    func applyRecommendation(_ recommendation: Recommendation) async throws {
        // Execute the action based on type
        switch recommendation.actionType {
        case .assignResource:
            if let resourceId = recommendation.actionPayload?["resourceId"],
               let studentId = contextStudentId {
                // Fetch resource details first
                if let resource = try? await ResourceLibraryService.shared.fetchResource(id: resourceId) {
                    try await ResourceAssignmentService.shared.assignResource(
                        resourceId: resourceId,
                        studentId: studentId,
                        planId: contextPlanId,
                        resourceTitle: resource.title,
                        resourceCategory: resource.category.rawValue,
                        resourceURL: resource.url
                    )
                }
            }
            
        case .createGoal:
            if let description = recommendation.actionPayload?["description"],
               let planId = contextPlanId {
                // Would create goal via GoalsRepository
                print("[RecommendationsStateModel] Would create goal: \(description) for plan: \(planId)")
            }
            
        case .scheduleMeeting:
            // Would open scheduling flow
            print("[RecommendationsStateModel] Would open meeting scheduler")
            
        case .exploreCareer:
            if let careerId = recommendation.actionPayload?["careerId"] {
                print("[RecommendationsStateModel] Would navigate to career: \(careerId)")
            }
            
        case .addInterest:
            if let interestId = recommendation.actionPayload?["interestId"],
               let studentId = contextStudentId {
                try await StudentInterestService.shared.addInterest(
                    studentId: studentId,
                    interestId: interestId,
                    level: 3,
                    source: .staff
                )
            }
            
        case .viewContent:
            // Would navigate to content
            print("[RecommendationsStateModel] Would navigate to content")
        }
        
        try await markAsApplied(recommendation)
    }
    
    // MARK: - Selection
    
    @MainActor
    func selectRecommendation(_ recommendation: Recommendation?) {
        selectedRecommendation = recommendation
        
        // Mark as viewed if pending
        if let rec = recommendation, rec.status == .pending {
            Task {
                var updated = rec
                updated.status = .viewed
                updated.updatedAt = Date()
                try? await updateRecommendation(updated)
            }
        }
    }
    
    // MARK: - Private Helpers
    
    @MainActor
    private func updateRecommendation(_ recommendation: Recommendation) async throws {
        try await recommendationsService.updateRecommendation(recommendation)
        
        // Update local state
        if let index = recommendations.firstIndex(where: { $0.id == recommendation.id }) {
            recommendations[index] = recommendation
        }
        
        updateDerivedCollections()
        updateState(.loaded(recommendations))
    }
    
    private func updateDerivedCollections() {
        pendingRecommendations = recommendations
            .filter { $0.status == .pending || $0.status == .viewed }
            .sorted { $0.priority.sortOrder < $1.priority.sortOrder }
        
        activeRecommendations = recommendations
            .filter { $0.status == .accepted || $0.status == .applied }
            .sorted { $0.updatedAt > $1.updatedAt }
        
        completedRecommendations = recommendations
            .filter { $0.status == .completed }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
}

// MARK: - Priority Sort Order

extension RecommendationPriority {
    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

// MARK: - Errors

enum RecommendationsError: LocalizedError {
    case noStudentContext
    case generationFailed(String)
    case updateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noStudentContext:
            return "No student context set for recommendations"
        case .generationFailed(let message):
            return "Failed to generate recommendations: \(message)"
        case .updateFailed(let message):
            return "Failed to update recommendation: \(message)"
        }
    }
}

// MARK: - Environment Key

private struct RecommendationsStateModelKey: EnvironmentKey {
    static let defaultValue = RecommendationsStateModel()
}

extension EnvironmentValues {
    var recommendationsStateModel: RecommendationsStateModel {
        get { self[RecommendationsStateModelKey.self] }
        set { self[RecommendationsStateModelKey.self] = newValue }
    }
}

