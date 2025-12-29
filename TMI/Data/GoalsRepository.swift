//
//  GoalsRepository.swift
//  TMI
//
//  Single-writer repository for goal mutations.
//  Ensures all goal changes go through a consistent path.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Goals Repository

/// Single-writer repository for goal mutations within TMI plans.
/// All goal changes should go through this repository to ensure consistency.
actor GoalsRepository {
    static let shared = GoalsRepository()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - CRUD Operations
    
    /// Add a goal to a plan
    /// - Parameters:
    ///   - goal: The goal to add
    ///   - planId: The plan ID to add the goal to
    /// - Returns: The added goal
    func addGoal(_ goal: Goal, toPlanId planId: String) async throws -> Goal {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw GoalsRepositoryError.userNotAuthenticated
        }
        
        let planRef = db.collection("users").document(uid).collection("tmiPlans").document(planId)
        
        // Get current plan
        let document = try await planRef.getDocument()
        guard document.exists, let data = document.data() else {
            throw GoalsRepositoryError.planNotFound
        }
        
        // Get existing goals
        var goalsData = data["goals"] as? [[String: Any]] ?? []
        
        // Add new goal
        goalsData.append(goal.toFirestoreData())
        
        // Update plan
        try await planRef.updateData([
            "goals": goalsData,
            "lastUpdated": Date().timeIntervalSince1970
        ])
        
        print("[GoalsRepository] Added goal to plan: \(planId)")
        return goal
    }
    
    /// Update a goal in a plan
    /// - Parameters:
    ///   - goal: The updated goal
    ///   - planId: The plan ID containing the goal
    /// - Returns: The updated goal
    func updateGoal(_ goal: Goal, inPlanId planId: String) async throws -> Goal {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw GoalsRepositoryError.userNotAuthenticated
        }
        
        let planRef = db.collection("users").document(uid).collection("tmiPlans").document(planId)
        
        // Get current plan
        let document = try await planRef.getDocument()
        guard document.exists, let data = document.data() else {
            throw GoalsRepositoryError.planNotFound
        }
        
        // Get existing goals
        var goalsData = data["goals"] as? [[String: Any]] ?? []
        
        // Find and update the goal
        if let index = goalsData.firstIndex(where: { ($0["id"] as? String) == goal.id.uuidString }) {
            goalsData[index] = goal.toFirestoreData()
        } else {
            throw GoalsRepositoryError.goalNotFound
        }
        
        // Update plan
        try await planRef.updateData([
            "goals": goalsData,
            "lastUpdated": Date().timeIntervalSince1970
        ])
        
        print("[GoalsRepository] Updated goal in plan: \(planId)")
        return goal
    }
    
    /// Delete a goal from a plan
    /// - Parameters:
    ///   - goalId: The goal ID to delete
    ///   - planId: The plan ID containing the goal
    func deleteGoal(goalId: UUID, fromPlanId planId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw GoalsRepositoryError.userNotAuthenticated
        }
        
        let planRef = db.collection("users").document(uid).collection("tmiPlans").document(planId)
        
        // Get current plan
        let document = try await planRef.getDocument()
        guard document.exists, let data = document.data() else {
            throw GoalsRepositoryError.planNotFound
        }
        
        // Get existing goals
        var goalsData = data["goals"] as? [[String: Any]] ?? []
        
        // Remove the goal
        goalsData.removeAll { ($0["id"] as? String) == goalId.uuidString }
        
        // Update plan
        try await planRef.updateData([
            "goals": goalsData,
            "lastUpdated": Date().timeIntervalSince1970
        ])
        
        print("[GoalsRepository] Deleted goal from plan: \(planId)")
    }
    
    /// Get all goals for a plan
    /// - Parameter planId: The plan ID
    /// - Returns: Array of goals
    func getGoals(forPlanId planId: String) async throws -> [Goal] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw GoalsRepositoryError.userNotAuthenticated
        }
        
        let planRef = db.collection("users").document(uid).collection("tmiPlans").document(planId)
        
        let document = try await planRef.getDocument()
        guard document.exists, let data = document.data() else {
            throw GoalsRepositoryError.planNotFound
        }
        
        let goalsData = data["goals"] as? [[String: Any]] ?? []
        
        return goalsData.compactMap { Goal.fromFirestoreData($0) }
    }
    
    // MARK: - Progress Management
    
    /// Update goal progress
    /// - Parameters:
    ///   - goalId: The goal ID
    ///   - progress: New progress value (0.0 - 1.0)
    ///   - planId: The plan ID containing the goal
    func updateProgress(goalId: UUID, progress: Double, inPlanId planId: String) async throws {
        let goals = try await getGoals(forPlanId: planId)
        
        guard let index = goals.firstIndex(where: { $0.id == goalId }) else {
            throw GoalsRepositoryError.goalNotFound
        }
        
        var updatedGoal = goals[index]
        updatedGoal.progress = max(0, min(1, progress))
        
        // Auto-update status based on progress
        if updatedGoal.progress >= 1.0 {
            updatedGoal.status = .completed
        } else if updatedGoal.progress > 0 {
            updatedGoal.status = .inProgress
        }
        
        _ = try await updateGoal(updatedGoal, inPlanId: planId)
    }
    
    /// Update goal status
    /// - Parameters:
    ///   - goalId: The goal ID
    ///   - status: New status
    ///   - planId: The plan ID containing the goal
    func updateStatus(goalId: UUID, status: GoalStatus, inPlanId planId: String) async throws {
        let goals = try await getGoals(forPlanId: planId)
        
        guard let index = goals.firstIndex(where: { $0.id == goalId }) else {
            throw GoalsRepositoryError.goalNotFound
        }
        
        var updatedGoal = goals[index]
        updatedGoal.status = status
        
        // Auto-update progress based on status
        if status == .completed {
            updatedGoal.progress = 1.0
        }
        
        _ = try await updateGoal(updatedGoal, inPlanId: planId)
    }
    
    // MARK: - Batch Operations
    
    /// Replace all goals in a plan
    /// - Parameters:
    ///   - goals: New goals array
    ///   - planId: The plan ID
    func replaceGoals(_ goals: [Goal], inPlanId planId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw GoalsRepositoryError.userNotAuthenticated
        }
        
        let planRef = db.collection("users").document(uid).collection("tmiPlans").document(planId)
        
        let goalsData = goals.map { $0.toFirestoreData() }
        
        try await planRef.updateData([
            "goals": goalsData,
            "lastUpdated": Date().timeIntervalSince1970
        ])
        
        print("[GoalsRepository] Replaced \(goals.count) goals in plan: \(planId)")
    }
    
    /// Reorder goals in a plan
    /// - Parameters:
    ///   - goalIds: Ordered array of goal IDs
    ///   - planId: The plan ID
    func reorderGoals(_ goalIds: [UUID], inPlanId planId: String) async throws {
        let goals = try await getGoals(forPlanId: planId)
        
        // Reorder based on provided IDs
        var reorderedGoals: [Goal] = []
        for id in goalIds {
            if let goal = goals.first(where: { $0.id == id }) {
                reorderedGoals.append(goal)
            }
        }
        
        // Add any goals not in the provided list at the end
        for goal in goals where !goalIds.contains(goal.id) {
            reorderedGoals.append(goal)
        }
        
        try await replaceGoals(reorderedGoals, inPlanId: planId)
    }
}

