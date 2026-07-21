//
//  PlanRepository.swift
//  TMI
//
//  Unified repository for plan operations.
//  Single owner of all plan subcollections (goals, meetings, resources, recommendations).
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Plan Repository

/// Unified repository for TMI Plan operations.
/// Owns all plan-related mutations and subcollection management.
actor PlanRepository {
    static let shared = PlanRepository()
    
    private let db = Firestore.firestore()
    private let goalsRepository = GoalsRepository.shared
    
    private init() {}
    
    // MARK: - Collection Access
    
    private var userPlansCollection: CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else {
            return nil
        }
        return db.collection("users").document(uid).collection("tmiPlans")
    }
    
    // MARK: - Plan CRUD
    
    /// Fetch all plans for the current user
    func fetchAllPlans() async throws -> [TMIPlan] {
        guard let collection = userPlansCollection else {
            throw PlanRepositoryError.userNotAuthenticated
        }
        
        let snapshot = try await collection.getDocuments()
        return snapshot.documents.compactMap { parsePlan(from: $0) }
    }
    
    /// Fetch a single plan by ID
    func fetchPlan(id: String) async throws -> TMIPlan? {
        guard let collection = userPlansCollection else {
            throw PlanRepositoryError.userNotAuthenticated
        }
        
        let document = try await collection.document(id).getDocument()
        guard document.exists else { return nil }
        
        return parsePlan(from: document)
    }
    
    /// Fetch plans for a specific student
    func fetchPlans(forStudentId studentId: String) async throws -> [TMIPlan] {
        let allPlans = try await fetchAllPlans()
        return allPlans.filter { plan in
            plan.students.contains(where: { $0.id == studentId })
        }
    }
    
    /// Create a new plan
    func createPlan(_ plan: TMIPlan) async throws -> TMIPlan {
        guard let collection = userPlansCollection else {
            throw PlanRepositoryError.userNotAuthenticated
        }
        
        let data = plan.toFirestoreData()
        let docRef = try await collection.addDocument(data: data)
        
        var createdPlan = plan
        createdPlan.id = docRef.documentID
        
        print("[PlanRepository] Created plan: \(docRef.documentID)")
        return createdPlan
    }
    
    /// Update an existing plan
    func updatePlan(_ plan: TMIPlan) async throws -> TMIPlan {
        guard let collection = userPlansCollection else {
            throw PlanRepositoryError.userNotAuthenticated
        }
        
        guard let planId = plan.id else {
            throw PlanRepositoryError.invalidPlanId
        }
        
        var updatedPlan = plan
        updatedPlan.lastUpdated = Date()
        
        let data = updatedPlan.toFirestoreData()
        try await collection.document(planId).updateData(data)
        
        print("[PlanRepository] Updated plan: \(planId)")
        return updatedPlan
    }
    
    /// Delete a plan
    func deletePlan(id: String) async throws {
        guard let collection = userPlansCollection else {
            throw PlanRepositoryError.userNotAuthenticated
        }
        
        try await collection.document(id).delete()
        print("[PlanRepository] Deleted plan: \(id)")
    }
    
    // MARK: - Goals Management (delegated to GoalsRepository)
    
    /// Add a goal to a plan
    func addGoal(_ goal: Goal, toPlanId planId: String) async throws -> Goal {
        return try await goalsRepository.addGoal(goal, toPlanId: planId)
    }
    
    /// Update a goal in a plan
    func updateGoal(_ goal: Goal, inPlanId planId: String) async throws -> Goal {
        return try await goalsRepository.updateGoal(goal, inPlanId: planId)
    }
    
    /// Delete a goal from a plan
    func deleteGoal(goalId: UUID, fromPlanId planId: String) async throws {
        try await goalsRepository.deleteGoal(goalId: goalId, fromPlanId: planId)
    }
    
    /// Get all goals for a plan
    func getGoals(forPlanId planId: String) async throws -> [Goal] {
        return try await goalsRepository.getGoals(forPlanId: planId)
    }
    
    // MARK: - Resources Management
    
    /// Link a resource to a plan
    func linkResource(resourceId: String, toPlanId planId: String) async throws {
        guard let collection = userPlansCollection else {
            throw PlanRepositoryError.userNotAuthenticated
        }
        
        let planRef = collection.document(planId)
        let document = try await planRef.getDocument()
        
        guard document.exists, let data = document.data() else {
            throw PlanRepositoryError.planNotFound
        }
        
        var resourceIds = data["linkedResourceIds"] as? [String] ?? []
        if !resourceIds.contains(resourceId) {
            resourceIds.append(resourceId)
        }
        
        try await planRef.updateData([
            "linkedResourceIds": resourceIds,
            "lastUpdated": Date().timeIntervalSince1970
        ])
        
        print("[PlanRepository] Linked resource \(resourceId) to plan \(planId)")
    }
    
    /// Unlink a resource from a plan
    func unlinkResource(resourceId: String, fromPlanId planId: String) async throws {
        guard let collection = userPlansCollection else {
            throw PlanRepositoryError.userNotAuthenticated
        }
        
        let planRef = collection.document(planId)
        let document = try await planRef.getDocument()
        
        guard document.exists, let data = document.data() else {
            throw PlanRepositoryError.planNotFound
        }
        
        var resourceIds = data["linkedResourceIds"] as? [String] ?? []
        resourceIds.removeAll { $0 == resourceId }
        
        try await planRef.updateData([
            "linkedResourceIds": resourceIds,
            "lastUpdated": Date().timeIntervalSince1970
        ])
        
        print("[PlanRepository] Unlinked resource \(resourceId) from plan \(planId)")
    }
    
    /// Get linked resource IDs for a plan
    func getLinkedResourceIds(forPlanId planId: String) async throws -> [String] {
        guard let collection = userPlansCollection else {
            throw PlanRepositoryError.userNotAuthenticated
        }
        
        let document = try await collection.document(planId).getDocument()
        guard document.exists, let data = document.data() else {
            throw PlanRepositoryError.planNotFound
        }
        
        return data["linkedResourceIds"] as? [String] ?? []
    }
    
    // MARK: - Status Management
    
    /// Update plan status
    func updateStatus(_ status: PlanStatus, forPlanId planId: String) async throws {
        guard let collection = userPlansCollection else {
            throw PlanRepositoryError.userNotAuthenticated
        }
        
        try await collection.document(planId).updateData([
            "status": status.rawValue,
            "lastUpdated": Date().timeIntervalSince1970
        ])
        
        print("[PlanRepository] Updated status to \(status.rawValue) for plan \(planId)")
    }
    
    /// Submit plan for approval
    func submitForApproval(planId: String) async throws {
        try await updateStatus(.pendingApproval, forPlanId: planId)
    }
    
    // MARK: - Progress Calculation
    
    /// Calculate and update plan progress based on goals
    func recalculateProgress(forPlanId planId: String) async throws -> Double {
        let goals = try await getGoals(forPlanId: planId)
        
        guard !goals.isEmpty else { return 0 }
        
        let totalProgress = goals.reduce(0.0) { $0 + $1.progress }
        let averageProgress = totalProgress / Double(goals.count)
        
        guard let collection = userPlansCollection else {
            throw PlanRepositoryError.userNotAuthenticated
        }
        
        try await collection.document(planId).updateData([
            "progress": averageProgress,
            "lastUpdated": Date().timeIntervalSince1970
        ])
        
        return averageProgress
    }
    
    // MARK: - Private Helpers
    
    private func parsePlan(from document: DocumentSnapshot) -> TMIPlan? {
        guard let data = document.data() else { return nil }
        
        guard let modelRaw = data["model"] as? String,
              let model = TMIPlanModel(rawValue: modelRaw),
              let progress = data["progress"] as? Double,
              let creationTimestamp = data["creationDate"] as? Double,
              let lastUpdatedTimestamp = data["lastUpdated"] as? Double else {
            return nil
        }
        
        let creationDate = Date(timeIntervalSince1970: creationTimestamp)
        let lastUpdated = Date(timeIntervalSince1970: lastUpdatedTimestamp)
        
        // Parse students
        let students: [Student]
        if let studentsData = data["students"] as? [[String: Any]] {
            students = studentsData.map { studentInfo in
                Student(
                    id: studentInfo["id"] as? String,
                    name: studentInfo["name"] as? String ?? "Unknown",
                    grade: studentInfo["grade"] as? String ?? "",
                    school: "",
                    dateOfBirth: Date()
                )
            }
        } else {
            students = []
        }
        
        // Parse interests
        let interests: [Interest]
        if let interestsData = data["interests"] as? [[String: Any]] {
            interests = interestsData.compactMap { interestData in
                Interest.fromFirestore(id: interestData["id"] as? String ?? "", data: interestData)
            }
        } else {
            interests = []
        }
        
        // Parse goals
        let goals: [Goal]
        if let goalsData = data["goals"] as? [[String: Any]] {
            goals = goalsData.compactMap { Goal.fromFirestoreData($0) }
        } else {
            goals = []
        }
        
        // Parse resources
        let resources: [Resource]
        if let resourcesData = data["resources"] as? [[String: Any]] {
            resources = resourcesData.compactMap { resourceData in
                Resource.fromFirestoreData(resourceData)
            }
        } else {
            resources = []
        }
        
        let title = data["title"] as? String ?? ""
        let notes = data["notes"] as? String ?? ""
        let startDate = (data["startDate"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
        let endDate = (data["endDate"] as? Double).map(Date.init(timeIntervalSince1970:))
        let createdBy = data["createdBy"] as? String ?? ""
        
        return TMIPlan(
            id: document.documentID,
            title: title,
            description: data["description"] as? String,
            students: students,
            model: model,
            interests: interests,
            startDate: startDate,
            endDate: endDate,
            creationDate: creationDate,
            lastUpdated: lastUpdated,
            goals: goals,
            progress: progress,
            notes: notes,
            strategies: data["strategies"] as? [String],
            progressTracking: nil,
            createdBy: createdBy,
            resources: resources
        )
    }
}

// MARK: - Plan Status

nonisolated enum PlanStatus: String, Codable, CaseIterable {
    case draft = "draft"
    case active = "active"
    case pendingApproval = "pending_approval"
    case approved = "approved"
    case rejected = "rejected"
    case needsRevision = "needs_revision"
    case completed = "completed"
    case archived = "archived"
}

// MARK: - Resource Extensions

nonisolated extension Resource {
    static func fromFirestoreData(_ data: [String: Any]) -> Resource? {
        guard let title = data["title"] as? String,
              let description = data["description"] as? String,
              let categoryRaw = data["category"] as? String,
              let category = Resource.ResourceCategory(rawValue: categoryRaw),
              let url = data["url"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Double,
              let updatedAtTimestamp = data["updatedAt"] as? Double else {
            return nil
        }
        
        return Resource(
            id: data["id"] as? String,
            title: title,
            description: description,
            category: category,
            url: url,
            createdAt: Date(timeIntervalSince1970: createdAtTimestamp),
            updatedAt: Date(timeIntervalSince1970: updatedAtTimestamp),
            tags: data["tags"] as? [String] ?? [],
            recommendedFor: data["recommendedFor"] as? [String] ?? [],
            isFeatured: data["isFeatured"] as? Bool ?? false,
            thumbnail: data["thumbnail"] as? String,
            scope: (data["scope"] as? String).flatMap { Resource.ResourceScope(rawValue: $0) },
            districtId: data["districtId"] as? String,
            ownerUid: data["ownerUid"] as? String
        )
    }
}

// MARK: - Errors

enum PlanRepositoryError: LocalizedError {
    case userNotAuthenticated
    case invalidPlanId
    case planNotFound
    case updateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .invalidPlanId:
            return "Invalid plan ID"
        case .planNotFound:
            return "Plan not found"
        case .updateFailed(let message):
            return "Failed to update plan: \(message)"
        }
    }
}
