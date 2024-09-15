//
//  FormTemplateBuilderViewModel.swift
//  CAMP APP
//
//  Created by Chandan Brown on 3/26/24.
//

import SwiftUI
import UniformTypeIdentifiers
import Observation

@Observable
class FormTemplateBuilderViewModel {
    var formTemplate: FormTemplate = FormTemplate(
        id: UUID().uuidString,
        name: "",
        templateDescription: "",
        sections: [],
        createdAt: Date(),
        updatedAt: Date(),
        isActive: true
    )
    
    var isEditing: Bool = false
    var expandedSectionIDs: Set<String> = []
    var currentDraggedFieldIndex: Int?
        
    func addNewSection() {
        let newSection = FormSection(id: UUID().uuidString, title: "New Section", fields: [])
        self.formTemplate.sections.append(newSection)
        saveTemplate()
    }
    
    func removeSection(at offsets: IndexSet) {
        formTemplate.sections.remove(atOffsets: offsets)
        saveTemplate()
    }
    
    func updateSectionName(at index: Int, with title: String) {
        if formTemplate.sections.indices.contains(index) {
            formTemplate.sections[index].title = title
            saveTemplate()
        }
    }
    
    func addDefaultSection(_ sectionTemplate: FormSection) {
        var newSection = sectionTemplate
        newSection.id = UUID().uuidString
        newSection.fields = newSection.fields.map { field -> FormField in
            var newField = field
            newField.id = UUID().uuidString
            return newField
        }
        self.formTemplate.sections.append(newSection)
        saveTemplate()
    }
    
    func addField(to sectionIndex: Int, fieldType: FieldType, sectionId: String? = nil) {
        let newField = FormField(
            id: UUID().uuidString,
            label: fieldType.defaultLabel,
            type: fieldType,
            isRequired: false,
            validationRules: [],
            options: fieldType.requiresOptions ? ["Option 1"] : nil
        )
        
        if let id = sectionId, let index = formTemplate.sections.firstIndex(where: { $0.id == id }) {
            formTemplate.sections[index].fields.append(newField)
        } else if formTemplate.sections.indices.contains(sectionIndex) {
            formTemplate.sections[sectionIndex].fields.append(newField)
        }
        
        saveTemplate()
    }
    
    func addEmptyField(toSectionAtIndex sectionIndex: Int, fieldType: FieldType) {
        guard formTemplate.sections.indices.contains(sectionIndex) else { return }
        let newField = FormField(
            id: UUID().uuidString,
            label: fieldType.defaultLabel,
            type: fieldType,
            isRequired: false,
            validationRules: [],
            options: fieldType.requiresOptions ? ["Option 1"] : nil
        )
        formTemplate.sections[sectionIndex].fields.append(newField)
        saveTemplate()
    }
    
    func removeSections(at offsets: IndexSet) {
        formTemplate.sections.remove(atOffsets: offsets)
        saveTemplate()
    }
    
    func removeField(fromSection sectionIndex: Int, at index: IndexSet) {
        guard formTemplate.sections.indices.contains(sectionIndex) else { return }
        formTemplate.sections[sectionIndex].fields.remove(atOffsets: index)
        saveTemplate()
    }
    
    func updateFieldLabel(inSection sectionIndex: Int, fieldIndex: Int, with label: String) {
        guard formTemplate.sections.indices.contains(sectionIndex),
              formTemplate.sections[sectionIndex].fields.indices.contains(fieldIndex) else { return }
        formTemplate.sections[sectionIndex].fields[fieldIndex].label = label
        saveTemplate()
    }
    
    func toggleFieldRequired(inSection sectionIndex: Int, fieldIndex: Int) {
        guard formTemplate.sections.indices.contains(sectionIndex),
              formTemplate.sections[sectionIndex].fields.indices.contains(fieldIndex) else { return }
        formTemplate.sections[sectionIndex].fields[fieldIndex].isRequired.toggle()
        saveTemplate()
    }
    
    func toggleSectionExpanded(_ sectionID: String) {
        if expandedSectionIDs.contains(sectionID) {
            expandedSectionIDs.remove(sectionID)
        } else {
            expandedSectionIDs.insert(sectionID)
        }
    }
    
    func isSectionExpanded(_ sectionID: String) -> Bool {
        expandedSectionIDs.contains(sectionID)
    }
    
    func updateOptions(forFieldInSection sectionIndex: Int, fieldIndex: Int, with options: [String]) {
        guard formTemplate.sections.indices.contains(sectionIndex),
              formTemplate.sections[sectionIndex].fields.indices.contains(fieldIndex),
              formTemplate.sections[sectionIndex].fields[fieldIndex].type.requiresOptions else { return }
        formTemplate.sections[sectionIndex].fields[fieldIndex].options = options
        saveTemplate()
    }
    
    func duplicateField(inSection sectionIndex: Int, fieldIndex: Int) {
        guard formTemplate.sections.indices.contains(sectionIndex),
              formTemplate.sections[sectionIndex].fields.indices.contains(fieldIndex) else { return }
        var duplicatedField = formTemplate.sections[sectionIndex].fields[fieldIndex]
        duplicatedField.id = UUID().uuidString // Assign a new unique ID
        formTemplate.sections[sectionIndex].fields.insert(duplicatedField, at: fieldIndex + 1)
        saveTemplate()
    }
    
