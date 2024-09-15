//
//  MyFormsView.swift
//  CAMP APP
//
//  Created by Chandan Brown on 3/29/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import Observation

@Observable
class MyFormsViewModel {
    var formTemplates: [FormTemplate] = [DefaultFormTemplates.camperRegistrationFormTemplate, DefaultFormTemplates.jobApplicationFormTemplate, DefaultFormTemplates.camperRegistrationFormTemplate]
    
    private var listener: ListenerRegistration?

    init() {
        fetchFormTemplates()
    }
    
    func fetchFormTemplates() {
        Task {
//            listener = FIREBASE_MANAGER.fetchCollectionData(
//                collectionReference: FirestoreCollection.formTemplates.reference(),
//                orderBy: FirestoreConstants.timestamp,
//                descending: true
//            ) { [weak self] (result: Result<[FormTemplate], Error>) in
//                switch result {
//                case .success(let templates):
//                    DispatchQueue.main.async {
//                        self?.formTemplates.append(contentsOf: templates)
//                    }
//                case .failure(let error):
//                    print("Error fetching post comments: \(error.localizedDescription)")
//                }
//            }
        }
    }
    
    func createFormTemplate(_ template: FormTemplate) {
        Task {
            do {
                try await FIREBASE_MANAGER.createDocument(inCollection: .formTemplates, document: template)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func updateFormTemplate(_ template: FormTemplate) {
        Task {
            do {
                try await FIREBASE_MANAGER.updateDocument(inCollection: .formTemplates, document: template)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func deleteFormTemplate(_ template: FormTemplate) {
        guard let documentID = template.id else { return }
        Task {
            do {
                try await FIREBASE_MANAGER.deleteDocument(inCollection: .formTemplates, withId: documentID)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

struct MyFormsView: View {
    @State var viewModel = MyFormsViewModel()
    @State private var showingFormEditor = false
    @State private var showingCreationView = false
    @State private var selectedFormTemplate: FormTemplate?
    
    var body: some View {
        ScrollView {
            VStack {
                HStack {
                    Text("My Forms")
                    Spacer()
                    Button(action: {
                        self.selectedFormTemplate = nil
                        self.showingCreationView = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                .padding()
                
                List(viewModel.formTemplates) { template in
                    Button(action: {
                        self.selectedFormTemplate = template
                        self.showingFormEditor = true
                    }) {
                        FormRowView(template: template)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete") {
                            viewModel.deleteFormTemplate(template)
                        }.tint(.red)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button("Edit") {
                            self.selectedFormTemplate = template
                            self.showingFormEditor = true
                        }.tint(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingFormEditor) {
            if let templateToEdit = selectedFormTemplate {
                FormDetailEditorView(template: templateToEdit)
            }
        }
        .sheet(isPresented: $showingCreationView) {
            FormCreationView()
        }
    }
}

#Preview {
    MyFormsView(viewModel: MyFormsViewModel())
}

struct FormRowView: View {
    var template: FormTemplate
    
    var body: some View {
        HStack {
            Image(systemName: template.imageName ?? "doc.plaintext")
                .foregroundColor(.secondary)
                .imageScale(.large)
                .padding(.trailing, 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(template.templateDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if template.isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}
