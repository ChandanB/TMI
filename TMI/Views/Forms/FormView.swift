//

import SwiftUI
import SDWebImageSwiftUI
import Combine
import Observation

@Observable
class DynamicFormViewModel {
    var formTemplate: FormTemplate? = DefaultFormTemplates.camperRegistrationFormTemplate
    var formData: [String: AnyCodable] = [:]
    var isLoading: Bool = false
    var error: Error?
    var showDocumentPicker: Bool = false
    var formSections: [FormSection] = []

    func loadFormTemplate(withId id: String) {
        isLoading = false
        Task {
            let template: FormTemplate = try await FIREBASE_MANAGER.fetchDocument(inCollection: .formTemplates, withId: id)
            self.formTemplate = template
        }
    }
    
    func updateData(forField fieldId: String, withValue value: AnyCodable) {
        formData[fieldId] = value
    }
    
    func submitForm() {
        isLoading = true
        guard let formId = formTemplate?.id else { return }        
        Task {
            do {
                try await FIREBASE_MANAGER.handleFormSubmission(formId: formId, submissionData: formData)
                isLoading = false
            } catch {
                print("Error submitting form: \(error)")
            }
        }
    }
    
    func uploadFile() {
        showDocumentPicker = true
    }
    
    func loadFormSections() {
        self.formSections = [DefaultSectionTemplates.personalDetails, DefaultSectionTemplates.eductionBackground, DefaultSectionTemplates.emergencyContact, DefaultSectionTemplates.fileUpload]
    }
}

struct DynamicFormView: View {
    @Bindable var viewModel: DynamicFormViewModel

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
            } else {
                VStack {
                    ForEach(viewModel.formSections, id: \.id) { section in
                        DynamicFormSectionView(section: section, viewModel: viewModel)
                    }
                    Button("Submit", action: {
                        viewModel.submitForm()
                    })
                    .padding(.top)
                    .disabled(viewModel.isLoading)
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.loadFormSections()
        }
    }
}

struct DynamicFormSectionView: View {
    let section: FormSection
    @Bindable var viewModel: DynamicFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.title2)
                .bold()

            ForEach(section.fields, id: \.id) { field in
                DynamicFormFieldView(viewModel: viewModel, field: field)
            }
            
            Divider()
                .padding(.vertical)
        }
    }
}

struct DynamicFormFieldView: View {
    @Bindable var viewModel: DynamicFormViewModel
    let field: FormField
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(field.label.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.top)
                        
            generateFieldView(for: field)
        }
    }
}

#Preview {
    DynamicFormView(viewModel: DynamicFormViewModel())
}

extension DynamicFormFieldView {
    
    @ViewBuilder
    func generateFieldView(for field: FormField) -> some View {
        let fieldID = field.id ?? ""
        switch field.type {
        case .allCases:
            Text("")
        case .text, .email, .phoneNumber:
            ZLHNTextField(placeholder: "Enter \(field.label)", text: stringBinding(for: fieldID))
            
        case .longText:
            ZLHNMultilineTextField(placeholder: "Enter \(field.label)", text: stringBinding(for: fieldID), limit: 1000)
            
        case .number:
            ZLHNTextField(placeholder: "Enter \(field.label)", text: stringBinding(for: fieldID))
                .keyboardType(.numberPad)
            
        case .date:
            DatePickerView(label: "Date", date: dateBinding(for: fieldID), displayedComponents: .date)
            
        case .time:
            DatePickerView(label: "Time", date: dateBinding(for: fieldID), displayedComponents: .hourAndMinute)
            
        case .dateTime:
            DatePickerView(label: field.label, date: dateBinding(for: fieldID), displayedComponents: [.date, .hourAndMinute])
            
        case .checkbox:
            Toggle(field.label, isOn: boolBinding(for: fieldID))
            
        case .multipleChoice:
            MultipleChoiceField(label: field.label, selectedOptions: stringArrayBinding(for: fieldID), options: field.options ?? [])
            
        case .dropdown:
            DropdownField(label: field.label, selection: stringBinding(for: fieldID), options: field.options ?? [])
            
        case .url:
            ZLHNTextField(placeholder: "Enter \(field.label)", text: stringBinding(for: fieldID))
                .keyboardType(.URL)
                .autocapitalization(.none)
            
        case .file:
            Button(action: {
                viewModel.uploadFile()
            }) {
                HStack {
                    Image(systemName: "paperclip")
                    Text("Upload File")
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
        }
    }
    
    private func stringBinding(for key: String) -> Binding<String> {
        Binding<String>(
            get: {
                self.viewModel.formData[key]?.value as? String ?? ""
            },
            set: { newValue in
                self.viewModel.formData[key] = AnyCodable(newValue)
            }
        )
    }
    
    private func boolBinding(for key: String) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                guard let data = viewModel.formData[key], let boolValue = data.value as? Bool else {
                    return false
                }
                return boolValue
            },
            set: {
                viewModel.formData[key] = AnyCodable($0)
            }
        )
    }
    
    private func dateBinding(for key: String) -> Binding<Date> {
        Binding<Date>(
            get: {
                guard let data = viewModel.formData[key], let dateValue = data.value as? Date else {
                    return Date()
                }
                return dateValue
            },
            set: {
                viewModel.formData[key] = AnyCodable($0)
            }
        )
    }
    
    private func stringArrayBinding(for key: String) -> Binding<[String]> {
        Binding<[String]>(
            get: {
                guard let data = viewModel.formData[key], let arrayValue = data.value as? [String] else {
                    return []
                }
                return arrayValue
            },
            set: {
                viewModel.formData[key] = AnyCodable($0)
            }
        )
    }
}
