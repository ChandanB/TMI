//
//  FormService.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import Firebase

extension FirebaseManager {
    // MARK: Save Form Template
    func handleFormSubmission(formId: String, submissionData: [String: AnyCodable]) async throws {
        let template: FormTemplate = DefaultFormTemplates.camperRegistrationFormTemplate

        for section in template.sections {
            for field in section.fields {
                guard let fieldID = field.id else { continue }

                guard let submittedValue = submissionData[fieldID] else {
                    if field.isRequired {
                        throw ValidationError.missingRequiredField(fieldID)
                    }
                    continue
                }

                if let validator = FormFieldValidator.validators[field.type], !validator(submittedValue) {
                    throw ValidationError.invalidDataType(fieldID)
                }
            }
        }

        let submission = FormSubmission(formId: formId, data: submissionData, submissionDate: Date())
        try await createDocument(inCollection: .formSubmissions, document: submission)
    }
    
    func addFormToUserCollection(userId: String, formId: String) async throws {
        let userMyFormsRef = FirestoreCollection.users.reference().document(userId).collection("myForms")
        try await userMyFormsRef.document(formId).setData(["formId": formId, "addedOn": Timestamp(date: Date())])
    }
    
    func addFormTemplateToUserCollection(formTemplateId: String, userId: String) async throws {
        var user: User = try await FIREBASE_MANAGER.fetchDocument(inCollection: .users, withId: userId)
        var formTemplates = user.formTemplates
        if !formTemplates.contains(formTemplateId) {
            formTemplates.append(formTemplateId)
            user.formTemplates = formTemplates
            try await updateDocument(inCollection: FirestoreCollection.users, document: user)
        } else if user.formTemplates == [] {
            user.formTemplates = [formTemplateId]
            try await updateDocument(inCollection: FirestoreCollection.users, document: user)
        }
    }
}

enum ValidationError: Error, LocalizedError {
    case missingRequiredField(String)
    case invalidDataType(String)
    
    var errorDescription: String? {
        switch self {
        case .missingRequiredField(let fieldId):
            return "Missing required field: \(fieldId)"
        case .invalidDataType(let fieldId):
            return "Invalid data type for field: \(fieldId)"
        }
    }
}

struct FormFieldValidator {
    static let validators: [FieldType: (AnyCodable) -> Bool] = [
        .text: { $0.value is String },
        .number: { $0.value is Int || $0.value is Double },
        .date: { $0.value is Date },
        .longText: { $0.value is String },
        .dateTime: { $0.value is Date },
        .time: { $0.value is Date },
        .dropdown: { $0.value is String },
        .multipleChoice: { $0.value is [String] },
        .checkbox: { $0.value is Bool },
        .email: {
            guard let email = $0.value as? String else { return false }
            return validateEmail(email)
        },
        .phoneNumber: {
            guard let phoneNumber = $0.value as? String else { return false }
            return validatePhoneNumber(phoneNumber)
        },
        .url: {
            guard let urlString = $0.value as? String, let url = URL(string: urlString) else { return false }
            return UIApplication.shared.canOpenURL(url)
        },
        .file: { $0.value is String } // Assuming file value is a string (e.g., a URL to the file); might require custom validation
    ]
    
    private static func validateEmail(_ email: String) -> Bool {
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailPattern)
        return emailPredicate.evaluate(with: email)
    }
    
    private static func validatePhoneNumber(_ phoneNumber: String) -> Bool {
        let phonePattern = "^\\d{3}-\\d{3}-\\d{4}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phonePattern)
        return phonePredicate.evaluate(with: phoneNumber)
    }
}


