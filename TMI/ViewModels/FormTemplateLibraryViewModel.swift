//
//  FormTemplateLibraryViewModel.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #3
//

import Foundation
import Observation

@Observable
@MainActor
class FormTemplateLibraryViewModel {
  // Service
  private let templateService = FormTemplateService()

  // State
  var templates: [FormTemplate] = []
  var filteredTemplates: [FormTemplate] = []
  var selectedTemplate: FormTemplate?

  // UI State
  var isLoading = false
  var errorMessage: String?
  var searchText = ""
  var selectedCategory: String?

  // Filter state
  var showPublicOnly = false
  var showPrivateOnly = false

  // Export state
  var exportedFileURL: URL?
  var isExporting = false

  // Import state
  var isImporting = false

  // MARK: - Data Fetching

  func loadTemplates(districtId: String?) async {
    isLoading = true
    errorMessage = nil

    do {
      var allTemplates: [FormTemplate] = []
      
      // 1. Fetch district templates
      if let districtId = districtId {
        let districtTemplates = try await templateService.fetchTemplates(districtId: districtId)
        allTemplates.append(contentsOf: districtTemplates)
      }
      
      // 2. Fetch public templates
      let publicTemplates = try await templateService.fetchPublicTemplates()
      
      // 3. Merge avoiding duplicates (structs with same ID)
      // Assuming ID is present.
      let existingIds = Set(allTemplates.compactMap { $0.id })
      let newPublicCalls = publicTemplates.filter { t in
          guard let id = t.id else { return true }
          return !existingIds.contains(id)
      }
      
      allTemplates.append(contentsOf: newPublicCalls)
      
      self.templates = allTemplates
      applyFilters()
      print("[FormTemplateLibraryViewModel] Loaded \(templates.count) templates")
    } catch {
      errorMessage = "Failed to load templates: \(error.localizedDescription)"
      print("[FormTemplateLibraryViewModel] Error: \(errorMessage ?? "Unknown")")
    }

    isLoading = false
  }

  func refreshTemplates(districtId: String?) async {
    await loadTemplates(districtId: districtId)
  }

  // MARK: - Filtering & Search

  func applyFilters() {
    var results = templates

    // Apply category filter
    if let category = selectedCategory {
      results = results.filter { $0.category == category }
    }

    // Apply public/private filter
    if showPublicOnly {
      results = results.filter { $0.isPublic }
    } else if showPrivateOnly {
      results = results.filter { !$0.isPublic }
    }

    // Apply search
    if !searchText.isEmpty {
      results = results.filter { template in
        template.name.localizedCaseInsensitiveContains(searchText) ||
          template.templateDescription.localizedCaseInsensitiveContains(searchText) ||
          template.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
      }
    }

    filteredTemplates = results
  }

  func updateSearch(_ text: String) {
    searchText = text
    applyFilters()
  }

  func selectCategory(_ category: String?) {
    selectedCategory = category
    applyFilters()
  }

  func togglePublicFilter() {
    showPublicOnly.toggle()
    if showPublicOnly {
      showPrivateOnly = false
    }
    applyFilters()
  }

  func togglePrivateFilter() {
    showPrivateOnly.toggle()
    if showPrivateOnly {
      showPublicOnly = false
    }
    applyFilters()
  }

  func clearFilters() {
    searchText = ""
    selectedCategory = nil
    showPublicOnly = false
    showPrivateOnly = false
    applyFilters()
  }

  // MARK: - Template Operations

  func createTemplate(_ template: FormTemplate) async {
    isLoading = true
    errorMessage = nil

    do {
      let newTemplate = try await templateService.createTemplate(template)
      templates.append(newTemplate)
      applyFilters()
      print("[FormTemplateLibraryViewModel] Created template: \(newTemplate.name)")
    } catch {
      errorMessage = "Failed to create template: \(error.localizedDescription)"
      print("[FormTemplateLibraryViewModel] Error: \(errorMessage ?? "Unknown")")
    }

    isLoading = false
  }

