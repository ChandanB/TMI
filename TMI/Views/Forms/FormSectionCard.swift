//
//  FormSectionCard.swift
//  CAMP APP
//
//  Created by Chandan Brown on 3/28/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct FormSectionCard: View {
    var sectionIndex: Int
    var section: FormSection
    
    @Bindable var viewModel: FormTemplateBuilderViewModel
    @State private var sectionName: String = "New Section"
    @Binding var fields: [FormField]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FormCardHeader(
                removeAction: { viewModel.removeSections(at: IndexSet(integer: sectionIndex)) },
                toggleExpandedAction: { viewModel.toggleSectionExpanded(section.id ?? "") },
                placeholder: "Section Name",
                text: viewModel.sectionTitleBinding(forSectionAtIndex: sectionIndex),
                sectionIndex: sectionIndex,
                viewModel: viewModel,
                isExpanded: viewModel.isSectionExpanded(section.id ?? ""),
                section: section
            )
            .padding()
            
            if !viewModel.isSectionExpanded(section.id ?? "") {
                VStack {
                    ForEach(Array(section.fields.enumerated()), id: \.element.id) { index, field in
                        let field = section.fields[index]
                        Divider()
                        FormCardSectionFieldRow(
                            fieldIndex: index,
                            sectionIndex: sectionIndex,
                            field: field,
                            fields: $fields,
                            viewModel: viewModel)
                    }
                }
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary, lineWidth: 0.5)
        )
        .padding([.horizontal, .top])
    }
}

struct FormCardHeader: View {
    var removeAction: () -> Void
    var toggleExpandedAction: () -> Void
    var placeholder: String
    @Binding var text: String
    var sectionIndex: Int
    @Bindable var viewModel: FormTemplateBuilderViewModel
    var isExpanded: Bool
    var section: FormSection
    
    var body: some View {
        HStack {
            if viewModel.isEditing {
                Button(action: removeAction) {
                    Image(systemName: "trash")
                }
                .padding(.horizontal)
                .foregroundStyle(.red)
                
                TextField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary, lineWidth: 0.5)
                    )
                
            } else {
                
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                if viewModel.isSectionExpanded(section.id ?? "") {
                    Button(action: { viewModel.moveSection(by: sectionIndex, direction: .up) }) {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(sectionIndex == 0)
                    
                    Button(action: { viewModel.moveSection(by: sectionIndex, direction: .down) }) {
                        Image(systemName: "arrow.down")
                    }
                    .disabled(sectionIndex == viewModel.formTemplate.sections.count - 1)
                    .padding(.leading)
                }               
            }
            
            if !viewModel.isSectionExpanded(section.id ?? "") {
                Menu {
                    Section(header: Text("Add Field To Section")) {
                        ForEach(FieldType.allCases, id: \.self) { type in
                            if type != .allCases {
                                Button(type.defaultLabel) {
                                    viewModel.addEmptyField(toSectionAtIndex: sectionIndex, fieldType: type)
                                }
                            }
                        }
                    }
                } label: {
                    Label("Add", systemImage: "plus.circle")
                        .labelStyle(IconOnlyLabelStyle())
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
            }
            
            Button(action: toggleExpandedAction) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .frame(maxWidth: 12)
            }
            .padding(.leading)
        }
    }
}

struct FormCardSectionFieldRow: View {
    var fieldIndex: Int
    var sectionIndex: Int
    var field: FormField
    @Binding var fields: [FormField]
    @Bindable var viewModel: FormTemplateBuilderViewModel
    
    var body: some View {
        HStack {
            if viewModel.isEditing {
                Button(action: { viewModel.removeField(fromSection: sectionIndex, at: IndexSet(integer: fieldIndex)) }) {
                    Image(systemName: "minus.circle")
                }
                .padding(.horizontal)
                .foregroundStyle(.red)
            }
            
            CustomNavigationLink(destination: FormFieldEditorView(fieldIndex: fieldIndex, sectionIndex: sectionIndex, field: $fields[fieldIndex], viewModel: viewModel)) {
                Text(field.label.isEmpty ? field.type.defaultLabel : field.label)
                    .title()
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
            }
            
            if viewModel.isEditing {
                Spacer()
                Button(action: { viewModel.moveField(inSection: sectionIndex, fieldIndex: fieldIndex, direction: .up) }) {
                    Image(systemName: "arrow.up")
                }
                .disabled(fieldIndex == 0)
                
                Button(action: { viewModel.moveField(inSection: sectionIndex, fieldIndex: fieldIndex, direction: .down) }) {
                    Image(systemName: "arrow.down")
                }
                .disabled(fieldIndex >= viewModel.formTemplate.sections[sectionIndex].fields.count - 1)
                
            } else {
                CustomNavigationLink(destination: FormFieldEditorView(fieldIndex: fieldIndex, sectionIndex: sectionIndex, field: $fields[fieldIndex], viewModel: viewModel)) {
                    Image(systemName: "chevron.right")
                        .padding(.leading)
                        .foregroundColor(.black)
                }
            }
        }
        .padding()
        .background(Color.white)
    }
}

struct CustomToolbarView: View {
    @Bindable var viewModel: FormTemplateBuilderViewModel
    @State private var showingPredefinedSections = false
    
    var body: some View {
        HStack {
            Button(viewModel.isEditing ? "Done" : "Edit Sections") {
                viewModel.isEditing.toggle()
            }
            
            Spacer()
            
            Menu {
                Section(header: Text("Sections")) {
                    Button("Add Section Template") {
                        showingPredefinedSections = true
                    }
                    Button("Add New Section") {
                        viewModel.addNewSection()
                    }
                }
            } label: {
                Text("Add Section")
                    .title()
                    .foregroundStyle(.blue)
            }
            .padding(.leading)
        }
        .padding()
        .foregroundColor(.primary)
        .sheet(isPresented: $showingPredefinedSections) {
            PredefinedSectionsView(viewModel: viewModel)
        }
    }
    
    private func addFieldToLastSection(fieldType: FieldType) {
        guard let lastSection = viewModel.formTemplate.sections.last else {
            print("No sections available to add a field to.")
            return
        }
        
        viewModel.addField(to: viewModel.formTemplate.sections.count - 1, fieldType: fieldType, sectionId: lastSection.id)
    }
    
}

struct PredefinedSectionsView: View {
    @Bindable var viewModel: FormTemplateBuilderViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationStack {
            List(DefaultSectionTemplates.all, id: \.id) { section in
                DisclosureGroup {
                    ForEach(section.fields, id: \.id) { field in
                        Text(field.label)
                            .padding(.leading, 20)
                            .foregroundColor(.gray)
                    }
                } label: {
                    HStack {
                        Text(section.title)
                            .foregroundColor(.primary)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.addDefaultSection(section)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .accentColor(.primary)
            }
            .listStyle(InsetGroupedListStyle()) 
            .navigationBarTitle("Select A Section Template")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

