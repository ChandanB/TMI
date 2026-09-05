//
//  RecommendationsService.swift
//  TMI
//
//  Service for managing recommendations.
//  Handles generation, fetching, and updating of recommendations.
//

import Foundation
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseAuth

// MARK: - Recommendations Service

nonisolated final class RecommendationsService: Sendable {
    static let shared = RecommendationsService()

    private let store: RecommendationStore
    private let authorizationSessions: any AuthorizationSessionProviding
    private let currentUserID: @Sendable () -> String?

    init(
        store: RecommendationStore = FirebaseRecommendationStore(),
        authorizationSessions: any AuthorizationSessionProviding = TrustedAuthorizationSessionStore.shared,
        currentUserID: @escaping @Sendable () -> String? = { Auth.auth().currentUser?.uid }
    ) {
        self.store = store
        self.authorizationSessions = authorizationSessions
        self.currentUserID = currentUserID
    }

    // MARK: - Fetch Operations

    /// Fetch recommendations for a specific student
    func fetchRecommendations(forStudentId studentId: String) async throws -> [Recommendation] {
        let session = try authorizedSession()

        let documents = try await store.documents(
            atCollectionPath: FirestorePaths.recommendations(districtID: session.membership.districtID),
            whereField: "studentId",
            equals: studentId
        )

        return documents.compactMap(parseRecommendation)
    }

    /// Fetch recommendations for a specific plan
    func fetchRecommendations(forPlanId planId: String) async throws -> [Recommendation] {
        let session = try authorizedSession()

        let documents = try await store.documents(
            atCollectionPath: FirestorePaths.recommendations(districtID: session.membership.districtID),
            whereField: "planId",
            equals: planId
        )

        return documents.compactMap(parseRecommendation)
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
        let session = try authorizedSession()

        try await store.setDocument(
            atCollectionPath: FirestorePaths.recommendations(districtID: session.membership.districtID),
            id: recommendation.id,
            data: recommendation.toFirestoreData(),
            merge: false
        )
    }

    /// Update a recommendation
    func updateRecommendation(_ recommendation: Recommendation) async throws {
        let session = try authorizedSession()

        try await store.updateDocument(
            atCollectionPath: FirestorePaths.recommendations(districtID: session.membership.districtID),
            id: recommendation.id,
            data: recommendation.toFirestoreData()
        )
    }

    /// Delete a recommendation
    func deleteRecommendation(id: String) async throws {
        let session = try authorizedSession()

        try await store.deleteDocument(
            atCollectionPath: FirestorePaths.recommendations(districtID: session.membership.districtID),
            id: id
        )
    }


    /// Get TMI plan suggestions for a student
    ///
    /// Not currently called anywhere in the app (verified by repo-wide grep).
    /// Left unrouted to the district-scoped store since it doesn't persist or
    /// read anything today; it's a stub returning an empty array either way.
    func getTMIPlanSuggestions(for student: Student) async throws -> [TMIPlanSuggestion] {
        // In production, this would analyze student data and generate plan suggestions
        // For now, return empty array
        return []
    }

    // MARK: - Authorization Helpers

    private func authorizedSession() throws -> AuthenticatedSession {
        guard let session = authorizationSessions.session(
            authenticatedUserID: currentUserID()
        ) else {
            throw RecommendationsServiceError.userNotAuthenticated
        }
        return session
    }

    // MARK: - Private Helpers

    private func parseRecommendation(from document: (id: String, data: [String: Any])) -> Recommendation? {
        let data = document.data

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
            id: document.id,
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
    nonisolated func toFirestoreData() -> [String: Any] {
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

enum RecommendationsServiceError: Error, LocalizedError, Equatable {
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
