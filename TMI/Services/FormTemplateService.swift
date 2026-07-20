//
//  FormTemplateService.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #3
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation

/// Service for managing public and tenant-scoped form templates.
@Observable
class FormTemplateService {
  private let db = Firestore.firestore()
  private let authorizationSessions: any AuthorizationSessionProviding
  private let authorization = RBACService()

  init(
    authorizationSessions: any AuthorizationSessionProviding = TrustedAuthorizationSessionStore.shared
  ) {
    self.authorizationSessions = authorizationSessions
  }

  private var templatesCollection: CollectionReference {
    db.collection(FirestorePaths.formTemplates)
  }

  // MARK: - Fetch Operations

  func fetchTemplates(districtId: String) async throws -> [FormTemplate] {
    let session = try authorizedSession()
    guard districtId == session.membership.districtID else {
      throw FormTemplateError.authorizationDenied
    }

    let querySnapshot = try await templatesCollection
      .whereField("districtId", isEqualTo: session.membership.districtID)
      .order(by: "updatedAt", descending: true)
      .getDocuments()
    let templates = querySnapshot.documents.compactMap {
      try? $0.data(as: FormTemplate.self)
    }

    return templates.filter {
      canRead($0, member: session.membership)
    }
  }

  /// Public catalog records do not confer tenant authority.
  func fetchPublicTemplates() async throws -> [FormTemplate] {
    let querySnapshot = try await templatesCollection
      .whereField("isPublic", isEqualTo: true)
      .order(by: "name", descending: false)
      .getDocuments()

    return querySnapshot.documents.compactMap {
      try? $0.data(as: FormTemplate.self)
    }
  }

  func fetchTemplate(id: String) async throws -> FormTemplate {
    let template = try await fetchTemplateDocument(id: id)
    if template.isPublic {
      return template
    }

    let session = try authorizedSession()
    guard canRead(template, member: session.membership) else {
      throw FormTemplateError.authorizationDenied
    }
    return template
  }

  // MARK: - CRUD Operations

  func createTemplate(_ template: FormTemplate) async throws -> FormTemplate {
    let session = try authorizedSession()
    var newTemplate = template
    newTemplate.id = nil
    newTemplate.createdAt = Date()
    newTemplate.updatedAt = Date()
    newTemplate.createdBy = session.membership.userID
    newTemplate.districtId = session.membership.districtID
    newTemplate.schoolId = try boundSchoolID(
      requestedSchoolID: template.schoolId,
      member: session.membership
    )

    let scope = TemplateAuthorizationScope(
      districtID: session.membership.districtID,
      schoolID: newTemplate.schoolId
    )
    guard authorization.canWriteTemplate(
      member: session.membership,
      template: scope
    ), !newTemplate.isPublic || session.membership.role == .districtAdministrator else {
      throw FormTemplateError.authorizationDenied
    }

    let data = try Firestore.Encoder().encode(newTemplate)
    let documentRef = try await templatesCollection.addDocument(data: data)
    newTemplate.id = documentRef.documentID
    return newTemplate
  }

  func updateTemplate(_ template: FormTemplate) async throws {
    guard let id = template.id else {
      throw FormTemplateError.invalidTemplate("Template ID is missing")
    }

    let session = try authorizedSession()
    let stored = try await fetchTemplateDocument(id: id)
    try requireWrite(stored, member: session.membership)

    var updated = template
    updated.createdAt = stored.createdAt
    updated.createdBy = stored.createdBy
    updated.districtId = stored.districtId
    updated.schoolId = stored.schoolId
    updated.updatedAt = Date()

    if updated.isPublic != stored.isPublic,
       session.membership.role != .districtAdministrator {
      throw FormTemplateError.authorizationDenied
    }

    let data = try Firestore.Encoder().encode(updated)
    try await templatesCollection.document(id).setData(data, merge: false)
  }

  func publishTemplate(_ id: String) async throws {
    let session = try authorizedSession()
    let stored = try await fetchTemplateDocument(id: id)
    try requireWrite(stored, member: session.membership)
    try await templatesCollection.document(id).updateData([
      "isActive": true,
      "updatedAt": Date()
    ])
  }

  /// Hard deletion remains disabled until a retention-aware template contract exists.
  func deleteTemplate(id: String) async throws {
    let session = try authorizedSession()
    let stored = try await fetchTemplateDocument(id: id)
    try requireWrite(stored, member: session.membership)
    throw FormTemplateError.deletionRequiresRetentionWorkflow
  }

  func duplicateTemplate(_ template: FormTemplate) async throws -> FormTemplate {
    if !template.isPublic {
      let session = try authorizedSession()
      guard canRead(template, member: session.membership) else {
        throw FormTemplateError.authorizationDenied
      }
    }

    var duplicate = template
    duplicate.id = nil
    duplicate.name = "\(template.name) (Copy)"
    duplicate.createdAt = Date()
    duplicate.updatedAt = Date()
    duplicate.uses = 0
    duplicate.version = 1
    duplicate.isPublic = false
    return try await createTemplate(duplicate)
  }

