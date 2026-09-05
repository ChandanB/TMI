import Foundation
import Testing
@testable import TMI

@Suite("FormStoreViewModel persistence")
struct FormStoreViewModelTests {

    @MainActor
    private func makeTemplate(name: String = "New Template") -> FormTemplate {
        FormTemplate(
            name: name,
            templateDescription: "A test template",
            sections: [],
            isActive: true
        )
    }

    private final class SuccessPersister: FormTemplatePersisting, @unchecked Sendable {
        private(set) var receivedTemplate: FormTemplate?
        let returnedTemplate: FormTemplate

        init(returnedTemplate: FormTemplate) {
            self.returnedTemplate = returnedTemplate
        }

        func createTemplate(_ template: FormTemplate) async throws -> FormTemplate {
            receivedTemplate = template
            return returnedTemplate
        }
    }

    private final class FailurePersister: FormTemplatePersisting, @unchecked Sendable {
        struct PersistenceError: Error {}

        func createTemplate(_ template: FormTemplate) async throws -> FormTemplate {
            throw PersistenceError()
        }
    }

    @Test("Successful creation appends the persisted template and clears the error")
    @MainActor
    func successfulCreationAppendsReturnedTemplate() async {
        var savedTemplate = makeTemplate()
        savedTemplate.id = "saved-id-123"
        let persister = SuccessPersister(returnedTemplate: savedTemplate)
        let viewModel = FormStoreViewModel(persister: persister)

        let draftTemplate = makeTemplate()
        await viewModel.createTemplate(draftTemplate)

        #expect(persister.receivedTemplate?.name == draftTemplate.name)
        #expect(viewModel.formTemplates.count == 1)
        #expect(viewModel.formTemplates.first?.id == "saved-id-123")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Failed creation does not append a template and sets an error message")
    @MainActor
    func failedCreationDoesNotAppendAndSetsError() async {
        let persister = FailurePersister()
        let viewModel = FormStoreViewModel(persister: persister)

        await viewModel.createTemplate(makeTemplate())

        #expect(viewModel.formTemplates.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }
}
