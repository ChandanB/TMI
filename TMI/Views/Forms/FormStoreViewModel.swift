import Foundation
import Observation
import FirebaseFirestore

protocol FormTemplatePersisting {
    func createTemplate(_ template: FormTemplate) async throws -> FormTemplate
}

extension FormTemplateService: FormTemplatePersisting {}

@Observable
class FormStoreViewModel {
    var formTemplates: [FormTemplate] = []
    var isLoading: Bool = false
    var errorMessage: String?

    private let persister: FormTemplatePersisting

    init(persister: FormTemplatePersisting = FormTemplateService()) {
        self.persister = persister
    }

    func loadTemplates() {
        isLoading = true
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                self.formTemplates = [
                    DefaultFormTemplates.studentEnrollmentFormTemplate,
                    DefaultFormTemplates.mentorApplicationFormTemplate
                ]
                self.isLoading = false
            }
        }
    }

    @MainActor
    func createTemplate(_ template: FormTemplate) async {
        do {
            let savedTemplate = try await persister.createTemplate(template)
            formTemplates.append(savedTemplate)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to save the template. Please try again."
        }
    }
}
