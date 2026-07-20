//
//  PlanTemplateService.swift
//  TMI
//
//  Service for managing trusted tenant plan templates.
//

import Foundation
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore

actor PlanTemplateService {
    static let shared = PlanTemplateService()

    private let db = Firestore.firestore()
    private let authorizationSessions: any AuthorizationSessionProviding
    private let authorization = RBACService()

    init(
        authorizationSessions: any AuthorizationSessionProviding = TrustedAuthorizationSessionStore.shared
    ) {
        self.authorizationSessions = authorizationSessions
    }

    // MARK: - Fetch Operations

    func fetchTemplates(districtId: String?) async throws -> [PlanTemplate] {
        guard let districtId else {
            return try await fetchPublicTemplates()
        }
        return try await fetchDistrictTemplates(districtId: districtId)
    }

    func fetchTemplate(id: String) async throws -> PlanTemplate? {
        let snapshot = try await templateDocument(id: id).getDocument()
        guard snapshot.exists else { return nil }

        let template = try snapshot.data(as: PlanTemplate.self)
        if template.isPublic {
            return template
        }

        let session = try authorizedSession()
        guard canRead(template, member: session.membership) else {
            throw PlanTemplateError.authorizationDenied
        }
        return template
    }

    func fetchAllTemplates(includeInactive: Bool = false) async throws -> [PlanTemplate] {
        _ = includeInactive
        let session = try authorizedSession()
        let snapshot = try await templatesCollection.order(by: "title").getDocuments()
        return try snapshot.documents.compactMap { document in
            let template = try document.data(as: PlanTemplate.self)
            return template.isPublic || canRead(template, member: session.membership)
                ? template
                : nil
        }
    }

    func fetchTemplates(for model: TMIPlanModel) async throws -> [PlanTemplate] {
        let session = try authorizedSession()
        let snapshot = try await templatesCollection
            .whereField("model", isEqualTo: model.rawValue)
            .order(by: "usageCount", descending: true)
            .getDocuments()

        return try snapshot.documents.compactMap { document in
            let template = try document.data(as: PlanTemplate.self)
            return template.isPublic || canRead(template, member: session.membership)
                ? template
                : nil
        }
    }

    func fetchDistrictTemplates(districtId: String) async throws -> [PlanTemplate] {
        let session = try authorizedSession()
        guard districtId == session.membership.districtID else {
            throw PlanTemplateError.authorizationDenied
        }
        let scope = TemplateAuthorizationScope(
            districtID: session.membership.districtID,
            schoolID: nil
        )
        guard authorization.canReadTemplate(
            member: session.membership,
            template: scope
        ) else {
            throw PlanTemplateError.authorizationDenied
        }

        let snapshot = try await templatesCollection
            .whereField("districtId", isEqualTo: session.membership.districtID)
            .order(by: "title")
            .getDocuments()
        return try snapshot.documents.map {
            try $0.data(as: PlanTemplate.self)
        }
    }

    func fetchPublicTemplates() async throws -> [PlanTemplate] {
        let snapshot = try await templatesCollection
            .whereField("isPublic", isEqualTo: true)
            .order(by: "usageCount", descending: true)
            .getDocuments()
        return try snapshot.documents.map {
            try $0.data(as: PlanTemplate.self)
        }
    }

    func fetchTemplates(tier: Int, districtId: String? = nil) async throws -> [PlanTemplate] {
        _ = tier
        return try await fetchTemplates(districtId: districtId)
    }

    func fetchTemplates(
        category: PlanTemplate.Category,
        districtId: String? = nil
    ) async throws -> [PlanTemplate] {
        try await fetchTemplates(districtId: districtId).filter {
            $0.category == category
        }
    }

    // MARK: - Mutations

    func createTemplate(_ template: PlanTemplate) async throws -> PlanTemplate {
        let session = try authorizedSession()
        let scope = TemplateAuthorizationScope(
            districtID: session.membership.districtID,
            schoolID: nil
        )
        guard authorization.canWriteTemplate(
            member: session.membership,
            template: scope
        ) else {
            throw PlanTemplateError.authorizationDenied
        }

        let newTemplate = normalizedTemplate(
            template,
            id: template.id ?? UUID().uuidString,
            districtID: session.membership.districtID,
            createdBy: session.membership.userID,
            createdAt: Date(),
            updatedAt: Date()
        )
        guard let id = newTemplate.id else {
            throw PlanTemplateError.invalidTemplateId
        }
        try await templateDocument(id: id).setData(from: newTemplate)
        return newTemplate
    }

    func updateTemplate(_ template: PlanTemplate) async throws {
        guard let templateID = template.id,
              let stored = try await fetchTemplate(id: templateID) else {
            throw PlanTemplateError.templateNotFound
        }

        let session = try authorizedSession()
        try requireWrite(stored, member: session.membership)
        let updated = normalizedTemplate(
            template,
            id: templateID,
            districtID: stored.districtId ?? session.membership.districtID,
            createdBy: stored.createdBy,
            createdAt: stored.createdAt,
            updatedAt: Date()
        )
        try await templateDocument(id: templateID).setData(from: updated, merge: false)
    }

    func archiveTemplate(id: String) async throws {
        guard let stored = try await fetchTemplate(id: id) else {
            throw PlanTemplateError.templateNotFound
        }
        let session = try authorizedSession()
        try requireWrite(stored, member: session.membership)
        try await templateDocument(id: id).updateData([
            "isArchived": true,
            "archivedAt": FieldValue.serverTimestamp()
        ])
    }

    func deleteTemplate(id: String) async throws {
        guard let stored = try await fetchTemplate(id: id) else {
            throw PlanTemplateError.templateNotFound
        }
        let session = try authorizedSession()
        try requireWrite(stored, member: session.membership)
        throw PlanTemplateError.deletionRequiresRetentionWorkflow
    }

    /// Catalog usage metrics are server-owned and cannot be incremented directly.
    func trackTemplateUsage(id: String) async throws {
        guard try await fetchTemplate(id: id) != nil else {
            throw PlanTemplateError.templateNotFound
        }
        throw PlanTemplateError.serverOwnedOperation
    }

    // MARK: - Plan Creation

    func createPlanFromTemplate(
        templateId: String,
        student: Student,
        startDate: Date,
        customizations: [String: Any]? = nil
    ) async throws -> (plan: TMIPlan, activities: [InterventionActivity]) {
        _ = customizations
        guard let template = try await fetchTemplate(id: templateId),
              let studentID = student.id else {
            throw PlanTemplateError.templateNotFound
        }

        let session = try authorizedSession()
        let studentService = StudentService(
            authorizationSessions: authorizationSessions
        )
        guard let canonicalStudent = try await studentService.getStudent(by: studentID),
              let studentScope = StudentAuthorizationScope(student: canonicalStudent) else {
            throw PlanTemplateError.studentNotFound
        }

        let planID = UUID().uuidString
        let planScope = PlanAuthorizationScope(
            planID: planID,
            districtID: session.membership.districtID,
            students: [studentScope]
        )
        guard authorization.canWritePlan(
            member: session.membership,
            plan: planScope
        ) else {
            throw PlanTemplateError.authorizationDenied
        }

        let endDate = Calendar.current.date(
            byAdding: .day,
            value: template.suggestedDurationWeeks * 7,
            to: startDate
        ) ?? startDate
        let goals = template.goalsTemplate.map {
            Goal(description: $0.title, notes: $0.description)
        }
        let plan = TMIPlan(
            id: planID,
            title: "\(template.title) - \(canonicalStudent.name)",
            description: template.description,
            students: [canonicalStudent],
            model: template.model,
            interests: [],
            startDate: startDate,
            endDate: endDate,
            creationDate: Date(),
            lastUpdated: Date(),
            goals: goals,
            progress: 0,
            notes: template.description,
            strategies: template.strategiesTemplate,
            createdBy: session.membership.userID,
            districtId: session.membership.districtID
        )
        return (plan, [])
    }

    // MARK: - Search and Filter

    func searchTemplates(
        query: String,
        districtId: String? = nil
    ) async throws -> [PlanTemplate] {
        let templates = try await fetchTemplates(districtId: districtId)
        let normalizedQuery = query.lowercased()
        return templates.filter {
            $0.title.lowercased().contains(normalizedQuery)
                || $0.description.lowercased().contains(normalizedQuery)
                || $0.category.rawValue.lowercased().contains(normalizedQuery)
                || $0.strategiesTemplate.contains {
                    $0.lowercased().contains(normalizedQuery)
                }
        }
    }

    func fetchTemplates(targeting interventions: [String]) async throws -> [PlanTemplate] {
        let templates = try await fetchAllTemplates()
        return templates.filter {
            !Set($0.strategiesTemplate).intersection(Set(interventions)).isEmpty
        }
    }

    // MARK: - Authorization Helpers

    private var templatesCollection: CollectionReference {
        db.collection(FirestorePaths.planTemplates)
    }

    private func templateDocument(id: String) -> DocumentReference {
        templatesCollection.document(id)
    }

    private func authorizedSession() throws -> AuthenticatedSession {
        guard let session = authorizationSessions.session(
            authenticatedUserID: Auth.auth().currentUser?.uid
        ) else {
            throw PlanTemplateError.userNotAuthenticated
        }
        return session
    }

    private func canRead(
        _ template: PlanTemplate,
        member: MembershipContext
    ) -> Bool {
        guard template.districtId == member.districtID else {
            return false
        }
        return authorization.canReadTemplate(
            member: member,
            template: TemplateAuthorizationScope(
                districtID: member.districtID,
                schoolID: nil
            )
        )
    }

    private func requireWrite(
        _ template: PlanTemplate,
        member: MembershipContext
    ) throws {
        guard template.districtId == member.districtID,
              authorization.canWriteTemplate(
                member: member,
                template: TemplateAuthorizationScope(
                    districtID: member.districtID,
                    schoolID: nil
                )
              ) else {
            throw PlanTemplateError.authorizationDenied
        }
    }

    private func normalizedTemplate(
        _ template: PlanTemplate,
        id: String,
        districtID: String,
        createdBy: String,
        createdAt: Date,
        updatedAt: Date
    ) -> PlanTemplate {
        PlanTemplate(
            id: id,
            title: template.title,
            description: template.description,
            model: template.model,
            category: template.category,
            goalsTemplate: template.goalsTemplate,
            strategiesTemplate: template.strategiesTemplate,
            suggestedDurationWeeks: template.suggestedDurationWeeks,
            targetGradeLevels: template.targetGradeLevels,
            isPublic: template.isPublic,
            createdBy: createdBy,
            districtId: districtID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            usageCount: template.usageCount,
            rating: template.rating
        )
    }
}

extension FirestorePaths {
    static let planTemplates = "planTemplates"

    static func planTemplate(templateId: String) -> String {
        "planTemplates/\(templateId)"
    }
}

enum PlanTemplateError: LocalizedError {
    case userNotAuthenticated
    case invalidTemplateId
    case templateNotFound
    case studentNotFound
    case invalidCustomizations
    case authorizationDenied
    case deletionRequiresRetentionWorkflow
    case serverOwnedOperation

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            "User is not authenticated"
        case .invalidTemplateId:
            "Invalid template ID"
        case .templateNotFound:
            "Plan template not found"
        case .studentNotFound:
            "Student not found"
        case .invalidCustomizations:
            "Invalid customization parameters"
        case .authorizationDenied:
            "You don’t have access to this plan template"
        case .deletionRequiresRetentionWorkflow:
            "Plan templates must be archived through the retention workflow"
        case .serverOwnedOperation:
            "This catalog operation is managed by the server"
        }
    }
}
