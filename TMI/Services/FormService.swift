//
//  FormService.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import Firebase
import FirebaseAuth
import Foundation

// MARK: - Optional Protocol Helper

protocol OptionalProtocol {
    var isNil: Bool { get }
}

extension Optional: OptionalProtocol {
    var isNil: Bool {
        return self == nil
    }
}

extension FirebaseManager {
    // MARK: - Form Template Management
    
    /// Fetches all available form templates
    func fetchFormTemplates() async throws -> [FormTemplate] {
        return try await fetchDocuments(inCollection: .formTemplates)
    }
    
    /// Creates a new form template
    func createFormTemplate(_ template: FormTemplate) async throws -> FormTemplate {
        try await createDocument(inCollection: .formTemplates, document: template)
        return template
    }
    
    /// Updates an existing form template
    func updateFormTemplate(_ template: FormTemplate) async throws {
        try await updateDocument(inCollection: .formTemplates, document: template)
    }
    
    // MARK: - Form Submission Management
    
    /// Handles form submission with proper validation
    func handleFormSubmission(formId: String, submissionData: [String: AnyCodable]) async throws {
        // Fetch the actual template for validation
        let template: FormTemplate = try await fetchDocument(inCollection: .formTemplates, withId: formId)

        // Validate submission data against template
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
                
                // Validate against field-specific rules
                for rule in field.validationRules {
                    try validateFieldRule(value: submittedValue, rule: rule, fieldId: fieldID)
                }
            }
        }

        // Create submission with metadata
        var submission = FormSubmission(formId: formId, data: submissionData, submissionDate: Date())
        
        // Add current user context if available
        if let user = Auth.auth().currentUser {
            submission.data["submittedBy"] = AnyCodable(user.uid)
        }
        
        try await createDocument(inCollection: .formSubmissions, document: submission)
        
        // Update template usage counter
        var updatedTemplate = template
        updatedTemplate.uses += 1
        try await updateDocument(inCollection: .formTemplates, document: updatedTemplate)
    }
    
    /// Fetches form submissions by a specific user
    func fetchUserFormSubmissions(userId: String) async throws -> [FormSubmission] {
        let query = FirestoreCollection.formSubmissions.reference()
            .whereField("data.submittedBy", isEqualTo: userId)
            .order(by: "submissionDate", descending: true)
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: FormSubmission.self) }
    }
    
    /// Fetches form submissions for a specific student (useful for tracking student progress)
    func fetchStudentFormSubmissions(studentId: String) async throws -> [FormSubmission] {
        let query = FirestoreCollection.formSubmissions.reference()
            .whereField("data.studentId", isEqualTo: studentId)
            .order(by: "submissionDate", descending: true)
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: FormSubmission.self) }
    }
    
    // MARK: - Validation Helpers

    private func isValueEmpty(_ value: Any) -> Bool {
        if let optionalValue = value as? (any OptionalProtocol) {
            return optionalValue.isNil
        }

        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if let array = value as? [Any] {
            return array.isEmpty
        }

        if let dict = value as? [String: Any] {
            return dict.isEmpty
        }

        return false
    }
    
    private func validateFieldRule(value: AnyCodable, rule: ValidationRule, fieldId: String) throws {
        switch rule.ruleType {
        case .required:
            if isValueEmpty(value.value) {
                throw ValidationError.validationFailed(field: fieldId, message: rule.message)
            }
        case .email:
            if let string = value.value as? String {
                let result = ValidationRules.email(string)
                if !result.isValid {
                    throw ValidationError.validationFailed(field: fieldId, message: result.errorMessage ?? rule.message)
                }
            }
        case .url:
            if let string = value.value as? String {
                let result = ValidationRules.url(string)
                if !result.isValid {
                    throw ValidationError.validationFailed(field: fieldId, message: result.errorMessage ?? rule.message)
                }
            }
        case .name:
            if let string = value.value as? String {
                let result = ValidationRules.name(string)
                if !result.isValid {
                    throw ValidationError.validationFailed(field: fieldId, message: result.errorMessage ?? rule.message)
                }
            }
        case .schoolName:
            if let string = value.value as? String {
                let result = ValidationRules.schoolName(string)
                if !result.isValid {
                    throw ValidationError.validationFailed(field: fieldId, message: result.errorMessage ?? rule.message)
                }
            }
        case .phone:
            if let string = value.value as? String {
                let result = ValidationRules.phoneNumber(string)
                if !result.isValid {
                    throw ValidationError.validationFailed(field: fieldId, message: result.errorMessage ?? rule.message)
                }
            }
        case .textLength:
            if let params = rule.parameters, case let .textLength(min, max, fieldName) = params, let string = value.value as? String {
                let result = ValidationRules.textLength(string, min: min, max: max, fieldName: fieldName)
                if !result.isValid {
                    throw ValidationError.validationFailed(field: fieldId, message: result.errorMessage ?? rule.message)
                }
            }
        case .numericRange:
            if let params = rule.parameters, case let .numericRange(min, max, fieldName) = params {
                if let intVal = value.value as? Int {
                    let result = ValidationRules.numericRange(intVal, min: min, max: max, fieldName: fieldName)
                    if !result.isValid {
                        throw ValidationError.validationFailed(field: fieldId, message: result.errorMessage ?? rule.message)
                    }
                } else if let doubleVal = value.value as? Double {
                    let result = ValidationRules.numericRange(doubleVal, min: Double(min), max: Double(max), fieldName: fieldName)
                    if !result.isValid {
                        throw ValidationError.validationFailed(field: fieldId, message: result.errorMessage ?? rule.message)
                    }
                }
            }
        case .collectionSize:
            if let params = rule.parameters, case let .collectionSize(min, max, fieldName) = params, let collection = value.value as? [Any] {
                let result = ValidationRules.collectionSize(collection, min: min, max: max, fieldName: fieldName)
                if !result.isValid {
                    throw ValidationError.validationFailed(field: fieldId, message: result.errorMessage ?? rule.message)
                }
            }
        case .date:
            if let params = rule.parameters, case let .date(after, before, fieldName) = params, let dateVal = value.value as? Date {
                let result = ValidationRules.date(dateVal, after: after, before: before, fieldName: fieldName)
                if !result.isValid {
                    throw ValidationError.validationFailed(field: fieldId, message: result.errorMessage ?? rule.message)
                }
            }
        case .custom:
            if let params = rule.parameters, case let .custom(validator) = params {
                if !validator(value.value) {
                    throw ValidationError.validationFailed(field: fieldId, message: rule.message)
                }
            }
        }
    }

}

struct FormFieldValidator {
    static let validators: [FieldType: @Sendable (AnyCodable) -> Bool] = [
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
            guard
                let urlString = $0.value as? String,
                let components = URLComponents(string: urlString),
                let scheme = components.scheme?.lowercased(),
                let host = components.host,
                !host.isEmpty
            else {
                return false
            }

            return scheme == "http" || scheme == "https"
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
