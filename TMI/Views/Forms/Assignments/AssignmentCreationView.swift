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
  @Environment(\.appDependencies) private var dependencies

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
  @State private var selectedSchoolId: String?
  @State private var selectedStudents: Set<String> = []
  @State private var availableSchools: [School] = []
  @State private var isLoadingSchools = false
  @State private var showingStudentPicker = false
  @State private var isSubmitting = false
  @State private var errorMessage: String?

  // Helper Enum for UI Picker
  enum CohortType: String, CaseIterable, Identifiable {
      case allStudents = "All Students"
      case grade = "Grade"
      case school = "School"
      case specificStudents = "Students"

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
          await loadSchools()
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

              switch selectedCohortType {
              case .allStudents:
                  Text("Every student you're authorized to assign to.")
                      .font(.caption)
                      .foregroundColor(.secondary)

              case .grade:
                  Picker("Grade", selection: $targetGrade) {
                      Text("Select Grade").tag("")
                      ForEach(["K", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"], id: \.self) { grade in
                          Text("Grade \(grade)").tag(grade)
                      }
                  }

              case .school:
                  if isLoadingSchools {
                      HStack(spacing: 8) {
                          ProgressView()
                          Text("Loading schools…")
                              .font(.caption)
                              .foregroundColor(.secondary)
                      }
                  } else if availableSchools.isEmpty {
                      Text("No schools are available for your district.")
                          .font(.caption)
                          .foregroundColor(.secondary)
                  } else {
                      Picker("School", selection: $selectedSchoolId) {
                          Text("Select School").tag(nil as String?)
                          ForEach(availableSchools) { school in
                              Text(school.name).tag(school.id as String?)
                          }
                      }
                  }

              case .specificStudents:
                  Button {
                      showingStudentPicker = true
                  } label: {
                      HStack {
                          Text("Selected Students")
                              .foregroundColor(.primary)
                          Spacer()
                          if selectedStudents.isEmpty {
                              Text("Select…").foregroundColor(.blue)
                          } else {
                              Text("\(selectedStudents.count) selected")
                                  .foregroundColor(.secondary)
                          }
                      }
                  }
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
      .sheet(isPresented: $showingStudentPicker) {
          if let member = authStateModel.currentMembership {
              FormAssignmentStudentPickerView(
                  selection: $selectedStudents,
                  member: member,
                  repository: dependencies.studentRepository
              )
              .tmiSheetStyle()
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
      case .allStudents:
          return "All Students in District/School"
      case .grade:
          return targetGrade.isEmpty ? "No grade selected" : "Grade \(targetGrade)"
      case .school:
          let name = availableSchools.first { $0.id == selectedSchoolId }?.name
          return name ?? "No school selected"
      case .specificStudents:
          if selectedStudents.isEmpty { return "No students selected" }
          return "\(selectedStudents.count) student\(selectedStudents.count == 1 ? "" : "s")"
      }
  }

  private func canProceed() -> Bool {
      switch currentStep {
      case 0: return selectedTemplate != nil
      case 1: return !instructions.isEmpty
      case 2:
          switch selectedCohortType {
          case .allStudents: return true
          case .grade: return !targetGrade.isEmpty
          case .school: return selectedSchoolId != nil
          case .specificStudents: return !selectedStudents.isEmpty
          }
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

  private func loadSchools() async {
      guard let membership = authStateModel.currentMembership else { return }
      isLoadingSchools = true
      defer { isLoadingSchools = false }
      do {
          let fetched = try await DistrictService.shared.fetchSchools(for: membership.districtID)
          // Only offer schools the member is scoped to; an empty scope (e.g. a
          // district administrator) may assign across every school.
          let memberSchoolIDs = membership.schoolIDs
          let scoped = memberSchoolIDs.isEmpty
              ? fetched
              : fetched.filter { school in
                  guard let id = school.id else { return false }
                  return memberSchoolIDs.contains(id)
              }
          availableSchools = scoped.sorted {
              $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
          }
      } catch {
          print("[AssignmentCreationView] Error loading schools: \(error.localizedDescription)")
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
      case .school:
          let schoolName = availableSchools.first { $0.id == selectedSchoolId }?.name ?? "Selected School"
          cohort = .school(schoolId: selectedSchoolId ?? "", schoolName: schoolName)
      case .specificStudents:
          cohort = .specificStudents(studentIds: Array(selectedStudents), count: selectedStudents.count)
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
          schoolId: selectedCohortType == .school ? selectedSchoolId : membership.schoolIDs.sorted().first
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
