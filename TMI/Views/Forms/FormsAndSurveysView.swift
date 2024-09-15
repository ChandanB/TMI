//
//  FormsAndSurveysView.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import SwiftUI

struct FormsAndSurveysView: View {
    @State private var viewModel = FormStoreViewModel()
    @State private var showingAddForm = false
    @State private var selectedFilter: FormFilter = .all
    @State private var showingFormBuilder = false
    
    enum FormFilter: String, CaseIterable {
        case all = "All"
        case surveys = "Surveys"
        case otherForms = "Other Forms"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterPicker
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(filteredForms) { template in
                            NavigationLink(destination: FormTemplateDetailView(template: template)) {
                                FormStoreCardView(template: template)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Forms & Surveys")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Create New Form") {
                            showingFormBuilder = true
                        }
                        Button("Add Existing Form") {
                            showingAddForm = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddForm) {
                FormCreationView()
            }
            .sheet(isPresented: $showingFormBuilder) {
                FormTemplateBuilderView()
            }
        }
        .onAppear {
            viewModel.loadTemplates()
        }
    }
    
    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(FormFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    private var filteredForms: [FormTemplate] {
        switch selectedFilter {
        case .all:
            return viewModel.formTemplates
        case .surveys:
            return viewModel.formTemplates.filter { $0.category == "Survey" }
        case .otherForms:
            return viewModel.formTemplates.filter { $0.category != "Survey" }
        }
    }
}

struct FormTemplateDetailView: View {
    var template: FormTemplate
    @State private var isAddingTemplate = false
    @State private var showingDynamicForm = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(template.templateDescription)
                    .font(.body)
                    .padding()
                
                Button("Preview Form") {
                    showingDynamicForm = true
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
                FormPreviewView(template: template)
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await saveTemplateToMyCollection()
                    }
                }) {
                    if isAddingTemplate {
                        ProgressView()
                    } else {
                        Text("Add to My Forms")
                    }
                }
                .disabled(isAddingTemplate)
            }
        }
        .sheet(isPresented: $showingDynamicForm) {
            DynamicFormView(viewModel: DynamicFormViewModel())
        }
    }
    
    private func saveTemplateToMyCollection() async {
        isAddingTemplate = true
        // Implement the logic to save the template to the user's collection
        // This would typically involve a call to your Firebase service
        isAddingTemplate = false
    }
}

struct FormCard: View {
    let form: FormTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(form.name)
                    .font(.headline)
                Spacer()
                Image(systemName: form.isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(form.isActive ? .green : .gray)
            }
            
            Text(form.category ?? "Uncategorized")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Label("\(form.sections.count)", systemImage: "list.bullet")
                Spacer()
                Text(form.updatedAt ?? Date(), style: .date)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.tmiBackground)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct FormDetailView: View {
    let form: FormTemplate
    
    var body: some View {
        List {
            ForEach(form.sections) { section in
                Section(header: Text(section.title)) {
                    ForEach(section.fields) { field in
                        VStack(alignment: .leading) {
                            Text(field.label)
                                .font(.headline)
                            Text(field.type.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(form.name)
    }
}

struct AddFormView: View {
    @Binding var forms: [FormTemplate]
    @State private var formName = ""
    @State private var formDescription = ""
    @State private var formCategory = "Survey"
    @State private var sections: [FormSection] = []
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Form Details")) {
                    TextField("Form Name", text: $formName)
                    TextField("Description", text: $formDescription)
                    Picker("Category", selection: $formCategory) {
                        Text("Survey").tag("Survey")
                        Text("Other").tag("Other")
                    }
                }
                
                Section(header: Text("Sections")) {
                    ForEach(sections.indices, id: \.self) { index in
                        NavigationLink(destination: EditSectionView(section: $sections[index])) {
                            Text(sections[index].title)
                        }
                    }
                    .onDelete(perform: deleteSection)
                    
                    Button("Add Section") {
                        sections.append(FormSection(title: "New Section", fields: []))
                    }
                }
            }
            .navigationTitle("Add Form")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveForm()
                    }
                }
            }
        }
    }
    
    private func deleteSection(at offsets: IndexSet) {
        sections.remove(atOffsets: offsets)
    }
    
    private func saveForm() {
        let newForm = FormTemplate(
            name: formName,
            templateDescription: formDescription,
            sections: sections,
            createdAt: Date(),
            updatedAt: Date(),
            isActive: true,
            category: formCategory
        )
        forms.append(newForm)
        presentationMode.wrappedValue.dismiss()
    }
}

struct EditSectionView: View {
    @Binding var section: FormSection
    
    var body: some View {
        Form {
            TextField("Section Title", text: $section.title)
            
            ForEach(section.fields.indices, id: \.self) { index in
                NavigationLink(destination: EditFieldView(field: $section.fields[index])) {
                    Text(section.fields[index].label)
                }
            }
            .onDelete(perform: deleteField)
            
            Button("Add Field") {
                section.fields.append(FormField(label: "New Field", type: .text, isRequired: false))
            }
        }
        .navigationTitle("Edit Section")
    }
    
    private func deleteField(at offsets: IndexSet) {
        section.fields.remove(atOffsets: offsets)
    }
}

struct EditFieldView: View {
    @Binding var field: FormField
    
    var body: some View {
        Form {
            TextField("Field Label", text: $field.label)
            Picker("Field Type", selection: $field.type) {
                ForEach(FieldType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            Toggle("Required", isOn: $field.isRequired)
            
            if field.type == .multipleChoice {
                Section(header: Text("Options")) {
                    ForEach(field.options ?? [], id: \.self) { option in
                        Text(option)
                    }
                    .onDelete(perform: deleteOption)
                    
                    Button("Add Option") {
                        field.options = (field.options ?? []) + ["New Option"]
                    }
                }
            }
        }
        .navigationTitle("Edit Field")
    }
    
    private func deleteOption(at offsets: IndexSet) {
        field.options?.remove(atOffsets: offsets)
    }
}

#Preview {
    FormsAndSurveysView()
}