    func setValidationRules(forFieldInSection sectionIndex: Int, fieldIndex: Int, with rules: [ValidationRule]) {
        guard formTemplate.sections.indices.contains(sectionIndex),
              formTemplate.sections[sectionIndex].fields.indices.contains(fieldIndex) else { return }
        formTemplate.sections[sectionIndex].fields[fieldIndex].validationRules = rules
        saveTemplate()
    }
    
    func getPreview() -> FormPreviewView {
        FormPreviewView(template: formTemplate)
    }
    
    func loadTemplate(withId id: String)  {
        Task {
            do {
                let loadedTemplate: FormTemplate = try await FIREBASE_MANAGER.fetchDocument(inCollection: .formTemplates, withId: id)
                formTemplate = loadedTemplate
            } catch {
                print("Error loading template: \(error)")
            }
        }
    }
    
    func saveTemplate()  {
        Task {
            do {
                if formTemplate.id == nil {
                    try await FIREBASE_MANAGER.createDocument(inCollection: .formTemplates, document: formTemplate)
                } else {
                    try await FIREBASE_MANAGER.updateDocument(inCollection: .formTemplates, document: formTemplate)
                }
            } catch {
                print("Error saving template: \(error)")
            }
        }
    }
    
    func importDefaultCamperRegistrationTemplate() {
        let template = DefaultFormTemplates.camperRegistrationFormTemplate
        formTemplate = template
        //        saveTemplate()
    }
    
    func exportTemplateAsJSON() -> String? {
        guard let jsonData = try? JSONEncoder().encode(formTemplate) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }
    
    func importTemplateFromJSON(_ jsonString: String) async {
        guard let jsonData = jsonString.data(using: .utf8),
              let importedTemplate = try? JSONDecoder().decode(FormTemplate.self, from: jsonData) else { return }
        formTemplate = importedTemplate
        saveTemplate()
    }
    
    func addOptionToField(inSection sectionIndex: Int, fieldIndex: Int, option: String) {
        guard formTemplate.sections.indices.contains(sectionIndex),
              formTemplate.sections[sectionIndex].fields.indices.contains(fieldIndex),
              formTemplate.sections[sectionIndex].fields[fieldIndex].type.requiresOptions else { return }
        
        var field = formTemplate.sections[sectionIndex].fields[fieldIndex]
        
        if field.options != nil {
            field.options!.append(option)
        } else {
            field.options = [option]
        }
        
        formTemplate.sections[sectionIndex].fields[fieldIndex] = field
        saveTemplate()
    }
    
    func removeOptionFromField(inSection sectionIndex: Int, fieldIndex: Int, optionIndex: Int) {
        guard formTemplate.sections.indices.contains(sectionIndex),
              formTemplate.sections[sectionIndex].fields.indices.contains(fieldIndex),
              let options = formTemplate.sections[sectionIndex].fields[fieldIndex].options,
              options.indices.contains(optionIndex) else { return }
        
        var field = formTemplate.sections[sectionIndex].fields[fieldIndex]
        field.options!.remove(at: optionIndex)
        
        formTemplate.sections[sectionIndex].fields[fieldIndex] = field
        saveTemplate()
    }
}

extension FormTemplateBuilderViewModel {
    private func swapFields(inSection sectionIndex: Int, fromIndex: Int, toIndex: Int) {
        withAnimation {
            formTemplate.sections[sectionIndex].fields.swapAt(fromIndex, toIndex)
        }
        saveTemplate()
    }
    
    func moveSection(by index: Int, direction: MoveDirection) {
        let newIndex = (direction == .up) ? index - 1 : index + 1
        guard newIndex >= 0, newIndex < formTemplate.sections.count else { return }
        formTemplate.sections.swapAt(index, newIndex)
        saveTemplate()
    }
    
    func moveField(inSection sectionIndex: Int, fieldIndex: Int, direction: MoveDirection) {
        let newIndex = (direction == .up) ? fieldIndex - 1 : fieldIndex + 1
        guard formTemplate.sections.indices.contains(sectionIndex),
              newIndex >= 0, newIndex < formTemplate.sections[sectionIndex].fields.count else { return }
        formTemplate.sections[sectionIndex].fields.swapAt(fieldIndex, newIndex)
        saveTemplate()
    }
    
    enum MoveDirection {
        case up
        case down
    }
    
    private func calculateTargetIndex(from location: CGPoint) -> Int {
        guard !formTemplate.sections.isEmpty else { return 0 }
        
        let sortedSections = formTemplate.sections.sorted {
            guard let loc1 = $0.location, let loc2 = $1.location else { return false }
            return loc1.y < loc2.y
        }
        
        let closest = sortedSections.enumerated().min(by: {
            abs($0.1.location?.y ?? 0 - location.y) < abs($1.1.location?.y ?? 0 - location.y)
        })
        
        return closest?.0 ?? 0
    }
    
    private func updateSectionLocations() {
        var updatedSections = [FormSection]()
        
        for (index, var section) in formTemplate.sections.enumerated() {
            let newY = CGFloat(index) * 100.0
            
            section.location = CGPoint(x: section.location?.x ?? 0, y: newY)
            
            updatedSections.append(section)
        }
        
        formTemplate.sections = updatedSections
    }
}

extension FormTemplateBuilderViewModel {
    func sectionTitleBinding(forSectionAtIndex index: Int) -> Binding<String> {
        Binding<String>(
            get: {
                if self.formTemplate.sections.indices.contains(index) {
                    return self.formTemplate.sections[index].title
                } else {
                    return ""
                }
            },
            set: { newTitle in
                if self.formTemplate.sections.indices.contains(index) {
                    self.formTemplate.sections[index].title = newTitle
                }
            }
        )
    }
}
