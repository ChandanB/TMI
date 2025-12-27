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

/// Service for managing form templates
@Observable
class FormTemplateService {
  private let db = Firestore.firestore()

  // MARK: - Collection References

  private var templatesCollection: CollectionReference {
    db.collection("formTemplates")
  }

  // MARK: - Fetch Operations

  /// Fetch all templates for a specific district
  func fetchTemplates(districtId: String) async throws -> [FormTemplate] {
    let querySnapshot = try await templatesCollection
      .whereField("districtId", isEqualTo: districtId)
      .order(by: "updatedAt", descending: true)
      .getDocuments()

    let templates = querySnapshot.documents.compactMap { try? $0.data(as: FormTemplate.self) }
    print("[FormTemplateService] Fetched \(templates.count) templates for district: \(districtId)")
    return templates
  }

  /// Fetch public templates (system-wide or shared)
  func fetchPublicTemplates() async throws -> [FormTemplate] {
    let querySnapshot = try await templatesCollection
      .whereField("isPublic", isEqualTo: true)
      .order(by: "name", descending: false)
      .getDocuments()

    let templates = querySnapshot.documents.compactMap { try? $0.data(as: FormTemplate.self) }
    return templates
  }
    
  /// Fetch a single template by ID
  func fetchTemplate(id: String) async throws -> FormTemplate {
    let document = try await templatesCollection.document(id).getDocument()
    guard document.exists else {
        throw FormTemplateError.templateNotFound(id)
    }
    return try document.data(as: FormTemplate.self)
  }

  // MARK: - CRUD Operations

  /// Create a new template
  func createTemplate(_ template: FormTemplate) async throws -> FormTemplate {
    guard let uid = Auth.auth().currentUser?.uid else {
      throw FormTemplateError.userNotAuthenticated
    }

    var newTemplate = template
    newTemplate.createdAt = Date()
    newTemplate.updatedAt = Date()
    newTemplate.createdBy = uid
    // Ensure districtId/schoolId are set if not already, typically passed in from ViewModel context

    let data = try Firestore.Encoder().encode(newTemplate)
    let documentRef = try await templatesCollection.addDocument(data: data)

    newTemplate.id = documentRef.documentID
    print("[FormTemplateService] Created template with ID: \(documentRef.documentID)")
    return newTemplate
  }

  /// Update an existing template
  func updateTemplate(_ template: FormTemplate) async throws {
    guard let id = template.id else {
      throw FormTemplateError.invalidTemplate("Template ID is missing")
    }

    var updatedTemplate = template
    updatedTemplate.updatedAt = Date()

    let data = try Firestore.Encoder().encode(updatedTemplate)
    try await templatesCollection.document(id).setData(data, merge: true)
    print("[FormTemplateService] Updated template: \(id)")
  }

  /// Publish a template (set isActive = true, potentially verify completeness)
  func publishTemplate(_ id: String) async throws {
    try await templatesCollection.document(id).updateData([
      "isActive": true,
      "updatedAt": Date()
    ])
    print("[FormTemplateService] Published template: \(id)")
  }

  /// Archive/Delete a template
  /// Archive/Delete a template
  func deleteTemplate(id: String) async throws {
    // Soft delete or hard delete? Let's do hard delete for now, or maybe set isActive = false
    try await templatesCollection.document(id).delete()
    print("[FormTemplateService] Deleted template: \(id)")
  }
    
  /// Duplicate a template
  func duplicateTemplate(_ template: FormTemplate) async throws -> FormTemplate {
     var duplicate = template
     duplicate.id = nil // Clear ID to create new doc
     duplicate.name = "\(template.name) (Copy)"
     duplicate.createdAt = Date()
     duplicate.updatedAt = Date()
     duplicate.uses = 0
     duplicate.version = 1
     // Keep other fields like sections, but reset metadata
     
     return try await createTemplate(duplicate)
  }
  // MARK: - Sharing
  
  /// Make a template public
  func makeTemplatePublic(_ template: FormTemplate, districtId: String) async throws {
    guard let id = template.id else { return }
    var updatedTemplate = template
    updatedTemplate.isPublic = true
    updatedTemplate.districtId = districtId // Assign to district when making public/shared
    
    try await updateTemplate(updatedTemplate)
    print("[FormTemplateService] Made template public: \(id)")
  }
  
  /// Make a template private
  func makeTemplatePrivate(_ template: FormTemplate) async throws {
    guard let id = template.id else { return }
    var updatedTemplate = template
    updatedTemplate.isPublic = false
    
    try await updateTemplate(updatedTemplate)
    print("[FormTemplateService] Made template private: \(id)")
  }

  // MARK: - Import/Export
  
  /// Export template to a temporary JSON file
  func exportTemplateToFile(_ template: FormTemplate) async throws -> URL {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(template)
    
    let fileName = "template_\(template.id ?? UUID().uuidString).json"
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent(fileName)
    
    try data.write(to: fileURL)
    return fileURL
  }
  
  /// Import template from JSON data
  func importTemplateJSON(_ data: Data) async throws -> FormTemplate {
    let decoder = JSONDecoder()
    var template = try decoder.decode(FormTemplate.self, from: data)
    
    // Reset metadata for import
    template.id = nil
    template.createdAt = Date()
    template.updatedAt = Date()
    template.createdBy = Auth.auth().currentUser?.uid ?? ""
    template.uses = 0
    template.isPublic = false // Default to private on import
    
    return try await createTemplate(template)
  }

  // MARK: - Seeding
  
  /// Seed sample templates if none exist
  func seedSampleTemplates() async throws {
      // Check if we already have templates
      let templates = try await fetchPublicTemplates()
      if !templates.isEmpty {
          print("[FormTemplateService] Templates already exist, skipping seed.")
          return
      }
      
      // Seed Parental Incarceration Support Template
      let template = FormTemplate.parentalIncarcerationSupportTemplate
      _ = try await createTemplate(template)
      print("[FormTemplateService] Seeded sample templates.")
  }
}

// MARK: - Error Handling

enum FormTemplateError: Error, LocalizedError {
  case userNotAuthenticated
  case templateNotFound(String)
  case invalidTemplate(String)

  var errorDescription: String? {
    switch self {
    case .userNotAuthenticated:
      return "User not authenticated"
    case .templateNotFound(let id):
      return "Template not found: \(id)"
    case .invalidTemplate(let reason):
      return "Invalid template: \(reason)"
    }
  }
}
