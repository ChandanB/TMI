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

    // MARK: - Convenience Fetch

    func fetchTemplates(districtId: String?) async throws -> [PlanTemplate] {
        if let districtId {
            return try await fetchDistrictTemplates(districtId: districtId)
        }
        return try await fetchAllTemplates()
    }
    
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
        try await docRef.setData(from: newTemplate)

        print("[PlanTemplateService] ✅ Created template: \(newTemplate.title)")
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
        var query = db.collection(FirestorePaths.planTemplates).order(by: "title")

        let snapshot = try await query.getDocuments()

        return try snapshot.documents.compactMap { doc in
            try doc.data(as: PlanTemplate.self)
        }
    }

    /// Fetch templates by TMI model
    func fetchTemplates(for model: TMIPlanModel) async throws -> [PlanTemplate] {
        let query = db.collection(FirestorePaths.planTemplates)
            .whereField("model", isEqualTo: model.rawValue)
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
            .order(by: "title")

        let snapshot = try await query.getDocuments()

        return try snapshot.documents.compactMap { doc in
            try doc.data(as: PlanTemplate.self)
        }
    }

    /// Fetch public templates (available to all districts)
    func fetchPublicTemplates() async throws -> [PlanTemplate] {
        let query = db.collection(FirestorePaths.planTemplates)
            .whereField("isPublic", isEqualTo: true)
            .order(by: "usageCount", descending: true)

        let snapshot = try await query.getDocuments()

        return try snapshot.documents.compactMap { doc in
            try doc.data(as: PlanTemplate.self)
        }
    }

    /// Fetch templates by MTSS tier
    func fetchTemplates(tier: Int, districtId: String? = nil) async throws -> [PlanTemplate] {
        // Tier is not represented in the current PlanTemplate model.
        // Return all templates for now and let the caller filter by category/strategy.
        if let districtId {
            return try await fetchDistrictTemplates(districtId: districtId)
        }
        return try await fetchAllTemplates()
    }

    /// Fetch templates by category
    func fetchTemplates(category: PlanTemplate.Category, districtId: String? = nil) async throws -> [PlanTemplate] {
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
        try await docRef.setData(from: template, merge: true)

        print("[PlanTemplateService] ✅ Updated template: \(template.title)")
    }

    /// Archive a template (soft delete)
    func archiveTemplate(id: String) async throws {
        let docRef = db.collection(FirestorePaths.planTemplates).document(id)

        try await docRef.updateData([
            "isArchived": true,
            "archivedAt": FieldValue.serverTimestamp()
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
        let endDate = calendar.date(byAdding: .day, value: template.suggestedDurationWeeks * 7, to: startDate) ?? startDate

        // No activity templates in current PlanTemplate model
        let scheduledActivities: [InterventionActivity] = []

        // Generate goals from template
        let goals: [Goal] = template.goalsTemplate.map { goalTemplate in
            Goal(
                description: goalTemplate.title,
                notes: goalTemplate.description
            )
        }

        let createdBy = Auth.auth().currentUser?.uid ?? "system"

        // Create TMI plan
        let plan = TMIPlan(
            id: UUID().uuidString,
            title: "\(template.title) - \(student.name)",
            description: template.description,
            students: [student],
            model: template.model,
            interests: [],
            startDate: startDate,
            endDate: endDate,
            creationDate: Date(),
            lastUpdated: Date(),
            goals: goals,
            progress: 0.0,
            notes: template.description,
            strategies: template.strategiesTemplate,
            createdBy: createdBy
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
            template.title.lowercased().contains(lowercasedQuery) ||
            template.description.lowercased().contains(lowercasedQuery) ||
            template.category.rawValue.lowercased().contains(lowercasedQuery) ||
            template.strategiesTemplate.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }

    /// Get templates matching specific targeted interventions
    func fetchTemplates(targeting interventions: [String]) async throws -> [PlanTemplate] {
        // Firestore array-contains limitation: can only query one array element at a time
        // For production, consider denormalization or composite queries
        let allTemplates = try await fetchAllTemplates()

        return allTemplates.filter { template in
            !Set(template.strategiesTemplate).intersection(Set(interventions)).isEmpty
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