  func updateTemplate(_ template: FormTemplate) async {
    isLoading = true
    errorMessage = nil

    do {
      try await templateService.updateTemplate(template)

      // Update in local array
      if let index = templates.firstIndex(where: { $0.id == template.id }) {
        templates[index] = template
        applyFilters()
      }

      print("[FormTemplateLibraryViewModel] Updated template: \(template.name)")
    } catch {
      errorMessage = "Failed to update template: \(error.localizedDescription)"
      print("[FormTemplateLibraryViewModel] Error: \(errorMessage ?? "Unknown")")
    }

    isLoading = false
  }

  func deleteTemplate(_ template: FormTemplate) async {
    guard let id = template.id else { return }

    isLoading = true
    errorMessage = nil

    do {
      try await templateService.deleteTemplate(id: id)

      // Remove from local array
      templates.removeAll { $0.id == id }
      applyFilters()

      print("[FormTemplateLibraryViewModel] Deleted template: \(id)")
    } catch {
      errorMessage = "Failed to delete template: \(error.localizedDescription)"
      print("[FormTemplateLibraryViewModel] Error: \(errorMessage ?? "Unknown")")
    }

    isLoading = false
  }

  func duplicateTemplate(_ template: FormTemplate) async {
    isLoading = true
    errorMessage = nil

    do {
      let duplicated = try await templateService.duplicateTemplate(template)
      templates.append(duplicated)
      applyFilters()
      print("[FormTemplateLibraryViewModel] Duplicated template: \(duplicated.name)")
    } catch {
      errorMessage = "Failed to duplicate template: \(error.localizedDescription)"
      print("[FormTemplateLibraryViewModel] Error: \(errorMessage ?? "Unknown")")
    }

    isLoading = false
  }

  // MARK: - Import/Export

  func exportTemplate(_ template: FormTemplate) async {
    isExporting = true
    errorMessage = nil

    do {
      let fileURL = try await templateService.exportTemplateToFile(template)
      exportedFileURL = fileURL
      print("[FormTemplateLibraryViewModel] Exported template to: \(fileURL.path)")
    } catch {
      errorMessage = "Failed to export template: \(error.localizedDescription)"
      print("[FormTemplateLibraryViewModel] Error: \(errorMessage ?? "Unknown")")
    }

    isExporting = false
  }

  func importTemplate(from url: URL) async {
    isImporting = true
    errorMessage = nil

    do {
      let jsonData = try Data(contentsOf: url)
      let template = try await templateService.importTemplateJSON(jsonData)
      templates.append(template)
      applyFilters()
      print("[FormTemplateLibraryViewModel] Imported template: \(template.name)")
    } catch {
      errorMessage = "Failed to import template: \(error.localizedDescription)"
      print("[FormTemplateLibraryViewModel] Error: \(errorMessage ?? "Unknown")")
    }

    isImporting = false
  }

  // MARK: - Sharing

  func makePublic(_ template: FormTemplate, districtId: String) async {
    isLoading = true
    errorMessage = nil

    do {
      try await templateService.makeTemplatePublic(template, districtId: districtId)

      // Update in local array
      if let index = templates.firstIndex(where: { $0.id == template.id }) {
        templates[index].isPublic = true
        templates[index].districtId = districtId
        applyFilters()
      }

      print("[FormTemplateLibraryViewModel] Made template public: \(template.name)")
    } catch {
      errorMessage = "Failed to make template public: \(error.localizedDescription)"
      print("[FormTemplateLibraryViewModel] Error: \(errorMessage ?? "Unknown")")
    }

    isLoading = false
  }

  func makePrivate(_ template: FormTemplate) async {
    isLoading = true
    errorMessage = nil

    do {
      try await templateService.makeTemplatePrivate(template)

      // Update in local array
      if let index = templates.firstIndex(where: { $0.id == template.id }) {
        templates[index].isPublic = false
        applyFilters()
      }

      print("[FormTemplateLibraryViewModel] Made template private: \(template.name)")
    } catch {
      errorMessage = "Failed to make template private: \(error.localizedDescription)"
      print("[FormTemplateLibraryViewModel] Error: \(errorMessage ?? "Unknown")")
    }

    isLoading = false
  }

  // MARK: - Computed Properties

  var categories: [String] {
    Array(Set(templates.compactMap { $0.category })).sorted()
  }

  var hasTemplates: Bool {
    !templates.isEmpty
  }

  var hasFilteredResults: Bool {
    !filteredTemplates.isEmpty
  }
}
