//
//  FormCompletionView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #4
//

import SwiftUI

struct FormCompletionView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.authStateModel) private var authStateModel

  let assignment: FormAssignment
  let existingSubmission: FormSubmission?

  @State private var template: FormTemplate?
  @State private var formData: [String: AnyCodable] = [:]
  @State private var isSaving = false
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var showingSubmitConfirmation = false

  private let templateService = FormTemplateService()
  private let submissionService = FormSubmissionService()

  var body: some View {
    NavigationStack {
      ZStack {
        TMIBackgroundView(variant: .dashboard)

        if isLoading {
          ProgressView("Loading form...")
        } else if let template {
          content(template: template)
        } else {
          Text("Failed to load form")
            .foregroundColor(.secondary)
        }
      }
      .navigationTitle(assignment.templateName)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Menu {
            Button {
              Task {
                await saveDraft()
              }
            } label: {
              Label("Save Draft", systemImage: "square.and.arrow.down")
            }
            .disabled(isSaving)

            Button {
              showingSubmitConfirmation = true
            } label: {
              Label("Submit Form", systemImage: "checkmark.circle")
            }
            .disabled(isSaving || !isFormValid)
          } label: {
            Image(systemName: "ellipsis.circle")
          }
        }
      }
      .task {
        await loadTemplate()
      }
      .alert("Submit Form", isPresented: $showingSubmitConfirmation) {
        Button("Cancel", role: .cancel) {}
        Button("Submit") {
          Task {
            await submitForm()
          }
        }
      } message: {
        Text("Are you sure you want to submit this form? You won't be able to edit it after submission.")
      }
      .alert("Error", isPresented: .constant(errorMessage != nil)) {
        Button("OK") {
          errorMessage = nil
        }
      } message: {
        if let error = errorMessage {
          Text(error)
        }
      }
    }
  }

  // MARK: - Content

  private func content(template: FormTemplate) -> some View {
    ScrollView {
      VStack(spacing: 20) {
        // Instructions
        if let instructions = assignment.instructions {
          InstructionsCard(instructions: instructions)
        }

        // Due date warning
        if let dueDate = assignment.dueDate, dueDate < Date() {
          DueDateWarning(dueDate: dueDate, allowLate: assignment.allowLateSubmissions)
        }

        // Form sections
        ForEach(template.sections) { section in
          FormSectionView(
            section: section,
            formData: $formData
          )
        }

        // Submit button
        Button {
          showingSubmitConfirmation = true
        } label: {
          Text("Submit Form")
            .font(.headline)
            .foregroundColor(Color.tmiTextPrimary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isFormValid ? Color.blue : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!isFormValid || isSaving)
        .padding(.top)
      }
      .padding()
    }
  }

  // MARK: - Actions

  private func loadTemplate() async {
    isLoading = true
    errorMessage = nil

    do {
      template = try await templateService.fetchTemplate(id: assignment.templateId)

      // Load existing data if available
      if let existing = existingSubmission {
        formData = existing.data
      } else {
        // Initialize with empty data
        initializeFormData()
      }

      print("[FormCompletionView] Loaded template: \(template?.name ?? "Unknown")")
    } catch {
      errorMessage = "Failed to load form: \(error.localizedDescription)"
      print("[FormCompletionView] Error: \(errorMessage ?? "Unknown")")
    }

    isLoading = false
  }

  private func initializeFormData() {
    guard let template else { return }

    for section in template.sections {
      for field in section.fields {
        let fieldKey = field.id ?? UUID().uuidString
        if let defaultValue = field.defaultValue {
          formData[fieldKey] = defaultValue
        } else {
          formData[fieldKey] = AnyCodable("")
        }
      }
    }
  }

  private func saveDraft() async {
    guard let studentId = authStateModel.currentUser?.userID else { return }

    isSaving = true
    errorMessage = nil

    do {
      if let existing = existingSubmission, let id = existing.id {
        // Update existing draft
        var updated = existing
        updated.data = formData
        updated.status = "draft"
        try await submissionService.updateSubmission(updated)
      } else {
        // Create new draft
        let submission = FormSubmission(
          formId: assignment.templateId,
          data: formData,
          assignmentId: assignment.id,
          studentId: studentId,
          status: "draft"
        )
        _ = try await submissionService.createSubmission(submission)
      }

      print("[FormCompletionView] Saved draft")
    } catch {
      errorMessage = "Failed to save draft: \(error.localizedDescription)"
      print("[FormCompletionView] Error: \(errorMessage ?? "Unknown")")
    }

    isSaving = false
  }

  private func submitForm() async {
    guard let studentId = authStateModel.currentUser?.userID else { return }

    isSaving = true
    errorMessage = nil

    do {
      if let existing = existingSubmission {
        // Update existing and submit
        var updated = existing
        updated.data = formData
        try await submissionService.submitForm(updated)
      } else {
        // Create new and submit
        let submission = FormSubmission(
          formId: assignment.templateId,
          data: formData,
          assignmentId: assignment.id,
          studentId: studentId,
          status: "submitted"
        )
        _ = try await submissionService.createSubmission(submission)
      }

      print("[FormCompletionView] Submitted form")
      dismiss()
    } catch {
      errorMessage = "Failed to submit form: \(error.localizedDescription)"
      print("[FormCompletionView] Error: \(errorMessage ?? "Unknown")")
    }

    isSaving = false
  }

  // MARK: - Validation

  private var isFormValid: Bool {
    guard let template else { return false }

    for section in template.sections {
      for field in section.fields where field.isRequired {
        let fieldKey = field.id ?? ""
        guard let value = formData[fieldKey]?.value else { return false }

        if let stringValue = value as? String, stringValue.isEmpty {
          return false
        }
      }
    }

    return true
  }
}

