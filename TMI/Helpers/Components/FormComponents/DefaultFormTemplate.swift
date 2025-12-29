//
//  DefaultFormTemplate.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import Foundation

struct DefaultFormTemplates {
    
    static let studentEnrollmentFormTemplate: FormTemplate = {
        // Student Personal Details Section
        let studentPersonalDetailsSection = DefaultSectionTemplates.studentPersonalDetails

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
            name: "Student Enrollment Form",
            templateDescription: "A comprehensive form to enroll a student including personal details, medical information, and emergency contacts.",
            sections: [studentPersonalDetailsSection, addressSection, medicalInformationSection, emergencyContactSection, consentSection],
            createdAt: Date(),
            updatedAt: Date(),
            isActive: true,
            imageName: "doc.plaintext"
        )
    }()

    
    static var mentorApplicationFormTemplate: FormTemplate {
        // Personal Information Section
        let personalInformationSection = DefaultSectionTemplates.personalDetails
        
        // Employment History Section
        let employmentHistorySection = DefaultSectionTemplates.employmentHistory
        
        // Education Background Section
        let educationBackgroundSection = DefaultSectionTemplates.educationBackground
        
        let fileUploadSection = DefaultSectionTemplates.fileUpload
        
        let declarationSection = DefaultSectionTemplates.declaration
        
        return FormTemplate(
            id: UUID().uuidString,
            name: "Mentor Application Form",
            templateDescription: "A detailed form for mentor application including personal details, employment history, education background, and document uploads.",
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

