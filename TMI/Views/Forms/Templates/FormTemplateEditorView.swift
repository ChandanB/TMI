//
//  FormTemplateEditorView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #3
//

import SwiftUI

struct FormTemplateEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.authStateModel) private var authStateModel

  @State private var template: FormTemplate
  @State private var isNew: Bool
  @State private var isSaving = false
  @State private var errorMessage: String?
  
  // UI State for adding fields
  @State private var showingFieldSheet = false
  @State private var currentSectionIndex: Int?

  private let templateService = FormTemplateService()
  
  init(template: FormTemplate? = nil) {
      if let template = template {
          _template = State(initialValue: template)
          _isNew = State(initialValue: false)
      } else {
          // Default new template
          _template = State(initialValue: FormTemplate(
              name: "Untitled Form",
              templateDescription: "",
              sections: [],
              isActive: false,
              category: "General"
          ))
          _isNew = State(initialValue: true)
      }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Details") {
          TextField("Form Name", text: $template.name)
          TextField("Description", text: $template.templateDescription, axis: .vertical)
            .lineLimit(2...4)
          TextField("Category", text: Binding(get: { template.category ?? "" }, set: { template.category = $0 }))
          Toggle("Active", isOn: $template.isActive)
        }

        Section {
          Toggle("Scored form", isOn: Binding(
            get: { template.isScored == true },
            set: { template.isScored = $0 }
          ))
          if template.isScored == true {
            ForEach(Binding(get: { template.scoreBands ?? [] }, set: { template.scoreBands = $0 })) { $band in
              HStack {
                TextField("Label", text: $band.label)
                Stepper("From \(band.minimum.formatted())", value: $band.minimum, in: 0...1_000, step: 1)
                  .fixedSize()
              }
            }
            .onDelete { template.scoreBands?.remove(atOffsets: $0) }
            Button("Add score band", systemImage: "plus") {
              let next = (template.scoreBands?.map(\.minimum).max() ?? -5) + 5
              template.scoreBands = (template.scoreBands ?? []) + [FormScoreBand(minimum: next, label: "")]
            }
          }
        } header: {
          Text("Scoring")
        } footer: {
          Text(template.isScored == true
            ? "The server adds up points from choice, checkbox, and rating questions when a response is submitted. Bands label score ranges."
            : "Turn on to score submissions from points you set on each question.")
        }
        
        ForEach(Array($template.sections.enumerated()), id: \.element.id) { index, $section in
          Section {
            TextField("Section Title", text: $section.title)

            ForEach(Array($section.fields.enumerated()), id: \.element.id) { fieldIndex, $field in
              HStack {
                  VStack(alignment: .leading) {
                      Text(field.label)
                          .font(.body)
                      Text([field.type.rawValue.capitalized, scoringSummary(field)].compactMap { $0 }.joined(separator: " · "))
                          .font(.caption)
                          .foregroundColor(.secondary)
                  }
                  Spacer()
                  if field.isRequired {
                      Text("Required")
                          .font(.caption)
                          .foregroundStyle(TMIColors.errorText)
                  }
              }
            }
            .onDelete { offsets in
                section.fields.remove(atOffsets: offsets)
            }

            Button("Add Field") {
                currentSectionIndex = index
                showingFieldSheet = true
            }
          } header: {
            HStack {
                Text("Section \(index + 1)")
                Spacer()
                Button {
                    template.sections.remove(at: index)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(TMIColors.errorText)
                }
            }
          }
        }
        
        Button("Add Section") {
            template.sections.append(FormSection(
                title: "New Section",
                fields: []
            ))
        }
      }
      .navigationTitle(isNew ? "New Template" : "Edit Template")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task { await saveTemplate() }
          }
          .disabled(template.name.isEmpty || isSaving)
        }
      }
      .sheet(isPresented: $showingFieldSheet) {
          FieldEditorSheet(isScored: template.isScored == true) { newField in
              guard let index = currentSectionIndex else { return }
              template.sections[index].fields.append(newField)
          }
          .tmiSheetStyle()
      }
      .alert("Error", isPresented: .constant(errorMessage != nil)) {
          Button("OK") { errorMessage = nil }
      } message: {
          if let msg = errorMessage { Text(msg) }
      }
    }
  }
  
  private func scoringSummary(_ field: FormField) -> String? {
      guard template.isScored == true else { return nil }
      if let points = field.optionPoints, !points.isEmpty {
          return "up to \(points.max()?.formatted() ?? "0") pts"
      }
      if let points = field.points {
          return field.type == .rating ? "rating × \(points.formatted())" : "\(points.formatted()) pts"
      }
      return nil
  }

  private func saveTemplate() async {
      isSaving = true
      guard let user = authStateModel.currentUser,
            let membership = authStateModel.currentMembership else {
          errorMessage = "We couldn’t verify your organization access."
          isSaving = false
          return
      }

      template.districtId = membership.districtID
      if let schoolID = template.schoolId,
         !membership.schoolIDs.contains(schoolID) {
          template.schoolId = nil
      }
      if template.schoolId == nil, membership.schoolIDs.count == 1 {
          template.schoolId = membership.schoolIDs.first
      }
      template.createdBy = user.userID
      
      do {
          if isNew {
              _ = try await templateService.createTemplate(template)
          } else {
              try await templateService.updateTemplate(template)
          }
          dismiss()
      } catch {
          errorMessage = error.localizedDescription
      }
      isSaving = false
  }
}