// MARK: - Goal Extensions

extension Goal {
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "description": description,
            "status": status.rawValue,
            "progress": progress
        ]
        
        if let dueDate = dueDate {
            data["dueDate"] = dueDate.timeIntervalSince1970
        }
        
        if let notes = notes {
            data["notes"] = notes
        }
        
        return data
    }
    
    static func fromFirestoreData(_ data: [String: Any]) -> Goal? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let description = data["description"] as? String,
              let statusString = data["status"] as? String,
              let status = GoalStatus(rawValue: statusString),
              let progress = data["progress"] as? Double else {
            return nil
        }
        
        let dueDate: Date?
        if let dueDateTimestamp = data["dueDate"] as? Double {
            dueDate = Date(timeIntervalSince1970: dueDateTimestamp)
        } else {
            dueDate = nil
        }
        
        let notes = data["notes"] as? String
        
        return Goal(
            id: id,
            description: description,
            dueDate: dueDate,
            status: status,
            progress: progress,
            notes: notes
        )
    }
}

// MARK: - Errors

enum GoalsRepositoryError: LocalizedError {
    case userNotAuthenticated
    case planNotFound
    case goalNotFound
    case updateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .planNotFound:
            return "Plan not found"
        case .goalNotFound:
            return "Goal not found"
        case .updateFailed(let message):
            return "Failed to update goal: \(message)"
        }
    }
}

