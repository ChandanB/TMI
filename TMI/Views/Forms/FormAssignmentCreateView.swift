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
  @Environment(\.appDependencies) private var dependencies
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

  // Cohort resolution data
  @State private var availableSchools: [School] = []
  @State private var isLoadingSchools = false
  @State private var showingStudentPicker = false

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
        .tmiSheetStyle()
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
      .task {
        await loadTemplates()
        await loadSchools()
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
        Picker("School", selection: $selectedSchool) {
          Text("Select School").tag(nil as String?)
          ForEach(availableSchools) { school in
            Text(school.name).tag(school.id as String?)
          }
        }
      }

    case .grade:
      Picker("Grade", selection: $selectedGrade) {
        Text("Select Grade").tag(nil as String?)
        ForEach(["K", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"], id: \.self) { grade in
          Text("Grade \(grade)").tag(grade as String?)
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
            Text("Select…")
              .foregroundColor(.blue)
          } else {
            Text("\(selectedStudents.count) selected")
              .foregroundColor(.secondary)
          }
        }
      }
    }
  }

  // MARK: - Actions

  private func loadTemplates() async {
    isLoadingTemplates = true
    
    guard let districtId = authStateModel.currentMembership?.districtID else {
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

  private func loadSchools() async {
    guard let districtId = authStateModel.currentMembership?.districtID else { return }
    isLoadingSchools = true
    defer { isLoadingSchools = false }
    do {
      let fetched = try await DistrictService.shared.fetchSchools(for: districtId)
      // Only offer schools the member is scoped to; an empty scope (e.g. a
      // district administrator) may assign across every school in the district.
      let memberSchoolIDs = authStateModel.currentMembership?.schoolIDs ?? []
      let scoped = memberSchoolIDs.isEmpty
        ? fetched
        : fetched.filter { school in
            guard let id = school.id else { return false }
            return memberSchoolIDs.contains(id)
          }
      availableSchools = scoped.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    } catch {
      print("[FormAssignmentCreateView] Error loading schools: \(error.localizedDescription)")
    }
  }

  private func createAssignment() async {
    guard let template = selectedTemplate else { return }
    guard let user = authStateModel.currentUser,
          let membership = authStateModel.currentMembership else { return }

    let cohort: AssignmentCohort = {
      switch selectedCohortType {
      case .allStudents:
        return .allStudents
      case .school:
        let schoolName = availableSchools.first { $0.id == selectedSchool }?.name ?? "Selected School"
        return .school(schoolId: selectedSchool ?? "", schoolName: schoolName)
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
      districtId: membership.districtID,
      schoolId: selectedSchool ?? membership.schoolIDs.sorted().first
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

// MARK: - Student Picker

/// Multi-select roster picker used to build a `.specificStudents` cohort.
/// Reuses the canonical `StudentListState` so search, paging, and access
/// policy match the main Students roster.
struct FormAssignmentStudentPickerView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var selection: Set<String>
  let member: MembershipContext
  let repository: any StudentRepository

  @State private var state: StudentListState?
  @State private var workingSelection: Set<String> = []

  var body: some View {
    NavigationStack {
      Group {
        if let state {
          FormAssignmentStudentPickerContent(
            state: state,
            workingSelection: $workingSelection
          )
        } else {
          ProgressView("Loading students…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .navigationTitle("Select Students")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            selection = workingSelection
            dismiss()
          }
        }
      }
    }
    .task {
      guard state == nil else { return }
      workingSelection = selection
      let newState = StudentListState(repository: repository, member: member)
      state = newState
      await newState.load()
    }
  }
}

private struct FormAssignmentStudentPickerContent: View {
  @Bindable var state: StudentListState
  @Binding var workingSelection: Set<String>

  var body: some View {
    Group {
      switch state.phase {
      case .idle, .loading:
        ProgressView("Loading students…")
          .frame(maxWidth: .infinity, maxHeight: .infinity)

      case .empty:
        ContentUnavailableView(
          "No Students",
          systemImage: "person.2.slash",
          description: Text("No students match your search or you don't have access to any roster records.")
        )

      case .permissionDenied:
        ContentUnavailableView(
          "Access Unavailable",
          systemImage: "lock",
          description: Text("A verified staff membership is required to view students.")
        )

      case .failed(let message):
        ContentUnavailableView(
          "Couldn't Load Students",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )

      case .loaded, .refreshing, .offline:
        studentList
      }
    }
    .searchable(text: $state.searchText, prompt: "Search students")
  }

  private var studentList: some View {
    List {
      if !workingSelection.isEmpty {
        Section {
          HStack {
            Text("\(workingSelection.count) selected")
              .font(.subheadline.weight(.medium))
              .foregroundColor(.secondary)
            Spacer()
            Button("Clear") { workingSelection.removeAll() }
              .font(.subheadline)
          }
        }
      }

      Section {
        ForEach(state.students) { record in
          studentRow(record)
            .onAppear {
              if record.id == state.students.last?.id, state.canLoadNextPage {
                Task { await state.loadNextPage() }
              }
            }
        }

        if state.isLoadingNextPage {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
        }
      }
    }
    .listStyle(.plain)
    .refreshable { await state.refresh() }
  }

  private func studentRow(_ record: StudentRecord) -> some View {
    let isSelected = workingSelection.contains(record.id)
    return Button {
      if isSelected {
        workingSelection.remove(record.id)
      } else {
        workingSelection.insert(record.id)
      }
    } label: {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text(record.displayName)
            .font(.body)
            .foregroundColor(.primary)
          Text("Grade \(record.grade)")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Spacer()
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 20))
          .foregroundColor(isSelected ? TMIColors.teal : Color.secondary.opacity(0.5))
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(record.displayName)
    .accessibilityValue(isSelected ? "Selected" : "Not selected")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

#Preview {
  FormAssignmentCreateView(viewModel: FormAssignmentViewModel())
}
