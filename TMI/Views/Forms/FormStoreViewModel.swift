import Foundation
import Observation
import FirebaseFirestore

@Observable
class FormStoreViewModel {
    var formTemplates: [FormTemplate] = []
    var isLoading: Bool = false
    var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    func loadTemplates() {
        isLoading = true
        
        // Simulate network delay or fetch from Firestore
        // For now, we'll use the default templates and maybe some mock data
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            await MainActor.run {
                self.formTemplates = [
                    DefaultFormTemplates.camperRegistrationFormTemplate,
                    DefaultFormTemplates.jobApplicationFormTemplate
                ]
                self.isLoading = false
            }
        }
    }
    
    func createTemplate(_ template: FormTemplate) {
        // Add to local list and save to Firestore
        formTemplates.append(template)
        // TODO: Save to Firestore
    }
}