// MARK: - Instructions Card

struct InstructionsCard: View {
  let instructions: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Instructions", systemImage: "info.circle")
        .font(.caption)
        .foregroundColor(.blue)

      Text(instructions)
        .font(.subheadline)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.blue.opacity(0.1))
    .cornerRadius(12)
  }
}

// MARK: - Due Date Warning

struct DueDateWarning: View {
  let dueDate: Date
  let allowLate: Bool

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundColor(.red)

      VStack(alignment: .leading, spacing: 4) {
        Text("Past Due Date")
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(.red)

        Text("Due: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
          .font(.caption2)
          .foregroundColor(.secondary)

        if allowLate {
          Text("Late submissions are accepted")
            .font(.caption2)
            .foregroundColor(.green)
        } else {
          Text("Late submissions are not accepted")
            .font(.caption2)
            .foregroundColor(.red)
        }
      }

      Spacer()
    }
    .padding()
    .background(Color.red.opacity(0.1))
    .cornerRadius(12)
  }
}

// MARK: - Form Section View

struct FormSectionView: View {
  let section: FormSection
  @Binding var formData: [String: AnyCodable]

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(section.title)
        .font(.headline)

      if let description = section.description {
        Text(description)
          .font(.caption)
          .foregroundColor(.secondary)
      }

      ForEach(section.fields) { field in
        FormFieldView(field: field, formData: $formData)
      }
    }
    .padding()
    .background(Color(UIColor.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
  }
}

// MARK: - Form Field View

struct FormFieldView: View {
  let field: FormField
  @Binding var formData: [String: AnyCodable]

  private var fieldKey: String {
    field.id ?? UUID().uuidString
  }

  private var fieldValue: Binding<String> {
    Binding(
      get: {
        if let value = formData[fieldKey]?.value as? String {
          return value
        }
        return ""
      },
      set: { newValue in
        formData[fieldKey] = AnyCodable(newValue)
      }
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(field.label)
          .font(.subheadline)
          .fontWeight(.medium)

        if field.isRequired {
          Text("*")
            .foregroundColor(.red)
        }
      }

      switch field.type {
      case .text, .email, .phoneNumber, .url:
        TextField(field.placeholder ?? "Enter text", text: fieldValue)
          .textFieldStyle(.roundedBorder)
          .keyboardType(field.type == .email ? .emailAddress : field.type == .phoneNumber ? .phonePad : field.type == .url ? .URL : .default)

      case .longText:
        TextEditor(text: fieldValue)
          .frame(minHeight: 100)
          .padding(8)
          .background(Color(UIColor.secondarySystemBackground))
          .cornerRadius(8)

      case .number:
        TextField(field.placeholder ?? "Enter number", text: fieldValue)
          .textFieldStyle(.roundedBorder)
          .keyboardType(.numberPad)

      case .multipleChoice, .dropdown:
        if let options = field.options {
          Picker("Select", selection: fieldValue) {
            Text("Select...").tag("")
            ForEach(options, id: \.self) { option in
              Text(option).tag(option)
            }
          }
          .pickerStyle(.menu)
        }

      case .date:
        DatePicker("Select Date", selection: Binding(
          get: { Date() },
          set: { newDate in
            formData[fieldKey] = AnyCodable(newDate.ISO8601Format())
          }
        ), displayedComponents: [.date])

      case .checkbox:
        Toggle(field.label, isOn: Binding(
          get: {
            formData[fieldKey]?.value as? Bool ?? false
          },
          set: { newValue in
            formData[fieldKey] = AnyCodable(newValue)
          }
        ))
        
      default:
        Text("Unsupported field type: \(field.type.rawValue)")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(8)
          .background(Color.gray.opacity(0.1))
          .cornerRadius(8)
      }
    }
  }
}

#Preview {
  FormCompletionView(
    assignment: FormAssignment(
      templateId: "template_001",
      templateName: "Student Intake",
      assignedBy: "teacher_001",
      cohort: .allStudents,
      instructions: "Please fill out this form completely and honestly."
    ),
    existingSubmission: nil
  )
}
