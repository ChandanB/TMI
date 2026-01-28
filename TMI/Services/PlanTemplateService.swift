//
//  PlanTemplateService.swift
//  TMI
//
//  Service for managing TMI Plan templates with comprehensive CRUD operations
//  Phase 2.3: Plan Templates & Activities
//

import Foundation
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseAuth

actor PlanTemplateService {
    static let shared = PlanTemplateService()

    private let db = Firestore.firestore()

    private init() {}
    
    // MARK: - Template CRUD Operations

    /// Create a new plan template
    func createTemplate(_ template: PlanTemplate) async throws -> PlanTemplate {
        guard Auth.auth().currentUser?.uid != nil else {
            throw PlanTemplateError.userNotAuthenticated
        }

        var newTemplate = template
        newTemplate.id = newTemplate.id ?? UUID().uuidString

        // Save to Firestore
        let docRef = db.collection(FirestorePaths.planTemplates).document(newTemplate.id!)
        try docRef.setData(from: newTemplate)

        print("[PlanTemplateService] ✅ Created template: \(newTemplate.name)")
        return newTemplate
    }

    /// Fetch a specific template by ID
    func fetchTemplate(id: String) async throws -> PlanTemplate? {
        let docRef = db.collection(FirestorePaths.planTemplates).document(id)
        let snapshot = try await docRef.getDocument()

        guard snapshot.exists else { return nil }

        return try snapshot.data(as: PlanTemplate.self)
    }

    /// Fetch all active templates
    func fetchAllTemplates(includeInactive: Bool = false) async throws -> [PlanTemplate] {
        var query = db.collection(FirestorePaths.planTemplates).order(by: "name")

        if !includeInactive {
            query = query.whereField("isActive", isEqualTo: true)
        }

        let snapshot = try await query.getDocuments()

        return try snapshot.documents.compactMap { doc in
            try doc.data(as: PlanTemplate.self)
        }
    }

    /// Fetch templates by TMI model
    func fetchTemplates(for model: TMIPlanModel) async throws -> [PlanTemplate] {
        let query = db.collection(FirestorePaths.planTemplates)
            .whereField("model", isEqualTo: model.rawValue)
            .whereField("isActive", isEqualTo: true)
            .order(by: "usageCount", descending: true)

        let snapshot = try await query.getDocuments()

        return try snapshot.documents.compactMap { doc in
            try doc.data(as: PlanTemplate.self)
        }
    }

    /// Fetch templates by district
    func fetchDistrictTemplates(districtId: String) async throws -> [PlanTemplate] {
        let query = db.collection(FirestorePaths.planTemplates)
            .whereField("districtId", isEqualTo: districtId)
            .whereField("isActive", isEqualTo: true)
            .order(by: "name")

        let snapshot = try await query.getDocuments()

        return try snapshot.documents.compactMap { doc in
            try doc.data(as: PlanTemplate.self)
        }
    }

    /// Fetch public templates (available to all districts)
    func fetchPublicTemplates() async throws -> [PlanTemplate] {
        let query = db.collection(FirestorePaths.planTemplates)
            .whereField("isPublic", isEqualTo: true)
            .whereField("isActive", isEqualTo: true)
            .order(by: "usageCount", descending: true)

        let snapshot = try await query.getDocuments()

        return try snapshot.documents.compactMap { doc in
            try doc.data(as: PlanTemplate.self)
        }
    }

    /// Fetch templates by MTSS tier
    func fetchTemplates(tier: Int, districtId: String? = nil) async throws -> [PlanTemplate] {
        var query = db.collection(FirestorePaths.planTemplates)
            .whereField("tier", isEqualTo: tier)
            .whereField("isActive", isEqualTo: true)

        if let districtId = districtId {
            // Fetch both district-specific and public templates
            let districtQuery = query.whereField("districtId", isEqualTo: districtId)
            let publicQuery = query.whereField("isPublic", isEqualTo: true)

            let districtSnapshot = try await districtQuery.getDocuments()
            let publicSnapshot = try await publicQuery.getDocuments()

            let districtTemplates = try districtSnapshot.documents.compactMap { try $0.data(as: PlanTemplate.self) }
            let publicTemplates = try publicSnapshot.documents.compactMap { try $0.data(as: PlanTemplate.self) }

            return districtTemplates + publicTemplates
        } else {
            // Fetch all templates for the tier
            let snapshot = try await query.getDocuments()
            return try snapshot.documents.compactMap { try $0.data(as: PlanTemplate.self) }
        }
    }

    /// Fetch templates by category
    func fetchTemplates(category: String, districtId: String?) async throws -> [PlanTemplate] {
        let allTemplates = districtId != nil
            ? try await fetchDistrictTemplates(districtId: districtId!)
            : try await fetchAllTemplates()

        return allTemplates.filter { $0.category == category }
    }
    
    /// Update an existing template
    func updateTemplate(_ template: PlanTemplate) async throws {
        guard let templateId = template.id else {
            throw PlanTemplateError.invalidTemplateId
        }

        let docRef = db.collection(FirestorePaths.planTemplates).document(templateId)
        try docRef.setData(from: template, merge: true)

        print("[PlanTemplateService] ✅ Updated template: \(template.name)")
    }

    /// Archive a template (soft delete)
    func archiveTemplate(id: String) async throws {
        let docRef = db.collection(FirestorePaths.planTemplates).document(id)

        try await docRef.updateData([
            "isActive": false
        ])

        print("[PlanTemplateService] 🗄️ Archived template: \(id)")
    }

    /// Delete a template (hard delete - use with caution)
    func deleteTemplate(id: String) async throws {
        let docRef = db.collection(FirestorePaths.planTemplates).document(id)

        try await docRef.delete()

        print("[PlanTemplateService] 🗑️ Deleted template: \(id)")
    }

    // MARK: - Template Usage Tracking

    /// Increment usage count when a template is used to create a plan
    func trackTemplateUsage(id: String) async throws {
        let docRef = db.collection(FirestorePaths.planTemplates).document(id)

        try await docRef.updateData([
            "usageCount": FieldValue.increment(Int64(1)),
            "lastUsedAt": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - Plan Creation from Template

    /// Create a TMI plan from a template with scheduled activities
    func createPlanFromTemplate(
        templateId: String,
        student: Student,
        startDate: Date,
        customizations: [String: Any]? = nil
    ) async throws -> (plan: TMIPlan, activities: [InterventionActivity]) {
        guard let template = try await fetchTemplate(id: templateId) else {
            throw PlanTemplateError.templateNotFound
        }

        // Calculate end date
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: template.recommendedDuration, to: startDate) ?? startDate

        // Generate scheduled activities from template
        var scheduledActivities: [InterventionActivity] = []

        for activityTemplate in template.activities.sorted(by: { $0.sequenceOrder < $1.sequenceOrder }) {
            let scheduledDate = activityTemplate.scheduleSuggestion.scheduledDate(
                startDate: startDate,
                occurrence: 1
            )

            let activity = InterventionActivity(
                planId: "", // Will be set after plan creation
                templateId: activityTemplate.id,
                title: activityTemplate.title,
                description: activityTemplate.description,
                type: activityTemplate.type,
                estimatedDuration: activityTemplate.estimatedDuration,
                scheduledDate: scheduledDate,
                status: .pending,
                assignedTo: student.id ?? "",
                instructions: activityTemplate.instructions,
                requiredMaterials: activityTemplate.requiredMaterials,
                assessmentCriteria: activityTemplate.assessmentCriteria
            )

            scheduledActivities.append(activity)
        }

        // Generate goals from template
        let goals = template.goalTemplates
            .sorted(by: { $0.sequenceOrder < $1.sequenceOrder })
            .map { $0.toGoal() }

        // Create TMI plan
        let plan = TMIPlan(
            id: UUID().uuidString,
            title: "\(template.name) - \(student.name)",
            model: template.model,
            students: [student],
            goals: goals.map { $0.title }, // Convert to string array for compatibility
            startDate: startDate,
            endDate: endDate,
            status: "draft",
            notes: template.description,
            tier: template.tier
        )

        // Track template usage
        try await trackTemplateUsage(id: templateId)

        return (plan, scheduledActivities)
    }

    // MARK: - Search and Filter

    /// Search templates by keyword
    func searchTemplates(query: String, districtId: String? = nil) async throws -> [PlanTemplate] {
        // Note: Firestore doesn't support full-text search natively
        // For production, consider using Algolia or similar service
        let allTemplates = districtId != nil
            ? try await fetchDistrictTemplates(districtId: districtId!)
            : try await fetchAllTemplates()

        let lowercasedQuery = query.lowercased()

        return allTemplates.filter { template in
            template.name.lowercased().contains(lowercasedQuery) ||
            template.description.lowercased().contains(lowercasedQuery) ||
            template.category.lowercased().contains(lowercasedQuery) ||
            template.targetedInterventions.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }

    /// Get templates matching specific targeted interventions
    func fetchTemplates(targeting interventions: [String]) async throws -> [PlanTemplate] {
        // Firestore array-contains limitation: can only query one array element at a time
        // For production, consider denormalization or composite queries
        let allTemplates = try await fetchAllTemplates()

        return allTemplates.filter { template in
            !Set(template.targetedInterventions).intersection(Set(interventions)).isEmpty
        }
    }
}

// MARK: - Extension for FirestorePaths

extension FirestorePaths {
    static let planTemplates = "planTemplates"

    static func planTemplate(templateId: String) -> String {
        return "planTemplates/\(templateId)"
    }
}

// MARK: - Errors

enum PlanTemplateError: LocalizedError {
    case userNotAuthenticated
    case invalidTemplateId
    case templateNotFound
    case studentNotFound
    case invalidCustomizations

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .invalidTemplateId:
            return "Invalid template ID"
        case .templateNotFound:
            return "Plan template not found"
        case .studentNotFound:
            return "Student not found"
        case .invalidCustomizations:
            return "Invalid customization parameters"
        }
    }
}
