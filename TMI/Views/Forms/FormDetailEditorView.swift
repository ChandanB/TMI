//
//  FormDetailEditorView.swift
//  CAMP APP
//
//  Created by Chandan Brown on 3/31/24.
//

import SwiftUI
import FirebaseFirestore
import Observation

@Observable
class FormDetailEditorViewModel {
    var template: FormTemplate = FormTemplate(name: "", templateDescription: "", sections: [], isActive: false)
    
    func saveChanges() {
        Task {
            guard let templateID = template.id else { return }
            let updatedData: [String: Any] = [
                "id": templateID,
                "name": template.name,
                "description": template.templateDescription,
                "isActive": template.isActive,
                "updatedAt": Timestamp(date: Date()),
            ]

//            try await FIREBASE_MANAGER.updateDocument(inCollection: .formTemplates, document: updatedData)
            
        }
    }
}

struct FormDetailEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @Bindable var viewModel = FormDetailEditorViewModel()
    var template: FormTemplate
    
    init(template: FormTemplate) {
        self.template = template
        self.viewModel.template = self.template
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Name", text: $viewModel.template.name)
                    TextField("Description", text: $viewModel.template.templateDescription)
                }
            }
            .navigationTitle("Edit Form")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    viewModel.saveChanges()
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}


#Preview {
    FormDetailEditorView(template: DefaultFormTemplates.camperRegistrationFormTemplate)
}