// MARK: - Field Editor Helper

struct FieldEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    var isScored = false
    var onSave: (FormField) -> Void

    @State private var label = ""
    @State private var type: FieldType = .text
    @State private var isRequired = false
    @State private var placeholder = ""
    @State private var options: [ChoiceOption] = [ChoiceOption(), ChoiceOption()]
    @State private var points: Double = 1

    struct ChoiceOption: Identifiable {
        let id = UUID()
        var text = ""
        var points: Double = 0
    }

    private var addableTypes: [FieldType] {
        FieldType.allCases.filter { $0 != .allCases && $0 != .table && $0 != .file }
    }

    private var cleanedOptions: [ChoiceOption] {
        options.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var isValid: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty && (!type.requiresOptions || cleanedOptions.count >= 2)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Question", text: $label)
                    Picker("Type", selection: $type) {
                        ForEach(addableTypes, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    if !type.requiresOptions && type != .checkbox && type != .rating {
                        TextField("Placeholder", text: $placeholder)
                    }
                    Toggle("Required", isOn: $isRequired)
                }
                if type.requiresOptions {
                    Section {
                        ForEach($options) { $option in
                            HStack {
                                TextField("Option", text: $option.text)
                                if isScored {
                                    Stepper("\(option.points.formatted()) pts", value: $option.points, in: 0...100, step: 1)
                                        .fixedSize()
                                }
                            }
                        }
                        .onDelete { options.remove(atOffsets: $0) }
                        Button("Add option", systemImage: "plus") { options.append(ChoiceOption()) }
                    } header: {
                        Text("Options")
                    } footer: {
                        Text("Add at least two options.")
                    }
                } else if isScored && (type == .checkbox || type == .rating) {
                    Section {
                        Stepper(
                            type == .checkbox ? "Checked scores \(points.formatted()) pts" : "Each star scores \(points.formatted()) pts",
                            value: $points, in: 0...100, step: 1
                        )
                    } header: {
                        Text("Points")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(makeField())
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func makeField() -> FormField {
        let choices = cleanedOptions
        return FormField(
            label: label.trimmingCharacters(in: .whitespaces),
            type: type,
            isRequired: isRequired,
            options: type.requiresOptions ? choices.map { $0.text.trimmingCharacters(in: .whitespaces) } : nil,
            placeholder: placeholder.isEmpty ? nil : placeholder,
            optionPoints: isScored && type.requiresOptions ? choices.map(\.points) : nil,
            points: isScored && (type == .checkbox || type == .rating) ? points : nil
        )
    }
}
