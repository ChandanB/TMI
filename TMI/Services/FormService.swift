//
//  FormService.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import Firebase
import FirebaseAuth

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
    
    // MARK: - Validation Helper
    
    private func validateFieldRule(value: AnyCodable, rule: ValidationRule, fieldId: String) throws {
        switch rule.rule {
        case .minLength:
            if let string = value.value as? String,
               let minLength = rule.value?.value as? Int,
               string.count < minLength {
                throw ValidationError.validationFailed(fieldId, rule.message)
            }
        case .maxLength:
            if let string = value.value as? String,
               let maxLength = rule.value?.value as? Int,
               string.count > maxLength {
                throw ValidationError.validationFailed(fieldId, rule.message)
            }
        case .minValue:
            if let number = value.value as? Double,
               let minValue = rule.value?.value as? Double,
               number < minValue {
                throw ValidationError.validationFailed(fieldId, rule.message)
            }
        case .maxValue:
            if let number = value.value as? Double,
               let maxValue = rule.value?.value as? Double,
               number > maxValue {
                throw ValidationError.validationFailed(fieldId, rule.message)
            }
        // case .custom:
            // Custom validation would be implemented based on specific requirements
            // break
        default:
            break
        }
    }

}

enum ValidationError: Error, LocalizedError {
    case missingRequiredField(String)
    case invalidDataType(String)
    case validationFailed(String, String)
    
    var errorDescription: String? {
        switch self {
        case .missingRequiredField(let fieldId):
            return "Missing required field: \(fieldId)"
        case .invalidDataType(let fieldId):
            return "Invalid data type for field: \(fieldId)"
        case .validationFailed(let fieldId, let message):
            return "Validation failed for field \(fieldId): \(message)"
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