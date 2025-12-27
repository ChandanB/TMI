//
//  FormAssignmentCreateView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #4
//

import SwiftUI

struct FormAssignmentCreateView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.authStateModel) private var authStateModel
  let viewModel: FormAssignmentViewModel

  // Form state
  @State private var selectedTemplate: FormTemplate?
  @State private var selectedCohortType: CohortType = .allStudents
  @State private var selectedSchool: String?
  @State private var selectedGrade: String?
  @State private var selectedStudents: Set<String> = []
  @State private var dueDate: Date?
  @State private var hasDueDate = false
  @State private var instructions = ""
  @State private var allowLateSubmissions = true
  @State private var requiresReview = false

  // Template selection
  @State private var showingTemplatePicker = false
  @State private var availableTemplates: [FormTemplate] = []
  @State private var isLoadingTemplates = false

  // Services
  @State private var templateService = FormTemplateService()

  var body: some View {
    NavigationStack {
      ZStack {
        TMIBackgroundView(variant: .dashboard)

        Form {
          // Template selection
          Section {
            Button {
              showingTemplatePicker = true
            } label: {
              HStack {
                Text("Form Template")
                  .foregroundColor(.primary)
                Spacer()
                if let template = selectedTemplate {
                  Text(template.name)
                    .foregroundColor(.secondary)
                } else {
                  Text("Select...")
                    .foregroundColor(.blue)
                }
              }
            }
          } header: {
            Text("Form")
          }

          // Cohort selection
          Section {
            Picker("Assign To", selection: $selectedCohortType) {
              ForEach(CohortType.allCases, id: \.self) { type in
                Text(type.displayName).tag(type)
              }
            }

            cohortDetails
          } header: {
            Text("Assignment Target")
          }

          // Assignment details
          Section {
            Toggle("Set Due Date", isOn: $hasDueDate)

            if hasDueDate {
              DatePicker("Due Date", selection: Binding(
                get: { dueDate ?? Date().addingTimeInterval(604800) },
                set: { dueDate = $0 }
              ), displayedComponents: [.date])
            }

            Toggle("Allow Late Submissions", isOn: $allowLateSubmissions)
            Toggle("Requires Review", isOn: $requiresReview)
          } header: {
            Text("Options")
          }

          // Instructions
          Section {
            TextEditor(text: $instructions)
              .frame(minHeight: 100)
          } header: {
            Text("Instructions (Optional)")
          }
        }
        .scrollContentBackground(.hidden)
      }
      .navigationTitle("Create Assignment")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Create") {
            Task {
              await createAssignment()
            }
          }
          .disabled(!canCreate)
        }
      }
      .sheet(isPresented: $showingTemplatePicker) {
        FormTemplatePickerView(
          selectedTemplate: $selectedTemplate,
          templates: availableTemplates
        )
      }
      .task {
        await loadTemplates()
      }
    }
  }

  // MARK: - Cohort Details

  @ViewBuilder
  private var cohortDetails: some View {
    switch selectedCohortType {
    case .allStudents:
      Text("All students in your district")
        .font(.caption)
        .foregroundColor(.secondary)

    case .school:
      Picker("School", selection: $selectedSchool) {
        Text("Select School").tag(nil as String?)
        // Would fetch schools from DistrictService
        Text("Lincoln High School").tag("school_001" as String?)
        Text("Washington Middle School").tag("school_002" as String?)
      }

    case .grade:
      Picker("Grade", selection: $selectedGrade) {
        Text("Select Grade").tag(nil as String?)
        ForEach(["K", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"], id: \.self) { grade in
          Text("Grade \(grade)").tag(grade as String?)
        }
      }

    case .specificStudents:
      Text("Student selection feature coming soon")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }

  // MARK: - Actions

  private func loadTemplates() async {
    isLoadingTemplates = true
    
    // Get current user's district ID
    guard let districtId = authStateModel.currentUser?.districtId else {
        // If no district, maybe just fetch public? Or show empty.
        // For now, let's fetch public only if no district.
        do {
            availableTemplates = try await templateService.fetchPublicTemplates()
        } catch {
            print("[FormAssignmentCreateView] Error loading public templates: \(error.localizedDescription)")
        }
        isLoadingTemplates = false
        return
    }

    do {
      // Fetch both district and public templates
      // Note: fetching sequentially for simplicity, could be concurrent
      let districtTemplates = try await templateService.fetchTemplates(districtId: districtId)
      let publicTemplates = try await templateService.fetchPublicTemplates()
      
      // Combine and deduplicate if necessary (though IDs should be unique)
      availableTemplates = (districtTemplates + publicTemplates).sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
      
    } catch {
      print("[FormAssignmentCreateView] Error loading templates: \(error.localizedDescription)")
    }

    isLoadingTemplates = false
  }

  private func createAssignment() async {
    guard let template = selectedTemplate else { return }
    guard let user = authStateModel.currentUser else { return }

    let cohort: AssignmentCohort = {
      switch selectedCohortType {
      case .allStudents:
        return .allStudents
      case .school:
        return .school(schoolId: selectedSchool ?? "", schoolName: "Selected School")
      case .grade:
        return .grade(grade: selectedGrade ?? "9")
      case .specificStudents:
        return .specificStudents(studentIds: Array(selectedStudents), count: selectedStudents.count)
      }
    }()

    let assignment = FormAssignment(
      templateId: template.id ?? "",
      templateName: template.name,
      assignedBy: user.userID,
      assignedByName: user.displayName,
      cohort: cohort,
      dueDate: hasDueDate ? dueDate : nil,
      instructions: instructions.isEmpty ? nil : instructions,
      allowLateSubmissions: allowLateSubmissions,
      requiresReview: requiresReview,
      districtId: user.districtId,
      schoolId: user.schoolId
    )

    await viewModel.createAssignment(assignment)
    dismiss()
  }

  // MARK: - Validation

  private var canCreate: Bool {
    guard selectedTemplate != nil else { return false }

    switch selectedCohortType {
    case .allStudents:
      return true
    case .school:
      return selectedSchool != nil
    case .grade:
      return selectedGrade != nil
    case .specificStudents:
      return !selectedStudents.isEmpty
    }
  }
}

// MARK: - Cohort Type

enum CohortType: CaseIterable {
  case allStudents
  case school
  case grade
  case specificStudents

  var displayName: String {
    switch self {
    case .allStudents: return "All Students"
    case .school: return "Specific School"
    case .grade: return "Grade Level"
    case .specificStudents: return "Specific Students"
    }
  }
}

// MARK: - Template Picker

struct FormTemplatePickerView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var selectedTemplate: FormTemplate?
  let templates: [FormTemplate]

  var body: some View {
    NavigationStack {
      List(templates) { template in
        Button {
          selectedTemplate = template
          dismiss()
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(template.name)
              .font(.headline)

            Text(template.templateDescription)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(2)

            if let category = template.category {
              Text(category)
                .font(.caption2)
                .foregroundColor(.blue)
            }
          }
          .padding(.vertical, 4)
        }
      }
      .navigationTitle("Select Template")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
    }
  }
}

#Preview {
  FormAssignmentCreateView(viewModel: FormAssignmentViewModel())
}

