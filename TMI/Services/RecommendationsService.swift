//
//  RecommendationsService.swift
//  TMI
//
//  Service for managing recommendations.
//  Handles generation, fetching, and updating of recommendations.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Recommendations Service

final class RecommendationsService {
    static let shared = RecommendationsService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Collection Access
    
    private var recommendationsCollection: CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else {
            return nil
        }
        return db.collection("users").document(uid).collection("recommendations")
    }
    
    // MARK: - Fetch Operations
    
    /// Fetch recommendations for a specific student
    func fetchRecommendations(forStudentId studentId: String) async throws -> [Recommendation] {
        guard let collection = recommendationsCollection else {
            throw RecommendationsServiceError.userNotAuthenticated
        }
        
        let query = collection.whereField("studentId", isEqualTo: studentId)
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { parseRecommendation(from: $0) }
    }
    
    /// Fetch recommendations for a specific plan
    func fetchRecommendations(forPlanId planId: String) async throws -> [Recommendation] {
        guard let collection = recommendationsCollection else {
            throw RecommendationsServiceError.userNotAuthenticated
        }
        
        let query = collection.whereField("planId", isEqualTo: planId)
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { parseRecommendation(from: $0) }
    }
    
    // MARK: - Generation
    
    /// Generate new recommendations for a student
    func generateRecommendations(studentId: String, planId: String?) async throws -> [Recommendation] {
        // In production, this would call an AI/ML service or rule engine
        // For now, return empty - the logic would be domain-specific
        
        print("[RecommendationsService] Generating recommendations for student: \(studentId)")
        
        // Example: Get student interests and generate resource recommendations
        let interests = try await StudentInterestService.shared.getStudentInterests(studentId: studentId)
        
        var recommendations: [Recommendation] = []
        
        // Generate resource recommendations based on interests
        for interest in interests.prefix(3) {
            let recommendation = Recommendation(
                id: UUID().uuidString,
                type: .resource,
                title: "Explore \(interest.interestId)",
                description: "Based on your interest in this topic, here are some resources.",
                rationale: "This recommendation is based on your expressed interests.",
                status: .pending,
                priority: .medium,
                createdAt: Date(),
                updatedAt: Date(),
                studentId: studentId,
                planId: planId,
                linkedInterestIds: [interest.interestId],
                linkedCareerIds: [],
                linkedResourceIds: [],
                linkedGoalIds: [],
                actionType: .viewContent,
                actionPayload: ["interestId": interest.interestId],
                feedback: nil
            )
            recommendations.append(recommendation)
        }
        
        // Save recommendations
        for recommendation in recommendations {
            try await saveRecommendation(recommendation)
        }
        
        return recommendations
    }
    
    // MARK: - CRUD Operations
    
    /// Save a recommendation
    func saveRecommendation(_ recommendation: Recommendation) async throws {
        guard let collection = recommendationsCollection else {
            throw RecommendationsServiceError.userNotAuthenticated
        }
        
        let data = recommendation.toFirestoreData()
        try await collection.document(recommendation.id).setData(data)
    }
    
    /// Update a recommendation
    func updateRecommendation(_ recommendation: Recommendation) async throws {
        guard let collection = recommendationsCollection else {
            throw RecommendationsServiceError.userNotAuthenticated
        }
        
        let data = recommendation.toFirestoreData()
        try await collection.document(recommendation.id).updateData(data)
    }
    
    /// Delete a recommendation
    func deleteRecommendation(id: String) async throws {
        guard let collection = recommendationsCollection else {
            throw RecommendationsServiceError.userNotAuthenticated
        }
        
        try await collection.document(id).delete()
    }
    
    /// Get personalized dashboard for a student
    func getPersonalizedDashboard(for student: Student) async throws -> PersonalizedDashboard {
        // In production, this would aggregate student data and generate personalized content
        // For now, return stub dashboard
        return PersonalizedDashboard(
            studentId: student.id ?? "",
            trendingCareers: [],
            trendingInterests: [],
            recommendedResources: [],
            upcomingMilestones: [],
            recentAchievements: []
        )
    }
    
    /// Get TMI plan suggestions for a student
    func getTMIPlanSuggestions(for student: Student) async throws -> [TMIPlanSuggestion] {
        // In production, this would analyze student data and generate plan suggestions
        // For now, return empty array
        return []
    }
    
    // MARK: - Private Helpers
    
    private func parseRecommendation(from document: DocumentSnapshot) -> Recommendation? {
        guard let data = document.data() else { return nil }
        
        guard let typeRaw = data["type"] as? String,
              let type = RecommendationType(rawValue: typeRaw),
              let title = data["title"] as? String,
              let description = data["description"] as? String,
              let rationale = data["rationale"] as? String,
              let statusRaw = data["status"] as? String,
              let status = RecommendationStatus(rawValue: statusRaw),
              let priorityRaw = data["priority"] as? String,
              let priority = RecommendationPriority(rawValue: priorityRaw),
              let createdAtTimestamp = data["createdAt"] as? Double,
              let updatedAtTimestamp = data["updatedAt"] as? Double,
              let studentId = data["studentId"] as? String,
              let actionTypeRaw = data["actionType"] as? String,
              let actionType = RecommendationActionType(rawValue: actionTypeRaw) else {
            return nil
        }
        
        let feedback: RecommendationFeedback?
        if let feedbackData = data["feedback"] as? [String: Any],
           let rating = feedbackData["rating"] as? Int,
           let helpful = feedbackData["helpful"] as? Bool,
           let feedbackCreatedAt = feedbackData["createdAt"] as? Double {
            feedback = RecommendationFeedback(
                rating: rating,
                helpful: helpful,
                comment: feedbackData["comment"] as? String,
                createdAt: Date(timeIntervalSince1970: feedbackCreatedAt)
            )
        } else {
            feedback = nil
        }
        
        return Recommendation(
            id: document.documentID,
            type: type,
            title: title,
            description: description,
            rationale: rationale,
            status: status,
            priority: priority,
            createdAt: Date(timeIntervalSince1970: createdAtTimestamp),
            updatedAt: Date(timeIntervalSince1970: updatedAtTimestamp),
            studentId: studentId,
            planId: data["planId"] as? String,
            linkedInterestIds: data["linkedInterestIds"] as? [String] ?? [],
            linkedCareerIds: data["linkedCareerIds"] as? [String] ?? [],
            linkedResourceIds: data["linkedResourceIds"] as? [String] ?? [],
            linkedGoalIds: data["linkedGoalIds"] as? [String] ?? [],
            actionType: actionType,
            actionPayload: data["actionPayload"] as? [String: String],
            feedback: feedback
        )
    }
}

