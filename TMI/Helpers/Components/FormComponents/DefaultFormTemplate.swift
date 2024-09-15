//
//  DefaultFormTemplate.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import Foundation

struct DefaultFormTemplates {
    
    static let camperRegistrationFormTemplate: FormTemplate = {
        // Camper Personal Details Section
        let camperPersonalDetailsSection = DefaultSectionTemplates.camperPersonalDetails

        // Address Section
        let addressSection = DefaultSectionTemplates.address

        // Medical Information Section
        let medicalInformationSection = DefaultSectionTemplates.medicalForm

        // Emergency Contact Section
        let emergencyContactSection = DefaultSectionTemplates.emergencyContact

        // Consent Section
        let consentSection = DefaultSectionTemplates.photoConsent

        return FormTemplate(
            id: UUID().uuidString,
            name: "Camper Registration Form",
            templateDescription: "A comprehensive form to register a camper including personal details, medical information, and emergency contacts.",
            sections: [camperPersonalDetailsSection, addressSection, medicalInformationSection, emergencyContactSection, consentSection],
            createdAt: Date(),
            updatedAt: Date(),
            isActive: true,
            imageName: "doc.plaintext"
        )
    }()

    
    static var jobApplicationFormTemplate: FormTemplate {
        // Personal Information Section
        let personalInformationSection = DefaultSectionTemplates.personalDetails
        
        // Employment History Section
        let employmentHistorySection = DefaultSectionTemplates.employmentHistory
        
        // Education Background Section
        let educationBackgroundSection = DefaultSectionTemplates.eductionBackground
        
        let fileUploadSection = DefaultSectionTemplates.fileUpload
        
        let declarationSection = DefaultSectionTemplates.declaration
        
        return FormTemplate(
            id: UUID().uuidString,
            name: "Job Application Form",
            templateDescription: "A detailed form for job application including personal details, employment history, education background, and document uploads.",
            sections: [personalInformationSection, employmentHistorySection, educationBackgroundSection, fileUploadSection, declarationSection],
            createdAt: Date(),
            updatedAt: Date(),
            isActive: true,
            imageName: "doc.plaintext" // Updated image URL placeholder
        )
    }
        
    // Export the template as JSON
    static func exportAsJSON(template: FormTemplate) -> String? {
        guard let jsonData = try? JSONEncoder().encode(template) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }
    
    // Import a template from JSON
    static func importFromJSON(_ jsonString: String) -> FormTemplate? {
        guard let jsonData = jsonString.data(using: .utf8),
              let template = try? JSONDecoder().decode(FormTemplate.self, from: jsonData) else { return nil }
        return template
    }
}

