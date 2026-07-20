//
//  AssignmentCreationView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #4
//

import SwiftUI

struct AssignmentCreationView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.authStateModel) private var authStateModel
  
  // Dependencies
  private let assignmentService = FormAssignmentService()
  private let templateService = FormTemplateService()
  
  // State
  @State private var currentStep = 0
  @State private var selectedTemplate: FormTemplate?
  @State private var templates: [FormTemplate] = []
  @State private var searchQuery = ""
  
  // Assignment Details
  @State private var instructions = ""
  @State private var dueDate = Date().addingTimeInterval(86400 * 7) // 1 week default
  @State private var requiresReview = false
  @State private var allowLateSubmissions = true
  
  // Cohort Selection
  @State private var selectedCohortType: CohortType = .allStudents
  @State private var targetGrade = ""
  @State private var targetClassName = ""
  @State private var isSubmitting = false
  @State private var errorMessage: String?
  
  // Helper Enum for UI Picker
  enum CohortType: String, CaseIterable, Identifiable {
      case allStudents = "All Students"
      case grade = "Specific Grade"
      case customClass = "Custom Class"
      // case school, specificStudents omitted for MVP simplicity
      
      var id: String { rawValue }
  }

  var body: some View {
    NavigationStack {
      VStack {
        // Progress Indicator
        ProgressView(value: Double(currentStep), total: 2)
          .padding(.horizontal)
        
        TabView(selection: $currentStep) {
          // Step 1: Select Template
          templateSelectionStep
            .tag(0)
          
          // Step 2: Configure Details
          configurationStep
            .tag(1)
          
          // Step 3: Select Cohort & Review
          cohortSelectionStep
            .tag(2)
        }
        #if canImport(UIKit)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #else
        .tabViewStyle(.automatic)
        #endif
        .animation(.easeInOut, value: currentStep)
        
        // Navigation Buttons
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation { currentStep -= 1 }
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            if currentStep < 2 {
                Button("Next") {
                    if canProceed() {
                        withAnimation { currentStep += 1 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceed())
            } else {
                Button("Assign Form") {
                    Task { await createAssignment() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting)
            }
        }
        .padding()
      }
      .navigationTitle("New Assignment")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
          ToolbarItem(placement: .cancellationAction) {
              Button("Cancel") { dismiss() }
          }
      }
      .task {
          await loadTemplates()
      }
      .alert("Error", isPresented: .constant(errorMessage != nil)) {
          Button("OK") { errorMessage = nil }
      } message: {
          if let msg = errorMessage { Text(msg) }
      }
    }
  }
  
  // MARK: - Steps
  
  private var templateSelectionStep: some View {
      VStack {
          Text("Select a Template")
              .font(.headline)
              .padding(.top)
          
          TextField("Search templates...", text: $searchQuery)
              .textFieldStyle(.roundedBorder)
              .padding(.horizontal)
          
          List(filteredTemplates) { template in
              HStack {
                  VStack(alignment: .leading) {
                      Text(template.name)
                          .font(.body)
                      Text(template.templateDescription)
                          .font(.caption)
                          .foregroundColor(.secondary)
                          .lineLimit(1)
                  }
                  Spacer()
                  if selectedTemplate?.id == template.id {
                      Image(systemName: "checkmark.circle.fill")
                          .foregroundColor(.blue)
                  }
              }
              .contentShape(Rectangle())
              .onTapGesture {
                  selectedTemplate = template
              }
          }
          .listStyle(.plain)
      }
  }
  
  private var configurationStep: some View {
      Form {
          Section("Instructions") {
              TextField("Instructions for students", text: $instructions, axis: .vertical)
                  .lineLimit(3...6)
          }
          
          Section("Due Date") {
              DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
          }
          
          Section("Settings") {
              Toggle("Requires Review", isOn: $requiresReview)
              Toggle("Allow Late Submissions", isOn: $allowLateSubmissions)
          }
      }
  }
  
  private var cohortSelectionStep: some View {
      Form {
          Section("Target Audience") {
              Picker("Assign To", selection: $selectedCohortType) {
                  ForEach(CohortType.allCases) { type in
                      Text(type.rawValue).tag(type)
                  }
              }
              .pickerStyle(.segmented)
              
              if selectedCohortType == .grade {
                  TextField("Grade Level (e.g. 9, 10)", text: $targetGrade)
                      .keyboardType(.numberPad)
              }
              
              if selectedCohortType == .customClass {
                  TextField("Class Name (e.g. Homeroom 101)", text: $targetClassName)
              }
          }
          
          Section("Summary") {
              if let template = selectedTemplate {
                  LabeledContent("Template", value: template.name)
              }
              LabeledContent("Due Date", value: dueDate.formatted(date: .abbreviated, time: .shortened))
              LabeledContent("Cohort", value: cohortDescription)
          }
      }
  }
  
  // MARK: - Logic
  
  private var filteredTemplates: [FormTemplate] {
      if searchQuery.isEmpty {
          return templates
      } else {
          return templates.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
      }
  }
  
  private var cohortDescription: String {
      switch selectedCohortType {
      case .allStudents: return "All Students in District/School"
      case .grade: return "Grade \(targetGrade)"
      case .customClass: return "Class: \(targetClassName)"
      }
  }
  
  private func canProceed() -> Bool {
      switch currentStep {
      case 0: return selectedTemplate != nil
      case 1: return !instructions.isEmpty
      case 2:
          if selectedCohortType == .grade { return !targetGrade.isEmpty }
          if selectedCohortType == .customClass { return !targetClassName.isEmpty }
          return true
      default: return false
      }
  }
  
  private func loadTemplates() async {
      do {
          // Load public + district templates. Simplified for now.
          if let districtId = authStateModel.currentMembership?.districtID {
              templates = try await templateService.fetchTemplates(districtId: districtId)
          } else {
              templates = try await templateService.fetchPublicTemplates()
          }
      } catch {
          errorMessage = "Failed to load templates: \(error.localizedDescription)"
      }
  }
  
  private func createAssignment() async {
      guard let template = selectedTemplate,
            let templateId = template.id,
            let currentUser = authStateModel.currentUser,
            let membership = authStateModel.currentMembership else { return }
      
      isSubmitting = true
      
      // Construct Model
      let cohort: AssignmentCohort
      switch selectedCohortType {
      case .allStudents:
          cohort = .allStudents
      case .grade:
          cohort = .grade(grade: targetGrade)
      case .customClass:
          // NOTE: In a real app we'd likely select from existing classes or get student IDs
          // For now, we mock it with an empty student list or assume the service handles lookup
          cohort = .customClass(className: targetClassName, studentIds: [])
      }
      
      let assignment = FormAssignment(
          templateId: templateId,
          templateName: template.name,
          assignedBy: currentUser.userID,
          assignedByName: currentUser.displayName,
          cohort: cohort,
          dueDate: dueDate,
          instructions: instructions,
          allowLateSubmissions: allowLateSubmissions,
          requiresReview: requiresReview,
          districtId: membership.districtID,
          schoolId: membership.schoolIDs.sorted().first
      )
      
      do {
          _ = try await assignmentService.createAssignment(assignment)
          dismiss()
      } catch {
          errorMessage = "Failed to assign: \(error.localizedDescription)"
      }
      isSubmitting = false
  }
}