  // MARK: - Sharing

  func makeTemplatePublic(_ template: FormTemplate, districtId: String) async throws {
    let session = try authorizedSession()
    guard districtId == session.membership.districtID,
          session.membership.role == .districtAdministrator else {
      throw FormTemplateError.authorizationDenied
    }

    var updated = template
    updated.isPublic = true
    try await updateTemplate(updated)
  }

  func makeTemplatePrivate(_ template: FormTemplate) async throws {
    let session = try authorizedSession()
    guard session.membership.role == .districtAdministrator else {
      throw FormTemplateError.authorizationDenied
    }

    var updated = template
    updated.isPublic = false
    try await updateTemplate(updated)
  }

  // MARK: - Import/Export

  func exportTemplateToFile(_ template: FormTemplate) async throws -> URL {
    if !template.isPublic {
      let session = try authorizedSession()
      guard canRead(template, member: session.membership),
            session.membership.capabilities.contains(.reportExport) else {
        throw FormTemplateError.authorizationDenied
      }
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(template)
    let fileName = "template_\(template.id ?? UUID().uuidString).json"
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(fileName)
    try data.write(to: fileURL)
    return fileURL
  }

  func importTemplateJSON(_ data: Data) async throws -> FormTemplate {
    let decoder = JSONDecoder()
    var template = try decoder.decode(FormTemplate.self, from: data)
    template.id = nil
    template.createdAt = Date()
    template.updatedAt = Date()
    template.uses = 0
    template.isPublic = false
    return try await createTemplate(template)
  }

  /// Global catalog seeding is a server-owned operation.
  func seedSampleTemplates() async throws {
    throw FormTemplateError.authorizationDenied
  }

  // MARK: - Authorization Helpers

  private func authorizedSession() throws -> AuthenticatedSession {
    guard let session = authorizationSessions.session(
      authenticatedUserID: Auth.auth().currentUser?.uid
    ) else {
      throw FormTemplateError.userNotAuthenticated
    }
    return session
  }

  private func fetchTemplateDocument(id: String) async throws -> FormTemplate {
    let document = try await templatesCollection.document(id).getDocument()
    guard document.exists else {
      throw FormTemplateError.templateNotFound(id)
    }
    return try document.data(as: FormTemplate.self)
  }

  private func canRead(
    _ template: FormTemplate,
    member: MembershipContext
  ) -> Bool {
    guard template.districtId == member.districtID else {
      return false
    }
    let scope = TemplateAuthorizationScope(
      districtID: member.districtID,
      schoolID: template.schoolId ?? member.schoolIDs.onlyElement
    )
    return authorization.canReadTemplate(member: member, template: scope)
  }

  private func requireWrite(
    _ template: FormTemplate,
    member: MembershipContext
  ) throws {
    guard template.districtId == member.districtID else {
      throw FormTemplateError.authorizationDenied
    }
    let scope = TemplateAuthorizationScope(
      districtID: member.districtID,
      schoolID: template.schoolId
    )
    guard authorization.canWriteTemplate(member: member, template: scope) else {
      throw FormTemplateError.authorizationDenied
    }
  }

  private func boundSchoolID(
    requestedSchoolID: String?,
    member: MembershipContext
  ) throws -> String? {
    if member.role == .districtAdministrator {
      if let requestedSchoolID {
        guard TrustedIdentifier.isValid(requestedSchoolID) else {
          throw FormTemplateError.authorizationDenied
        }
      }
      return requestedSchoolID
    }

    if let requestedSchoolID,
       member.schoolIDs.contains(requestedSchoolID) {
      return requestedSchoolID
    }
    guard let schoolID = member.schoolIDs.onlyElement else {
      throw FormTemplateError.authorizationDenied
    }
    return schoolID
  }
}

private extension Set {
  var onlyElement: Element? {
    count == 1 ? first : nil
  }
}

enum FormTemplateError: Error, LocalizedError {
  case userNotAuthenticated
  case templateNotFound(String)
  case invalidTemplate(String)
  case authorizationDenied
  case deletionRequiresRetentionWorkflow

  var errorDescription: String? {
    switch self {
    case .userNotAuthenticated:
      return "User not authenticated"
    case .templateNotFound(let id):
      return "Template not found: \(id)"
    case .invalidTemplate(let reason):
      return "Invalid template: \(reason)"
    case .authorizationDenied:
      return "You don’t have access to this template"
    case .deletionRequiresRetentionWorkflow:
      return "Templates must be archived through the retention workflow"
    }
  }
}
