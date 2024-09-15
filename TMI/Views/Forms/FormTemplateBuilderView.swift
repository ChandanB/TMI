//
//  FormBuilderView.swift
//  CAMP APP
//
//  Created by Chandan Brown on 3/25/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct FormTemplateBuilderView: View {
    @Bindable var viewModel = FormTemplateBuilderViewModel()
    @State private var isPreviewMode = false
    
    var body: some View {
        ScrollView {
            VStack {
                previewModeToggle
                
                Divider()
                
                if isPreviewMode {
                    FormPreviewView(template: viewModel.formTemplate)
                } else {
                    CustomToolbarView(viewModel: viewModel)
                        .padding(.horizontal)
                    
                    Divider()
                    
                    ScrollView  {
                        VStack {
                            ForEach(Array(viewModel.formTemplate.sections.enumerated()), id: \.element.id) { index, section in
                                FormSectionCard(sectionIndex: index, section: section, viewModel: viewModel, fields: $viewModel.formTemplate.sections[index].fields)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Form Builder")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var previewModeToggle: some View {
        Picker("Mode", selection: $isPreviewMode) {
            Text("Edit Form").tag(false)
            Text("Preview").tag(true)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
}

struct FormFieldEditorView: View {
    var fieldIndex: Int
    var sectionIndex: Int
    @Binding var field: FormField
    @Bindable var viewModel: FormTemplateBuilderViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            ZLHNTextField(label: "Field Label", placeholder: "Name This Field", text: $field.label)
                .padding()
            
            Divider()
            
            ScrollView {
                if field.type.requiresOptions {
                    OptionsEditor(
                        options: Binding(
                            get: { self.viewModel.formTemplate.sections[self.sectionIndex].fields[self.fieldIndex].options ?? [] },
                            set: { self.viewModel.formTemplate.sections[self.sectionIndex].fields[self.fieldIndex].options = $0.isEmpty ? nil : $0 }
                        ),
                        viewModel: viewModel,
                        sectionIndex: sectionIndex,
                        fieldIndex: fieldIndex
                    )
                    .padding()
                }
                
                ValidationRulesEditor(validationRules: Binding(
                    get: { $field.validationRules.wrappedValue },
                    set: { field.validationRules = $0 }
                ), fieldType: field.type)
                .padding()
            }
        }
        .navigationTitle("\(field.type.defaultLabel.capitalized)")
        .navigationBarItems(trailing: saveButton)
    }
    
    var saveButton: some View {
        Button("Save") {
            self.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    FormTemplateBuilderView(viewModel: FormTemplateBuilderViewModel())
}