// MARK: - Recommendation Firestore Extension

extension Recommendation {
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "type": type.rawValue,
            "title": title,
            "description": description,
            "rationale": rationale,
            "status": status.rawValue,
            "priority": priority.rawValue,
            "createdAt": createdAt.timeIntervalSince1970,
            "updatedAt": updatedAt.timeIntervalSince1970,
            "studentId": studentId,
            "linkedInterestIds": linkedInterestIds,
            "linkedCareerIds": linkedCareerIds,
            "linkedResourceIds": linkedResourceIds,
            "linkedGoalIds": linkedGoalIds,
            "actionType": actionType.rawValue
        ]
        
        if let planId = planId {
            data["planId"] = planId
        }
        
        if let actionPayload = actionPayload {
            data["actionPayload"] = actionPayload
        }
        
        if let feedback = feedback {
            data["feedback"] = [
                "rating": feedback.rating,
                "helpful": feedback.helpful,
                "comment": feedback.comment as Any,
                "createdAt": feedback.createdAt.timeIntervalSince1970
            ]
        }
        
        return data
    }
}

// MARK: - Personalized Dashboard

struct PersonalizedDashboard: Codable, Sendable {
    let studentId: String
    let trendingCareers: [Career]
    let trendingInterests: [Interest]
    let recommendedResources: [Resource]
    let upcomingMilestones: [Milestone]
    let recentAchievements: [Achievement]
    
    struct Milestone: Codable, Identifiable, Sendable {
        let id: String
        let title: String
        let description: String
        let targetDate: Date
        let progress: Double
    }
    
    struct Achievement: Codable, Identifiable, Sendable {
        let id: String
        let title: String
        let description: String
        let achievedAt: Date
        let icon: String
    }
}

// MARK: - TMI Plan Suggestion

struct TMIPlanSuggestion: Codable, Identifiable, Sendable {
    let id: String
    let type: TMIPlanModel
    let title: String
    let description: String
    let rationale: String
    let priority: Priority
    let suggestedInterests: [String]
    let suggestedGoals: [String]
    
    enum Priority: String, Codable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }
}

// MARK: - Errors

enum RecommendationsServiceError: LocalizedError {
    case userNotAuthenticated
    case fetchFailed(String)
    case saveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .fetchFailed(let message):
            return "Failed to fetch recommendations: \(message)"
        case .saveFailed(let message):
            return "Failed to save recommendation: \(message)"
        }
    }
}
