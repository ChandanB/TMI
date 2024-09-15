//
//  FormCreationView.swift
//  CAMP APP
//
//  Created by Chandan Brown on 4/12/24.
//

import SwiftUI
import FirebaseFirestore
import Observation

@Observable
class FormCreationViewModel {
    var name: String = ""
    var description: String = ""
    var isActive: Bool = true
    
    func createTemplate(completion: @escaping (Bool, Error?) -> Void) {
        let newTemplateData: [String: Any] = [
            "name": name,
            "description": description,
            "isActive": isActive,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            // Add additional fields as necessary
        ]
        
        FIRESTORE_DATABASE.collection("formTemplates").addDocument(data: newTemplateData) { error in
            if let error = error {
                completion(false, error)
            } else {
                completion(true, nil)
            }
        }
    }
}

struct FormCreationView: View {
    @Bindable var viewModel = FormCreationViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("New Form Details")) {
                    TextField("Name", text: $viewModel.name)
                    TextField("Description", text: $viewModel.description)
                    Toggle("Active", isOn: $viewModel.isActive)
                }
                Button("Create") {
                    viewModel.createTemplate { success, error in
                        // Handle the response, such as showing an error alert or confirming success.
                        // Dismiss the view if successful or show error feedback.
                    }
                }
            }
            .navigationTitle("Create New Form")
            .navigationBarItems(
                leading: Button("Cancel") {
                    // Handle cancel action, e.g., dismiss the view.
                }
            )
        }
    }
}

#Preview {
    FormCreationView()
}
