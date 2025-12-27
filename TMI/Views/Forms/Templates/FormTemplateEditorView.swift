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
        
        ForEach($template.sections.indices, id: \.self) { index in
          Section {
            TextField("Section Title", text: $template.sections[index].title)
            
            ForEach($template.sections[index].fields.indices, id: \.self) { fieldIndex in
              HStack {
                  VStack(alignment: .leading) {
                      Text(template.sections[index].fields[fieldIndex].label)
                          .font(.body)
                      Text(template.sections[index].fields[fieldIndex].type.rawValue.capitalized)
                          .font(.caption)
                          .foregroundColor(.secondary)
                  }
                  Spacer()
                  if template.sections[index].fields[fieldIndex].isRequired {
                      Text("Required")
                          .font(.caption)
                          .foregroundColor(.red)
                  }
              }
            }
            .onDelete { offsets in
                template.sections[index].fields.remove(atOffsets: offsets)
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
                        .foregroundColor(.red)
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
          FieldEditorSheet { newField in
              guard let index = currentSectionIndex else { return }
              template.sections[index].fields.append(newField)
          }
      }
      .alert("Error", isPresented: .constant(errorMessage != nil)) {
          Button("OK") { errorMessage = nil }
      } message: {
          if let msg = errorMessage { Text(msg) }
      }
    }
  }
  
  private func saveTemplate() async {
      isSaving = true
      // Set user info
      if let user = authStateModel.currentUser {
          template.districtId = user.districtId
          template.schoolId = user.schoolId
          template.createdBy = user.userID
      }
      
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
    var onSave: (FormField) -> Void
    
    @State private var label = ""
    @State private var type: FieldType = .text
    @State private var isRequired = false
    @State private var placeholder = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Field Label", text: $label)
                    Picker("Type", selection: $type) {
                        ForEach(FieldType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    TextField("Placeholder", text: $placeholder)
                    Toggle("Required", isOn: $isRequired)
                }
            }
            .navigationTitle("Add Field")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let field = FormField(
                            label: label,
                            type: type,
                            isRequired: isRequired,
                            placeholder: placeholder.isEmpty ? nil : placeholder
                        )
                        onSave(field)
                        dismiss()
                    }
                    .disabled(label.isEmpty)
                }
            }
        }
    }
}
